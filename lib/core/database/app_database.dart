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
    return openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        completed_at     INTEGER
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
      // This timestamp is used for all terminal statuses (delivered, rts, osa)
      // so that the today-only filter can be applied consistently across
      // all of them.
      final cols = await db.rawQuery(
        'PRAGMA table_info(local_deliveries)',
      );
      final hasCompletedAt = cols.any((c) => c['name'] == 'completed_at');
      if (!hasCompletedAt) {
        await db.execute(
          'ALTER TABLE local_deliveries ADD COLUMN completed_at INTEGER',
        );
      }
      // Backfill completed_at from delivered_at or updated_at.
      await db.execute(
        "UPDATE local_deliveries SET completed_at = COALESCE(delivered_at, updated_at) "
        "WHERE delivery_status IN ('delivered', 'rts', 'osa')",
      );
    }
  }

  /// Deletes ALL rows from [local_deliveries] and [delivery_update_queue].
  /// Called on logout and on session-fingerprint mismatch at login to prevent
  /// stale data from a previous user/server being visible to the next user.
  static Future<void> clearAllDeliveryData() async {
    final db = await getInstance();
    await db.delete('local_deliveries');
    await db.delete('delivery_update_queue');
  }
}
