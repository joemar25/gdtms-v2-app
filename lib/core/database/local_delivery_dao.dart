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
    await db.update(
      'local_deliveries',
      {
        'delivery_status': status,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
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
    await db.update(
      'local_deliveries',
      {
        'delivery_status':
            json['delivery_status']?.toString() ?? 'pending',
        'recipient_name':
            json['name']?.toString() ?? json['recipient_name']?.toString(),
        'delivery_address':
            json['address']?.toString() ??
            json['delivery_address']?.toString(),
        'raw_json': jsonEncode(json),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
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
      if (terminalBarcodes.contains(delivery.barcode)) continue;
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

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Deletes completed delivery records older than [retentionMs] milliseconds.
  /// Only `delivered`, `rts`, and `osa` records are eligible.
  /// `pending` records are never deleted.
  Future<void> deleteOldSynced(int retentionMs) async {
    final db = await _db;
    final cutoff = DateTime.now().millisecondsSinceEpoch - retentionMs;
    await db.delete(
      'local_deliveries',
      where:
          "delivery_status IN ('delivered', 'rts', 'osa') AND updated_at < ?",
      whereArgs: [cutoff],
    );
  }
}
