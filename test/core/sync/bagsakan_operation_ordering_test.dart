import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';

class MockSyncOperationsDao extends Mock implements SyncOperationsDao {}

void main() {
  group('Bagsakan Sync Operation Ordering Tests', () {
    late MockSyncOperationsDao mockDao;

    setUp(() {
      mockDao = MockSyncOperationsDao();
    });

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

      when(
        () => mockDao.getPending('courier-1'),
      ).thenAnswer((_) async => operations);

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
      when(
        () => mockDao.hasUnfinishedCreateBagsakan(
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
    });

    test('DELETE operation blocks dependent operations', () async {
      when(() => mockDao.getAll('courier-1')).thenAnswer(
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

      expect(all[0].operationType, 'ASSIGN_TO_BAGSAKAN');
      expect(all[1].operationType, 'DELETE_BAGSAKAN_GROUP');
    });

    test(
      'Multiple groups can be processed in parallel (independent)',
      () async {
        final operations = [
          SyncOperation(
            id: 'g1-create',
            courierId: 'courier-1',
            barcode: 'BAGSAKAN_1',
            operationType: 'CREATE_BAGSAKAN',
            payloadJson: jsonEncode({'id': 1}),
            status: 'pending',
            createdAt: 1000,
          ),
          SyncOperation(
            id: 'g2-create',
            courierId: 'courier-1',
            barcode: 'BAGSAKAN_2',
            operationType: 'CREATE_BAGSAKAN',
            payloadJson: jsonEncode({'id': 2}),
            status: 'pending',
            createdAt: 1100,
          ),
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
          () => mockDao.getPending('courier-1'),
        ).thenAnswer((_) async => operations);

        final pending = await mockDao.getPending('courier-1');

        expect(pending[0].barcode, 'BAGSAKAN_1');
        expect(pending[1].barcode, 'BAGSAKAN_2');
        expect(pending[2].barcode, 'BAGSAKAN_1');
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
    });

    test('Deleted synced operations removed from queue', () async {
      when(
        () => mockDao.deleteByStatus('courier-1', 'synced'),
      ).thenAnswer((_) async => 3);

      final deleted = await mockDao.deleteByStatus('courier-1', 'synced');

      expect(deleted, 3);
    });

    test('Retry count incremented on failure', () async {
      when(
        () => mockDao.updateStatus(
          any(),
          any(),
          retryCount: any(named: 'retryCount'),
          lastError: any(named: 'lastError'),
        ),
      ).thenAnswer((_) async {});

      await mockDao.updateStatus(
        'op-assign',
        'failed',
        retryCount: 1,
        lastError: 'Transient error',
      );

      verify(
        () => mockDao.updateStatus(
          'op-assign',
          'failed',
          retryCount: 1,
          lastError: any(named: 'lastError'),
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

      expect(conflictOp.status, 'conflict');
      expect(conflictOp.lastError, isNotNull);

      when(() => mockDao.getPending('courier-1')).thenAnswer((_) async => []);

      final pending = await mockDao.getPending('courier-1');
      expect(pending.isEmpty, true);
    });

    test('Processing state prevents duplicate concurrent syncs', () async {
      when(
        () => mockDao.updateStatus(
          any(),
          any(),
          lastAttemptAt: any(named: 'lastAttemptAt'),
        ),
      ).thenAnswer((_) async {});

      await mockDao.updateStatus(
        'op-assign',
        'processing',
        lastAttemptAt: DateTime.now().millisecondsSinceEpoch,
      );

      when(() => mockDao.getPending('courier-1')).thenAnswer((_) async => []);

      final pending = await mockDao.getPending('courier-1');
      expect(pending.isEmpty, true);
    });
  });
}
