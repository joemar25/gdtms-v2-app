// DOCS: docs/core/models.md — update that file when you edit this one.

/// A durable operation recorded on the mobile device before syncing to the server.
class SyncOperation {
  const SyncOperation({
    required this.id,
    this.courierId,
    required this.barcode,
    required this.operationType,
    required this.payloadJson,
    this.mediaPathsJson,
    this.status = 'pending',
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    this.lastAttemptAt,
  });

  final String id;
  final String? courierId;
  final String barcode;
  final String operationType;
  final String payloadJson;
  final String? mediaPathsJson;
  final String status;
  final int retryCount;
  final String? lastError;
  final int createdAt;
  final int? lastAttemptAt;

  factory SyncOperation.fromDb(Map<String, dynamic> row) {
    return SyncOperation(
      id: row['id'] as String,
      courierId: row['courier_id'] as String?,
      barcode: row['barcode'] as String,
      operationType: row['operation_type'] as String,
      payloadJson: row['payload_json'] as String,
      mediaPathsJson: row['media_paths_json'] as String?,
      status: row['status'] as String,
      retryCount: row['retry_count'] as int,
      lastError: row['last_error'] as String?,
      createdAt: row['created_at'] as int,
      lastAttemptAt: row['last_attempt_at'] as int?,
    );
  }

  Map<String, dynamic> toDb() => {
    'id': id,
    'courier_id': courierId,
    'barcode': barcode,
    'operation_type': operationType,
    'payload_json': payloadJson,
    if (mediaPathsJson != null) 'media_paths_json': mediaPathsJson,
    'status': status,
    'retry_count': retryCount,
    if (lastError != null) 'last_error': lastError,
    'created_at': createdAt,
    if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
  };

  SyncOperation copyWith({
    String? status,
    int? retryCount,
    String? lastError,
    int? lastAttemptAt,
    String? payloadJson,
  }) {
    return SyncOperation(
      id: id,
      courierId: courierId,
      barcode: barcode,
      operationType: operationType,
      payloadJson: payloadJson ?? this.payloadJson,
      mediaPathsJson: mediaPathsJson,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }
}
