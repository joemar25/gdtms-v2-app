// DOCS: docs/development-standards.md
// DOCS: docs/shared/helpers.md — update that file when you edit this one.

import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';

/// Centralized logic to determine if a delivery is in a "locked" (read-only) state.
///
/// A delivery is locked if it is:
/// - [DeliveryStatus.delivered]
/// - [DeliveryStatus.osa]
/// - [DeliveryStatus.failedDelivery] and [FailedDeliveryVerificationStatus.isVerified]
/// - [DeliveryStatus.failedDelivery] and attempts >= 3
bool checkIsLocked({
  required String status,
  required String rtsVerificationStatus,
  int attempts = 0,
}) {
  final ds = DeliveryStatus.fromString(status);
  final rv = FailedDeliveryVerificationStatus.fromString(rtsVerificationStatus);

  return ds == DeliveryStatus.delivered ||
      ds == DeliveryStatus.osa ||
      (ds == DeliveryStatus.failedDelivery && rv.isVerified) ||
      (ds == DeliveryStatus.failedDelivery && attempts >= 3);
}

/// Returns the number of failed delivery attempts for a delivery map.
///
/// Priority order:
///   1. `failed_delivery_count` — integer shipped by the server (v2.9 update, April 2026).
///   2. `failed_delivery_attempts` — full attempt objects (detail endpoint).
///   3. `rts_count` / `rts_attempts` — legacy fallbacks for backward compatibility.
///   4. `0` — safe default.
int getAttemptsCountFromMap(Map<String, dynamic> delivery) {
  // Helper to parse numeric-like values reliably.
  int? parseInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) {
      final p = int.tryParse(v);
      if (p != null) return p;
      final d = double.tryParse(v);
      if (d != null) return d.toInt();
    }
    return null;
  }

  // 1) Prefer explicit integer count keys (support snake_case and camelCase).
  final countKeys = <String>[
    'failed_delivery_count',
    'failedDeliveryCount',
    'failed_delivery_attempt_count',
    'failedAttemptCount',
    'failed_attempts_count',
    'failed_attempt_count',
    'rts_count',
    'rtsCount',
    'attempt_count',
    'attempts_count',
    'attempts',
  ];
  for (final k in countKeys) {
    final v = delivery[k];
    final parsed = parseInt(v);
    if (parsed != null) return parsed;
  }

  // 2) Fall back to attempt lists (detail endpoint arrays).
  final listKeys = <String>[
    'failed_delivery_attempts',
    'failedDeliveryAttempts',
    'rts_attempts',
    'rtsAttempts',
    'failed_attempts',
    '_failed_delivery_attempts',
    '_rts_attempts',
    'attempts',
  ];
  for (final k in listKeys) {
    final l = delivery[k];
    if (l is List) return l.length;
  }

  // 3) Nested object fallback (e.g. delivery['failed_delivery'] = { count, attempts }).
  final fd = delivery['failed_delivery'];
  if (fd is Map<String, dynamic>) {
    final v = fd['count'] ?? fd['attempt_count'] ?? fd['attempts'];
    final parsed = parseInt(v);
    if (parsed != null) return parsed;
    final l = fd['attempts'];
    if (l is List) return l.length;
  }

  return 0;
}

/// Helper to check locking state from a delivery map (rawJson decoded).
bool checkIsLockedFromMap(Map<String, dynamic> delivery) {
  final status = (delivery['delivery_status'] ?? 'FOR_DELIVERY').toString();
  final failedDeliveryVerif =
      (delivery['rts_verification_status'] ??
              delivery['_rts_verification_status'] ??
              delivery['failed_delivery_verification_status'] ??
              delivery['_failed_delivery_verification_status'] ??
              'unvalidated')
          .toString();

  final ds = DeliveryStatus.fromString(status);
  final attempts = getAttemptsCountFromMap(delivery);
  if (ds == DeliveryStatus.failedDelivery && attempts >= 3) return true;

  return checkIsLocked(
    status: status,
    rtsVerificationStatus: failedDeliveryVerif,
  );
}

/// Extension on LocalDelivery for convenient access to locking logic.
extension LocalDeliveryLocking on LocalDelivery {
  bool get isLocked => checkIsLockedFromMap(toDeliveryMap());
}
