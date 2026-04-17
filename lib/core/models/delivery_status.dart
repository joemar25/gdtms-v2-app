// DOCS: docs/core/models.md — update that file when you edit this one.

// =============================================================================
// delivery_status.dart — Single source of truth for all delivery status values
// =============================================================================
//
// ## Status Contract (API v2.8)
//
// The mobile app emits and expects FAILED_DELIVERY for failed-delivery outcomes.
// The backend normalises both FAILED_DELIVERY and RTS (legacy) on write and returns
// FAILED_DELIVERY on all read responses (GET list, GET detail, PATCH response).
//
// Defensive parsing: fromString() expects FAILED_DELIVERY.
//
// Everything else in the app uses this enum — there are no other places to change.
// =============================================================================

/// All possible delivery statuses in the FSI Courier app.
///
/// Use [fromString] to parse API / SQLite values.
/// Use [toApiString] / [toDbString] to serialise back to string for API calls
/// and SQLite writes.
enum DeliveryStatus {
  pending,
  delivered,

  /// Failed delivery — courier could not deliver; package returned to FSI.
  /// API contract: FAILED_DELIVERY.
  failedDelivery,

  /// Out of Serviceable Area — package misrouted and being resent.
  osa,

  /// Fallback for any unrecognised value returned by the API.
  unknown;

  // ── Parsing ───────────────────────────────────────────────────────────────

  /// Maps an API / SQLite string to a [DeliveryStatus].
  ///
  /// Case-insensitive. Returns [unknown] for unrecognised values.
  static DeliveryStatus fromString(String? value) {
    final v = value?.trim().toUpperCase() ?? '';

    // Common canonical values
    if (v == 'PENDING' || v == 'FOR_DELIVERY') return pending;

    // Server aliases / legacy values that should be treated as pending/actionable
    if (v == 'FOR_REDELIVERY' || v == 'REDELIVERY' || v == 'FOR_REATTEMPT' || v == 'REATTEMPT') return pending;

    if (v == 'DELIVERED') return delivered;

    // Accept both the new contract and legacy RTS token for failed delivery
    if (v == 'FAILED_DELIVERY' || v == 'RTS') return failedDelivery;

    if (v == 'OSA') return osa;

    return unknown;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// The string value sent to the backend API and stored in SQLite.
  /// Emits 'FAILED_DELIVERY' per the v2.7 contract.
  String toApiString() => switch (this) {
    pending => 'FOR_DELIVERY',
    delivered => 'DELIVERED',
    failedDelivery => 'FAILED_DELIVERY',
    osa => 'OSA',
    unknown => '',
  };

  /// The value written to the SQLite `delivery_status` column.
  String toDbString() => toApiString();

  // ── Display ───────────────────────────────────────────────────────────────

  /// Human-readable label for display in the UI.
  String get displayName => switch (this) {
    pending => 'Pending',
    delivered => 'Delivered',
    failedDelivery => 'Failed Delivery',
    osa => 'Misrouted',
    unknown => '—',
  };

  // ── Business logic ────────────────────────────────────────────────────────

  /// True when the delivery lifecycle is complete — no further courier action.
  bool get isFinal => switch (this) {
    delivered || failedDelivery || osa => true,
    _ => false,
  };

  /// True for any failed or non-delivered state.
  bool get isFailed => this == failedDelivery;

  /// True if this status should count as a failed delivery attempt on record.
  bool get shouldCountAsFailedAttempt => this == failedDelivery;

  /// True if the courier can still submit a status update for this delivery.
  bool get isUpdatable => this == pending || this == failedDelivery;

  /// True when the delivery has been physically completed (success or failed back to FSI).
  bool get isCompleted => isFinal;
}

// =============================================================================
// FailedDeliveryVerificationStatus — verification state after a failed delivery is
// returned to the FSI site.
// =============================================================================

/// Verification state of a failed delivery once physically returned to FSI.
///
/// Set by the FSI site team after the courier hands over the parcel.
/// Stored in SQLite as `rts_verification_status`.
enum FailedDeliveryVerificationStatus {
  /// Default — site team has not yet reviewed the returned parcel.
  unvalidated,

  /// Site team confirmed return and approved payment to the courier.
  verifiedWithPay,

  /// Site team confirmed return but no courier payment is due.
  verifiedNoPay;

  // ── Parsing ───────────────────────────────────────────────────────────────

  static FailedDeliveryVerificationStatus fromString(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'verified_with_pay' => verifiedWithPay,
      'verified_no_pay' => verifiedNoPay,
      _ => unvalidated,
    };
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  String toDbString() => switch (this) {
    unvalidated => 'unvalidated',
    verifiedWithPay => 'verified_with_pay',
    verifiedNoPay => 'verified_no_pay',
  };

  // ── Business logic ────────────────────────────────────────────────────────

  /// True when the site team has reviewed and finalised the return.
  bool get isVerified => this == verifiedWithPay || this == verifiedNoPay;

  /// True when payment to the courier was approved.
  bool get isWithPay => this == verifiedWithPay;
}
