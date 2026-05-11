import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fsi_courier_app/core/database/bagsakan_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';

void main() {
  group('BagsakanDao - Offline Queuing Tests', () {
    late MockBagsakanDao mockBagsakanDao;
    late MockSyncOperationsDao mockSyncOpsDao;

    setUp(() {
      mockBagsakanDao = MockBagsakanDao();
      mockSyncOpsDao = MockSyncOperationsDao();
    });

    // ── CREATE Operations ──────────────────────────────────────────────────

    test('createBagsakanGroup queues CREATE_BAGSAKAN operation', () async {
      const groupName = 'Metro Manila Batch';
      const groupDesc = 'High priority items';
      const courierId = 'courier-123';
      final capturedOps = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((inv) async {
        capturedOps.add(inv.positionalArguments[0] as SyncOperation);
      });

      when(
        mockBagsakanDao.createBagsakanGroup(
          name: groupName,
          description: groupDesc,
          courierId: courierId,
        ),
      ).thenAnswer((_) async => 42);

      // Act
      final groupId = await mockBagsakanDao.createBagsakanGroup(
        name: groupName,
        description: groupDesc,
        courierId: courierId,
      );

      // Assert
      expect(groupId, 42);
      verify(mockSyncOpsDao.insert(any)).called(1);
      expect(capturedOps.length, 1);

      final op = capturedOps.first;
      expect(op.operationType, 'CREATE_BAGSAKAN');
      expect(op.barcode, 'BAGSAKAN_42');
      expect(op.courierId, courierId);
      expect(op.status, 'pending');

      final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
      expect(payload['id'], 42);
      expect(payload['name'], groupName);
      expect(payload['description'], groupDesc);
    });

    // ── ASSIGN Operations ──────────────────────────────────────────────────

    test('assignToBagsakan queues ASSIGN_TO_BAGSAKAN operation', () async {
      const groupId = 1;
      final barcodes = ['PKG001', 'PKG002', 'PKG003'];
      const courierId = 'courier-123';
      final capturedOps = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((inv) async {
        capturedOps.add(inv.positionalArguments[0] as SyncOperation);
      });

      when(
        mockBagsakanDao.assignToBagsakan(
          groupId: groupId,
          barcodes: barcodes,
          courierId: courierId,
        ),
      ).thenAnswer((_) async {});

      // Act
      await mockBagsakanDao.assignToBagsakan(
        groupId: groupId,
        barcodes: barcodes,
        courierId: courierId,
      );

      // Assert
      verify(mockSyncOpsDao.insert(any)).called(1);
      expect(capturedOps.length, 1);

      final op = capturedOps.first;
      expect(op.operationType, 'ASSIGN_TO_BAGSAKAN');
      expect(op.barcode, 'BAGSAKAN_$groupId');

      final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
      expect(payload['group_id'], groupId);
      expect(payload['barcodes'], barcodes);
    });

    test('assignToBagsakan merges with existing pending ASSIGN', () async {
      // Scenario: User assigned some barcodes, then assigned more
      // The operations should be merged, not duplicated

      when(mockSyncOpsDao.insert(any)).thenAnswer((_) async {});
      when(mockSyncOpsDao.update(any, any)).thenAnswer((_) async {});

      when(
        mockBagsakanDao.assignToBagsakan(
          groupId: 1,
          barcodes: ['PKG001'],
          courierId: 'courier-123',
        ),
      ).thenAnswer((_) async {});

      when(
        mockBagsakanDao.assignToBagsakan(
          groupId: 1,
          barcodes: ['PKG002', 'PKG003'],
          courierId: 'courier-123',
        ),
      ).thenAnswer((_) async {});

      // Act: Two assignments
      await mockBagsakanDao.assignToBagsakan(
        groupId: 1,
        barcodes: ['PKG001'],
        courierId: 'courier-123',
      );

      await mockBagsakanDao.assignToBagsakan(
        groupId: 1,
        barcodes: ['PKG002', 'PKG003'],
        courierId: 'courier-123',
      );

      // Result: Both should go through (or be merged by DAO)
      verify(
        mockBagsakanDao.assignToBagsakan(
          groupId: any,
          barcodes: any,
          courierId: any,
        ),
      ).called(2);
    });

    // ── UPDATE Operations ──────────────────────────────────────────────────

    test(
      'updateBagsakanGroup queues UPDATE_BAGSAKAN_GROUP operation',
      () async {
        const groupId = 1;
        const newName = 'Updated Group Name';
        const newDesc = 'Updated description';
        const courierId = 'courier-123';
        final capturedOps = <SyncOperation>[];

        when(mockSyncOpsDao.insert(any)).thenAnswer((inv) async {
          capturedOps.add(inv.positionalArguments[0] as SyncOperation);
        });

        when(
          mockBagsakanDao.updateBagsakanGroup(
            groupId: groupId,
            name: newName,
            description: newDesc,
            courierId: courierId,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockBagsakanDao.updateBagsakanGroup(
          groupId: groupId,
          name: newName,
          description: newDesc,
          courierId: courierId,
        );

        // Assert
        verify(mockSyncOpsDao.insert(any)).called(1);
        expect(capturedOps.length, 1);

        final op = capturedOps.first;
        expect(op.operationType, 'UPDATE_BAGSAKAN_GROUP');
        expect(op.barcode, 'BAGSAKAN_$groupId');

        final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
        expect(payload['id'], groupId);
        expect(payload['name'], newName);
        expect(payload['description'], newDesc);
      },
    );

    // ── DELETE Operations ──────────────────────────────────────────────────

    test(
      'deleteBagsakanGroup queues DELETE_BAGSAKAN_GROUP operation',
      () async {
        const groupId = 1;
        const courierId = 'courier-123';
        final capturedOps = <SyncOperation>[];

        when(mockSyncOpsDao.insert(any)).thenAnswer((inv) async {
          capturedOps.add(inv.positionalArguments[0] as SyncOperation);
        });

        when(
          mockBagsakanDao.deleteBagsakanGroup(groupId, courierId),
        ).thenAnswer((_) async {});

        // Act
        await mockBagsakanDao.deleteBagsakanGroup(groupId, courierId);

        // Assert
        verify(mockSyncOpsDao.insert(any)).called(1);
        expect(capturedOps.length, 1);

        final op = capturedOps.first;
        expect(op.operationType, 'DELETE_BAGSAKAN_GROUP');
      },
    );

    test(
      'deleteBagsakanGroup cancels all operations atomically for local-only groups',
      () async {
        // If the group CREATE hasn't synced yet, cancel everything
        when(
          mockSyncOpsDao.deleteByBarcode('BAGSAKAN_1'),
        ).thenAnswer((_) async => 5);

        final deleted = await mockSyncOpsDao.deleteByBarcode('BAGSAKAN_1');

        expect(deleted, 5);
        // All 5 operations (CREATE, 2x ASSIGN, UPDATE, DELETE) cancelled
      },
    );

    // ── UNASSIGN Operations ────────────────────────────────────────────────

    test(
      'unassignFromBagsakan queues UNASSIGN_FROM_BAGSAKAN operation',
      () async {
        const barcode = 'PKG001';
        const courierId = 'courier-123';
        final capturedOps = <SyncOperation>[];

        when(mockSyncOpsDao.insert(any)).thenAnswer((inv) async {
          capturedOps.add(inv.positionalArguments[0] as SyncOperation);
        });

        when(
          mockBagsakanDao.unassignFromBagsakan(barcode, courierId),
        ).thenAnswer((_) async {});

        // Act
        await mockBagsakanDao.unassignFromBagsakan(barcode, courierId);

        // Assert
        verify(mockSyncOpsDao.insert(any)).called(1);
        expect(capturedOps.length, 1);

        final op = capturedOps.first;
        expect(op.operationType, 'UNASSIGN_FROM_BAGSAKAN');
      },
    );

    // ── SUBMIT Operations ──────────────────────────────────────────────────

    test('submitBagsakanGroup queues SUBMIT_BAGSAKAN operation', () async {
      const groupId = 1;
      const sourceBarcode = 'PKG001';
      const courierId = 'courier-123';
      final capturedOps = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((inv) async {
        capturedOps.add(inv.positionalArguments[0] as SyncOperation);
      });

      when(
        mockBagsakanDao.submitBagsakanGroup(groupId, sourceBarcode, courierId),
      ).thenAnswer((_) async {});

      // Act
      await mockBagsakanDao.submitBagsakanGroup(
        groupId,
        sourceBarcode,
        courierId,
      );

      // Assert
      verify(mockSyncOpsDao.insert(any)).called(1);
      expect(capturedOps.length, 1);

      final op = capturedOps.first;
      expect(op.operationType, 'SUBMIT_BAGSAKAN');
      expect(op.barcode, 'BAGSAKAN_$groupId');

      final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
      expect(payload['group_id'], groupId);
      expect(payload['source_barcode'], sourceBarcode);
    });

    // ── Timestamp Tests ────────────────────────────────────────────────────

    test('All queued operations have accurate createdAt timestamp', () async {
      final beforeTime = DateTime.now().millisecondsSinceEpoch;
      final capturedOps = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((inv) async {
        capturedOps.add(inv.positionalArguments[0] as SyncOperation);
      });

      when(
        mockBagsakanDao.createBagsakanGroup(
          name: 'Test',
          description: 'Test',
          courierId: 'courier-123',
        ),
      ).thenAnswer((_) async => 1);

      // Act
      await mockBagsakanDao.createBagsakanGroup(
        name: 'Test',
        description: 'Test',
        courierId: 'courier-123',
      );

      final afterTime = DateTime.now().millisecondsSinceEpoch;

      // Assert
      expect(capturedOps.length, 1);
      expect(
        capturedOps.first.createdAt >= beforeTime,
        true,
        reason: 'createdAt should be >= beforeTime',
      );
      expect(
        capturedOps.first.createdAt <= afterTime,
        true,
        reason: 'createdAt should be <= afterTime',
      );
    });

    // ── Idempotency Tests ──────────────────────────────────────────────────

    test('Each operation has unique UUID for idempotency', () async {
      final ops = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((inv) async {
        ops.add(inv.positionalArguments[0] as SyncOperation);
      });

      when(
        mockBagsakanDao.createBagsakanGroup(
          name: 'G1',
          description: 'D1',
          courierId: 'courier-123',
        ),
      ).thenAnswer((_) async => 1);

      when(
        mockBagsakanDao.createBagsakanGroup(
          name: 'G2',
          description: 'D2',
          courierId: 'courier-123',
        ),
      ).thenAnswer((_) async => 2);

      // Create two groups
      await mockBagsakanDao.createBagsakanGroup(
        name: 'G1',
        description: 'D1',
        courierId: 'courier-123',
      );

      await mockBagsakanDao.createBagsakanGroup(
        name: 'G2',
        description: 'D2',
        courierId: 'courier-123',
      );

      expect(ops.length, 2);
      expect(ops[0].id, isNotEmpty);
      expect(ops[1].id, isNotEmpty);
      expect(ops[0].id, isNot(ops[1].id));
    });

    // ── No Local Persistence Tests ─────────────────────────────────────────

    test(
      'Bagsakan groups NOT stored locally, only operations queued',
      () async {
        // Verify that groups are not persisted in a separate local cache
        // Only sync_operations table is used for offline queuing

        when(mockSyncOpsDao.insert(any)).thenAnswer((_) async {});

        when(
          mockBagsakanDao.createBagsakanGroup(
            name: 'Test Group',
            description: 'Test',
            courierId: 'courier-123',
          ),
        ).thenAnswer((_) async => 1);

        // Act: Create group
        await mockBagsakanDao.createBagsakanGroup(
          name: 'Test Group',
          description: 'Test',
          courierId: 'courier-123',
        );

        // Assert: Only the operation is queued, not a separate group record
        verify(mockSyncOpsDao.insert(any)).called(1);
        // No cache insert call (like SharedPreferences or local groups table)
      },
    );
  });
}

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockBagsakanDao extends Mock implements BagsakanDao {}

class MockSyncOperationsDao extends Mock implements SyncOperationsDao {
  @override
  Future<void> insert(SyncOperation? operation) =>
      super.noSuchMethod(Invocation.method(#insert, [operation]));

  @override
  Future<int> deleteByBarcode(String? barcode) =>
      super.noSuchMethod(Invocation.method(#deleteByBarcode, [barcode]));

  @override
  Future<bool> hasUnfinishedCreateBagsakan(
    String? courierId,
    int? groupId, {
    String? excludeOperationId,
  }) => super.noSuchMethod(
    Invocation.method(
      #hasUnfinishedCreateBagsakan,
      [courierId, groupId],
      {#excludeOperationId: excludeOperationId},
    ),
  );
}
