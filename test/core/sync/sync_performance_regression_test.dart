import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/core/sync/sync_upsert_policy.dart';
import 'package:fsi_courier_app/core/sync/sync_write_coordinator.dart';

/// Cross-cutting regression checks for P1/P2/P5/A3 + no-lost-update gates.
void main() {
  group('Production performance + safety regression matrix', () {
    test('P2 page size stays in safe band (100–200)', () {
      expect(
        DeliveryBootstrapService.kSyncPerPage,
        allOf(greaterThanOrEqualTo(100), lessThanOrEqualTo(200)),
      );
    });

    test('P1 concurrency model: 4 status * N pages never drops page indices',
        () {
      // 4 statuses × 5 pages: each status still needs pages 1..5.
      const lastPage = 5;
      final remaining = DeliverySyncPaging.remainingPages(lastPage);
      final chunks = DeliverySyncPaging.chunkPages(remaining, 3);
      final flattened = chunks.expand((c) => c).toList();
      expect(flattened, [2, 3, 4, 5]);
      expect(
        DeliverySyncPaging.expectedListCallsForStatus(lastPage),
        lastPage,
      );
    });

    test('P5 never skips dirty rows (protects offline courier POD)', () {
      expect(
        SyncUpsertPolicy.shouldSkipUnchangedChecksum(
          isDirty: true,
          existingChecksum: 'x',
          incomingChecksum: 'x',
        ),
        isFalse,
      );
    });

    test('A3 + offline completeWrite still refreshes without flush', () async {
      final container = ProviderContainer(
        overrides: [isOnlineProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      await container
          .read(syncWriteCoordinatorProvider)
          .completeWrite(
            reason: 'offline_submit',
            kickQueue: true,
            barcodes: {'OFFLINE1'},
          );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(container.read(deliveryRefreshProvider), greaterThanOrEqualTo(1));
      expect(
        container.read(lastDeliveryRefreshBarcodesProvider),
        contains('OFFLINE1'),
      );
    });

    test('requestFlush while offline does not throw and leaves queue alone',
        () async {
      final container = ProviderContainer(
        overrides: [isOnlineProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      // Empty SyncManager — must complete without error.
      await container
          .read(syncManagerProvider.notifier)
          .requestFlush(reason: 'regression_offline', awaitIdle: true);

      expect(container.read(syncManagerProvider).isSyncing, isFalse);
    });

    test('parallel status list order independence of barcode union', () {
      // Simulates Phase-2 collecting barcodes from parallel status maps.
      final serverBarcodesPerStatus = <String, Set<String>>{
        'FOR_DELIVERY': {'A', 'B'},
        'FAILED_DELIVERY': {'C'},
        'MISROUTED': {'D'},
        'DELIVERED': {'E'},
      };
      final all = <String>{
        for (final s in serverBarcodesPerStatus.values) ...s,
      };
      expect(all, {'A', 'B', 'C', 'D', 'E'});
    });
  });
}
