/// Synchronisation state of a queued delivery update.
enum SyncStatus { pending, syncing, synced, failed }

/// A single offline delivery update waiting to be sent to the server.
///
/// When a rider submits a delivery update while offline, the full PATCH payload
/// is serialised into [payloadJson] and stored here until connectivity is
/// available.
class DeliveryUpdateEntry {
  const DeliveryUpdateEntry({
    this.id,
    this.courierId,
    required this.barcode,
    required this.payloadJson,
    required this.syncStatus,
    this.errorMessage,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });

  final int? id;

  /// The ID of the courier who created this entry.
  /// Used to prevent a different courier's pending updates from being
  /// processed when the same device is reused.
  final String? courierId;

  final String barcode;

  /// JSON-encoded [Map] of the exact payload to replay on [PATCH /deliveries/{barcode}].
  final String payloadJson;

  final SyncStatus syncStatus;
  final String? errorMessage;
  final int attemptCount;
  final int createdAt;
  final int updatedAt;

  /// Unix ms timestamp of when the record was successfully uploaded to the server.
  final int? syncedAt;

  // ── Factories ─────────────────────────────────────────────────────────────

  factory DeliveryUpdateEntry.fromDb(Map<String, dynamic> row) {
    return DeliveryUpdateEntry(
      id: row['id'] as int?,
      courierId: row['courier_id'] as String?,
      barcode: row['barcode'] as String,
      payloadJson: row['payload_json'] as String,
      syncStatus: _parseSyncStatus(row['sync_status'] as String?),
      errorMessage: row['error_message'] as String?,
      attemptCount: row['attempt_count'] as int? ?? 0,
      createdAt: row['created_at'] as int,
      updatedAt: row['updated_at'] as int,
      syncedAt: row['synced_at'] as int?,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toDb() => {
    if (id != null) 'id': id,
    'courier_id': courierId,
    'barcode': barcode,
    'payload_json': payloadJson,
    'sync_status': syncStatus.name,
    'error_message': errorMessage,
    'attempt_count': attemptCount,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'synced_at': syncedAt,
  };

  // ── Copy helpers ──────────────────────────────────────────────────────────

  DeliveryUpdateEntry copyWith({
    SyncStatus? syncStatus,
    String? errorMessage,
    int? attemptCount,
    int? updatedAt,
    int? syncedAt,
  }) {
    return DeliveryUpdateEntry(
      id: id,
      courierId: courierId,
      barcode: barcode,
      payloadJson: payloadJson,
      syncStatus: syncStatus ?? this.syncStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static SyncStatus _parseSyncStatus(String? value) {
    return switch (value) {
      'syncing' => SyncStatus.syncing,
      'synced' => SyncStatus.synced,
      'failed' => SyncStatus.failed,
      _ => SyncStatus.pending,
    };
  }
}
