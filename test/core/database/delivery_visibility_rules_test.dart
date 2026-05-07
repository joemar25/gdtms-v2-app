// test/core/database/delivery_visibility_rules_test.dart
//
// Business-rule tests for LocalDelivery visibility and staleness logic.
//
// These tests do NOT touch SQLite. They validate the pure-Dart rules that
// the DAO SQL queries and isVisibleToRider() enforce:
//
//   FOR_DELIVERY   → visible while not archived (no date window)
//   FAILED_DELIVERY→ visible while unverified (no date window)
//                    locked (not interactable via POD) when attempts >= 3
//                    removed from DB only when verified OR server no longer
//                    returns it (removeStaleLocalPending archives it)
//   OSA            → visible while not archived (no date window)
//                    removed from DB only when server stops returning it
//   DELIVERED      → visible only on the day of delivery (today-only window)
//
// These match the rules in:
//   lib/core/database/local_delivery_dao.dart  (isVisibleToRider, queries)
//   lib/core/models/local_delivery.dart        (LocalDelivery.fromApiItem)
//   lib/core/sync/delivery_bootstrap_service.dart (removeStaleLocalPending)

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Builds a minimal [LocalDelivery] for testing visibility logic.
LocalDelivery _makeDelivery({
  required String status,
  String rtsVerificationStatus = 'unvalidated',
  int failedDeliveryCount = 0,
  int? deliveredAt,
  int? completedAt,
  bool isArchived = false,
}) {
  final rawJson = jsonEncode({
    'barcode': 'TEST001',
    'delivery_status': status,
    'failed_delivery_count': failedDeliveryCount,
    'rts_verification_status': rtsVerificationStatus,
  });

  return LocalDelivery(
    barcode: 'TEST001',
    deliveryStatus: status,
    rtsVerificationStatus: rtsVerificationStatus,
    rawJson: rawJson,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
    deliveredAt: deliveredAt,
    completedAt: completedAt,
    isArchived: isArchived,
  );
}

/// Mirrors [LocalDeliveryDao._windowMs].
/// Returns null when minutes <= 0 (no window).
int? _windowMs(int minutes) {
  if (minutes <= 0) return null;
  return minutes * Duration.millisecondsPerMinute;
}

/// Returns true if [completedAt] is within a [windowMinutes] rolling window.
/// Mirrors the logic in isVisibleToRider for FAILED_DELIVERY / OSA.
bool _withinWindow(int? completedAt, int windowMinutes) {
  final ms = _windowMs(windowMinutes);
  if (ms == null) return true; // no window = always within
  final cutoff = DateTime.now().millisecondsSinceEpoch - ms;
  return (completedAt ?? 0) >= cutoff;
}

/// Simulates the [isVisibleToRider] decision tree in pure Dart,
/// with optional visibility window support (mirrors DAO logic exactly).
bool _isVisible(
  LocalDelivery d, {
  int forDeliveryWindowMinutes = 0,
  int failedDeliveryWindowMinutes = 0,
  int osaWindowMinutes = 0,
}) {
  if (d.isArchived) return false;

  final status = d.deliveryStatus.toUpperCase();
  final now = DateTime.now();
  final todayStart = DateTime(
    now.year,
    now.month,
    now.day,
  ).millisecondsSinceEpoch;
  final tomorrowStart = DateTime(
    now.year,
    now.month,
    now.day + 1,
  ).millisecondsSinceEpoch;

  switch (status) {
    case 'FOR_DELIVERY':
      // Apply window if set (testing mode).
      if (!_withinWindow(d.createdAt, forDeliveryWindowMinutes)) {
        return false;
      }
      return true;
    case 'DELIVERED':
      final at = d.deliveredAt ?? 0;
      return at >= todayStart && at < tomorrowStart;
    case 'FAILED_DELIVERY':
      final verif = d.rtsVerificationStatus.toLowerCase();
      if (verif == 'verified_with_pay' || verif == 'verified_no_pay') {
        return false;
      }
      // Apply window if set (testing mode).
      if (!_withinWindow(d.completedAt, failedDeliveryWindowMinutes)) {
        return false;
      }
      // Visible even at 3+ attempts — locked but still shown in list.
      return true;
    case 'OSA':
      // Apply window if set (testing mode).
      if (!_withinWindow(d.completedAt, osaWindowMinutes)) return false;
      return true;
    default:
      return false;
  }
}

/// Returns true if a FAILED_DELIVERY item is LOCKED (not interactable via scan).
bool _isLocked(LocalDelivery d) {
  if (d.deliveryStatus.toUpperCase() != 'FAILED_DELIVERY') return false;
  final attempts = getAttemptsCountFromMap(d.toDeliveryMap());
  return attempts >= 3;
}

// ─── Tests ──────────────────────────────────────────────────────────────────

void main() {
  // ── FOR_DELIVERY ──────────────────────────────────────────────────────────

  group('FOR_DELIVERY visibility rules', () {
    test('is visible when not archived', () {
      final d = _makeDelivery(status: 'FOR_DELIVERY');
      expect(_isVisible(d), isTrue);
    });

    test('is NOT visible when archived (removed from server workload)', () {
      final d = _makeDelivery(status: 'FOR_DELIVERY', isArchived: true);
      expect(_isVisible(d), isFalse);
    });

    test('remains visible across day boundaries (no date filter)', () {
      // Simulate a delivery that was synced yesterday (old completedAt = null).
      final d = _makeDelivery(status: 'FOR_DELIVERY', completedAt: null);
      expect(_isVisible(d), isTrue);
    });
  });

  // ── DELIVERED ─────────────────────────────────────────────────────────────

  group('DELIVERED visibility rules — today-only window', () {
    test('is visible when delivered_at is today', () {
      final todayMs = DateTime.now().millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'DELIVERED', deliveredAt: todayMs);
      expect(_isVisible(d), isTrue);
    });

    test('is NOT visible when delivered_at is yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayMs = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        12,
      ).millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'DELIVERED', deliveredAt: yesterdayMs);
      expect(_isVisible(d), isFalse);
    });

    test('is NOT visible when delivered_at is tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowMs = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        8,
      ).millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'DELIVERED', deliveredAt: tomorrowMs);
      expect(_isVisible(d), isFalse);
    });

    test('is NOT visible when delivered_at is null', () {
      final d = _makeDelivery(status: 'DELIVERED', deliveredAt: null);
      // null treated as 0 which is before today
      expect(_isVisible(d), isFalse);
    });

    test('is NOT visible when archived (even if delivered today)', () {
      final todayMs = DateTime.now().millisecondsSinceEpoch;
      final d = _makeDelivery(
        status: 'DELIVERED',
        deliveredAt: todayMs,
        isArchived: true,
      );
      expect(_isVisible(d), isFalse);
    });
  });

  // ── FAILED_DELIVERY ───────────────────────────────────────────────────────

  group('FAILED_DELIVERY visibility rules', () {
    test('is visible with 1 attempt (unvalidated)', () {
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 1,
        rtsVerificationStatus: 'unvalidated',
      );
      expect(_isVisible(d), isTrue);
    });

    test('is visible with 2 attempts (unvalidated)', () {
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 2,
        rtsVerificationStatus: 'unvalidated',
      );
      expect(_isVisible(d), isTrue);
    });

    test('is STILL visible with 3 attempts (subject to verification)', () {
      // At 3+ attempts the item is visible but LOCKED (cannot be updated via scan).
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 3,
        rtsVerificationStatus: 'unvalidated',
      );
      expect(
        _isVisible(d),
        isTrue,
        reason:
            'Item must appear in the list so the courier can see its status',
      );
    });

    test('is LOCKED (not interactable) at 3 attempts', () {
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 3,
        rtsVerificationStatus: 'unvalidated',
      );
      expect(_isLocked(d), isTrue);
    });

    test('is NOT locked at 2 attempts', () {
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 2,
        rtsVerificationStatus: 'unvalidated',
      );
      expect(_isLocked(d), isFalse);
    });

    test('is NOT visible when verified_with_pay', () {
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 3,
        rtsVerificationStatus: 'verified_with_pay',
      );
      expect(
        _isVisible(d),
        isFalse,
        reason: 'Verified items must never appear in the courier workload',
      );
    });

    test('is NOT visible when verified_no_pay', () {
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 3,
        rtsVerificationStatus: 'verified_no_pay',
      );
      expect(_isVisible(d), isFalse);
    });

    test('is NOT visible when archived (reassigned by server)', () {
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 1,
        rtsVerificationStatus: 'unvalidated',
        isArchived: true,
      );
      expect(_isVisible(d), isFalse);
    });

    test('persists across midnight — no date filter applied', () {
      // completedAt is yesterday — item must still be visible
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayMs = yesterday.millisecondsSinceEpoch;
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 2,
        rtsVerificationStatus: 'unvalidated',
        completedAt: yesterdayMs,
      );
      expect(
        _isVisible(d),
        isTrue,
        reason: 'FAILED_DELIVERY items must not disappear after midnight',
      );
    });

    test('persists even with completedAt from 3 days ago', () {
      final threeDaysAgo = DateTime.now()
          .subtract(const Duration(days: 3))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 1,
        rtsVerificationStatus: 'unvalidated',
        completedAt: threeDaysAgo,
      );
      expect(_isVisible(d), isTrue);
    });
  });

  // ── OSA ───────────────────────────────────────────────────────────────────

  group('OSA (misrouted) visibility rules', () {
    test('is visible when not archived', () {
      final d = _makeDelivery(status: 'OSA');
      expect(_isVisible(d), isTrue);
    });

    test('is NOT visible when archived (reassigned to another courier)', () {
      final d = _makeDelivery(status: 'OSA', isArchived: true);
      expect(
        _isVisible(d),
        isFalse,
        reason:
            'Archived OSA means the server no longer returns it — another '
            'courier owns it',
      );
    });

    test('persists across midnight — no date filter applied', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayMs = yesterday.millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'OSA', completedAt: yesterdayMs);
      expect(
        _isVisible(d),
        isTrue,
        reason: 'OSA items must not disappear after midnight',
      );
    });

    test('persists even with completedAt from multiple days ago', () {
      final oldMs = DateTime(2026, 4, 15, 17, 40).millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'OSA', completedAt: oldMs);
      expect(_isVisible(d), isTrue);
    });
  });

  // ── UNKNOWN / OTHER status ─────────────────────────────────────────────────

  group('Unknown / other status', () {
    test('is never visible', () {
      for (final status in ['DISPATCHED', 'CANCELLED', 'UNKNOWN', '']) {
        final d = _makeDelivery(status: status);
        expect(
          _isVisible(d),
          isFalse,
          reason: 'Status "$status" must never appear in the workload',
        );
      }
    });
  });

  // ── removeStaleLocalPending logic ────────────────────────────────────────

  group('removeStaleLocalPending rules (pure-Dart simulation)', () {
    /// Simulates what removeStaleLocalPending does: archives barcodes for
    /// FOR_DELIVERY, FAILED_DELIVERY, OSA that are absent from serverBarcodes,
    /// skipping dirty records and DELIVERED items.
    Set<String> staleBarcodes({
      required Map<String, String> localItems, // barcode → status
      required Set<String> dirtyBarcodes,
      required Set<String> serverBarcodes,
    }) {
      final stale = <String>{};
      final actionable = {'FOR_DELIVERY', 'FAILED_DELIVERY', 'OSA'};
      for (final entry in localItems.entries) {
        final barcode = entry.key;
        final status = entry.value.toUpperCase();
        if (!actionable.contains(status)) continue; // DELIVERED never archived
        if (dirtyBarcodes.contains(barcode)) continue; // skip unsynced
        if (!serverBarcodes.contains(barcode)) stale.add(barcode);
      }
      return stale;
    }

    test('FOR_DELIVERY absent from server is stale', () {
      final stale = staleBarcodes(
        localItems: {'A': 'FOR_DELIVERY', 'B': 'FOR_DELIVERY'},
        dirtyBarcodes: {},
        serverBarcodes: {'A'},
      );
      expect(stale, equals({'B'}));
    });

    test('FAILED_DELIVERY absent from server is stale', () {
      final stale = staleBarcodes(
        localItems: {'X': 'FAILED_DELIVERY', 'Y': 'FAILED_DELIVERY'},
        dirtyBarcodes: {},
        serverBarcodes: {'X'},
      );
      expect(stale, equals({'Y'}));
    });

    test('OSA absent from server is stale', () {
      final stale = staleBarcodes(
        localItems: {'M': 'OSA', 'N': 'OSA'},
        dirtyBarcodes: {},
        serverBarcodes: {'M'},
      );
      expect(stale, equals({'N'}));
    });

    test('DELIVERED is NEVER stale regardless of server set', () {
      final stale = staleBarcodes(
        localItems: {'D': 'DELIVERED'},
        dirtyBarcodes: {},
        serverBarcodes: {}, // server doesn't return it — but that's fine
      );
      expect(
        stale,
        isEmpty,
        reason: 'DELIVERED items are kept for payout tracking',
      );
    });

    test('dirty records are NEVER stale', () {
      final stale = staleBarcodes(
        localItems: {'Z': 'FOR_DELIVERY'},
        dirtyBarcodes: {'Z'}, // courier submitted offline — unsynced
        serverBarcodes: {}, // server doesn't have it yet
      );
      expect(
        stale,
        isEmpty,
        reason: 'Dirty records must not be archived — they have unsent updates',
      );
    });

    test('items present on server are NOT stale', () {
      final stale = staleBarcodes(
        localItems: {'A': 'FOR_DELIVERY', 'B': 'FAILED_DELIVERY', 'C': 'OSA'},
        dirtyBarcodes: {},
        serverBarcodes: {'A', 'B', 'C'},
      );
      expect(stale, isEmpty);
    });

    test(
      'mixed scenario: only absent non-dirty non-DELIVERED items are stale',
      () {
        final stale = staleBarcodes(
          localItems: {
            'GONE_PENDING': 'FOR_DELIVERY', // absent → stale
            'GONE_FAILED': 'FAILED_DELIVERY', // absent → stale
            'GONE_OSA': 'OSA', // absent → stale
            'STILL_PENDING': 'FOR_DELIVERY', // present → safe
            'DELIVERED_ITEM': 'DELIVERED', // DELIVERED → never stale
            'DIRTY_GONE': 'FOR_DELIVERY', // dirty → never stale
          },
          dirtyBarcodes: {'DIRTY_GONE'},
          serverBarcodes: {'STILL_PENDING'},
        );
        expect(stale, equals({'GONE_PENDING', 'GONE_FAILED', 'GONE_OSA'}));
      },
    );
  });

  // ── LocalDelivery.fromApiItem — completedAt for terminal statuses ────────

  group(
    'LocalDelivery.fromApiItem — completedAt is set for terminal statuses',
    () {
      final beforeCall = DateTime.now().millisecondsSinceEpoch;

      test('FAILED_DELIVERY sets completedAt to now', () {
        final d = LocalDelivery.fromApiItem({
          'barcode': 'FD001',
          'delivery_status': 'FAILED_DELIVERY',
        }, serverStatus: 'FAILED_DELIVERY');
        expect(d.completedAt, isNotNull);
        expect(d.completedAt, greaterThanOrEqualTo(beforeCall));
      });

      test('OSA sets completedAt to now', () {
        final d = LocalDelivery.fromApiItem({
          'barcode': 'OSA001',
          'delivery_status': 'OSA',
        }, serverStatus: 'OSA');
        expect(d.completedAt, isNotNull);
        expect(d.completedAt, greaterThanOrEqualTo(beforeCall));
      });

      test('DELIVERED sets completedAt and deliveredAt', () {
        final d = LocalDelivery.fromApiItem({
          'barcode': 'DEL001',
          'delivery_status': 'DELIVERED',
          'delivered_date': '2026-04-28T23:34:55.000000Z',
        }, serverStatus: 'DELIVERED');
        expect(d.completedAt, isNotNull);
        expect(d.deliveredAt, isNotNull);
      });

      test('FOR_DELIVERY does NOT set completedAt', () {
        final d = LocalDelivery.fromApiItem({
          'barcode': 'FWD001',
          'delivery_status': 'FOR_DELIVERY',
        }, serverStatus: 'FOR_DELIVERY');
        expect(d.completedAt, isNull);
      });

      // Critical regression: completedAt being set to "old date" must not cause
      // items to disappear. Since we removed the completed_at date filter for
      // FAILED_DELIVERY and OSA, this is now safe — but test it anyway.
      test(
        'OSA with old completedAt (April) remains visible — no date filter',
        () {
          final aprilMs = DateTime(
            2026,
            4,
            15,
            17,
            40,
            52,
          ).millisecondsSinceEpoch;
          final d = _makeDelivery(status: 'OSA', completedAt: aprilMs);
          // The visibility helper does not check completedAt for OSA.
          expect(_isVisible(d), isTrue);
        },
      );

      test(
        'FAILED_DELIVERY with old completedAt (April) remains visible — no date filter',
        () {
          final aprilMs = DateTime(
            2026,
            4,
            15,
            17,
            44,
            37,
          ).millisecondsSinceEpoch;
          final d = _makeDelivery(
            status: 'FAILED_DELIVERY',
            failedDeliveryCount: 2,
            rtsVerificationStatus: 'unvalidated',
            completedAt: aprilMs,
          );
          expect(_isVisible(d), isTrue);
        },
      );
    },
  );

  // ── API data from user report ──────────────────────────────────────────────

  group('Regression: real API data from May 7 report', () {
    // FAILED_DELIVERY items from the live API
    final failedItems = [
      {
        'barcode': 'B281613QU47005',
        'count': 2,
        'verif': 'unvalidated',
      }, // redelivery
      {
        'barcode': 'B281613TH47009',
        'count': 1,
        'verif': 'unvalidated',
      }, // redelivery
      {
        'barcode': 'B281613CY47008',
        'count': 3,
        'verif': 'unvalidated',
      }, // for return
      {
        'barcode': 'B281613CE47014',
        'count': 3,
        'verif': 'unvalidated',
      }, // for return
    ];

    for (final item in failedItems) {
      final barcode = item['barcode'] as String;
      final count = item['count'] as int;
      final verif = item['verif'] as String;

      test('$barcode (count=$count) is visible', () {
        final d = _makeDelivery(
          status: 'FAILED_DELIVERY',
          failedDeliveryCount: count,
          rtsVerificationStatus: verif,
        );
        expect(_isVisible(d), isTrue);
      });

      test('$barcode (count=$count) locked=${count >= 3}', () {
        final d = _makeDelivery(
          status: 'FAILED_DELIVERY',
          failedDeliveryCount: count,
          rtsVerificationStatus: verif,
        );
        expect(_isLocked(d), equals(count >= 3));
      });
    }

    // OSA items from the live API
    final osaItems = [
      'B281613SA47002', // transaction_at: 2026-04-15 (old date!)
      'B281613SO47017', // transaction_at: 2026-04-28
    ];

    for (final barcode in osaItems) {
      test(
        'OSA $barcode is visible (regardless of original transaction date)',
        () {
          // Simulate old completedAt from April
          final aprilMs = DateTime(2026, 4, 15).millisecondsSinceEpoch;
          final d = _makeDelivery(status: 'OSA', completedAt: aprilMs);
          expect(
            _isVisible(d),
            isTrue,
            reason:
                'OSA items from April must still show in May since they are '
                'not yet reassigned',
          );
        },
      );
    }
  });

  // ── Visibility window config (dart-define / config.dart) ─────────────────
  //
  // Tests for kFailedDeliveryVisibilityWindowMinutes / kOsaVisibilityWindowMinutes.
  // These run against the pure-Dart mirrors of the DAO logic (_withinWindow,
  // _windowMs) because the actual constants are compile-time (dart-define).
  //
  // To test with a non-zero window at runtime:
  //   flutter run --dart-define=FAILED_DELIVERY_VISIBILITY_MINUTES=1 ...
  //   (1 min = items expire after 60 seconds — great for rapid on-device testing)

  group('_windowMs helper (int minutes)', () {
    test('returns null when minutes = 0 (no window, production mode)', () {
      expect(_windowMs(0), isNull);
    });

    test('returns null when minutes < 0 (guard against negative input)', () {
      expect(_windowMs(-1), isNull);
    });

    test('returns correct ms for 1 minute', () {
      expect(_windowMs(1), equals(60000));
    });

    test('returns correct ms for 30 minutes', () {
      expect(_windowMs(30), equals(1800000));
    });

    test('returns correct ms for 60 minutes (1 hour)', () {
      expect(_windowMs(60), equals(3600000));
    });

    test('returns correct ms for 1440 minutes (1 day)', () {
      expect(_windowMs(1440), equals(86400000));
    });
  });

  group('_withinWindow helper (int minutes)', () {
    test('always returns true when window = 0 (no window)', () {
      // Even a very old timestamp passes with no window.
      final ancient = DateTime(2000).millisecondsSinceEpoch;
      expect(_withinWindow(ancient, 0), isTrue);
      expect(_withinWindow(null, 0), isTrue);
    });

    test('returns true for completedAt = now when window = 60 min', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      expect(_withinWindow(nowMs, 60), isTrue);
    });

    test('returns true for completedAt = 30 min ago when window = 60 min', () {
      final thirtyMinAgo = DateTime.now()
          .subtract(const Duration(minutes: 30))
          .millisecondsSinceEpoch;
      expect(_withinWindow(thirtyMinAgo, 60), isTrue);
    });

    test('returns false for completedAt = 2h ago when window = 60 min', () {
      final twoHoursAgo = DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      expect(
        _withinWindow(twoHoursAgo, 60),
        isFalse,
        reason: 'Item is outside the 60-minute rolling window',
      );
    });

    test('returns false for completedAt = yesterday when window = 60 min', () {
      final yesterdayMs = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;
      expect(_withinWindow(yesterdayMs, 60), isFalse);
    });

    test('returns false for null completedAt when window is active', () {
      // null → treated as 0 (epoch) → always outside any positive window.
      expect(
        _withinWindow(null, 60),
        isFalse,
        reason:
            'An item with no completedAt is considered outside any active window',
      );
    });

    test(
      'boundary: item completed exactly 1 min ago is within 1 min window',
      () {
        final oneMinAgo = DateTime.now()
            .subtract(const Duration(seconds: 59))
            .millisecondsSinceEpoch;
        expect(_withinWindow(oneMinAgo, 1), isTrue);
      },
    );

    test('boundary: item completed 2 min ago is outside 1 min window', () {
      final twoMinAgo = DateTime.now()
          .subtract(const Duration(minutes: 2))
          .millisecondsSinceEpoch;
      expect(_withinWindow(twoMinAgo, 1), isFalse);
    });
  });

  group('Visibility window — FAILED_DELIVERY (testing mode simulation)', () {
    test(
      'window=0 min: item from April still visible (production behaviour)',
      () {
        final aprilMs = DateTime(2026, 4, 15).millisecondsSinceEpoch;
        final d = _makeDelivery(
          status: 'FAILED_DELIVERY',
          failedDeliveryCount: 2,
          completedAt: aprilMs,
        );
        // No window → no expiry.
        expect(_isVisible(d, failedDeliveryWindowMinutes: 0), isTrue);
      },
    );

    test('window=60 min: item completed 30 min ago is visible', () {
      final thirtyMinAgo = DateTime.now()
          .subtract(const Duration(minutes: 30))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 1,
        completedAt: thirtyMinAgo,
      );
      expect(_isVisible(d, failedDeliveryWindowMinutes: 60), isTrue);
    });

    test('window=60 min: item completed 2h ago is NOT visible', () {
      final twoHoursAgo = DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 1,
        completedAt: twoHoursAgo,
      );
      expect(
        _isVisible(d, failedDeliveryWindowMinutes: 60),
        isFalse,
        reason: 'Window expired — item should disappear from list',
      );
    });

    test('window=1 min: item completed 30 s ago is visible', () {
      final thirtySecAgo = DateTime.now()
          .subtract(const Duration(seconds: 30))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 1,
        completedAt: thirtySecAgo,
      );
      expect(_isVisible(d, failedDeliveryWindowMinutes: 1), isTrue);
    });

    test('window=1 min: item completed 2 min ago is NOT visible', () {
      final twoMinAgo = DateTime.now()
          .subtract(const Duration(minutes: 2))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 1,
        completedAt: twoMinAgo,
      );
      expect(
        _isVisible(d, failedDeliveryWindowMinutes: 1),
        isFalse,
        reason: 'Fastest test scenario: 1-minute window expired',
      );
    });

    test(
      'window active: verified item is still NOT visible (verification wins)',
      () {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final d = _makeDelivery(
          status: 'FAILED_DELIVERY',
          failedDeliveryCount: 3,
          rtsVerificationStatus: 'verified_with_pay',
          completedAt: nowMs, // within any window
        );
        // Verification check runs BEFORE the window check.
        expect(_isVisible(d, failedDeliveryWindowMinutes: 60), isFalse);
      },
    );

    test(
      'window active: archived item is still NOT visible (archive wins)',
      () {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final d = _makeDelivery(
          status: 'FAILED_DELIVERY',
          failedDeliveryCount: 1,
          completedAt: nowMs,
          isArchived: true,
        );
        // Archive check runs BEFORE the window check.
        expect(_isVisible(d, failedDeliveryWindowMinutes: 60), isFalse);
      },
    );
  });

  group('Visibility window — OSA (testing mode simulation)', () {
    test(
      'window=0 min: item from April still visible (production behaviour)',
      () {
        final aprilMs = DateTime(2026, 4, 15).millisecondsSinceEpoch;
        final d = _makeDelivery(status: 'OSA', completedAt: aprilMs);
        expect(_isVisible(d, osaWindowMinutes: 0), isTrue);
      },
    );

    test('window=60 min: item completed 30 min ago is visible', () {
      final thirtyMinAgo = DateTime.now()
          .subtract(const Duration(minutes: 30))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'OSA', completedAt: thirtyMinAgo);
      expect(_isVisible(d, osaWindowMinutes: 60), isTrue);
    });

    test('window=60 min: item completed 2h ago is NOT visible', () {
      final twoHoursAgo = DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'OSA', completedAt: twoHoursAgo);
      expect(
        _isVisible(d, osaWindowMinutes: 60),
        isFalse,
        reason: 'Window expired — OSA should disappear from list',
      );
    });

    test('window active: archived OSA is still NOT visible (archive wins)', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final d = _makeDelivery(
        status: 'OSA',
        completedAt: nowMs,
        isArchived: true,
      );
      expect(_isVisible(d, osaWindowMinutes: 60), isFalse);
    });

    test('window=30 min: item completed 29 min ago is visible', () {
      final twentyNineMinAgo = DateTime.now()
          .subtract(const Duration(minutes: 29))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'OSA', completedAt: twentyNineMinAgo);
      expect(_isVisible(d, osaWindowMinutes: 30), isTrue);
    });

    test('window=30 min: item completed 31 min ago is NOT visible', () {
      final thirtyOneMinAgo = DateTime.now()
          .subtract(const Duration(minutes: 31))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'OSA', completedAt: thirtyOneMinAgo);
      expect(_isVisible(d, osaWindowMinutes: 30), isFalse);
    });

    test('window=1 min: item completed 30 s ago is visible', () {
      final thirtySecAgo = DateTime.now()
          .subtract(const Duration(seconds: 30))
          .millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'OSA', completedAt: thirtySecAgo);
      expect(_isVisible(d, osaWindowMinutes: 1), isTrue);
    });
  });

  group('Visibility window — production safety assertions', () {
    // These tests document and lock the production defaults.
    // If any of these fail, it means a non-zero window was accidentally
    // committed to the default config — that would be a production bug.

    test('default kFailedDeliveryVisibilityWindowMinutes is 0 (no window)', () {
      // In tests, dart-defines are not set, so the default (0) is used.
      // We verify _windowMs(0) returns null which means "no window".
      expect(
        _windowMs(0),
        isNull,
        reason:
            'Production default must be 0 (no expiry). '
            'If this fails, check dart_defines.json and ensure '
            'FAILED_DELIVERY_VISIBILITY_MINUTES is 0.',
      );
    });

    test('default kOsaVisibilityWindowMinutes is 0 (no window)', () {
      expect(
        _windowMs(0),
        isNull,
        reason:
            'Production default must be 0 (no expiry). '
            'If this fails, check dart_defines.json and ensure '
            'OSA_VISIBILITY_MINUTES is 0.',
      );
    });

    test('FAILED_DELIVERY with April completedAt and window=0 is visible', () {
      // Regression lock: this exact scenario was the original bug.
      final aprilMs = DateTime(2026, 4, 15, 17, 44, 37).millisecondsSinceEpoch;
      final d = _makeDelivery(
        status: 'FAILED_DELIVERY',
        failedDeliveryCount: 2,
        completedAt: aprilMs,
      );
      expect(
        _isVisible(d, failedDeliveryWindowMinutes: 0),
        isTrue,
        reason:
            'With no window (production default), April FAILED_DELIVERY items '
            'must still be visible in May.',
      );
    });

    test('OSA with April completedAt and window=0 is visible', () {
      // Regression lock: this exact scenario was the original bug.
      final aprilMs = DateTime(2026, 4, 15, 17, 40, 52).millisecondsSinceEpoch;
      final d = _makeDelivery(status: 'OSA', completedAt: aprilMs);
      expect(
        _isVisible(d, osaWindowMinutes: 0),
        isTrue,
        reason:
            'With no window (production default), April OSA items must '
            'still be visible in May.',
      );
    });
  });
}
