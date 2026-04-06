import 'package:fsi_courier_app/core/models/local_delivery.dart';

/// Centralized logic to determine if a delivery is in a "locked" (read-only) state.
///
/// A delivery is locked if it is:
/// - DELIVERED
/// - OSA
/// - RTS and has been verified (with or without pay)
bool checkIsLocked({
  required String status,
  required String rtsVerificationStatus,
  int attempts = 0,
}) {
  final s = status.toUpperCase();
  final v = rtsVerificationStatus.toLowerCase();

  final isDelivered = s == 'DELIVERED';
  final isOsa = s == 'OSA';
  final isRtsVerified =
      s == 'RTS' && (v == 'verified_with_pay' || v == 'verified_no_pay');
  final isRtsMaxAttempts = s == 'RTS' && attempts >= 3;

  return isDelivered || isOsa || isRtsVerified || isRtsMaxAttempts;
}

/// Returns the number of RTS attempts for a delivery map.
///
/// Priority order:
///   1. `rts_count` — integer shipped by the server on all list / delta-sync
///      payloads (guaranteed since the backend update, April 2026).
///   2. `rts_attempts` — full attempt objects returned only by the detail
///      endpoint (`GET /deliveries/:barcode`). Used as a local override so the
///      detail screen always shows the accurate count even before the next sync.
///   3. `0` — safe default if neither field is present.
int getAttemptsCountFromMap(Map<String, dynamic> delivery) {
  // 1. Prefer the server-provided integer count (list & delta-sync payloads).
  final rtsCount = delivery['rts_count'];
  if (rtsCount is num) return rtsCount.toInt();

  // 2. Fall back to counting the detail-endpoint attempts array.
  final attemptsList = delivery['rts_attempts'];
  if (attemptsList is List && attemptsList.isNotEmpty) {
    return attemptsList.whereType<Map<String, dynamic>>().length;
  }

  return 0;
}

/// Helper to check locking state from a delivery map (rawJson decoded).
bool checkIsLockedFromMap(Map<String, dynamic> delivery) {
  final status = (delivery['delivery_status'] ?? 'PENDING').toString();
  final rtsVerif =
      (delivery['rts_verification_status'] ??
              delivery['_rts_verification_status'] ??
              'unvalidated')
          .toString();

  // If it's an RTS item and attempts >= 3, consider it locked.
  final attempts = getAttemptsCountFromMap(delivery);
  if (status.toUpperCase() == 'RTS' && attempts >= 3) return true;

  return checkIsLocked(status: status, rtsVerificationStatus: rtsVerif);
}

/// Extension on LocalDelivery for convenient access to locking logic.
extension LocalDeliveryLocking on LocalDelivery {
  bool get isLocked => checkIsLockedFromMap(toDeliveryMap());
}
