import 'dart:convert';
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
        where: 'barcode COLLATE NOCASE = ?',
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
      where: 'barcode COLLATE NOCASE = ?',
      whereArgs: [barcode],
    );
  }

  /// Returns all bagsakan groups with item counts, ordered by most recently created.
  /// Filters out submitted groups older than 1 day (Requirement 166).
  Future<List<Map<String, dynamic>>> getBagsakanGroups() async {
    final db = await _db;
    final oneDayAgo = DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;

    return await db.rawQuery(
      '''
      SELECT g.*, COUNT(d.barcode) as item_count
      FROM bagsakan_groups g
      LEFT JOIN local_deliveries d ON g.id = d.bagsakan_id
      WHERE g.status != 'submitted' 
         OR g.submitted_at >= ?
      GROUP BY g.id
      ORDER BY g.created_at DESC
    ''',
      [oneDayAgo],
    );
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
  /// Only allowed if the group is not yet submitted.
  Future<void> deleteBagsakanGroup(int groupId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // Verify not submitted
      final groups = await txn.query(
        'bagsakan_groups',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [groupId],
      );
      if (groups.isNotEmpty && groups.first['status'] == 'submitted') {
        throw Exception('Cannot delete a submitted bagsakan group');
      }

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

  /// Submits a bagsakan group, propagating data from a source delivery to all others.
  /// This action is irreversible and locks the group.
  Future<void> submitBagsakanGroup(int groupId, String sourceBarcode) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // 1. Fetch source delivery
      final sourceRows = await txn.query(
        'local_deliveries',
        where: 'barcode = ? AND bagsakan_id = ?',
        whereArgs: [sourceBarcode, groupId],
        limit: 1,
      );
      if (sourceRows.isEmpty) throw Exception('Source delivery not found');

      final source = LocalDelivery.fromDb(sourceRows.first);
      final sourceMap = source.toDeliveryMap();

      // 2. Update all other deliveries in the group
      final otherRows = await txn.query(
        'local_deliveries',
        where: 'bagsakan_id = ? AND barcode != ?',
        whereArgs: [groupId, sourceBarcode],
      );

      for (final row in otherRows) {
        final item = LocalDelivery.fromDb(row);
        final itemMap = item.toDeliveryMap();

        // Merge delivery details from source into itemMap
        // Requirement: Copy POD image, transaction date, and all delivery details.
        final Map<String, dynamic> updatedMap = {
          ...itemMap,
          'delivery_status': 'DELIVERED',
          'delivered_at': source.deliveredAt,
          'completed_at': source.completedAt,
          // Copy POD specific fields
          'proof_of_delivery': sourceMap['proof_of_delivery'],
          'signature_image': sourceMap['signature_image'],
          'photo_image': sourceMap['photo_image'],
          'recipient_relation': sourceMap['recipient_relation'],
          'recipient_type': sourceMap['recipient_type'],
          'latitude': sourceMap['latitude'],
          'longitude': sourceMap['longitude'],
        };

        await txn.update(
          'local_deliveries',
          {
            'delivery_status': 'DELIVERED',
            'delivered_at': source.deliveredAt,
            'completed_at': source.completedAt,
            'raw_json': jsonEncode(updatedMap),
            'sync_status': 'dirty',
            'updated_at': now,
          },
          where: 'barcode = ?',
          whereArgs: [item.barcode],
        );
      }

      // 3. Mark group as submitted and set the 1-day purge clock
      await txn.update(
        'bagsakan_groups',
        {'status': 'submitted', 'submitted_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [groupId],
      );
    });
  }

  /// Searches deliveries by barcode (Filtered for Bagsakan).
  Future<List<LocalDelivery>> searchByBarcodeLike(
    String query, {
    bool eligibleOnly = true,
  }) async {
    if (query.trim().isEmpty) return [];
    final db = await _db;
    final q = '%${query.trim()}%';
    
    String where = '(barcode LIKE ? COLLATE NOCASE)';
    if (eligibleOnly) {
      where += " AND delivery_status COLLATE NOCASE IN ('FOR_DELIVERY', 'FOR_REDELIVERY', 'FAILED_DELIVERY') "
               " AND (COALESCE(rts_verification_status, 'unvalidated') COLLATE NOCASE NOT IN ('verified_with_pay', 'verified_no_pay')) "
               " AND bagsakan_id IS NULL "
               " AND COALESCE(is_archived, 0) = 0";
    }

    final maps = await db.query(
      'local_deliveries',
      where: where,
      whereArgs: [q],
      limit: 20,
    );
    return maps.map((e) => LocalDelivery.fromDb(e)).toList();
  }

  /// Search for deliveries by account name.
  Future<List<LocalDelivery>> searchByAccountName(
    String query, {
    bool eligibleOnly = true,
  }) async {
    if (query.trim().isEmpty) return [];
    final db = await _db;
    final q = '%${query.trim()}%';

    String where = '(recipient_name LIKE ? COLLATE NOCASE)';
    if (eligibleOnly) {
      where += " AND delivery_status COLLATE NOCASE IN ('FOR_DELIVERY', 'FOR_REDELIVERY', 'FAILED_DELIVERY') "
               " AND (COALESCE(rts_verification_status, 'unvalidated') COLLATE NOCASE NOT IN ('verified_with_pay', 'verified_no_pay')) "
               " AND bagsakan_id IS NULL "
               " AND COALESCE(is_archived, 0) = 0";
    }

    final maps = await db.query(
      'local_deliveries',
      where: where,
      whereArgs: [q],
      limit: 50,
    );
    return maps.map((e) => LocalDelivery.fromDb(e)).toList();
  }
}
