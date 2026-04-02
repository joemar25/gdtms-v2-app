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
}) {
  final s = status.toUpperCase();
  final v = rtsVerificationStatus.toLowerCase();

  final isDelivered = s == 'DELIVERED';
  final isOsa = s == 'OSA';
  final isRtsVerified =
      s == 'RTS' && (v == 'verified_with_pay' || v == 'verified_no_pay');

  return isDelivered || isOsa || isRtsVerified;
}

/// Parse attempts count from a decoded delivery map.
/// Supports 'rts_attempts' (list) and numeric/string fields like 'attempts',
/// 'attempt_count', 'attempts_count', or 'delivery_attempts'.
int? _attemptsCountFromMap(Map<String, dynamic> delivery) {
  final attemptsList = delivery['rts_attempts'];
  if (attemptsList is List) {
    return attemptsList.whereType<Map<String, dynamic>>().length;
  }

  final candidates = [
    delivery['attempts'],
    delivery['attempt_count'],
    delivery['attempts_count'],
    delivery['delivery_attempts'],
    delivery['attemptsMade'],
    delivery['attempts_made'],
  ];

  for (final c in candidates) {
    if (c == null) continue;
    if (c is num) return c.toInt();
    final s = c.toString().trim();
    if (s.isEmpty) continue;
    final parsed = int.tryParse(s);
    if (parsed != null) return parsed;
  }

  return null;
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
  final attempts = _attemptsCountFromMap(delivery) ?? 0;
  if (status.toUpperCase() == 'RTS' && attempts >= 3) return true;

  return checkIsLocked(status: status, rtsVerificationStatus: rtsVerif);
}

/// Extension on LocalDelivery for convenient access to locking logic.
extension LocalDeliveryLocking on LocalDelivery {
  bool get isLocked => checkIsLockedFromMap(toDeliveryMap());
}
