import 'dart:convert';

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
  /// status (delivered, rts, osa). used for today-only filtering.
  final int? completedAt;
  /// Timestamp of last server-side update.
  final int? serverUpdatedAt;
  /// 'clean', 'dirty', or 'conflict'
  final String syncStatus;
  /// True if missing from server list
  final bool isArchived;

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
      deliveryStatus: _str(json, 'delivery_status') ?? 'pending',
      // 'product' carries the mail/product type in the eligibility response.
      mailType: _str(json, 'product') ?? _str(json, 'mail_type'),
      dispatchCode: dispatchCode,
      rawJson: jsonEncode(json),
      createdAt: now,
      updatedAt: now,
      completedAt: (json['delivery_status'] == 'delivered' ||
              json['delivery_status'] == 'rts' ||
              json['delivery_status'] == 'osa')
          ? now
          : null,
      syncStatus: 'clean',
      isArchived: false,
    );
  }

  /// Constructs from a delivery item in the `GET /deliveries` list or
  /// `GET /deliveries/{barcode}` detail response.
  ///
  /// Handles both the eligibility-response field names (`barcode_value`, `name`,
  /// `address`, `product`) and the delivery-API field names (`barcode`,
  /// `recipient_name`, `delivery_address`, `mail_type`).
  factory LocalDelivery.fromApiItem(
    Map<String, dynamic> json, {
    String dispatchCode = '',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final barcode =
        _str(json, 'barcode_value') ??
        _str(json, 'barcode') ??
        _str(json, 'tracking_number') ??
        '';

    final status = _str(json, 'delivery_status') ?? 'pending';

    // Derive deliveredAt from server-provided date fields when available.
    int? deliveredAt;
    if (status == 'delivered') {
      final dateStr =
          _str(json, 'delivered_date') ?? _str(json, 'transaction_at');
      if (dateStr != null) {
        try {
          deliveredAt = DateTime.parse(dateStr).millisecondsSinceEpoch;
        } catch (_) {
          deliveredAt = now;
        }
      } else {
        deliveredAt = now;
      }
    }

    // completedAt is essentially the same as deliveredAt for 'delivered',
    // but also covers 'rts' and 'osa'.
    int? completedAt = deliveredAt;
    if (completedAt == null && (status == 'rts' || status == 'osa')) {
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
      // Sentinel 1ms = "paid historically" — shows PAID badge, excluded from
      // the today-visible delivered list until next-day cleanup applies.
      paidAt: (json['is_paid'] as bool? ?? false) ? 1 : null,
      deliveredAt: deliveredAt,
      completedAt: completedAt,
      serverUpdatedAt: _dateMs(json, 'updated_at'),
      syncStatus: 'clean',
      isArchived: false,
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
      deliveryStatus: row['delivery_status'] as String? ?? 'pending',
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
  };

  /// Decodes [rawJson] back into the delivery map consumed by UI widgets
  /// such as [DeliveryCard] and detail screens.
  Map<String, dynamic> toDeliveryMap() {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) return decoded;
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
    try {
      return DateTime.parse(str).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }
}
