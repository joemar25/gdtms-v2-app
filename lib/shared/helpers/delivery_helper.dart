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
  final isRtsVerified = s == 'RTS' && (v == 'verified_with_pay' || v == 'verified_no_pay');

  return isDelivered || isOsa || isRtsVerified;
}

/// Helper to check locking state from a delivery map (rawJson decoded).
bool checkIsLockedFromMap(Map<String, dynamic> delivery) {
  final status = (delivery['delivery_status'] ?? 'PENDING').toString();
  final rtsVerif = (delivery['rts_verification_status'] ?? 
                    delivery['_rts_verification_status'] ?? 
                    'unvalidated').toString();
  
  return checkIsLocked(
    status: status,
    rtsVerificationStatus: rtsVerif,
  );
}

/// Extension on LocalDelivery for convenient access to locking logic.
extension LocalDeliveryLocking on LocalDelivery {
  bool get isLocked => checkIsLocked(
    status: deliveryStatus,
    rtsVerificationStatus: rtsVerificationStatus,
  );
}
