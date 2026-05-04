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

  // Prefer explicit integer count keys.
  final v =
      delivery['failed_delivery_count'] ?? delivery['failedDeliveryCount'];
  final parsed = parseInt(v);
  if (parsed != null) return parsed;

  // Fallback to attempt lists if count is missing.
  final l =
      delivery['failed_delivery_attempts'] ??
      delivery['failedDeliveryAttempts'];
  if (l is List) return l.length;

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
