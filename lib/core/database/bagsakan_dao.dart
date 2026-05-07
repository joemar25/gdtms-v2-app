import 'package:sqflite/sqflite.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';

class BagsakanDao {
  BagsakanDao._();
  static final BagsakanDao instance = BagsakanDao._();

  Future<Database> get _db async => await AppDatabase.getInstance();

  // ─── MARK: Bagsakan Operations ──────────────────────────────────────────────

  /// Creates a new bagsakan group and returns its ID.
  Future<int> createBagsakanGroup({
    required String name,
    String? description,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.insert('bagsakan_groups', {
      'name': name,
      'description': description,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Returns a specific bagsakan group by ID.
  Future<Map<String, dynamic>?> getBagsakanGroup(int groupId) async {
    final db = await _db;
    final results = await db.query(
      'bagsakan_groups',
      where: 'id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Updates a bagsakan group's metadata.
  Future<void> updateBagsakanGroup({
    required int groupId,
    required String name,
    required String description,
  }) async {
    final db = await _db;
    await db.update(
      'bagsakan_groups',
      {'name': name, 'description': description},
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  /// Unlinks all deliveries from a specific bagsakan group.
  Future<void> clearBagsakanGroup(int groupId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'local_deliveries',
      {'bagsakan_id': null, 'updated_at': now, 'sync_status': 'dirty'},
      where: 'bagsakan_id = ?',
      whereArgs: [groupId],
    );
  }

  /// Assigns a list of barcodes to a bagsakan group.
  Future<void> assignToBagsakan({
    required int groupId,
    required List<String> barcodes,
  }) async {
    if (barcodes.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final batch = db.batch();
    for (final barcode in barcodes) {
      batch.update(
        'local_deliveries',
        {'bagsakan_id': groupId, 'updated_at': now, 'sync_status': 'dirty'},
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Unlinks a delivery from any bagsakan group.
  Future<void> unassignFromBagsakan(String barcode) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'local_deliveries',
      {'bagsakan_id': null, 'updated_at': now, 'sync_status': 'dirty'},
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  /// Returns all bagsakan groups with item counts, ordered by most recently created.
  Future<List<Map<String, dynamic>>> getBagsakanGroups() async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT g.*, COUNT(d.barcode) as item_count
      FROM bagsakan_groups g
      LEFT JOIN local_deliveries d ON g.id = d.bagsakan_id
      GROUP BY g.id
      ORDER BY g.created_at DESC
    ''');
  }

  /// Returns all items assigned to a specific bagsakan group.
  Future<List<LocalDelivery>> getBagsakanItems(int groupId) async {
    final db = await _db;
    final maps = await db.query(
      'local_deliveries',
      where: 'bagsakan_id = ?',
      whereArgs: [groupId],
    );
    return maps.map((e) => LocalDelivery.fromDb(e)).toList();
  }

  /// Deletes a bagsakan group and unlinks all associated deliveries.
  Future<void> deleteBagsakanGroup(int groupId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.update(
        'local_deliveries',
        {'bagsakan_id': null, 'updated_at': now, 'sync_status': 'dirty'},
        where: 'bagsakan_id = ?',
        whereArgs: [groupId],
      );

      await txn.delete(
        'bagsakan_groups',
        where: 'id = ?',
        whereArgs: [groupId],
      );
    });
  }

  /// Searches deliveries by barcode (Filtered for Bagsakan).
  Future<List<LocalDelivery>> searchByBarcodeLike(
    String query, {
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) return [];
    final db = await _db;
    final q = '%${query.trim()}%';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM local_deliveries
      WHERE barcode LIKE ? COLLATE NOCASE 
        AND COALESCE(is_archived, 0) = 0
        AND delivery_status COLLATE NOCASE IN ('FOR_DELIVERY', 'FOR_REDELIVERY', 'FAILED_DELIVERY')
        AND bagsakan_id IS NULL
      ORDER BY updated_at DESC
      LIMIT $limit
      ''',
      [q],
    );
    final deliveries = rows.map(LocalDelivery.fromDb).toList();

    return deliveries.where((d) {
      final status = d.deliveryStatus.toUpperCase();
      if (status == 'FOR_DELIVERY' || status == 'FOR_REDELIVERY') return true;
      if (status == 'FAILED_DELIVERY') {
        return getAttemptsCountFromMap(d.toDeliveryMap()) < 3;
      }
      return false;
    }).toList();
  }

  /// Searches deliveries by recipient_name (Filtered for Bagsakan).
  Future<List<LocalDelivery>> searchByAccountName(
    String query, {
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) return [];
    final db = await _db;
    final q = '%${query.trim()}%';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM local_deliveries
      WHERE recipient_name LIKE ? COLLATE NOCASE 
        AND COALESCE(is_archived, 0) = 0
        AND delivery_status COLLATE NOCASE IN ('FOR_DELIVERY', 'FOR_REDELIVERY', 'FAILED_DELIVERY')
        AND bagsakan_id IS NULL
      ORDER BY updated_at DESC
      LIMIT $limit
      ''',
      [q],
    );
    final deliveries = rows.map(LocalDelivery.fromDb).toList();

    return deliveries.where((d) {
      final status = d.deliveryStatus.toUpperCase();
      if (status == 'FOR_DELIVERY' || status == 'FOR_REDELIVERY') return true;
      if (status == 'FAILED_DELIVERY') {
        return getAttemptsCountFromMap(d.toDeliveryMap()) < 3;
      }
      return false;
    }).toList();
  }
}
