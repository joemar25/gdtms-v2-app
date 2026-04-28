// DOCS: docs/core/models.md — update that file when you edit this one.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';

/// A delivery record stored locally in SQLite after dispatch acceptance.
///
/// [rawJson] holds the original server-side delivery JSON so all fields remain
/// available for display without additional API calls.
class LocalDelivery {
  const LocalDelivery({
    this.id,
    required this.barcode,
    this.trackingNumber,
    this.recipientName,
    this.deliveryAddress,
    required this.deliveryStatus,
    this.mailType,
    this.dispatchCode,
    required this.rawJson,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
    this.deliveredAt,
    this.completedAt,
    this.serverUpdatedAt,
    this.syncStatus = 'clean',
    this.isArchived = false,
    this.rtsVerificationStatus = 'unvalidated',
  });

  final int? id;
  final String barcode;
  final String? trackingNumber;
  final String? recipientName;
  final String? deliveryAddress;
  final String deliveryStatus;
  final String? mailType;
  final String? dispatchCode;

  /// Full server JSON blob — decoded via [toDeliveryMap] for UI widgets.
  final String rawJson;
  final int createdAt;
  final int updatedAt;

  /// Millisecond timestamp when this delivery was part of a paid payout.
  final int? paidAt;

  /// Millisecond timestamp when this delivery transitioned to [delivered] status.
  final int? deliveredAt;

  /// Millisecond timestamp when this delivery transitioned to any terminal
  /// status (delivered, failedDelivery, osa). used for today-only filtering.
  final int? completedAt;

  /// Timestamp of last server-side update.
  final int? serverUpdatedAt;

  /// 'clean', 'dirty', or 'conflict'
  final String syncStatus;

  /// True if missing from server list
  final bool isArchived;

  /// Failed delivery verification: 'unvalidated', 'verified_with_pay', 'verified_no_pay'
  final String rtsVerificationStatus;

  /// Typed [DeliveryStatus] for this delivery.
  ///
  /// Prefer this over comparing [deliveryStatus] string directly.
  DeliveryStatus get statusEnum => DeliveryStatus.fromString(deliveryStatus);

  /// Typed [FailedDeliveryVerificationStatus] for this delivery.
  FailedDeliveryVerificationStatus get failedDeliveryVerifEnum =>
      FailedDeliveryVerificationStatus.fromString(rtsVerificationStatus);

  /// Whether this delivery is in a non-actionable "locked" state.
  bool get isLocked => checkIsLocked(
    status: deliveryStatus,
    rtsVerificationStatus: rtsVerificationStatus,
  );

  // ── Factories ─────────────────────────────────────────────────────────────

  /// Constructs from a delivery object embedded in the eligibility response.
  ///
  /// Field mapping from API:  barcode_value, job_order, name, address,
  /// contact, product, special_instruction, delivery_status.
  factory LocalDelivery.fromJson(
    Map<String, dynamic> json, {
    required String dispatchCode,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // barcode_value is the primary identifier returned by the eligibility API.
    final barcode =
        _str(json, 'barcode_value') ??
        _str(json, 'barcode') ??
        _str(json, 'tracking_number') ??
        '';

    return LocalDelivery(
      barcode: barcode,
      // tracking_number is not present in the eligibility payload; job_order
      // serves as a human-readable reference until the detail API is called.
      trackingNumber: _str(json, 'tracking_number') ?? _str(json, 'job_order'),
      // 'name' is the recipient name in the eligibility response.
      recipientName: _str(json, 'name'),
      // 'address' is the delivery address in the eligibility response.
      deliveryAddress: _str(json, 'address'),
      // API boundary: parse and normalise via DeliveryStatus (maps to failedDelivery).
      deliveryStatus: DeliveryStatus.fromString(
        _str(json, 'delivery_status') ?? 'FOR_DELIVERY',
      ).toDbString(),
      // 'product' carries the mail/product type in the eligibility response.
      mailType: _str(json, 'product') ?? _str(json, 'mail_type'),
      dispatchCode: dispatchCode,
      rawJson: jsonEncode(json),
      createdAt: now,
      updatedAt: now,
      completedAt:
          DeliveryStatus.fromString(json['delivery_status']?.toString()).isFinal
          ? now
          : null,
      syncStatus: 'clean',
      isArchived: false,
      rtsVerificationStatus:
          _str(json, 'failed_delivery_verification_status') ??
          _str(json, 'rts_verification_status') ??
          'unvalidated',
    );
  }

  /// Constructs from a delivery item in the `GET /deliveries` list or
  /// `GET /deliveries/{barcode}` detail response.
  ///
  /// Handles both the eligibility-response field names (`barcode_value`, `name`,
  /// `address`, `product`) and the delivery-API field names (`barcode`,
  /// `recipient_name`, `delivery_address`, `mail_type`).
  ///
  /// [serverStatus] — the status bucket this item was fetched from (e.g.
  /// `'delivered'`, `'failed_delivery'`). Used as a fallback when the API item does not
  /// include its own `delivery_status` field, ensuring timestamps are computed
  /// correctly even when the server omits the field from list responses.
  factory LocalDelivery.fromApiItem(
    Map<String, dynamic> json, {
    String dispatchCode = '',
    String serverStatus = '',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final barcode =
        _str(json, 'barcode_value') ??
        _str(json, 'barcode') ??
        _str(json, 'tracking_number') ??
        '';

    // serverStatus is the endpoint bucket we fetched from ('FOR_DELIVERY', 'DELIVERED',
    // 'FAILED_DELIVERY', 'OSA'). We previously used it as the primary status, which caused
    // issues when the API item contains a more specific state like 'DISPATCHED'.
    //
    // New Rule: If the JSON contains a non-pending status, we trust it over the
    // bucket status to prevent regressions (e.g. DISPATCHED showing as DELIVERED
    // if the server inadvertently includes it in the wrong list).
    // API boundary: resolve status from JSON field, falling back to the server
    // bucket ('FOR_DELIVERY', 'FAILED_DELIVERY', etc.) when the item itself omits delivery_status.
    // DeliveryStatus.fromString normalises 'FAILED_DELIVERY' (and 'FOR_DELIVERY'
    // → pending) so no raw string comparisons are needed below.
    final jsonStatus = (_str(json, 'delivery_status') ?? '').toUpperCase();
    final rawStatus =
        (jsonStatus.isNotEmpty && jsonStatus != 'FOR_DELIVERY'
                ? jsonStatus
                : (serverStatus.isNotEmpty ? serverStatus : 'FOR_DELIVERY'))
            .toUpperCase();
    // Normalise through the enum so any future API aliases are handled centrally.
    final status = DeliveryStatus.fromString(rawStatus).toDbString();

    debugPrint(
      '[API-STATUS] barcode=$barcode json=$jsonStatus bucket=$serverStatus raw=$rawStatus → final=$status',
    );

    // Derive deliveredAt from server-provided date fields when available.
    // Only use delivered_date — transaction_at is the package creation date
    // (assigned at dispatch time) and must NOT be used as a fallback because
    // it would set delivered_at to a past date, causing the today-filter in
    // countVisibleDelivered / getVisibleDeliveredPaged to exclude the item.
    int? deliveredAt;
    if (status == 'DELIVERED') {
      final dateStr = _str(json, 'delivered_date');
      if (dateStr != null) {
        final parsedDate = parseServerDate(dateStr);
        if (parsedDate != null) {
          deliveredAt = parsedDate.millisecondsSinceEpoch;
        } else {
          deliveredAt = now;
        }
      } else {
        deliveredAt = now;
      }
    }

    // completedAt covers DELIVERED, failedDelivery, and OSA.
    final ds = DeliveryStatus.fromString(status);
    int? completedAt = deliveredAt;
    if (completedAt == null && ds.isFinal) {
      completedAt = now;
    }

    return LocalDelivery(
      barcode: barcode,
      trackingNumber: _str(json, 'tracking_number') ?? _str(json, 'job_order'),
      recipientName: _str(json, 'recipient_name') ?? _str(json, 'name'),
      deliveryAddress: _str(json, 'delivery_address') ?? _str(json, 'address'),
      deliveryStatus: status,
      mailType: _str(json, 'mail_type') ?? _str(json, 'product'),
      dispatchCode: dispatchCode,
      rawJson: jsonEncode(json),
      createdAt: now,
      updatedAt: now,
      // mar-note: paid_at sentinel values:
      //   NULL / 0  → not yet paid; shows in dashboard + delivery list.
      //   1 (sentinel) → server reports is_paid=true but no local payout yet;
      //                   EXCLUDED from dashboard/list counts; PAID badge shown.
      //   >1 (real ms) → locally confirmed paid via payout request;
      //                   EXCLUDED from all dashboard/list/search views;
      //                   deleted after kPaidDeliveryRetentionDays (1 day).
      // Any COALESCE(paid_at,0) > 0 means the record is considered paid and
      // must not appear in visible-delivered counts or scan results.
      paidAt: (json['is_paid'] as bool? ?? false) ? 1 : null,
      deliveredAt: deliveredAt,
      completedAt: completedAt,
      serverUpdatedAt: _dateMs(json, 'updated_at'),
      syncStatus: 'clean',
      isArchived: false,
      rtsVerificationStatus:
          _str(json, 'failed_delivery_verification_status') ??
          _str(json, 'rts_verification_status') ??
          'unvalidated',
    );
  }

  /// Constructs from a SQLite row map.
  factory LocalDelivery.fromDb(Map<String, dynamic> row) {
    return LocalDelivery(
      id: row['id'] as int?,
      barcode: row['barcode'] as String,
      trackingNumber: row['tracking_number'] as String?,
      recipientName: row['recipient_name'] as String?,
      deliveryAddress: row['delivery_address'] as String?,
      deliveryStatus: row['delivery_status'] as String? ?? 'FOR_DELIVERY',
      mailType: row['mail_type'] as String?,
      dispatchCode: row['dispatch_code'] as String?,
      rawJson: row['raw_json'] as String,
      createdAt: row['created_at'] as int,
      updatedAt: row['updated_at'] as int,
      paidAt: row['paid_at'] as int?,
      deliveredAt: row['delivered_at'] as int?,
      completedAt: row['completed_at'] as int?,
      serverUpdatedAt: row['server_updated_at'] as int?,
      syncStatus: row['sync_status'] as String? ?? 'clean',
      isArchived: (row['is_archived'] as int? ?? 0) == 1,
      rtsVerificationStatus:
          row['rts_verification_status'] as String? ?? 'unvalidated',
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toDb() => {
    if (id != null) 'id': id,
    'barcode': barcode,
    'tracking_number': trackingNumber,
    'recipient_name': recipientName,
    'delivery_address': deliveryAddress,
    'delivery_status': deliveryStatus,
    'mail_type': mailType,
    'dispatch_code': dispatchCode,
    'raw_json': rawJson,
    'created_at': createdAt,
    'updated_at': updatedAt,
    if (paidAt != null) 'paid_at': paidAt,
    if (deliveredAt != null) 'delivered_at': deliveredAt,
    'completed_at': completedAt,
    if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
    'sync_status': syncStatus,
    'is_archived': isArchived ? 1 : 0,
    'rts_verification_status': rtsVerificationStatus,
  };

  /// Decodes [rawJson] back into the delivery map consumed by UI widgets
  /// such as [DeliveryCard] and detail screens.
  ///
  /// Injects internal state prefixed with '_' so the UI can synchronously
  /// evaluate visibility/locked rules.
  Map<String, dynamic> toDeliveryMap() {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        decoded['_sync_status'] = syncStatus;
        decoded['_paid_at'] = paidAt;
        decoded['_rts_verification_status'] = rtsVerificationStatus;
        decoded['_is_archived'] = isArchived;
        decoded['_completed_at'] = completedAt;
        decoded['_delivered_at'] = deliveredAt;
        return decoded;
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  // ── Copy helpers ──────────────────────────────────────────────────────────

  LocalDelivery copyWith({
    String? deliveryStatus,
    String? rawJson,
    int? updatedAt,
    int? paidAt,
    int? deliveredAt,
    int? completedAt,
    int? serverUpdatedAt,
    String? syncStatus,
    bool? isArchived,
    String? rtsVerificationStatus,
  }) {
    return LocalDelivery(
      id: id,
      barcode: barcode,
      trackingNumber: trackingNumber,
      recipientName: recipientName,
      deliveryAddress: deliveryAddress,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      mailType: mailType,
      dispatchCode: dispatchCode,
      rawJson: rawJson ?? this.rawJson,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      completedAt: completedAt ?? this.completedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      isArchived: isArchived ?? this.isArchived,
      rtsVerificationStatus:
          rtsVerificationStatus ?? this.rtsVerificationStatus,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static String? _str(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _dateMs(Map<String, dynamic> json, String key) {
    final str = _str(json, key);
    if (str == null) return null;
    return parseServerDate(str)?.millisecondsSinceEpoch;
  }
}
