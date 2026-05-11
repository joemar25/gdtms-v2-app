import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:uuid/uuid.dart';

class BagsakanDao {
  BagsakanDao._();
  static final BagsakanDao instance = BagsakanDao._();

  Future<Database> get _db async => await AppDatabase.getInstance();

  Future<void> _upsertGroupedBagsakanOperation({
    required String courierId,
    required int groupId,
    required String operationType,
    required List<String> barcodes,
    required int createdAt,
    String? groupName,
  }) async {
    if (barcodes.isEmpty) return;

    final db = await _db;
    final groupBarcode = 'BAGSAKAN_$groupId';

    String? oppositeType;
    if (operationType == 'ASSIGN_TO_BAGSAKAN') {
      oppositeType = 'UNASSIGN_FROM_BAGSAKAN';
    } else if (operationType == 'UNASSIGN_FROM_BAGSAKAN') {
      oppositeType = 'ASSIGN_TO_BAGSAKAN';
    }

    Set<String> parseBarcodeSet(String? payloadJson) {
      if (payloadJson == null || payloadJson.isEmpty) return <String>{};
      try {
        final decoded = jsonDecode(payloadJson);
        if (decoded is! Map<String, dynamic>) return <String>{};
        final raw = decoded['barcodes'];
        if (raw is! List) return <String>{};
        return raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet();
      } catch (_) {
        return <String>{};
      }
    }

    // Resolve group name from existing payload or DB if not provided.
    String? resolvedName = groupName;
    if (resolvedName == null || resolvedName.isEmpty) {
      final existingRows = await db.query(
        'sync_operations',
        columns: ['payload_json'],
        where:
            "courier_id = ? AND barcode = ? "
            "AND operation_type IN ('CREATE_BAGSAKAN','UPDATE_BAGSAKAN_GROUP','ASSIGN_TO_BAGSAKAN','UNASSIGN_FROM_BAGSAKAN')",
        whereArgs: [courierId, groupBarcode],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        try {
          final p = jsonDecode(
            existingRows.first['payload_json']?.toString() ?? '{}',
          );
          resolvedName = p['group_name']?.toString();
        } catch (_) {}
      }
    }
    if (resolvedName == null || resolvedName.isEmpty) {
      final groupRow = await db.query(
        'bagsakan_groups',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [groupId],
        limit: 1,
      );
      resolvedName = groupRow.isNotEmpty
          ? groupRow.first['name']?.toString()
          : null;
    }

    String encodePayload(Iterable<String> values) {
      return jsonEncode({
        'group_id': groupId,
        if (resolvedName != null && resolvedName.isNotEmpty)
          'group_name': resolvedName,
        'barcodes': values.toList(growable: false),
      });
    }

    final incoming = barcodes
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (incoming.isEmpty) return;

    if (oppositeType != null) {
      final oppositeRows = await db.query(
        'sync_operations',
        columns: ['id', 'payload_json'],
        where:
            "courier_id = ? AND barcode = ? AND operation_type = ? "
            "AND status IN ('pending','failed','conflict')",
        whereArgs: [courierId, groupBarcode, oppositeType],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (oppositeRows.isNotEmpty) {
        final oppositeRow = oppositeRows.first;
        final oppositeId = oppositeRow['id']?.toString();
        if (oppositeId != null && oppositeId.isNotEmpty) {
          final oppositeSet = parseBarcodeSet(
            oppositeRow['payload_json']?.toString(),
          );

          final cancelled = incoming
              .where(
                (b) =>
                    oppositeSet.any((x) => x.toUpperCase() == b.toUpperCase()),
              )
              .toSet();

          if (cancelled.isNotEmpty) {
            oppositeSet.removeWhere(
              (x) => cancelled.any((c) => c.toUpperCase() == x.toUpperCase()),
            );
            incoming.removeWhere(
              (x) => cancelled.any((c) => c.toUpperCase() == x.toUpperCase()),
            );

            if (oppositeSet.isEmpty) {
              await db.delete(
                'sync_operations',
                where: 'id = ?',
                whereArgs: [oppositeId],
              );
            } else {
              await db.update(
                'sync_operations',
                {
                  'payload_json': encodePayload(oppositeSet),
                  'status': 'pending',
                  'retry_count': 0,
                  'last_error': null,
                },
                where: 'id = ?',
                whereArgs: [oppositeId],
              );
            }
          }
        }
      }
    }

    if (incoming.isEmpty) return;

    final rows = await db.query(
      'sync_operations',
      columns: ['id', 'payload_json'],
      where:
          "courier_id = ? AND barcode = ? AND operation_type = ? "
          "AND status IN ('pending','failed','conflict')",
      whereArgs: [courierId, groupBarcode, operationType],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      await SyncOperationsDao.instance.insert(
        SyncOperation(
          id: const Uuid().v4(),
          courierId: courierId,
          barcode: groupBarcode,
          operationType: operationType,
          payloadJson: encodePayload(incoming),
          createdAt: createdAt,
        ),
      );
      return;
    }

    final row = rows.first;
    final opId = row['id']?.toString();
    if (opId == null || opId.isEmpty) return;

    final merged = parseBarcodeSet(row['payload_json']?.toString())
      ..addAll(incoming);

    await db.update(
      'sync_operations',
      {
        'payload_json': encodePayload(merged),
        // Promote back to pending so grouped retries are not stuck in failed/conflict.
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [opId],
    );
  }

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
    final barcode = 'BAGSAKAN_$groupId';

    await db.transaction((txn) async {
      // 1. Update local metadata
      await txn.update(
        'bagsakan_groups',
        {'name': name, 'description': description, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [groupId],
      );

      // 2. Collapse/Upsert sync operation
      // If there's already a pending/failed/conflict UPDATE_BAGSAKAN_GROUP for this barcode,
      // update its payload instead of inserting a new one.
      final existing = await txn.query(
        'sync_operations',
        columns: ['id'],
        where:
            "courier_id = ? AND barcode = ? AND operation_type = ? "
            "AND status IN ('pending', 'failed', 'conflict')",
        whereArgs: [courierId, barcode, 'UPDATE_BAGSAKAN_GROUP'],
        limit: 1,
      );

      final payloadJson = jsonEncode({
        'id': groupId,
        'name': name,
        'description': description,
      });

      if (existing.isNotEmpty) {
        final opId = existing.first['id'] as String;
        await txn.update(
          'sync_operations',
          {
            'payload_json': payloadJson,
            'status':
                'pending', // Re-promote to pending if it was failed/conflict
            'retry_count': 0,
            'last_error': null,
            'created_at':
                now, // Update timestamp so it stays fresh in queue order
          },
          where: 'id = ?',
          whereArgs: [opId],
        );
      } else {
        await SyncOperationsDao.instance.insert(
          SyncOperation(
            id: const Uuid().v4(),
            courierId: courierId,
            barcode: barcode,
            operationType: 'UPDATE_BAGSAKAN_GROUP',
            payloadJson: payloadJson,
            createdAt: now,
          ),
        );
      }
    });
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
      await _upsertGroupedBagsakanOperation(
        courierId: courierId,
        groupId: groupId,
        operationType: 'UNASSIGN_FROM_BAGSAKAN',
        barcodes: barcodes,
        createdAt: now,
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

    await _upsertGroupedBagsakanOperation(
      courierId: courierId,
      groupId: groupId,
      operationType: 'ASSIGN_TO_BAGSAKAN',
      barcodes: barcodes,
      createdAt: now,
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
      await _upsertGroupedBagsakanOperation(
        courierId: courierId,
        groupId: groupId,
        operationType: 'UNASSIGN_FROM_BAGSAKAN',
        barcodes: [barcode],
        createdAt: now,
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
      SELECT g.*, 
             COUNT(d.barcode) as item_count,
             (SELECT COUNT(*) FROM sync_operations s 
              WHERE s.barcode = 'BAGSAKAN_' || g.id 
                AND s.status IN ('pending', 'processing', 'failed', 'conflict')) as pending_sync_count
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
      // Verify not submitted and get name
      final groups = await txn.query(
        'bagsakan_groups',
        columns: ['status', 'name'],
        where: 'id = ?',
        whereArgs: [groupId],
      );
      if (groups.isEmpty) throw Exception('Group not found');
      if (groups.first['status'] == 'submitted') {
        throw Exception('Cannot delete a submitted bagsakan group');
      }
      final groupName = groups.first['name']?.toString() ?? 'Unknown';

      // IMPORTANT: stay on the transaction handle only to avoid DB lock
      // contention (sqflite warns if we call root DB methods while txn is open).
      final itemRows = await txn.query(
        'local_deliveries',
        columns: ['barcode'],
        where: 'bagsakan_id = ?',
        whereArgs: [groupId],
      );
      final barcodes = itemRows
          .map((e) => (e['barcode']?.toString() ?? '').trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Check if this group exists on the server yet by looking for pending CREATE/UPDATE operations.
      // If the group is purely local (CREATE is still pending), we can cancel everything
      // without hitting the server.
      final groupBarcode = 'BAGSAKAN_$groupId';
      final pendingOps = await txn.query(
        'sync_operations',
        columns: ['id', 'status'],
        where:
            'barcode = ? AND operation_type = ? AND status IN (\'pending\', \'failed\', \'conflict\', \'processing\')',
        whereArgs: [groupBarcode, 'CREATE_BAGSAKAN'],
      );

      final isLocalOnly = pendingOps.isNotEmpty;

      // 1. Unassign local deliveries
      await txn.update(
        'local_deliveries',
        {'bagsakan_id': null, 'updated_at': now, 'sync_status': 'dirty'},
        where: 'bagsakan_id = ?',
        whereArgs: [groupId],
      );

      // 2. Delete the group locally
      await txn.delete(
        'bagsakan_groups',
        where: 'id = ?',
        whereArgs: [groupId],
      );

      if (isLocalOnly) {
        // 3a. ATOMIC CANCELLATION: Delete ALL pending operations for this local group.
        // This includes CREATE, ASSIGN, UNASSIGN, etc.
        await txn.delete(
          'sync_operations',
          where: 'barcode = ?',
          whereArgs: [groupBarcode],
        );
        debugPrint(
          '[DAO] deleteBagsakanGroup: atomic cancellation for local-only group $groupId',
        );
      } else {
        // 3b. Queue a server-side delete operation for existing groups.
        await txn.insert(
          'sync_operations',
          SyncOperation(
            id: const Uuid().v4(),
            courierId: courierId,
            barcode: groupBarcode,
            operationType: 'DELETE_BAGSAKAN_GROUP',
            payloadJson: jsonEncode({
              'id': groupId,
              'group_name': groupName,
              'barcodes': barcodes,
            }),
            createdAt: now,
          ).toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Submits a bagsakan group, propagating data from a source delivery to all others.
  /// This action is irreversible and locks the group.
  Future<void> submitBagsakanGroup(
    int groupId,
    String sourceBarcode,
    String courierId, {
    String? propagationStatus,
  }) async {
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
      final sourceStatus = DeliveryStatus.fromString(
        propagationStatus ?? source.deliveryStatus,
      );
      if (!sourceStatus.isFinal) {
        throw Exception('Source delivery must be in a final status');
      }
      final sourceStatusApi = sourceStatus.toApiString();

      // 2. Update all other deliveries in the group
      final otherRows = await txn.query(
        'local_deliveries',
        where: 'bagsakan_id = ? AND barcode != ?',
        whereArgs: [groupId, sourceBarcode],
      );

      for (final row in otherRows) {
        final item = LocalDelivery.fromDb(row);
        final itemMap = item.toDeliveryMap();

        // Merge delivery details from source into itemMap.
        // Status propagation is based on the chosen source update.
        final Map<String, dynamic> updatedMap = {
          ...itemMap,
          'delivery_status': sourceStatusApi,
          'delivered_at': sourceStatus == DeliveryStatus.delivered
              ? source.deliveredAt
              : null,
          'completed_at': source.completedAt ?? now,
          'note': sourceMap['note'],
          'reason': sourceMap['reason'],
          'transaction_at': sourceMap['transaction_at'],
          'delivered_date': sourceMap['delivered_date'],
          'latitude': sourceMap['latitude'],
          'longitude': sourceMap['longitude'],
          'geo_accuracy': sourceMap['geo_accuracy'],
          'delivery_confirmation_code': sourceMap['delivery_confirmation_code'],
        };

        if (sourceStatus == DeliveryStatus.delivered) {
          updatedMap['proof_of_delivery'] = sourceMap['proof_of_delivery'];
          updatedMap['signature_image'] = sourceMap['signature_image'];
          updatedMap['photo_image'] = sourceMap['photo_image'];
          updatedMap['recipient_relation'] = sourceMap['recipient_relation'];
          updatedMap['recipient_type'] = sourceMap['recipient_type'];
          updatedMap['recipient'] = sourceMap['recipient'];
          updatedMap['relationship'] = sourceMap['relationship'];
          updatedMap['placement_type'] = sourceMap['placement_type'];
        }

        await txn.update(
          'local_deliveries',
          {
            'delivery_status': sourceStatusApi,
            'delivered_at': sourceStatus == DeliveryStatus.delivered
                ? source.deliveredAt
                : null,
            'completed_at': source.completedAt ?? now,
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

      // 4. Queue sync operation on the same transaction to avoid DB lock.
      await txn.insert(
        'sync_operations',
        SyncOperation(
          id: const Uuid().v4(),
          courierId: courierId,
          barcode: 'BAGSAKAN_$groupId',
          operationType: 'SUBMIT_BAGSAKAN',
          payloadJson: jsonEncode({
            'group_id': groupId,
            'source_barcode': sourceBarcode,
            'propagation_status': sourceStatusApi,
            // barcodes are no longer sent to the server (handled server-side)
            // but we keep them locally for sync manager cleanup logic.
            'barcodes': otherRows.map((e) => e['barcode']).toList(),
          }),
          createdAt: now,
        ).toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
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

    final deliveries = maps.map((e) => LocalDelivery.fromDb(e)).toList();

    if (eligibleOnly) {
      // Post-filter: enforce "< 3 attempts" for failed deliveries.
      // This logic is mirrored from LocalDeliveryDao.searchVisibleByQuery.
      return deliveries.where((d) {
        if (d.deliveryStatus.toUpperCase() != 'FAILED_DELIVERY') return true;
        return getAttemptsCountFromMap(d.toDeliveryMap()) < 3;
      }).toList();
    }

    return deliveries;
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

    final deliveries = maps.map((e) => LocalDelivery.fromDb(e)).toList();

    if (eligibleOnly) {
      // Post-filter: enforce "< 3 attempts" for failed deliveries.
      return deliveries.where((d) {
        if (d.deliveryStatus.toUpperCase() != 'FAILED_DELIVERY') return true;
        return getAttemptsCountFromMap(d.toDeliveryMap()) < 3;
      }).toList();
    }

    return deliveries;
  }

  /// Synchronizes Bagsakan groups from the server.
  /// Archived groups are deleted locally. Also reconciles local_deliveries.bagsakan_id
  /// from the server's barcodes payload so the mobile stays consistent even when
  /// ASSIGN_TO_BAGSAKAN operations haven't synced yet.
  Future<void> upsertGroupsFromSync(List<Map<String, dynamic>> groups) async {
    if (groups.isEmpty) return;
    final db = await _db;

    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final s = value.trim();
        if (s.isEmpty) return null;
        return int.tryParse(s);
      }
      return null;
    }

    int? toEpochMs(dynamic value) {
      final asInt = toInt(value);
      if (asInt != null) return asInt;
      if (value is String) {
        final dt = DateTime.tryParse(value.trim());
        if (dt != null) return dt.millisecondsSinceEpoch;
      }
      return null;
    }

    bool toBoolish(dynamic value) {
      if (value == true) return true;
      if (value == false || value == null) return false;
      if (value is num) return value.toInt() == 1;
      if (value is String) {
        final s = value.trim().toLowerCase();
        return s == '1' || s == 'true' || s == 'yes';
      }
      return false;
    }

    await db.transaction((txn) async {
      for (final group in groups) {
        final id = toInt(group['id']);
        if (id == null) {
          debugPrint(
            '[DAO] upsertGroupsFromSync: Skipping group with invalid id: ${group['id']}',
          );
          continue;
        }

        final isArchived = toBoolish(group['is_archived']);

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
            columns: ['status', 'submitted_at', 'created_at'],
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

          final now = DateTime.now().millisecondsSinceEpoch;
          final createdAtFromServer = toEpochMs(group['created_at']);
          final existingCreatedAt = existing.isNotEmpty
              ? toEpochMs(existing.first['created_at'])
              : null;

          final submittedAtFromServer = toEpochMs(group['submitted_at']);
          final serverStatus =
              (group['status']?.toString().trim().isNotEmpty ?? false)
              ? group['status'].toString()
              : 'pending';
          final groupName =
              (group['name']?.toString().trim().isNotEmpty ?? false)
              ? group['name'].toString()
              : 'BAGSAKAN_$id';

          // Upsert group metadata
          final data = {
            'id': id,
            'name': groupName,
            'description': group['description']?.toString(),
            'status': serverStatus,
            'submitted_at': submittedAtFromServer,
            'is_archived': group['is_archived'] == true ? 1 : 0,
            'created_at': createdAtFromServer ?? existingCreatedAt ?? now,
            'updated_at': now,
          };

          // If we are protecting a submitted status, ensure we don't overwrite it.
          if (existing.isNotEmpty &&
              existing.first['status'] == 'submitted' &&
              data['status'] != 'submitted') {
            data['status'] = 'submitted';
            // Also preserve submitted_at if the server hasn't provided one yet
            data['submitted_at'] ??= existing.first['submitted_at'];
          }

          // ── KEY FIX 2: Reconcile redundant sync operations ──
          // If the server state already matches a pending operation, mark it as synced.
          await _reconcileRedundantOperations(txn, id, group);

          // Use insert with conflict replace to upsert
          await txn.insert(
            'bagsakan_groups',
            data,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // ── KEY FIX: Reconcile local_deliveries.bagsakan_id from server payload ──
          // The server includes a 'barcodes' list in the sync payload.
          // 1. If archived: unassign ALL local items.
          // 2. If active: reconcile to match server list exactly.
          if (data['is_archived'] == 1) {
            await txn.update(
              'local_deliveries',
              {'bagsakan_id': null, 'updated_at': now},
              where: 'bagsakan_id = ?',
              whereArgs: [id],
            );
            debugPrint(
              '[DAO] upsertGroupsFromSync: unassigned all items for ARCHIVED group $id',
            );
          } else {
            final serverBarcodes = group['barcodes'];
            if (serverBarcodes is List) {
              final barcodeList = serverBarcodes
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              // A. Unassign items that are NO LONGER in this group on the server.
              if (barcodeList.isEmpty) {
                await txn.update(
                  'local_deliveries',
                  {'bagsakan_id': null, 'updated_at': now},
                  where: 'bagsakan_id = ?',
                  whereArgs: [id],
                );
              } else {
                final placeholders = barcodeList.map((_) => '?').join(', ');
                await txn.rawUpdate(
                  'UPDATE local_deliveries '
                  'SET bagsakan_id = NULL, updated_at = ? '
                  'WHERE bagsakan_id = ? AND barcode COLLATE NOCASE NOT IN ($placeholders)',
                  [now, id, ...barcodeList],
                );

                // B. Assign items that ARE in this group on the server.
                await txn.rawUpdate(
                  'UPDATE local_deliveries '
                  'SET bagsakan_id = ?, updated_at = ? '
                  'WHERE barcode COLLATE NOCASE IN ($placeholders)',
                  [id, now, ...barcodeList],
                );
              }
              debugPrint(
                '[DAO] upsertGroupsFromSync: reconciled ${barcodeList.length} items for group $id',
              );
            }
          }
        }
      }
    });
  }

  /// Re-maps a local temporary group id to the authoritative server id.
  ///
  /// This keeps local deliveries and queued sync operations consistent when the
  /// server does not preserve client-provided ids during CREATE_BAGSAKAN.
  Future<void> remapGroupId({
    required int fromGroupId,
    required int toGroupId,
  }) async {
    if (fromGroupId == toGroupId) return;

    final db = await _db;
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Move deliveries first so UI and subsequent queue operations point to
      // the server-backed id.
      await txn.update(
        'local_deliveries',
        {'bagsakan_id': toGroupId, 'updated_at': now},
        where: 'bagsakan_id = ?',
        whereArgs: [fromGroupId],
      );

      final sourceRows = await txn.query(
        'bagsakan_groups',
        where: 'id = ?',
        whereArgs: [fromGroupId],
        limit: 1,
      );
      if (sourceRows.isNotEmpty) {
        final source = Map<String, dynamic>.from(sourceRows.first);
        source['id'] = toGroupId;
        source['updated_at'] = now;

        final targetRows = await txn.query(
          'bagsakan_groups',
          where: 'id = ?',
          whereArgs: [toGroupId],
          limit: 1,
        );
        if (targetRows.isEmpty) {
          await txn.insert(
            'bagsakan_groups',
            source,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await txn.delete(
          'bagsakan_groups',
          where: 'id = ?',
          whereArgs: [fromGroupId],
        );
      }

      final legacyBarcode = 'BAGSAKAN_$fromGroupId';
      final canonicalBarcode = 'BAGSAKAN_$toGroupId';
      final rows = await txn.query(
        'sync_operations',
        columns: ['id', 'operation_type', 'payload_json', 'status'],
        where:
            'barcode = ? AND status IN (\'pending\', \'processing\', \'failed\', \'conflict\')',
        whereArgs: [legacyBarcode],
      );

      for (final row in rows) {
        final opId = row['id']?.toString() ?? '';
        if (opId.isEmpty) continue;

        final opType = row['operation_type']?.toString() ?? '';
        final payloadStr = row['payload_json']?.toString();
        Map<String, dynamic> payload = {};
        if (payloadStr != null && payloadStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(payloadStr);
            if (decoded is Map<String, dynamic>) {
              payload = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {
            payload = {};
          }
        }

        if (opType == 'CREATE_BAGSAKAN' ||
            opType == 'UPDATE_BAGSAKAN_GROUP' ||
            opType == 'DELETE_BAGSAKAN_GROUP') {
          payload['id'] = toGroupId;
        } else if (opType == 'ASSIGN_TO_BAGSAKAN' ||
            opType == 'UNASSIGN_FROM_BAGSAKAN' ||
            opType == 'SUBMIT_BAGSAKAN') {
          payload['group_id'] = toGroupId;
        }

        await txn.update(
          'sync_operations',
          {
            'barcode': canonicalBarcode,
            if (payload.isNotEmpty) 'payload_json': jsonEncode(payload),
          },
          where: 'id = ?',
          whereArgs: [opId],
        );
      }
    });
  }

  /// Force reconcile bagsakan_id during cleanup to ensure consistency
  /// even if a concurrent sync-from-api pass cleared it locally.
  Future<void> forceReconcileItemAssignment(
    String barcode,
    int? groupId,
  ) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'local_deliveries',
      {'bagsakan_id': groupId, 'updated_at': now},
      where: 'barcode COLLATE NOCASE = ?',
      whereArgs: [barcode],
    );
  }

  /// Deletes ALL bagsakan groups and clears bagsakan_id from all deliveries.
  /// Used by clearAndSync operations (which must not touch sync_operations).
  Future<void> deleteAllGroups() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE local_deliveries SET bagsakan_id = NULL WHERE bagsakan_id IS NOT NULL',
      );
      await txn.delete('bagsakan_groups');
    });
  }

  /// Removes local bagsakan groups that are not in the provided set of server IDs,
  /// provided they have no pending sync operations.
  /// This ensures "Online Priority" by purging stale local records that don't
  /// exist on the authoritative server.
  Future<void> removeStaleGroups(Set<int> serverIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      // Find all groups not in the server list
      final placeholders = serverIds.isEmpty
          ? ''
          : serverIds.map((_) => '?').join(', ');
      final where = serverIds.isEmpty ? '1=1' : 'id NOT IN ($placeholders)';

      final staleGroups = await txn.query(
        'bagsakan_groups',
        columns: ['id'],
        where: where,
        whereArgs: serverIds.toList(),
      );

      for (final g in staleGroups) {
        final id = g['id'] as int;

        // Safety: check if there are pending sync operations for this group
        // If it's pending, it means it's a new local-only group; keep it.
        final pending = await txn.query(
          'sync_operations',
          columns: ['id'],
          where:
              "barcode = ? AND status IN ('pending', 'processing', 'failed', 'conflict')",
          whereArgs: ['BAGSAKAN_$id'],
          limit: 1,
        );

        if (pending.isEmpty) {
          debugPrint(
            '[DAO] removeStaleGroups: purging stale group $id (not on server, no pending sync)',
          );

          // 1. Unassign items
          await txn.update(
            'local_deliveries',
            {'bagsakan_id': null},
            where: 'bagsakan_id = ?',
            whereArgs: [id],
          );

          // 2. Delete group
          await txn.delete('bagsakan_groups', where: 'id = ?', whereArgs: [id]);
        }
      }
    });
  }

  /// Aggressively reconciles pending sync operations against authoritative server data.
  /// This prevents "ghost" unsynced statuses when the server already has the data.
  Future<void> _reconcileRedundantOperations(
    Transaction txn,
    int groupId,
    Map<String, dynamic> serverGroup,
  ) async {
    final barcode = 'BAGSAKAN_$groupId';
    final ops = await txn.query(
      'sync_operations',
      where: "barcode = ? AND status IN ('pending', 'failed', 'conflict')",
      whereArgs: [barcode],
    );

    if (ops.isEmpty) return;

    final serverName = serverGroup['name']?.toString() ?? '';
    final serverDesc = serverGroup['description']?.toString() ?? '';
    final serverStatus = serverGroup['status']?.toString() ?? 'pending';
    final serverBarcodes =
        (serverGroup['barcodes'] as List?)
            ?.map((e) => e.toString().toUpperCase())
            .toSet() ??
        {};

    final now = DateTime.now().millisecondsSinceEpoch;

    for (final op in ops) {
      final opId = op['id'] as String;
      final type = op['operation_type'] as String;
      final payloadJson = op['payload_json'] as String?;
      if (payloadJson == null) continue;

      bool isRedundant = false;
      try {
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

        if (type == 'CREATE_BAGSAKAN' || type == 'UPDATE_BAGSAKAN_GROUP') {
          final pName = payload['name']?.toString() ?? '';
          final pDesc = payload['description']?.toString() ?? '';
          // If server matches what we want to update, it's redundant.
          if (pName == serverName && pDesc == serverDesc) {
            isRedundant = true;
          }
        } else if (type == 'SUBMIT_BAGSAKAN') {
          if (serverStatus == 'submitted') {
            isRedundant = true;
          }
        } else if (type == 'ASSIGN_TO_BAGSAKAN') {
          final pBarcodes =
              (payload['barcodes'] as List?)
                  ?.map((e) => e.toString().toUpperCase())
                  .toList() ??
              [];
          if (pBarcodes.isNotEmpty &&
              pBarcodes.every((b) => serverBarcodes.contains(b))) {
            isRedundant = true;
          }
        } else if (type == 'UNASSIGN_FROM_BAGSAKAN') {
          final pBarcodes =
              (payload['barcodes'] as List?)
                  ?.map((e) => e.toString().toUpperCase())
                  .toList() ??
              [];
          if (pBarcodes.isNotEmpty &&
              pBarcodes.every((b) => !serverBarcodes.contains(b))) {
            isRedundant = true;
          }
        }
      } catch (e) {
        debugPrint('[DAO] Error parsing payload for reconciliation: $e');
      }

      if (isRedundant) {
        debugPrint(
          '[DAO] _reconcileRedundantOperations: marking $type for $barcode as synced (server already matches)',
        );
        await txn.update(
          'sync_operations',
          {
            'status': 'synced',
            'last_attempt_at': now,
            'last_error': 'Resolved via authoritative sync sweep.',
          },
          where: 'id = ?',
          whereArgs: [opId],
        );
      }
    }
  }
}
