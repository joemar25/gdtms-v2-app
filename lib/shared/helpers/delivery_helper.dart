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
}) {
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
  final failedDeliveryVerif =
      (delivery['rts_verification_status'] ?? 'unvalidated').toString();
  final attempts = getAttemptsCountFromMap(delivery);

  return isTerminalState(
    status: status,
    rtsVerificationStatus: failedDeliveryVerif,
    attempts: attempts,
  );
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
  // RULE: Items assigned to a Bagsakan group are locked for individual action.
  if (delivery['bagsakan_id'] != null) return true;

  return isTerminalStateFromMap(delivery);
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
  final failedDeliveryVerif =
      (delivery['rts_verification_status'] ?? 'unvalidated').toString();
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
