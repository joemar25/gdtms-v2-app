import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';

/// Data access object for the [local_deliveries] table.
class LocalDeliveryDao {
  const LocalDeliveryDao._();

  static const LocalDeliveryDao instance = LocalDeliveryDao._();

  Future<Database> get _db => AppDatabase.getInstance();

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Inserts (or replaces) the delivery objects from the eligibility response
  /// into local storage, binding them to the accepting [dispatchCode].
  ///
  /// Deliveries with no resolvable barcode are silently skipped.
  Future<void> insertAll(
    List<Map<String, dynamic>> deliveries, {
    required String dispatchCode,
  }) async {
    final db = await _db;
    final batch = db.batch();
    for (final json in deliveries) {
      final delivery = LocalDelivery.fromJson(
        json,
        dispatchCode: dispatchCode,
      );
      if (delivery.barcode.isEmpty) continue;
      batch.insert(
        'local_deliveries',
        delivery.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Updates only [delivery_status] and [updated_at] for the given [barcode].
  /// Used for optimistic local updates when a rider submits offline.
  Future<void> updateStatus(String barcode, String status) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'local_deliveries',
      {
        'delivery_status': status,
        'updated_at': now,
        if (status == 'delivered') 'delivered_at': now,
      },
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  /// Refreshes a record's indexed fields and [rawJson] from a fresh API response.
  /// Called after a successful GET or PATCH while online.
  Future<void> updateFromJson(
    String barcode,
    Map<String, dynamic> json,
  ) async {
    final db = await _db;
    final status = json['delivery_status']?.toString() ?? 'pending';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Parse is_paid from the fresh API response (v2.0 field).
    // Sentinel 1 = historically paid; only set when not already a real timestamp.
    final isPaid = json['is_paid'] as bool? ?? false;

    await db.update(
      'local_deliveries',
      {
        'delivery_status': status,
        'recipient_name':
            json['name']?.toString() ?? json['recipient_name']?.toString(),
        'delivery_address':
            json['address']?.toString() ??
            json['delivery_address']?.toString(),
        'raw_json': jsonEncode(json),
        'updated_at': now,
      },
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    // Update paid_at sentinel when API reports is_paid=true but local record
    // has no real payout timestamp yet.
    if (isPaid) {
      await db.rawUpdate(
        'UPDATE local_deliveries SET paid_at = COALESCE(NULLIF(paid_at, 0), 1) WHERE barcode = ? AND (paid_at IS NULL OR paid_at <= 1)',
        [barcode],
      );
    }

    // Preserve the original delivered_at — prefer the server's delivered_date,
    // fall back to transaction_at, then now. COALESCE keeps the earlier value
    // on subsequent syncs so the timestamp is never overwritten.
    if (status == 'delivered') {
      final dateStr =
          json['delivered_date']?.toString() ??
          json['transaction_at']?.toString();
      int deliveredAt = now;
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          deliveredAt = DateTime.parse(dateStr).millisecondsSinceEpoch;
        } catch (_) {
          deliveredAt = now;
        }
      }
      await db.rawUpdate(
        'UPDATE local_deliveries SET delivered_at = COALESCE(delivered_at, ?) WHERE barcode = ?',
        [deliveredAt, barcode],
      );
    }
  }

  /// Inserts (or replaces) delivery items from the `GET /deliveries` API response.
  /// Uses [LocalDelivery.fromApiItem] which tolerates both eligibility-response
  /// field names and delivery-API field names.
  ///
  /// Records that are already in a terminal state locally (`delivered`, `rts`,
  /// `osa`) are never overwritten by this bootstrap operation. This prevents
  /// the background API sync from downgrading a locally-delivered item back to
  /// `pending` (which would cause it to vanish from the delivered list).
  Future<void> insertAllFromApiItems(
    List<Map<String, dynamic>> items, {
    String dispatchCode = '',
  }) async {
    final db = await _db;

    // Collect barcodes that already have a terminal status locally so we can
    // skip them and preserve their status and updatedAt timestamp.
    final existingRows = await db.query(
      'local_deliveries',
      columns: ['barcode', 'delivery_status'],
      where: "delivery_status IN ('delivered', 'rts', 'osa')",
    );
    final terminalBarcodes = <String>{
      for (final row in existingRows) row['barcode'] as String,
    };

    final batch = db.batch();
    for (final json in items) {
      final delivery = LocalDelivery.fromApiItem(
        json,
        dispatchCode: dispatchCode,
      );
      if (delivery.barcode.isEmpty) continue;
      // Never overwrite a locally terminal record via bootstrap — the sync
      // queue (not the bootstrap) is responsible for reconciling those.
      // Exception: always correct delivered_at from the server's delivered_date
      // so the today-filter works accurately (v4 migration may have stamped
      // delivered_at = bootstrap-time for old items).
      if (terminalBarcodes.contains(delivery.barcode)) {
        if (delivery.deliveredAt != null) {
          batch.update(
            'local_deliveries',
            {'delivered_at': delivery.deliveredAt},
            where: "barcode = ? AND delivery_status = 'delivered'",
            whereArgs: [delivery.barcode],
          );
        }
        continue;
      }
      batch.insert(
        'local_deliveries',
        delivery.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Read ──────────────────────────────────────────────────────────────────────────────

  /// Returns the count of deliveries matching [status].
  Future<int> countByStatus(String status) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      columns: ['id'],
      where: 'delivery_status = ?',
      whereArgs: [status],
    );
    return rows.length;
  }

  /// Returns all deliveries with the given [status], ordered by [created_at].
  Future<List<LocalDelivery>> getByStatus(String status) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      where: 'delivery_status = ?',
      whereArgs: [status],
      orderBy: 'created_at ASC',
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Returns the delivery matching [barcode], or `null` if not found.
  Future<LocalDelivery?> getByBarcode(String barcode) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocalDelivery.fromDb(rows.first);
  }

  /// Returns delivered items whose [delivered_at] falls within today
  /// (i.e. transaction_date / delivered_date from the server is today).
  ///
  /// Strictly bounded to [todayStart, tomorrowStart) so only deliveries
  /// with an actual delivery date of today are shown.
  Future<List<LocalDelivery>> getVisibleDelivered() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      where:
          "delivery_status = 'delivered' "
          'AND delivered_at >= ? AND delivered_at < ?',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'delivered_at DESC, created_at DESC',
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Returns the count of delivered items whose [delivered_at] is today.
  /// Used by the dashboard offline fallback to match the server's
  /// today-only [delivered_today] figure.
  Future<int> countVisibleDelivered() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      columns: ['id'],
      where:
          "delivery_status = 'delivered' "
          'AND delivered_at >= ? AND delivered_at < ?',
      whereArgs: [todayStart, tomorrowStart],
    );
    return rows.length;
  }

  /// Deletes ALL rows from [local_deliveries].
  /// Used by [DeliveryBootstrapService.clearAndSyncFromApi] to force a fresh
  /// load from the server (e.g. "Reload from Server" action on Sync screen).
  Future<void> deleteAll() async {
    final db = await _db;
    await db.delete('local_deliveries');
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Marks the given [barcodes] as paid by setting [paid_at] to now.
  ///
  /// Called when a payout request transitions to the "paid" status so that
  /// the cleanup service can apply the shorter [kPaidDeliveryRetentionDays]
  /// window to these records instead of the standard [kLocalDataRetentionDays].
  Future<void> markAsPaid(List<String> barcodes) async {
    if (barcodes.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final barcode in barcodes) {
      batch.update(
        'local_deliveries',
        {'paid_at': now},
        where: 'barcode = ? AND (paid_at IS NULL OR paid_at <= 1)',
        whereArgs: [barcode],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Deletes completed delivery records older than [retentionMs] milliseconds.
  /// Only `delivered`, `rts`, and `osa` records are eligible.
  /// `pending` records are never deleted.
  ///
  /// Privacy rule — paid deliveries use a shorter window ([paidRetentionMs]):
  /// once a delivery belongs to a paid payout ([paid_at] IS NOT NULL) it is
  /// kept for only [kPaidDeliveryRetentionDays] day before deletion, regardless
  /// of the standard [retentionMs].
  Future<void> deleteOldSynced(int retentionMs, {required int paidRetentionMs}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - retentionMs;
    final paidCutoff = now - paidRetentionMs;

    // Delete standard (unpaid) completed records past standard retention.
    await db.delete(
      'local_deliveries',
      where:
          "delivery_status IN ('delivered', 'rts', 'osa') "
          "AND paid_at IS NULL "
          "AND updated_at < ?",
      whereArgs: [cutoff],
    );

    // Delete paid records past the shorter paid retention window.
    await db.delete(
      'local_deliveries',
      where:
          "delivery_status IN ('delivered', 'rts', 'osa') "
          "AND paid_at IS NOT NULL "
          "AND paid_at < ?",
      whereArgs: [paidCutoff],
    );
  }
}
