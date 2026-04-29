import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';

// ── Mock classes ─────────────────────────────────────────────────────────────
class MockSyncOperationsDao extends Mock implements SyncOperationsDao {}

class MockLocalDeliveryDao extends Mock implements LocalDeliveryDao {}

class MockApiClient extends Mock implements ApiClient {}

// We mock the AuthNotifier by providing a fixed state.
class MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  @override
  AuthState build() => const AuthState(
    courier: {'id': 'courier_123', 'name': 'Test Courier'},
    isAuthenticated: true,
    themeMode: ThemeMode.light,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;
  late MockSyncOperationsDao mockSyncDao;
  late MockLocalDeliveryDao mockLocalDao;
  late MockApiClient mockApiClient;

  setUp(() {
    mockSyncDao = MockSyncOperationsDao();
    mockLocalDao = MockLocalDeliveryDao();
    mockApiClient = MockApiClient();

    // Register fallback values for mocktail when using any() with custom types
    registerFallbackValue(
      const SyncOperation(
        id: '',
        barcode: '',
        operationType: '',
        payloadJson: '',
        createdAt: 0,
        status: '',
        retryCount: 0,
      ),
    );

    container = ProviderContainer(
      overrides: [
        syncOperationsDaoProvider.overrideWithValue(mockSyncDao),
        localDeliveryDaoProvider.overrideWithValue(mockLocalDao),
        apiClientProvider.overrideWithValue(mockApiClient),
        authProvider.overrideWith(MockAuthNotifier.new),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SyncManagerNotifier', () {
    test(
      'Given a courier ID, when loadEntries is called, then it updates state with DAO results',
      () async {
        // Arrange (Given)
        final mockEntries = [
          const SyncOperation(
            id: 'op_1',
            barcode: 'BAR123',
            operationType: 'UPDATE_STATUS',
            payloadJson: '{}',
            createdAt: 1000,
            status: 'pending',
            retryCount: 0,
          ),
        ];

        when(
          () => mockSyncDao.getAll('courier_123'),
        ).thenAnswer((_) async => mockEntries);

        // Act (When)
        await container.read(syncManagerProvider.notifier).loadEntries();

        // Assert (Then)
        final state = container.read(syncManagerProvider);
        expect(state.entries, mockEntries);
        expect(state.entries.first.barcode, 'BAR123');

        verify(() => mockSyncDao.getAll('courier_123')).called(1);
      },
    );

    test(
      'Given an empty queue, when processQueue is called, then it reloads entries and stays idle',
      () async {
        // Arrange (Given)
        when(
          () => mockSyncDao.getPending('courier_123'),
        ).thenAnswer((_) async => []);
        when(
          () => mockSyncDao.getAll('courier_123'),
        ).thenAnswer((_) async => []);

        // Act (When)
        await container.read(syncManagerProvider.notifier).processQueue();

        // Assert (Then)
        final state = container.read(syncManagerProvider);
        expect(state.isSyncing, false);
        expect(state.total, 0);

        verify(() => mockSyncDao.getPending('courier_123')).called(1);
      },
    );
  });
}
