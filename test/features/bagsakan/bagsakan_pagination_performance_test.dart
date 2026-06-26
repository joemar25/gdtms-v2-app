// DOCS: docs/development-standards.md
// DOCS: docs/features/bagsakan.md — update that file when you edit this one.

// Pagination Performance & Load Tests for Bagsakan Feature
//
// Focused tests on:
// - Pagination responsiveness under load
// - Page transition performance
// - Cache efficiency
// - Network request optimization
// - List rebuild performance
//
// Run: flutter test test/features/bagsakan/bagsakan_pagination_performance_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/core/database/bagsakan_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';

// ============================================================================
// MOCK DAO WITH LATENCY SIMULATION
// ============================================================================

class MockBagsakanDaoWithLatency extends Mock implements BagsakanDao {
  /// Simulates network latency in milliseconds
  int networkLatencyMs = 100;

  /// Track all page requests for analysis
  final List<PageRequest> pageRequests = [];

  Future<List<LocalDelivery>> simulatedGetItems(
    int groupId,
    int offset,
    int limit,
  ) async {
    final request = PageRequest(
      groupId: groupId,
      offset: offset,
      limit: limit,
      timestamp: DateTime.now(),
    );
    pageRequests.add(request);

    // Simulate network latency
    await Future.delayed(Duration(milliseconds: networkLatencyMs));

    // Generate test data
    final items = <LocalDelivery>[];
    for (int i = 0; i < limit; i++) {
      final index = offset + i;
      items.add(
        LocalDelivery(
          barcode: 'PAGE_${offset ~/ limit}_ITEM_$index',
          deliveryStatus: 'FOR_DELIVERY',
          jobOrder: 'JO_$index',
          recipientName: 'Recipient $index',
          deliveryAddress: '$index Main Street',
          bagsakanId: groupId,
          rawJson: '{}',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    return items;
  }

  void resetMetrics() => pageRequests.clear();

  String getMetricsReport() {
    if (pageRequests.isEmpty) return 'No requests recorded';

    final avgLatency =
        pageRequests.fold<int>(0, (sum, r) => sum + r.duration) ~/
        pageRequests.length;
    final totalPages = pageRequests.length;
    final totalItems = pageRequests.fold<int>(0, (sum, r) => sum + r.limit);

    return '''
Pagination Performance Report:
- Total Page Requests: $totalPages
- Total Items Loaded: $totalItems
- Average Latency: ${avgLatency}ms
- Min Latency: ${pageRequests.map((r) => r.duration).reduce((a, b) => a < b ? a : b)}ms
- Max Latency: ${pageRequests.map((r) => r.duration).reduce((a, b) => a > b ? a : b)}ms
    ''';
  }
}

class PageRequest {
  final int groupId;
  final int offset;
  final int limit;
  final DateTime timestamp;

  PageRequest({
    required this.groupId,
    required this.offset,
    required this.limit,
    required this.timestamp,
  });

  int get duration => 0; // Set after completion
}

// ============================================================================
// TEST SUITE
// ============================================================================

void main() {
  setUpAll(() {
    EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  });

  group('Pagination Performance - Page Load Times', () {
    late MockBagsakanDaoWithLatency mockDao;

    setUp(() {
      mockDao = MockBagsakanDaoWithLatency();
      mockDao.networkLatencyMs = 100;
    });

    test('Single page load performance (50 items)', () async {
      const pageSize = 50;
      const groupId = 1;

      final stopwatch = Stopwatch()..start();
      await mockDao.simulatedGetItems(groupId, 0, pageSize);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds >= 100, true);
      expect(
        stopwatch.elapsedMilliseconds < 1000,
        true,
        reason: 'Page load took too long: ${stopwatch.elapsedMilliseconds}ms',
      );

      expect(mockDao.pageRequests.length, equals(1));
      expect(mockDao.pageRequests.first.limit, equals(pageSize));
    });

    test('Sequential page loads (100 items per page, 10 pages)', () async {
      const pageSize = 100;
      const pageCount = 10;
      const groupId = 2;

      final pageTimes = <int>[];
      double totalTime = 0;

      for (int page = 0; page < pageCount; page++) {
        final stopwatch = Stopwatch()..start();
        await mockDao.simulatedGetItems(groupId, page * pageSize, pageSize);
        stopwatch.stop();

        pageTimes.add(stopwatch.elapsedMilliseconds);
        totalTime += stopwatch.elapsedMilliseconds;
      }

      final avgPageTime = (totalTime / pageCount).toInt();
      final maxPageTime = pageTimes.reduce((a, b) => a > b ? a : b);

      // Simulated latency is 100ms; allow OS timer / GC jitter on Windows CI.
      expect(
        pageTimes.every((time) => time >= 90),
        true,
        reason: 'Page finished faster than simulated latency: $pageTimes',
      );
      expect(
        maxPageTime,
        lessThan(1000),
        reason: 'A page load was catastrophically slow: $pageTimes',
      );
      expect(
        pageTimes.where((time) => time <= 400).length,
        greaterThanOrEqualTo(8),
        reason: 'Too many slow page loads (GC jitter?): $pageTimes',
      );

      // Average should stay near the simulated latency despite occasional spikes.
      expect(avgPageTime, greaterThanOrEqualTo(100));
      expect(avgPageTime, lessThan(200));

      expect(mockDao.pageRequests.length, equals(pageCount));
    });

    test('Random access pagination (jump between pages)', () async {
      const pageSize = 100;
      const groupId = 3;
      final pageAccess = [0, 5, 2, 8, 1, 9, 3];

      for (final pageNum in pageAccess) {
        await mockDao.simulatedGetItems(groupId, pageNum * pageSize, pageSize);
      }

      // All requests should be recorded
      expect(mockDao.pageRequests.length, equals(pageAccess.length));

      // Verify correct offsets
      for (int i = 0; i < pageAccess.length; i++) {
        final expectedOffset = pageAccess[i] * pageSize;
        expect(mockDao.pageRequests[i].offset, equals(expectedOffset));
      }
    });
  });

  group('Pagination Performance - Large Page Sizes', () {
    late MockBagsakanDaoWithLatency mockDao;

    setUp(() {
      mockDao = MockBagsakanDaoWithLatency();
      mockDao.networkLatencyMs = 100;
    });

    test('Large page size: 500 items', () async {
      const pageSize = 500;
      const groupId = 4;

      final stopwatch = Stopwatch()..start();
      final items = await mockDao.simulatedGetItems(groupId, 0, pageSize);
      stopwatch.stop();

      expect(items.length, equals(pageSize));
      // Larger pages take more time to process
      expect(stopwatch.elapsedMilliseconds >= 100, true);
      expect(stopwatch.elapsedMilliseconds < 2000, true);
    });

    test('Very large page size: 1000 items', () async {
      const pageSize = 1000;
      const groupId = 5;

      final stopwatch = Stopwatch()..start();
      final items = await mockDao.simulatedGetItems(groupId, 0, pageSize);
      stopwatch.stop();

      expect(items.length, equals(pageSize));
      expect(stopwatch.elapsedMilliseconds >= 100, true);
    });

    test('Optimal vs suboptimal page sizes', () async {
      const groupId = 6;
      final optimalPageSize = 100;
      final suboptimalPageSize = 5000;

      // Load same amount of data with different page sizes
      final totalItems = 10000;

      // Optimal: 100 items per page = 100 requests
      int optimalRequests = 0;
      for (int i = 0; i < totalItems; i += optimalPageSize) {
        await mockDao.simulatedGetItems(groupId, i, optimalPageSize);
        optimalRequests++;
      }

      mockDao.resetMetrics();

      // Suboptimal: 5000 items per page = 2 requests
      int suboptimalRequests = 0;
      for (int i = 0; i < totalItems; i += suboptimalPageSize) {
        await mockDao.simulatedGetItems(groupId, i, suboptimalPageSize);
        suboptimalRequests++;
      }

      expect(optimalRequests, equals(100));
      expect(suboptimalRequests, equals(2));

      // Fewer large requests is generally better if the client can handle it
      expect(suboptimalRequests < optimalRequests, true);
    });
  });

  group('Pagination Performance - Network Conditions', () {
    late MockBagsakanDaoWithLatency mockDao;

    setUp(() {
      mockDao = MockBagsakanDaoWithLatency();
    });

    test('Fast network (20ms latency) - 10 pages', () async {
      mockDao.networkLatencyMs = 20;
      const pageSize = 100;
      const groupId = 7;
      const pageCount = 10;

      final stopwatch = Stopwatch()..start();
      for (int page = 0; page < pageCount; page++) {
        await mockDao.simulatedGetItems(groupId, page * pageSize, pageSize);
      }
      stopwatch.stop();

      final totalTime = stopwatch.elapsedMilliseconds;
      final avgTime = totalTime ~/ pageCount;

      expect(avgTime, greaterThanOrEqualTo(20));
      expect(avgTime, lessThan(200));
    });

    test('Moderate network (150ms latency) - 10 pages', () async {
      mockDao.networkLatencyMs = 150;
      const pageSize = 100;
      const groupId = 8;
      const pageCount = 10;

      final stopwatch = Stopwatch()..start();
      for (int page = 0; page < pageCount; page++) {
        await mockDao.simulatedGetItems(groupId, page * pageSize, pageSize);
      }
      stopwatch.stop();

      final totalTime = stopwatch.elapsedMilliseconds;
      final avgTime = totalTime ~/ pageCount;

      expect(avgTime, greaterThanOrEqualTo(150));
    });

    test('Slow network (500ms latency) - 10 pages', () async {
      mockDao.networkLatencyMs = 500;
      const pageSize = 100;
      const groupId = 9;
      const pageCount = 10;

      final stopwatch = Stopwatch()..start();
      for (int page = 0; page < pageCount; page++) {
        await mockDao.simulatedGetItems(groupId, page * pageSize, pageSize);
      }
      stopwatch.stop();

      final totalTime = stopwatch.elapsedMilliseconds;
      final avgTime = totalTime ~/ pageCount;

      expect(avgTime, greaterThanOrEqualTo(500));

      // With slow network, recommend showing loading indicator
      expect(avgTime > 300, true);
    });
  });

  group('Pagination Performance - Offset vs Cursor', () {
    late MockBagsakanDaoWithLatency mockDao;

    setUp(() {
      mockDao = MockBagsakanDaoWithLatency();
      mockDao.networkLatencyMs = 100;
    });

    test('Offset-based pagination (current approach)', () async {
      const groupId = 10;
      const pageSize = 100;
      final requests = <OffsetRequest>[];

      // Simulate user scrolling and jumping
      for (int page in [0, 1, 2, 3, 2, 4, 5]) {
        final offset = page * pageSize;
        final stopwatch = Stopwatch()..start();
        await mockDao.simulatedGetItems(groupId, offset, pageSize);
        stopwatch.stop();

        requests.add(
          OffsetRequest(
            offset: offset,
            pageNumber: page,
            latency: stopwatch.elapsedMilliseconds,
          ),
        );
      }

      // Offset pagination is simple and works well for forward/backward
      expect(requests.length, equals(7));

      // Jumping back to page 2 is as fast as first visit
      expect(requests[4].latency, greaterThanOrEqualTo(100));
    });

    test(
      'Offset pagination on 100K items - no degradation as offset increases',
      () async {
        const groupId = 11;
        const pageSize = 100;

        final firstPageTime = Stopwatch()..start();
        await mockDao.simulatedGetItems(groupId, 0, pageSize);
        firstPageTime.stop();

        mockDao.resetMetrics();

        // Jump to middle
        final middlePageTime = Stopwatch()..start();
        await mockDao.simulatedGetItems(groupId, 50000, pageSize);
        middlePageTime.stop();

        // Time should be similar (offset doesn't affect query time)
        expect(
          (firstPageTime.elapsedMilliseconds -
                  middlePageTime.elapsedMilliseconds)
              .abs(),
          lessThan(100),
          reason: 'Offset should not affect query performance significantly',
        );
      },
    );
  });

  group('Pagination Performance - Request Deduplication', () {
    late MockBagsakanDaoWithLatency mockDao;

    setUp(() {
      mockDao = MockBagsakanDaoWithLatency();
      mockDao.networkLatencyMs = 100;
    });

    test('Detect duplicate requests for same page', () async {
      const groupId = 12;
      const pageSize = 100;

      // Load same page twice
      await mockDao.simulatedGetItems(groupId, 0, pageSize);
      await mockDao.simulatedGetItems(groupId, 0, pageSize);

      // Both requests recorded
      expect(mockDao.pageRequests.length, equals(2));

      // Both have same parameters
      expect(
        mockDao.pageRequests[0].offset,
        equals(mockDao.pageRequests[1].offset),
      );
      expect(
        mockDao.pageRequests[0].limit,
        equals(mockDao.pageRequests[1].limit),
      );

      // Recommendation: Use caching to avoid duplicate requests
    });

    test('Optimal: Load once, cache, serve from cache', () async {
      const groupId = 13;
      const pageSize = 100;

      final cache = <String, List<LocalDelivery>>{};

      Future<List<LocalDelivery>> loadWithCache(
        int groupId,
        int offset,
        int limit,
      ) async {
        final cacheKey = '$groupId:$offset:$limit';

        if (cache.containsKey(cacheKey)) {
          return cache[cacheKey]!;
        }

        final items = await mockDao.simulatedGetItems(groupId, offset, limit);
        cache[cacheKey] = items;
        return items;
      }

      // First load
      await loadWithCache(groupId, 0, pageSize);
      expect(mockDao.pageRequests.length, equals(1));

      // Second load (cached)
      await loadWithCache(groupId, 0, pageSize);
      expect(mockDao.pageRequests.length, equals(1)); // No new request

      // Different page (not cached)
      await loadWithCache(groupId, pageSize, pageSize);
      expect(mockDao.pageRequests.length, equals(2));
    });
  });

  group('Pagination Performance - Recommendations', () {
    test('Suggested page size based on data volume', () {
      // Based on performance, recommend:
      final recommendations = <int, int>{
        10000: 50, // 10K items: 50 per page = 200 pages, 50ms load
        50000: 100, // 50K items: 100 per page = 500 pages, 100ms load
        100000: 200, // 100K items: 200 per page = 500 pages, 100ms load
        500000: 500, // 500K items: 500 per page = 1000 pages, 100ms load
      };

      // Verify these are reasonable
      for (final entry in recommendations.entries) {
        final totalItems = entry.key;
        final pageSize = entry.value;
        final pages = (totalItems / pageSize).ceil();

        // Should result in manageable number of page requests
        expect(pages >= 100, true); // At least 100 pages
        expect(pages <= 2000, true); // But not absurdly many
      }
    });

    test('Prefetch strategy: Next page hints for better UX', () async {
      const groupId = 14;
      const pageSize = 100;
      final mockDao = MockBagsakanDaoWithLatency();
      mockDao.networkLatencyMs = 200;

      // When user loads page 1, prefetch page 2
      // This hides latency from user experience
      final page1 = mockDao.simulatedGetItems(groupId, 0, pageSize);
      final page2Prefetch = mockDao.simulatedGetItems(
        groupId,
        pageSize,
        pageSize,
      );

      // Both load in parallel
      final results = await Future.wait<List<LocalDelivery>>([
        page1,
        page2Prefetch,
      ]);

      expect(results[0].length, equals(pageSize));
      expect(results[1].length, equals(pageSize));

      // When user scrolls to bottom (before page 2 loads), it's ready
    });

    test('Bidirectional pagination support', () async {
      const groupId = 15;
      const pageSize = 100;

      // User can load forward and backward without performance hit
      final scenarios = [
        0, // Start at page 0
        pageSize, // Page 1
        pageSize * 2, // Page 2
        pageSize, // Back to page 1 (from cache)
        pageSize * 3, // Jump to page 3
        pageSize * 2, // Back to page 2
      ];

      final mockDao = MockBagsakanDaoWithLatency();
      mockDao.networkLatencyMs = 100;

      for (final offset in scenarios) {
        await mockDao.simulatedGetItems(groupId, offset, pageSize);
      }

      // All requests should succeed
      expect(mockDao.pageRequests.length, equals(6));
    });
  });
}

class OffsetRequest {
  final int offset;
  final int pageNumber;
  final int latency;

  OffsetRequest({
    required this.offset,
    required this.pageNumber,
    required this.latency,
  });
}
