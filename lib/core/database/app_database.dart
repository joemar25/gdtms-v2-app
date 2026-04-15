// DOCS: docs/core/database.md — update that file when you edit this one.

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton SQLite database instance for the FSI Courier app.
///
/// SQLite is used as a **temporary operational data store** only.
/// The backend server remains the authoritative system.
///
/// Tables:
/// - [local_deliveries]     — deliveries stored after dispatch acceptance.
/// - [delivery_update_queue] — offline update queue pending sync to server.
class AppDatabase {
  AppDatabase._();

  static Database? _instance;

  /// Returns the open database, initializing it on first call.
  static Future<Database> getInstance() async {
    if (_instance != null && _instance!.isOpen) return _instance!;
    _instance = await _open();
    return _instance!;
  }

  static Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'fsi_courier.db');
    final db = await openDatabase(
      path,
      version: 13,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    // sqflite blocks execute() inside all open callbacks (onConfigure, onOpen).
    // Running PRAGMAs here — after openDatabase() returns a live handle — is
    // the only reliable way to apply connection-level tuning.
    await _applyPragmas(db);
    return db;
  }

  /// Applies performance PRAGMAs on an already-open database connection.
  /// Failures are non-fatal: the app continues with SQLite defaults.
  static Future<void> _applyPragmas(Database db) async {
    try {
      // WAL mode: concurrent reads during writes; no corruption on force-close.
      await db.execute('PRAGMA journal_mode=WAL');
      // NORMAL: fsync only at WAL checkpoints, not every write.
      await db.execute('PRAGMA synchronous=NORMAL');
      // Keep temp tables in memory rather than on disk.
      await db.execute('PRAGMA temp_store=MEMORY');
      // 64 MB memory-mapped I/O for faster read-heavy list queries.
      await db.execute('PRAGMA mmap_size=67108864');
      // 5-second busy timeout prevents SQLITE_BUSY when workmanager and the
      // main isolate access the DB concurrently.
      await db.execute('PRAGMA busy_timeout=5000');
    } catch (e) {
      // Log but never crash — SQLite defaults are safe fallbacks.
      debugPrint('[DB] PRAGMA setup warning (non-fatal): $e');
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_deliveries (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode         TEXT    UNIQUE NOT NULL,
        tracking_number TEXT,
        recipient_name  TEXT,
        delivery_address TEXT,
        delivery_status  TEXT    NOT NULL DEFAULT 'pending',
        mail_type        TEXT,
        dispatch_code    TEXT,
        raw_json         TEXT    NOT NULL,
        created_at       INTEGER NOT NULL,
        updated_at       INTEGER NOT NULL,
        paid_at          INTEGER,
        delivered_at     INTEGER,
        completed_at     INTEGER,
        server_updated_at INTEGER,
        sync_status      TEXT    NOT NULL DEFAULT 'clean',
        is_archived      INTEGER NOT NULL DEFAULT 0,
        rts_verification_status TEXT NOT NULL DEFAULT 'unvalidated'
      )
    ''');

    await db.execute('''
      CREATE TABLE delivery_update_queue (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        courier_id      TEXT,
        barcode         TEXT    NOT NULL,
        payload_json    TEXT    NOT NULL,
        sync_status     TEXT    NOT NULL DEFAULT 'pending',
        error_message   TEXT,
        attempt_count   INTEGER NOT NULL DEFAULT 0,
        created_at      INTEGER NOT NULL,
        updated_at      INTEGER NOT NULL,
        synced_at       INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_operations (
        id               TEXT PRIMARY KEY,
        courier_id       TEXT,
        barcode          TEXT NOT NULL,
        operation_type   TEXT NOT NULL,
        payload_json     TEXT NOT NULL,
        media_paths_json TEXT,
        status           TEXT NOT NULL DEFAULT 'pending',
        retry_count      INTEGER NOT NULL DEFAULT 0,
        last_error       TEXT,
        created_at       INTEGER NOT NULL,
        last_attempt_at  INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE error_logs (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        level      TEXT    NOT NULL DEFAULT 'error',
        context    TEXT    NOT NULL,
        message    TEXT    NOT NULL,
        detail     TEXT,
        barcode    TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // v2: add courier_id to delivery_update_queue for per-courier isolation.
      // Existing rows get NULL, which the DAO treats as belonging to the
      // current user (safe because logout already cleared foreign-user rows).
      await db.execute(
        'ALTER TABLE delivery_update_queue ADD COLUMN courier_id TEXT',
      );
    }
    if (oldVersion < 3) {
      // v3: add paid_at to local_deliveries.
      // Once a delivery is part of a paid payout, paid_at is set to the
      // timestamp when the payout was marked paid. The cleanup service uses
      // this to enforce a 1-day retention (kPaidDeliveryRetentionDays) for
      // paid records — shorter than the standard retention — for privacy.
      await db.execute(
        'ALTER TABLE local_deliveries ADD COLUMN paid_at INTEGER',
      );
    }
    if (oldVersion < 4) {
      // v4: add delivered_at to local_deliveries.
      // Set when a delivery transitions to the 'delivered' status so the
      // dashboard offline count and the delivered list use the same
      // today-only filter, matching the server's delivered_today figure.
      await db.execute(
        'ALTER TABLE local_deliveries ADD COLUMN delivered_at INTEGER',
      );
      // Backfill existing delivered records using updated_at as a proxy.
      await db.execute(
        "UPDATE local_deliveries SET delivered_at = updated_at "
        "WHERE delivery_status = 'delivered' AND delivered_at IS NULL",
      );
    }
    if (oldVersion < 6) {
      // v6: add completed_at to local_deliveries.
      // This timestamp is used for all terminal statuses (delivered, failed-delivery, osa)
      // so that the today-only filter can be applied consistently across
      // all of them.
      final cols = await db.rawQuery('PRAGMA table_info(local_deliveries)');
      final hasCompletedAt = cols.any((c) => c['name'] == 'completed_at');
      if (!hasCompletedAt) {
        await db.execute(
          'ALTER TABLE local_deliveries ADD COLUMN completed_at INTEGER',
        );
      }
      // Backfill completed_at from delivered_at or updated_at.
      await db.execute(
        "UPDATE local_deliveries SET completed_at = COALESCE(delivered_at, updated_at) "
        "WHERE delivery_status IN ('delivered', 'FAILED_DELIVERY', 'osa')",
      );
    }
    if (oldVersion < 7) {
      // v7: Add mobile-only offline sync architecture components
      await db.execute('''
        CREATE TABLE sync_operations (
          id               TEXT PRIMARY KEY,
          courier_id       TEXT,
          barcode          TEXT NOT NULL,
          operation_type   TEXT NOT NULL,
          payload_json     TEXT NOT NULL,
          media_paths_json TEXT,
          status           TEXT NOT NULL DEFAULT 'pending',
          retry_count      INTEGER NOT NULL DEFAULT 0,
          last_error       TEXT,
          created_at       INTEGER NOT NULL,
          last_attempt_at  INTEGER
        )
      ''');

      await db.execute(
        "ALTER TABLE local_deliveries ADD COLUMN server_updated_at INTEGER",
      );
      await db.execute(
        "ALTER TABLE local_deliveries ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'clean'",
      );
      await db.execute(
        "ALTER TABLE local_deliveries ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0",
      );
    }
    if (oldVersion < 8) {
      // v8: add rts_verification_status (legacy) to local_deliveries.
      // Tracks failed delivery verification state. Note: this handles duplicate cases
      // caused by hot-reload interruptions during previous DB upgrade runs.
      final cols = await db.rawQuery('PRAGMA table_info(local_deliveries)');
      final hasRtsStatus = cols.any(
        (c) => c['name'] == 'rts_verification_status',
      );
      if (!hasRtsStatus) {
        await db.execute(
          "ALTER TABLE local_deliveries ADD COLUMN rts_verification_status TEXT NOT NULL DEFAULT 'unvalidated'",
        );
      }
    }
    if (oldVersion < 9) {
      // v9: add error_logs table for on-device diagnostic logging.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS error_logs (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          level      TEXT    NOT NULL DEFAULT 'error',
          context    TEXT    NOT NULL,
          message    TEXT    NOT NULL,
          detail     TEXT,
          barcode    TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 10) {
      // v10: add index on sync_operations(courier_id, status) to speed up
      // the sync-lock barcode query that runs on every delivery list load.
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sync_courier '
        'ON sync_operations(courier_id, status)',
      );
    }
    if (oldVersion < 11) {
      // v11: rename legacy 'RTS' delivery_status values to 'FAILED_DELIVERY'
      // to align with the v2.8 API contract. The backend returns FAILED_DELIVERY
      // in all read responses; dual-value IN clauses in the DAO are removed.
      await db.execute(
        "UPDATE local_deliveries SET delivery_status = 'FAILED_DELIVERY' "
        "WHERE delivery_status = 'RTS'",
      );
    }
    if (oldVersion < 12) {
      // v12: Keep rts_verification_status as per requirement.
      // (This slot is preserved to maintain version numbering)
    }
    if (oldVersion < 13) {
      // v13: Restore rts_verification_status if it was renamed to failed_delivery_verification_status
      // in previous experimental builds.
      final cols = await db.rawQuery('PRAGMA table_info(local_deliveries)');
      final hasModern = cols.any(
        (c) => c['name'] == 'failed_delivery_verification_status',
      );
      final hasLegacy = cols.any((c) => c['name'] == 'rts_verification_status');

      if (hasModern && !hasLegacy) {
        // SQLite does not support RENAME COLUMN on all platforms/versions used by sqflite,
        // so we use the safest approach: alter table to add columns is fine, but renaming
        // is tricky. However, most modern Android/iOS versions (SQLite 3.25+) support it.
        // We'll wrap in try-catch to be safe.
        try {
          await db.execute(
            'ALTER TABLE local_deliveries RENAME COLUMN failed_delivery_verification_status TO rts_verification_status',
          );
        } catch (e) {
          debugPrint('[DB] Migration failed (rename): $e');
          // If rename fails, we fallback to adding the column if it's really missing.
          if (!hasLegacy) {
            await db.execute(
              "ALTER TABLE local_deliveries ADD COLUMN rts_verification_status TEXT NOT NULL DEFAULT 'unvalidated'",
            );
          }
        }
      }
    }
  }

  /// Deletes ALL rows from [local_deliveries] and [delivery_update_queue].
  /// Called on logout and on session-fingerprint mismatch at login to prevent
  /// stale data from a previous user/server being visible to the next user.
  static Future<void> clearAllDeliveryData() async {
    final db = await getInstance();
    await db.delete('local_deliveries');
    await db.delete('delivery_update_queue');
    await db.delete('sync_operations');
  }
}
