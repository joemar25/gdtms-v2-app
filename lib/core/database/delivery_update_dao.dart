import 'package:sqflite/sqflite.dart';

import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/models/delivery_update_entry.dart';

/// Data access object for the [delivery_update_queue] table.
class DeliveryUpdateDao {
  const DeliveryUpdateDao._();

  static const DeliveryUpdateDao instance = DeliveryUpdateDao._();

  Future<Database> get _db => AppDatabase.getInstance();

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Inserts a new queue entry and returns its auto-generated [id].
  Future<int> insert(DeliveryUpdateEntry entry) async {
    final db = await _db;
    final row = entry.toDb()..remove('id');
    return db.insert(
      'delivery_update_queue',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markSyncing(int id) async {
    final db = await _db;
    await db.update(
      'delivery_update_queue',
      {
        'sync_status': 'syncing',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _db;
    await db.update(
      'delivery_update_queue',
      {
        'sync_status': 'synced',
        'error_message': null,
        'updated_at': now,
        'synced_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id, String errorMessage) async {
    final db = await _db;
    await db.rawUpdate(
      '''
      UPDATE delivery_update_queue
         SET sync_status   = 'failed',
             error_message = ?,
             attempt_count = attempt_count + 1,
             updated_at    = ?
       WHERE id = ?
      ''',
      [errorMessage, DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  /// Resets a failed entry back to [pending] so [SyncManagerNotifier] can
  /// retry it on the next [processQueue] call.
  Future<void> resetToPending(int id) async {
    final db = await _db;
    await db.update(
      'delivery_update_queue',
      {
        'sync_status': 'pending',
        'error_message': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns all entries with [sync_status = 'pending'] that belong to
  /// [courierId], ordered FIFO.
  ///
  /// Rows where [courier_id IS NULL] are also included for backwards
  /// compatibility with entries created before the v2 schema migration.
  Future<List<DeliveryUpdateEntry>> getPending(String courierId) async {
    final db = await _db;
    final rows = await db.query(
      'delivery_update_queue',
      where: "sync_status = 'pending' AND (courier_id = ? OR courier_id IS NULL)",
      whereArgs: [courierId],
      orderBy: 'created_at ASC',
    );
    return rows.map(DeliveryUpdateEntry.fromDb).toList();
  }

  /// Returns every entry ordered by creation date (newest first).
  /// Used by the Sync screen to display the full history.
  Future<List<DeliveryUpdateEntry>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      'delivery_update_queue',
      orderBy: 'created_at DESC',
    );
    return rows.map(DeliveryUpdateEntry.fromDb).toList();
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Deletes synced entries older than [retentionMs] milliseconds.
  /// Entries with [sync_status = 'pending'] or [sync_status = 'syncing']
  /// are never deleted.
  Future<void> deleteOldSynced(int retentionMs) async {
    final db = await _db;
    final cutoff = DateTime.now().millisecondsSinceEpoch - retentionMs;
    await db.delete(
      'delivery_update_queue',
      where: "sync_status = 'synced' AND synced_at < ?",
      whereArgs: [cutoff],
    );
  }

  /// Permanently removes all [failed] entries from the queue.
  /// Intended for debug / developer use only.
  Future<void> deleteAllFailed() async {
    final db = await _db;
    await db.delete(
      'delivery_update_queue',
      where: "sync_status = 'failed'",
    );
  }
}
