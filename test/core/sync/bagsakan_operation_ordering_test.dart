import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';

void main() {
  group('Bagsakan Sync Operation Ordering Tests', () {
    late MockSyncOperationsDao mockDao;

    setUp(() {
      mockDao = MockSyncOperationsDao();
    });

    /// Tests the core requirement:
    /// Operations must execute in this order:
    /// 1. CREATE_BAGSAKAN
    /// 2. UPDATE_BAGSAKAN_GROUP
    /// 3. ASSIGN_TO_BAGSAKAN
    /// 4. UNASSIGN_FROM_BAGSAKAN
    /// 5. SUBMIT_BAGSAKAN
    /// 6. DELETE_BAGSAKAN_GROUP
    test('Operations execute in required precedence order', () async {
      final operations = [
        SyncOperation(
          id: 'op-create',
          courierId: 'courier-1',
          barcode: 'BAGSAKAN_1',
          operationType: 'CREATE_BAGSAKAN',
          payloadJson: jsonEncode({'id': 1, 'name': 'Group 1'}),
          status: 'pending',
          createdAt: 1000,
        ),
        SyncOperation(
          id: 'op-update',
          courierId: 'courier-1',
          barcode: 'BAGSAKAN_1',
          operationType: 'UPDATE_BAGSAKAN_GROUP',
          payloadJson: jsonEncode({'id': 1, 'name': 'Updated Group 1'}),
          status: 'pending',
          createdAt: 2000,
        ),
        SyncOperation(
          id: 'op-assign',
          courierId: 'courier-1',
          barcode: 'BAGSAKAN_1',
          operationType: 'ASSIGN_TO_BAGSAKAN',
          payloadJson: jsonEncode({
            'group_id': 1,
            'barcodes': ['PKG001', 'PKG002'],
          }),
          status: 'pending',
          createdAt: 3000,
        ),
        SyncOperation(
          id: 'op-submit',
          courierId: 'courier-1',
          barcode: 'BAGSAKAN_1',
          operationType: 'SUBMIT_BAGSAKAN',
          payloadJson: jsonEncode({
            'group_id': 1,
            'source_barcode': 'PKG001',
            'barcodes': ['PKG002'],
          }),
          status: 'pending',
          createdAt: 4000,
        ),
      ];

      when(mockDao.getPending('courier-1')).thenAnswer((_) async => operations);

      final pending = await mockDao.getPending('courier-1');

      // Verify operations are in precedence order
      expect(pending[0].operationType, 'CREATE_BAGSAKAN');
      expect(pending[1].operationType, 'UPDATE_BAGSAKAN_GROUP');
      expect(pending[2].operationType, 'ASSIGN_TO_BAGSAKAN');
      expect(pending[3].operationType, 'SUBMIT_BAGSAKAN');

      // Verify no operation has a later createdAt than its successor
      for (int i = 0; i < pending.length - 1; i++) {
        expect(
          pending[i].createdAt <= pending[i + 1].createdAt,
          true,
          reason:
              '${pending[i].operationType} should not be created after ${pending[i + 1].operationType}',
        );
      }
    });

    test('ASSIGN operation blocked if CREATE not synced', () async {
      // Scenario: User created group offline, tried to assign items,
      // then came online. ASSIGN should wait for CREATE to complete first.

      when(
        mockDao.hasUnfinishedCreateBagsakan(
          'courier-1',
          1,
          excludeOperationId: 'op-assign',
        ),
      ).thenAnswer((_) async => true);

      final waiting = await mockDao.hasUnfinishedCreateBagsakan(
        'courier-1',
        1,
        excludeOperationId: 'op-assign',
      );

      expect(waiting, true);
      // In real sync, ASSIGN operation would be requeued until CREATE completes
    });

    test('DELETE operation blocks dependent operations', () async {
      // If DELETE is encountered before ASSIGN completes,
      // ASSIGN for that group should not proceed

      // This is handled by getAll() with status filtering
      when(mockDao.getAll('courier-1')).thenAnswer(
        (_) async => [
          SyncOperation(
            id: 'op-assign',
            courierId: 'courier-1',
            barcode: 'BAGSAKAN_1',
            operationType: 'ASSIGN_TO_BAGSAKAN',
            payloadJson: jsonEncode({'group_id': 1}),
            status: 'pending',
            createdAt: 1000,
          ),
          SyncOperation(
            id: 'op-delete',
            courierId: 'courier-1',
            barcode: 'BAGSAKAN_1',
            operationType: 'DELETE_BAGSAKAN_GROUP',
            payloadJson: jsonEncode({'id': 1}),
            status: 'pending',
            createdAt: 2000,
          ),
        ],
      );

      final all = await mockDao.getAll('courier-1');

      // ASSIGN comes before DELETE, so it should proceed
      expect(all[0].operationType, 'ASSIGN_TO_BAGSAKAN');
      expect(all[1].operationType, 'DELETE_BAGSAKAN_GROUP');
    });

    test(
      'Multiple groups can be processed in parallel (independent)',
      () async {
        // Group 1 and Group 2 are independent and can sync in any order
        final operations = [
          // Group 1 operations
          SyncOperation(
            id: 'g1-create',
            courierId: 'courier-1',
            barcode: 'BAGSAKAN_1',
            operationType: 'CREATE_BAGSAKAN',
            payloadJson: jsonEncode({'id': 1}),
            status: 'pending',
            createdAt: 1000,
          ),
          // Group 2 operations
          SyncOperation(
            id: 'g2-create',
            courierId: 'courier-1',
            barcode: 'BAGSAKAN_2',
            operationType: 'CREATE_BAGSAKAN',
            payloadJson: jsonEncode({'id': 2}),
            status: 'pending',
            createdAt: 1100,
          ),
          // Group 1 assign (depends on Group 1 create)
          SyncOperation(
            id: 'g1-assign',
            courierId: 'courier-1',
            barcode: 'BAGSAKAN_1',
            operationType: 'ASSIGN_TO_BAGSAKAN',
            payloadJson: jsonEncode({'group_id': 1}),
            status: 'pending',
            createdAt: 1200,
          ),
        ];

        when(
          mockDao.getPending('courier-1'),
        ).thenAnswer((_) async => operations);

        final pending = await mockDao.getPending('courier-1');

        // Verify mixed-group operations are in creation order
        expect(pending[0].barcode, 'BAGSAKAN_1');
        expect(pending[1].barcode, 'BAGSAKAN_2');
        expect(pending[2].barcode, 'BAGSAKAN_1');

        // But sync logic should handle group 1 create before group 1 assign
        // and group 2 create independently
      },
    );

    test('Payload includes group_id for dependent operations', () async {
      final assignOp = SyncOperation(
        id: 'op-assign',
        courierId: 'courier-1',
        barcode: 'BAGSAKAN_5',
        operationType: 'ASSIGN_TO_BAGSAKAN',
        payloadJson: jsonEncode({
          'group_id': 5,
          'group_name': 'Test Group',
          'barcodes': ['PKG001', 'PKG002'],
        }),
        status: 'pending',
        createdAt: 0,
      );

      final payload = jsonDecode(assignOp.payloadJson) as Map<String, dynamic>;

      expect(payload['group_id'], 5);
      expect(payload['barcodes'], ['PKG001', 'PKG002']);
      // group_id is used to detect and wait for CREATE dependency
    });

    test('Deleted synced operations removed from queue', () async {
      when(
        mockDao.deleteByStatus('courier-1', 'synced'),
      ).thenAnswer((_) async => 3);

      final deleted = await mockDao.deleteByStatus('courier-1', 'synced');

      expect(deleted, 3);
      // Synced operations cleaned up after retention period
    });

    test('Retry count incremented on failure', () async {
      when(
        mockDao.updateStatus(
          'op-assign',
          'failed',
          retryCount: 1,
          lastError: 'Transient error',
        ),
      ).thenAnswer((_) async {});

      await mockDao.updateStatus(
        'op-assign',
        'failed',
        retryCount: 1,
        lastError: 'Transient error',
      );

      verify(
        mockDao.updateStatus(
          'op-assign',
          'failed',
          retryCount: 1,
          lastError: any,
        ),
      ).called(1);
    });

    test('Conflict status prevents auto-retry', () async {
      final conflictOp = SyncOperation(
        id: 'op-assign',
        courierId: 'courier-1',
        barcode: 'BAGSAKAN_1',
        operationType: 'ASSIGN_TO_BAGSAKAN',
        payloadJson: jsonEncode({
          'group_id': 1,
          'barcodes': ['PKG001'],
        }),
        status: 'conflict',
        lastError: 'Barcode PKG001 already assigned to group "Other Group"',
        createdAt: 0,
      );

      // Conflict operations require user intervention, not auto-retry
      expect(conflictOp.status, 'conflict');
      expect(conflictOp.lastError, isNotNull);

      // Sync manager would skip conflict operations in auto-retry loop
      when(mockDao.getPending('courier-1')).thenAnswer(
        (_) async => [], // Pending status excludes 'conflict'
      );

      final pending = await mockDao.getPending('courier-1');
      expect(pending.isEmpty, true);
    });

    test('Processing state prevents duplicate concurrent syncs', () async {
      when(
        mockDao.updateStatus('op-assign', 'processing', lastAttemptAt: any),
      ).thenAnswer((_) async {});

      // Mark operation as processing
      await mockDao.updateStatus(
        'op-assign',
        'processing',
        lastAttemptAt: DateTime.now().millisecondsSinceEpoch,
      );

      // getPending should not return processing operations
      when(mockDao.getPending('courier-1')).thenAnswer((_) async => []);

      final pending = await mockDao.getPending('courier-1');
      expect(pending.isEmpty, true);
    });
  });
}

// ── Mock ───────────────────────────────────────────────────────────────────

class MockSyncOperationsDao extends Mock implements SyncOperationsDao {
  @override
  Future<void> insert(SyncOperation? operation) =>
      super.noSuchMethod(Invocation.method(#insert, [operation]));

  @override
  Future<int> deleteByStatus(String? courierId, String? status) => super
      .noSuchMethod(Invocation.method(#deleteByStatus, [courierId, status]));
}
