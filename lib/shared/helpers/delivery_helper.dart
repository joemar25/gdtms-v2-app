// DOCS: docs/development-standards.md
// DOCS: docs/shared/helpers.md — update that file when you edit this one.

import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';

/// Centralized logic to determine if a delivery is in a "locked" (read-only) state.
///
/// A delivery record stored locally in SQLite after dispatch acceptance.
///
/// A delivery is locked if it is:
/// - [DeliveryStatus.delivered]
/// - [DeliveryStatus.misrouted] (Misrouted)
/// - [DeliveryStatus.failedDelivery] and [FailedDeliveryVerificationStatus.isVerified]
/// - [DeliveryStatus.failedDelivery] and attempts >= 3
bool checkIsLocked({
  required String status,
  required String rtsVerificationStatus,
  int attempts = 0,
  String syncStatus = 'clean',
}) {
  // If there is a pending local update (dirty), lock the item to prevent
  // duplicate submissions or re-delivery attempts.
  if (syncStatus == 'dirty') return true;

  return isTerminalState(
    status: status,
    rtsVerificationStatus: rtsVerificationStatus,
    attempts: attempts,
  );
}

/// Centralized logic to determine if a delivery is in a terminal state.
///
/// A terminal state means the delivery is finalized and no longer actionable
/// by the courier.
bool isTerminalState({
  required String status,
  required String rtsVerificationStatus,
  int attempts = 0,
}) {
  final ds = DeliveryStatus.fromString(status);
  final rv = FailedDeliveryVerificationStatus.fromString(rtsVerificationStatus);

  if (ds == DeliveryStatus.delivered || ds == DeliveryStatus.misrouted) {
    return true;
  }

  if (ds == DeliveryStatus.failedDelivery) {
    if (rv.isVerified) return true;
    if (attempts >= kMaxDeliveryAttempts) return true;
  }

  final statusUpper = status.toUpperCase();
  if (kTerminalDeliveryStatuses.contains(statusUpper)) return true;

  return false;
}

/// Helper to check if a delivery is in a terminal state from a delivery map.
bool isTerminalStateFromMap(Map<String, dynamic> delivery) {
  final status = (delivery['delivery_status'] ?? 'FOR_DELIVERY').toString();
  final failedDeliveryVerif = _rtsVerificationStatusFromMap(delivery);
  final attempts = getAttemptsCountFromMap(delivery);

  return isTerminalState(
    status: status,
    rtsVerificationStatus: failedDeliveryVerif,
    attempts: attempts,
  );
}

int? _parseAttemptCount(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String _rtsVerificationStatusFromMap(Map<String, dynamic> delivery) {
  return (delivery['_rts_verification_status'] ??
          delivery['rts_verification_status'] ??
          delivery['_failed_delivery_verification_status'] ??
          delivery['failed_delivery_verification_status'] ??
          'unvalidated')
      .toString();
}

/// Raw `delivery_attempts` from the API — use for display only.
int? rawDeliveryAttemptsFromMap(Map<String, dynamic> delivery) {
  return _parseAttemptCount(delivery['delivery_attempts']);
}

/// Attempt count for lock/tab rules — reads API fields only, no derived values.
///
///   1. `delivery_attempts` (v4.2)
///   2. `failed_delivery_count` (list/sync alias)
///   3. `0`
int getAttemptsCountFromMap(Map<String, dynamic> delivery) {
  return rawDeliveryAttemptsFromMap(delivery) ??
      _parseAttemptCount(delivery['failed_delivery_count']) ??
      0;
}

/// Privacy lock — hides PII and blocks the account-details sheet.
///
/// Excludes [bagsakan_id]: Bagsakan screens manage those items explicitly
/// (remove from group, propagation) and still need identifiable cards.
bool checkIsPrivacyLockedFromMap(Map<String, dynamic> delivery) {
  final status = (delivery['delivery_status'] ?? 'FOR_DELIVERY').toString();
  final failedDeliveryVerif = _rtsVerificationStatusFromMap(delivery);
  final attempts = getAttemptsCountFromMap(delivery);
  final syncStatus =
      (delivery['_sync_status'] ?? delivery['sync_status'] ?? 'clean')
          .toString();

  return checkIsLocked(
    status: status,
    rtsVerificationStatus: failedDeliveryVerif,
    attempts: attempts,
    syncStatus: syncStatus,
  );
}

/// Helper to check locking state from a delivery map (rawJson decoded).
bool checkIsLockedFromMap(Map<String, dynamic> delivery) {
  // RULE: Items assigned to a Bagsakan group are locked for individual action.
  if (delivery['bagsakan_id'] != null) return true;

  return checkIsPrivacyLockedFromMap(delivery);
}

/// Centralized logic to determine if a delivery is valid for a delivery attempt.
///
/// A delivery is valid for delivery if:
/// - Its status is in [kValidForDeliveryStatuses]
/// - If FAILED_DELIVERY, it has < [kMaxDeliveryAttempts]
/// - It is not archived
/// - It is not verified by the hub
bool isValidForDelivery({
  required String status,
  required String rtsVerificationStatus,
  int attempts = 0,
  bool isArchived = false,
}) {
  if (isArchived) return false;

  if (isTerminalState(
    status: status,
    rtsVerificationStatus: rtsVerificationStatus,
    attempts: attempts,
  )) {
    return false;
  }

  final statusUpper = status.toUpperCase();
  if (!kValidForDeliveryStatuses.contains(statusUpper)) return false;

  return true;
}

/// Helper to check if a delivery is valid for delivery from a delivery map.
bool isValidForDeliveryFromMap(Map<String, dynamic> delivery) {
  final status = (delivery['delivery_status'] ?? 'FOR_DELIVERY').toString();
  final failedDeliveryVerif = _rtsVerificationStatusFromMap(delivery);
  final isArchived = (delivery['is_archived'] ?? 0).toString() == '1';
  final attempts = getAttemptsCountFromMap(delivery);

  return isValidForDelivery(
    status: status,
    rtsVerificationStatus: failedDeliveryVerif,
    attempts: attempts,
    isArchived: isArchived,
  );
}

/// Extension on LocalDelivery for convenient access to locking logic.
extension LocalDeliveryLocking on LocalDelivery {
  bool get isLocked => checkIsLockedFromMap(toDeliveryMap());
  bool get isValidForDelivery => isValidForDeliveryFromMap(toDeliveryMap());
  bool get isTerminal => isTerminalStateFromMap(toDeliveryMap());
}
