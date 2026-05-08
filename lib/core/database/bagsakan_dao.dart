import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:uuid/uuid.dart';

class BagsakanDao {
  BagsakanDao._();
  static final BagsakanDao instance = BagsakanDao._();

  Future<Database> get _db async => await AppDatabase.getInstance();

  // ─── MARK: Bagsakan Operations ──────────────────────────────────────────────

  /// Creates a new bagsakan group and returns its ID.
  Future<int> createBagsakanGroup({
    required String name,
    String? description,
    required String courierId,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('bagsakan_groups', {
      'name': name,
      'description': description,
      'created_at': now,
      'updated_at': now,
    });

    await SyncOperationsDao.instance.insert(
      SyncOperation(
        id: const Uuid().v4(),
        courierId: courierId,
        barcode: 'BAGSAKAN_$id',
        operationType: 'CREATE_BAGSAKAN',
        payloadJson: jsonEncode({
          'id': id,
          'name': name,
          'description': description,
        }),
        createdAt: now,
      ),
    );

    return id;
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
    required String courierId,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'bagsakan_groups',
      {'name': name, 'description': description, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [groupId],
    );

    await SyncOperationsDao.instance.insert(
      SyncOperation(
        id: const Uuid().v4(),
        courierId: courierId,
        barcode: 'BAGSAKAN_$groupId',
        operationType: 'UPDATE_BAGSAKAN_GROUP',
        payloadJson: jsonEncode({
          'id': groupId,
          'name': name,
          'description': description,
        }),
        createdAt: now,
      ),
    );
  }

  /// Unlinks all deliveries from a specific bagsakan group.
  Future<void> clearBagsakanGroup(int groupId, String courierId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Get all barcodes currently in the group to unassign them on server
    final items = await getBagsakanItems(groupId);
    final barcodes = items.map((e) => e.barcode).toList();

    await db.update(
      'local_deliveries',
      {'bagsakan_id': null, 'updated_at': now, 'sync_status': 'dirty'},
      where: 'bagsakan_id = ?',
      whereArgs: [groupId],
    );

    if (barcodes.isNotEmpty) {
      await SyncOperationsDao.instance.insert(
        SyncOperation(
          id: const Uuid().v4(),
          courierId: courierId,
          barcode: 'BAGSAKAN_$groupId',
          operationType: 'UNASSIGN_FROM_BAGSAKAN',
          payloadJson: jsonEncode({'group_id': groupId, 'barcodes': barcodes}),
          createdAt: now,
        ),
      );
    }
  }

  /// Assigns a list of barcodes to a bagsakan group.
  Future<void> assignToBagsakan({
    required int groupId,
    required List<String> barcodes,
    required String courierId,
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

    await SyncOperationsDao.instance.insert(
      SyncOperation(
        id: const Uuid().v4(),
        courierId: courierId,
        barcode: 'BAGSAKAN_$groupId',
        operationType: 'ASSIGN_TO_BAGSAKAN',
        payloadJson: jsonEncode({'group_id': groupId, 'barcodes': barcodes}),
        createdAt: now,
      ),
    );
  }

  /// Unlinks a delivery from any bagsakan group.
  Future<void> unassignFromBagsakan(String barcode, String courierId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Find the group ID first to create the sync operation
    final results = await db.query(
      'local_deliveries',
      columns: ['bagsakan_id'],
      where: 'barcode COLLATE NOCASE = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    final groupId = results.isNotEmpty
        ? results.first['bagsakan_id'] as int?
        : null;

    await db.update(
      'local_deliveries',
      {'bagsakan_id': null, 'updated_at': now, 'sync_status': 'dirty'},
      where: 'barcode COLLATE NOCASE = ?',
      whereArgs: [barcode],
    );

    if (groupId != null) {
      await SyncOperationsDao.instance.insert(
        SyncOperation(
          id: const Uuid().v4(),
          courierId: courierId,
          barcode: 'BAGSAKAN_$groupId',
          operationType: 'UNASSIGN_FROM_BAGSAKAN',
          payloadJson: jsonEncode({
            'group_id': groupId,
            'barcodes': [barcode],
          }),
          createdAt: now,
        ),
      );
    }
  }

  /// Returns all bagsakan groups with item counts, ordered by most recently created.
  /// Filters out submitted groups older than 1 day (Requirement 166) and archived groups.
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
      WHERE COALESCE(g.is_archived, 0) = 0
        AND (g.status != 'submitted' OR g.submitted_at >= ?)
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
  Future<void> deleteBagsakanGroup(int groupId, String courierId) async {
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

      // Get all barcodes currently in the group to unassign them on server
      final items = await getBagsakanItems(groupId);
      final barcodes = items.map((e) => e.barcode).toList();

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

      await SyncOperationsDao.instance.insert(
        SyncOperation(
          id: const Uuid().v4(),
          courierId: courierId,
          barcode: 'BAGSAKAN_$groupId',
          operationType: 'DELETE_BAGSAKAN_GROUP',
          payloadJson: jsonEncode({'id': groupId, 'barcodes': barcodes}),
          createdAt: now,
        ),
      );
    });
  }

  /// Submits a bagsakan group, propagating data from a source delivery to all others.
  /// This action is irreversible and locks the group.
  Future<void> submitBagsakanGroup(
    int groupId,
    String sourceBarcode,
    String courierId,
  ) async {
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

      // 4. Queue sync operation
      await SyncOperationsDao.instance.insert(
        SyncOperation(
          id: const Uuid().v4(),
          courierId: courierId,
          barcode: 'BAGSAKAN_$groupId',
          operationType: 'SUBMIT_BAGSAKAN',
          payloadJson: jsonEncode({
            'group_id': groupId,
            'source_barcode': sourceBarcode,
            'barcodes': otherRows.map((e) => e['barcode']).toList(),
          }),
          createdAt: now,
        ),
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
      where +=
          " AND delivery_status COLLATE NOCASE IN ('FOR_DELIVERY', 'FOR_REDELIVERY', 'FAILED_DELIVERY') "
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
      where +=
          " AND delivery_status COLLATE NOCASE IN ('FOR_DELIVERY', 'FOR_REDELIVERY', 'FAILED_DELIVERY') "
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

  /// Synchronizes Bagsakan groups from the server.
  /// Archived groups are deleted locally.
  Future<void> upsertGroupsFromSync(List<Map<String, dynamic>> groups) async {
    if (groups.isEmpty) return;
    final db = await _db;

    await db.transaction((txn) async {
      for (final group in groups) {
        final id = group['id'];
        final isArchived =
            group['is_archived'] == true || group['is_archived'] == 1;

        if (isArchived) {
          // Delete locally if archived on server
          await txn.delete('bagsakan_groups', where: 'id = ?', whereArgs: [id]);
          // Also unassign local items if they were still pointing here
          await txn.update(
            'local_deliveries',
            {'bagsakan_id': null},
            where: 'bagsakan_id = ?',
            whereArgs: [id],
          );
        } else {
          // Rule: Never downgrade a submitted group back to pending/draft.
          // The courier's local submission must be respected until the server
          // confirms it (terminal status wins).
          final existing = await txn.query(
            'bagsakan_groups',
            columns: ['status'],
            where: 'id = ?',
            whereArgs: [id],
          );

          if (existing.isNotEmpty && existing.first['status'] == 'submitted') {
            final serverStatus = group['status'] ?? 'pending';
            if (serverStatus != 'submitted') {
              debugPrint(
                '[DAO] upsertGroupsFromSync: Skipping status downgrade for group $id (local: submitted, server: $serverStatus)',
              );
              // Only update metadata other than status if needed, but for simplicity
              // we just skip the status update or skip the whole row.
              // Here we update everything BUT the status to stay safe.
            }
          }

          // Upsert group metadata
          final data = {
            'id': id,
            'name': group['name'],
            'description': group['description'],
            'status': group['status'] ?? 'pending',
            'submitted_at': group['submitted_at'],
            'is_archived': 0,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          };

          // If we are protecting a submitted status, ensure we don't overwrite it.
          if (existing.isNotEmpty &&
              existing.first['status'] == 'submitted' &&
              data['status'] != 'submitted') {
            data['status'] = 'submitted';
            // Also preserve submitted_at if the server hasn't provided one yet
            data['submitted_at'] ??= existing.first['submitted_at'];
          }

          // Use insert with conflict replace to upsert
          await txn.insert(
            'bagsakan_groups',
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
