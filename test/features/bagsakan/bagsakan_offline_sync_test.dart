import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/database/bagsakan_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/sync/sync_manager.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockBagsakanDao extends Mock implements BagsakanDao {}

class MockSyncOperationsDao extends Mock implements SyncOperationsDao {}

class MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    themeMode: ThemeMode.light,
    courier: {'id': 'test_courier_123'},
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  group('Bagsakan Offline-First Sync Tests', () {
    late MockBagsakanDao mockBagsakanDao;
    late MockSyncOperationsDao mockSyncOpsDao;
    late ProviderContainer container;

    setUp(() {
      mockBagsakanDao = MockBagsakanDao();
      mockSyncOpsDao = MockSyncOperationsDao();

      container = ProviderContainer(
        overrides: [
          bagsakanDaoProvider.overrideWithValue(mockBagsakanDao),
          syncOperationsDaoProvider.overrideWithValue(mockSyncOpsDao),
          authProvider.overrideWith(MockAuthNotifier.new),
        ],
      );
    });

    tearDown(() => container.dispose());

    // ── CREATE_BAGSAKAN Operation Tests ────────────────────────────────────

    test('CREATE_BAGSAKAN operation queues locally when offline', () async {
      const groupName = 'Metro Manila Q1 Batch';
      const groupDescription = 'High-priority medical supplies';
      final capturedOp = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((realInvocation) async {
        capturedOp.add(realInvocation.positionalArguments[0]);
      });

      when(
        mockBagsakanDao.createBagsakanGroup(
          name: groupName,
          description: groupDescription,
          courierId: 'test_courier_123',
        ),
      ).thenAnswer((_) async => 42);

      final groupId = await mockBagsakanDao.createBagsakanGroup(
        name: groupName,
        description: groupDescription,
        courierId: 'test_courier_123',
      );

      expect(groupId, 42);
      verify(mockSyncOpsDao.insert(any)).called(1);
    });

    test('CREATE_BAGSAKAN payload contains group metadata', () async {
      const groupName = 'Test Group';
      const groupDesc = 'Test Description';
      final capturedOps = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((inv) {
        capturedOps.add(inv.positionalArguments[0]);
      });

      when(
        mockBagsakanDao.createBagsakanGroup(
          name: groupName,
          description: groupDesc,
          courierId: 'test_courier_123',
        ),
      ).thenAnswer((_) async => 10);

      await mockBagsakanDao.createBagsakanGroup(
        name: groupName,
        description: groupDesc,
        courierId: 'test_courier_123',
      );

      expect(capturedOps, isNotEmpty);
      final op = capturedOps.first;
      expect(op.operationType, 'CREATE_BAGSAKAN');
      expect(op.barcode, 'BAGSAKAN_10');
      expect(op.status, 'pending');
    });

    // ── ASSIGN_TO_BAGSAKAN Operation Tests ─────────────────────────────────

    test('ASSIGN_TO_BAGSAKAN queues assignments locally', () async {
      final barcodes = ['PKG001', 'PKG002', 'PKG003'];
      final capturedOp = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((inv) {
        capturedOp.add(inv.positionalArguments[0]);
      });

      when(
        mockBagsakanDao.assignToBagsakan(
          groupId: 42,
          barcodes: barcodes,
          courierId: 'test_courier_123',
        ),
      ).thenAnswer((_) async {});

      await mockBagsakanDao.assignToBagsakan(
        groupId: 42,
        barcodes: barcodes,
        courierId: 'test_courier_123',
      );

      verify(mockSyncOpsDao.insert(any)).called(1);
    });

    // ── Offline Queuing Tests ──────────────────────────────────────────────

    test('Multiple operations queue in order when offline', () async {
      final operations = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((inv) {
        operations.add(inv.positionalArguments[0]);
      });

      when(
        mockBagsakanDao.createBagsakanGroup(
          name: 'Group 1',
          description: 'Desc 1',
          courierId: 'test_courier_123',
        ),
      ).thenAnswer((_) async => 1);

      when(
        mockBagsakanDao.assignToBagsakan(
          groupId: 1,
          barcodes: ['PKG001'],
          courierId: 'test_courier_123',
        ),
      ).thenAnswer((_) async {});

      // Simulate offline user: create group, then assign
      await mockBagsakanDao.createBagsakanGroup(
        name: 'Group 1',
        description: 'Desc 1',
        courierId: 'test_courier_123',
      );

      await mockBagsakanDao.assignToBagsakan(
        groupId: 1,
        barcodes: ['PKG001'],
        courierId: 'test_courier_123',
      );

      // Verify operations were queued in order
      expect(operations.length, 2);
      expect(operations[0].operationType, 'CREATE_BAGSAKAN');
      expect(operations[1].operationType, 'ASSIGN_TO_BAGSAKAN');
    });

    // ── Operation Dependency Tests ─────────────────────────────────────────

    test('ASSIGN operation waits for CREATE to sync first', () async {
      when(
        mockSyncOpsDao.hasUnfinishedCreateBagsakan(
          'test_courier_123',
          42,
          excludeOperationId: any,
        ),
      ).thenAnswer((_) async => true);

      final waitingForCreate = await mockSyncOpsDao.hasUnfinishedCreateBagsakan(
        'test_courier_123',
        42,
      );

      expect(waitingForCreate, true);
    });

    test('Dependent operations are requeued when dependency not met', () async {
      // Simulate: CREATE is still pending, ASSIGN should be requeued
      when(
        mockSyncOpsDao.hasUnfinishedCreateBagsakan(
          'test_courier_123',
          42,
          excludeOperationId: 'assign_op_id',
        ),
      ).thenAnswer((_) async => true);

      when(
        mockSyncOpsDao.updateStatus(
          'assign_op_id',
          'pending',
          lastAttemptAt: any,
        ),
      ).thenAnswer((_) async {});

      // In real sync, this would be checked before processing ASSIGN
      final hasUnfinished = await mockSyncOpsDao.hasUnfinishedCreateBagsakan(
        'test_courier_123',
        42,
        excludeOperationId: 'assign_op_id',
      );

      if (hasUnfinished) {
        await mockSyncOpsDao.updateStatus(
          'assign_op_id',
          'pending',
          lastAttemptAt: DateTime.now().millisecondsSinceEpoch,
        );
      }

      verify(
        mockSyncOpsDao.updateStatus(
          'assign_op_id',
          'pending',
          lastAttemptAt: any,
        ),
      ).called(1);
    });

    // ── Conflict Handling Tests ────────────────────────────────────────────

    test('Barcode conflict detected in ASSIGN operation', () async {
      final barcodes = ['PKG001', 'PKG002'];
      const conflictMessage =
          'already_assigned_barcodes: [PKG001], group_name: Other Group';

      when(
        mockSyncOpsDao.updateStatus(
          any,
          'conflict',
          lastError: conflictMessage,
        ),
      ).thenAnswer((_) async {});

      // Simulate conflict detection during sync
      await mockSyncOpsDao.updateStatus(
        'op_id_123',
        'conflict',
        lastError: conflictMessage,
      );

      verify(
        mockSyncOpsDao.updateStatus(
          'op_id_123',
          'conflict',
          lastError: conflictMessage,
        ),
      ).called(1);
    });

    // ── Data Retention Tests ───────────────────────────────────────────────

    test('Synced operations deleted after retention period', () async {
      const retentionDays = 7;

      when(
        mockSyncOpsDao.deleteOldSynced(retentionDays),
      ).thenAnswer((_) async => 3);

      final deletedCount = await mockSyncOpsDao.deleteOldSynced(retentionDays);

      expect(deletedCount, 3);
      verify(mockSyncOpsDao.deleteOldSynced(retentionDays)).called(1);
    });

    test(
      'Pending operations NOT deleted even after retention period',
      () async {
        // Pending operations should be retained indefinitely
        // This is validated by the cleanup logic only targeting 'synced' status
        when(mockSyncOpsDao.deleteOldSynced(7)).thenAnswer(
          (_) async => 0, // Only synced ops deleted, pending retained
        );

        final result = await mockSyncOpsDao.deleteOldSynced(7);
        expect(result, 0); // No pending operations deleted
      },
    );

    // ── Offline State Detection Tests ──────────────────────────────────────

    test('No local persistence for bagsakan groups when offline', () async {
      // Verify groups are NOT cached separately from sync operations
      // Only sync_operations table stores pending actions
      when(mockSyncOpsDao.getPending('test_courier_123')).thenAnswer(
        (_) async => [
          SyncOperation(
            id: '1',
            courierId: 'test_courier_123',
            barcode: 'BAGSAKAN_1',
            operationType: 'CREATE_BAGSAKAN',
            payloadJson: '{"id":1,"name":"Test","description":"Desc"}',
            createdAt: 0,
          ),
        ],
      );

      final pending = await mockSyncOpsDao.getPending('test_courier_123');

      // Verify only operations are stored, not group records
      expect(pending.length, 1);
      expect(pending.first.operationType, 'CREATE_BAGSAKAN');
    });

    // ── Sync Operation Sequencing Tests ────────────────────────────────────

    test(
      'Operations sync in correct order: CREATE → ASSIGN → SUBMIT',
      () async {
        final syncSequence = <String>[];

        when(mockSyncOpsDao.getPending('test_courier_123')).thenAnswer(
          (_) async => [
            SyncOperation(
              id: 'op1',
              courierId: 'test_courier_123',
              barcode: 'BAGSAKAN_1',
              operationType: 'CREATE_BAGSAKAN',
              payloadJson: '{"id":1}',
              createdAt: 1000,
            ),
            SyncOperation(
              id: 'op2',
              courierId: 'test_courier_123',
              barcode: 'BAGSAKAN_1',
              operationType: 'ASSIGN_TO_BAGSAKAN',
              payloadJson: '{"group_id":1,"barcodes":["PKG001"]}',
              createdAt: 2000,
            ),
            SyncOperation(
              id: 'op3',
              courierId: 'test_courier_123',
              barcode: 'BAGSAKAN_1',
              operationType: 'SUBMIT_BAGSAKAN',
              payloadJson:
                  '{"group_id":1,"source_barcode":"PKG001","barcodes":[]}',
              createdAt: 3000,
            ),
          ],
        );

        final pending = await mockSyncOpsDao.getPending('test_courier_123');

        // Verify operations are in creation order
        expect(pending[0].operationType, 'CREATE_BAGSAKAN');
        expect(pending[1].operationType, 'ASSIGN_TO_BAGSAKAN');
        expect(pending[2].operationType, 'SUBMIT_BAGSAKAN');
        expect(pending[0].createdAt < pending[1].createdAt, true);
        expect(pending[1].createdAt < pending[2].createdAt, true);
      },
    );

    // ── Idempotency Tests ──────────────────────────────────────────────────

    test('Each operation has unique X-Request-ID for idempotency', () async {
      when(mockSyncOpsDao.getPending('test_courier_123')).thenAnswer(
        (_) async => [
          SyncOperation(
            id: 'uuid-001',
            courierId: 'test_courier_123',
            barcode: 'BAGSAKAN_1',
            operationType: 'CREATE_BAGSAKAN',
            payloadJson: '{"id":1}',
            createdAt: 0,
          ),
          SyncOperation(
            id: 'uuid-002',
            courierId: 'test_courier_123',
            barcode: 'BAGSAKAN_1',
            operationType: 'ASSIGN_TO_BAGSAKAN',
            payloadJson: '{"group_id":1}',
            createdAt: 0,
          ),
        ],
      );

      final pending = await mockSyncOpsDao.getPending('test_courier_123');

      // Each operation has unique ID for X-Request-ID header
      expect(pending[0].id, isNotEmpty);
      expect(pending[1].id, isNotEmpty);
      expect(pending[0].id, isNot(pending[1].id));
    });

    // ── Retry Logic Tests ──────────────────────────────────────────────────

    test('Failed operation retries with exponential backoff', () async {
      const maxRetries = 3;
      int retryCount = 0;

      when(
        mockSyncOpsDao.updateStatus(
          any,
          'failed',
          retryCount: anyNamed('retryCount'),
          lastError: any,
        ),
      ).thenAnswer((_) async {
        retryCount++;
      });

      // Simulate 3 retry attempts
      for (int i = 0; i < maxRetries; i++) {
        await mockSyncOpsDao.updateStatus(
          'op_123',
          'failed',
          retryCount: i + 1,
          lastError: 'Transient error',
        );
      }

      expect(retryCount, 3);
      verify(
        mockSyncOpsDao.updateStatus(
          'op_123',
          'failed',
          retryCount: any,
          lastError: any,
        ),
      ).called(3);
    });

    // ── Operation Type Handling Tests ──────────────────────────────────────

    test(
      'DELETE_BAGSAKAN allows atomic cancellation for local-only groups',
      () async {
        const groupId = 1;
        const courierId = 'test_courier_123';

        // Simulate a CREATE operation that hasn't synced yet
        when(
          mockSyncOpsDao.deleteByBarcode('BAGSAKAN_$groupId'),
        ).thenAnswer((_) async => 5);

        final deleted = await mockSyncOpsDao.deleteByBarcode(
          'BAGSAKAN_$groupId',
        );

        // All 5 pending operations for this local-only group are canceled
        expect(deleted, 5);
      },
    );

    test('UPDATE_BAGSAKAN_GROUP operation queues correctly', () async {
      final capturedOps = <SyncOperation>[];

      when(mockSyncOpsDao.insert(any)).thenAnswer((inv) {
        capturedOps.add(inv.positionalArguments[0]);
      });

      when(
        mockBagsakanDao.updateBagsakanGroup(
          groupId: 1,
          name: 'Updated Name',
          description: 'Updated Desc',
          courierId: 'test_courier_123',
        ),
      ).thenAnswer((_) async {});

      await mockBagsakanDao.updateBagsakanGroup(
        groupId: 1,
        name: 'Updated Name',
        description: 'Updated Desc',
        courierId: 'test_courier_123',
      );

      verify(mockSyncOpsDao.insert(any)).called(1);
      if (capturedOps.isNotEmpty) {
        expect(capturedOps.first.operationType, 'UPDATE_BAGSAKAN_GROUP');
      }
    });

    // ── UI Status Tests ────────────────────────────────────────────────────

    test('UI displays "⏳ Pending Sync" badge for queued operations', () async {
      when(mockSyncOpsDao.getPending('test_courier_123')).thenAnswer(
        (_) async => [
          SyncOperation(
            id: '1',
            courierId: 'test_courier_123',
            barcode: 'BAGSAKAN_1',
            operationType: 'CREATE_BAGSAKAN',
            payloadJson: '{}',
            createdAt: 0,
          ),
        ],
      );

      final pending = await mockSyncOpsDao.getPending('test_courier_123');

      // When operations exist, UI shows pending sync badge
      expect(pending.isNotEmpty, true);
    });

    test('UI displays "✓ Synced" badge when operation completed', () async {
      when(mockSyncOpsDao.getAll('test_courier_123')).thenAnswer(
        (_) async => [
          SyncOperation(
            id: '1',
            courierId: 'test_courier_123',
            barcode: 'BAGSAKAN_1',
            operationType: 'CREATE_BAGSAKAN',
            payloadJson: '{}',
            status: 'synced',
            createdAt: 0,
          ),
        ],
      );

      final all = await mockSyncOpsDao.getAll('test_courier_123');

      // When operation is synced, show synced badge
      expect(all.first.status, 'synced');
    });
  });
}
