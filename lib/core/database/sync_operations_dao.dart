// DOCS: docs/core/database.md — update that file when you edit this one.

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
  Future<List<SyncOperation>> getPending(
    String courierId, {
    int limit = 5,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'sync_operations',
      where:
          "courier_id = ? "
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
    final updates = <String, dynamic>{'status': status};
    if (lastError != null) updates['last_error'] = lastError;
    if (retryCount != null) updates['retry_count'] = retryCount;
    if (lastAttemptAt != null) updates['last_attempt_at'] = lastAttemptAt;
    if (payloadJson != null) updates['payload_json'] = payloadJson;

    await db.update(
      'sync_operations',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes synced operations older than [retentionDays] calendar days and
  /// returns the deleted count.
  ///
  /// Uses midnight-aligned cutoffs so that all records created on the same
  /// calendar day expire together at the same midnight boundary, regardless of
  /// the exact time they were created.
  ///
  /// Special case: [retentionDays] == 0 activates the debug 1-minute mode —
  /// records created more than 60 seconds ago are deleted immediately (no
  /// midnight alignment).
  ///
  /// Examples (normal mode, retentionDays = 1, cleanup running on Apr 5):
  ///   cutoff = Apr 5 00:00 → items from Apr 4 (any time) are deleted ✓
  ///   items created today (Apr 5) are kept ✓
  Future<int> deleteOldSynced(int retentionDays) async {
    final db = await _db;
    final int cutoff;
    if (retentionDays <= 0) {
      // Debug 1-min mode: rolling cutoff, no midnight alignment.
      cutoff =
          DateTime.now().millisecondsSinceEpoch -
          const Duration(minutes: 1).inMilliseconds;
    } else {
      // Midnight-aligned: delete items whose creation calendar-day is strictly
      // before (today - (retentionDays - 1)).
      // Formula: cutoff = midnight of today - (retentionDays - 1) days.
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      cutoff = todayMidnight
          .subtract(Duration(days: retentionDays - 1))
          .millisecondsSinceEpoch;
    }
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
      {'status': 'pending', 'retry_count': 0, 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Gets count of incomplete operations for [courierId] (used for UI badge).
  Future<int> getPendingCount(String courierId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) as c FROM sync_operations "
      "WHERE courier_id = ? AND status IN ('pending', 'processing', 'failed', 'conflict')",
      [courierId],
    );
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

  /// Gets the total count of all synced operations for [courierId].
  ///
  /// No date filter — mirrors the full list shown in the History screen so
  /// dashboard counts always match what the courier sees when they tap the card.
  Future<int> getSyncedCount(String courierId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) as c FROM sync_operations "
      "WHERE courier_id = ? AND status = 'synced'",
      [courierId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Gets the count of operations successfully synced today for [courierId].
  Future<int> getSyncedTodayCount(String courierId) async {
    final db = await _db;
    final now = DateTime.now();
    final dayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) as c FROM sync_operations "
      "WHERE courier_id = ? AND status = 'synced' AND last_attempt_at >= ?",
      [courierId, dayStart],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
