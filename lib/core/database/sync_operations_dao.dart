import 'package:sqflite/sqflite.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';

/// Data access object for the [sync_operations] table.
class SyncOperationsDao {
  const SyncOperationsDao._();

  static const SyncOperationsDao instance = SyncOperationsDao._();

  Future<Database> get _db => AppDatabase.getInstance();

  /// Inserts a new sync operation.
  Future<void> insert(SyncOperation operation) async {
    final db = await _db;
    await db.insert(
      'sync_operations',
      operation.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns pending or failed operations ready for retry (respects exponential backoff).
  Future<List<SyncOperation>> getPending(String courierId, {int limit = 5}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'sync_operations',
      where: "courier_id = ? "
          "AND status IN ('pending', 'failed') "
          "AND retry_count < 10 "
          "AND (last_attempt_at IS NULL OR last_attempt_at + ("
          "  CASE retry_count "
          "    WHEN 0 THEN 0 "
          "    WHEN 1 THEN 30000 "
          "    WHEN 2 THEN 60000 "
          "    WHEN 3 THEN 120000 "
          "    WHEN 4 THEN 300000 "
          "    ELSE 600000 "
          "  END"
          ") <= ?)",
      whereArgs: [courierId, now],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(SyncOperation.fromDb).toList();
  }

  /// Updates status and potentially other fields of an operation.
  Future<void> updateStatus(
    String id,
    String status, {
    String? lastError,
    int? retryCount,
    int? lastAttemptAt,
    String? payloadJson,
  }) async {
    final db = await _db;
    await db.update(
      'sync_operations',
      {
        'status': status,
        if (lastError != null) 'last_error': lastError,
        if (retryCount != null) 'retry_count': retryCount,
        if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
        if (payloadJson != null) 'payload_json': payloadJson,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes synced operations older than [retentionMs] and returns the count.
  Future<int> deleteOldSynced(int retentionMs) async {
    final db = await _db;
    final cutoff = DateTime.now().millisecondsSinceEpoch - retentionMs;
    return await db.delete(
      'sync_operations',
      where: "status = 'synced' AND created_at < ?",
      whereArgs: [cutoff],
    );
  }

  /// Returns all operations for the UI.
  Future<List<SyncOperation>> getAll(String courierId) async {
    final db = await _db;
    final rows = await db.query(
      'sync_operations',
      where: 'courier_id = ?',
      whereArgs: [courierId],
      orderBy: 'created_at DESC',
    );
    return rows.map(SyncOperation.fromDb).toList();
  }

  /// Permanently deletes all failed operations.
  Future<void> deleteAllFailed(String courierId) async {
    final db = await _db;
    await db.delete(
      'sync_operations',
      where: "courier_id = ? AND status = 'failed'",
      whereArgs: [courierId],
    );
  }

  /// Resets a specific operation back to pending status.
  Future<void> resetToPending(String id) async {
    final db = await _db;
    await db.update(
      'sync_operations',
      {
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Gets count of incomplete operations (used for UI badge).
  Future<int> getPendingCount() async {
    final db = await _db;
    final rows = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sync_operations WHERE status IN ('pending', 'processing', 'failed', 'conflict')");
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Checks if there is an unfinished sync operation for a specific barcode.
  Future<bool> hasPendingSync(String barcode) async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT (COUNT(*) > 0) as has_pending "
      "FROM sync_operations "
      "WHERE barcode = ? AND status IN ('pending', 'processing', 'failed', 'conflict')",
      [barcode],
    );
    return (rows.first['has_pending'] as int) == 1;
  }

  /// Returns the set of barcodes that have at least one unfinished sync
  /// operation (pending / processing / failed / conflict) for [courierId].
  ///
  /// Used by list screens to batch-inject `_in_sync_queue` into delivery maps
  /// in a single DB round-trip instead of N individual [hasPendingSync] calls.
  /// A delivery in this set must not be re-updated until its operation resolves.
  Future<Set<String>> getSyncQueuedBarcodes(String courierId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT DISTINCT barcode FROM sync_operations "
      "WHERE courier_id = ? "
      "  AND status IN ('pending','processing','failed','conflict')",
      [courierId],
    );
    return {for (final r in rows) r['barcode'] as String};
  }
}
