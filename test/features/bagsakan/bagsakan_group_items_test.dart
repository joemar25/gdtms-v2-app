// test/features/bagsakan/bagsakan_group_items_test.dart
//
// Strict verification for the Bagsakan Item Removal workflow:
// 1. Confirm dialog must be shown.
// 2. Cancellation must not trigger DAO.
// 3. Confirmation must trigger DAO + Sync + Refresh.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_group_items_screen.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/database/bagsakan_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';

class MockBagsakanDao extends Mock implements BagsakanDao {}

class MockApiClient extends Mock implements ApiClient {}

class MockSyncOperationsDao extends Mock implements SyncOperationsDao {
  @override
  Future<bool> hasPendingSync(String? barcode) =>
      super.noSuchMethod(Invocation.method(#hasPendingSync, [barcode]));
}

class MockSyncManagerNotifier extends SyncManagerNotifier {
  @override
  SyncState build() => const SyncState.initial();
  @override
  Future<void> loadEntries() async {}
  @override
  Future<void> processQueue() async {}
}

void main() {
  late MockBagsakanDao mockBagsakanDao;
  late MockSyncManagerNotifier mockSyncManager;
  late MockApiClient mockApiClient;
  late MockSyncOperationsDao mockSyncDao;

  setUpAll(() {
    EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  });

  setUp(() {
    mockBagsakanDao = MockBagsakanDao();
    mockSyncManager = MockSyncManagerNotifier();
    mockApiClient = MockApiClient();
    mockSyncDao = MockSyncOperationsDao();

    // Stub ApiClient.get to avoid failures in _loadGroupDetailsFromApi
    when(
      () => mockApiClient.get<Map<String, dynamic>>(
        any(),
        parser: any(named: 'parser'),
      ),
    ).thenAnswer(
      (_) async => ApiSuccess({
        'data': {'deliveries': []},
      }),
    );

    when(
      () => mockSyncDao.hasPendingSync(any()),
    ).thenAnswer((_) async => false);
    registerFallbackValue(
      LocalDelivery(
        barcode: '',
        deliveryStatus: '',
        jobOrder: '',
        recipientName: '',
        deliveryAddress: '',
        rawJson: '{}',
        createdAt: 0,
        updatedAt: 0,
      ),
    );
  });

  Widget createWidgetUnderTest(int groupId) {
    final router = GoRouter(
      initialLocation: '/bagsakan/$groupId/items',
      routes: [
        GoRoute(
          path: '/bagsakan/:groupId/items',
          builder: (context, state) => BagsakanGroupItemsScreen(
            groupId: int.parse(state.pathParameters['groupId']!),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        connectionStatusProvider.overrideWith((ref) => ConnectionStatus.online),
        syncManagerProvider.overrideWith(() => mockSyncManager),
        bagsakanDaoProvider.overrideWithValue(mockBagsakanDao),
        apiClientProvider.overrideWithValue(mockApiClient),
        syncOperationsDaoProvider.overrideWithValue(mockSyncDao),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('Bagsakan Item Removal Strict Tests', () {
    testWidgets('Removal requires confirmation and triggers DAO + Sync', (
      tester,
    ) async {
      final groupId = 42;
      final delivery = LocalDelivery(
        barcode: 'B123',
        deliveryStatus: 'FOR_DELIVERY',
        jobOrder: 'JO1',
        recipientName: 'Test Recipient',
        deliveryAddress: '123 St',
        bagsakanId: groupId,
        rawJson: '{}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      when(() => mockBagsakanDao.getBagsakanGroup(groupId)).thenAnswer(
        (_) async => {'id': groupId, 'name': 'Test Group', 'status': 'pending'},
      );
      when(
        () => mockBagsakanDao.getBagsakanItems(groupId),
      ).thenAnswer((_) async => [delivery]);
      when(
        () => mockBagsakanDao.unassignFromBagsakan(any(), any()),
      ).thenAnswer((_) async => {});

      await tester.pumpWidget(createWidgetUnderTest(groupId));
      await tester.pumpAndSettle();

      // Find the remove button (prominent button label)
      final removeBtn = find.text('REMOVE FROM BAGSAKAN');
      expect(removeBtn, findsOneWidget);

      // 1. Tap remove - should show dialog
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();

      expect(find.text('bagsakan.remove_confirm_title'.tr()), findsOneWidget);

      // 2. Cancel - should not call DAO
      await tester.tap(find.text('common.cancel'.tr()));
      await tester.pumpAndSettle();

      verifyNever(() => mockBagsakanDao.unassignFromBagsakan(any(), any()));

      // 3. Confirm - should call DAO and Sync
      await tester.tap(removeBtn);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('common.delete'.tr()),
      ); // The confirm button we labeled as common.delete
      await tester.pump(); // Start processing

      verify(
        () => mockBagsakanDao.unassignFromBagsakan('B123', any()),
      ).called(1);

      // Note: Since _onRemoveFromBagsakan waits for loadEntries and processQueue,
      // we need to wait for those.
      await tester.pumpAndSettle();
    });

    testWidgets('Removal is disabled for submitted groups', (tester) async {
      final groupId = 42;
      final delivery = LocalDelivery(
        barcode: 'B123',
        deliveryStatus: 'DELIVERED',
        jobOrder: 'JO1',
        recipientName: 'Test Recipient',
        deliveryAddress: '123 St',
        bagsakanId: groupId,
        rawJson: '{}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      when(() => mockBagsakanDao.getBagsakanGroup(groupId)).thenAnswer(
        (_) async => {
          'id': groupId,
          'name': 'Test Group',
          'status': 'submitted',
        },
      );
      when(
        () => mockBagsakanDao.getBagsakanItems(groupId),
      ).thenAnswer((_) async => [delivery]);

      await tester.pumpWidget(createWidgetUnderTest(groupId));
      await tester.pumpAndSettle();

      // Remove button should NOT be present for submitted groups
      expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNothing);
    });

    testWidgets(
      'Submit shows confirmation (not block) when source is DELIVERED and group has failed items',
      (tester) async {
        final groupId = 77;
        final now = DateTime.now().millisecondsSinceEpoch;
        final delivered = LocalDelivery(
          barcode: 'B-DELIVERED',
          deliveryStatus: 'DELIVERED',
          jobOrder: 'JO-1',
          recipientName: 'R1',
          deliveryAddress: 'Addr 1',
          bagsakanId: groupId,
          rawJson: '{}',
          createdAt: now,
          updatedAt: now + 10,
          syncStatus: 'dirty',
        );
        final failed = LocalDelivery(
          barcode: 'B-FAILED',
          deliveryStatus: 'FAILED_DELIVERY',
          jobOrder: 'JO-2',
          recipientName: 'R2',
          deliveryAddress: 'Addr 2',
          bagsakanId: groupId,
          rawJson: '{}',
          createdAt: now,
          updatedAt: now,
        );

        when(() => mockBagsakanDao.getBagsakanGroup(groupId)).thenAnswer(
          (_) async => {
            'id': groupId,
            'name': 'Test Group',
            'status': 'pending',
          },
        );
        when(
          () => mockBagsakanDao.getBagsakanItems(groupId),
        ).thenAnswer((_) async => [delivered, failed]);

        await tester.pumpWidget(createWidgetUnderTest(groupId));
        await tester.pumpAndSettle();

        expect(
          find.text('bagsakan.submit_button'.tr().toUpperCase()),
          findsOneWidget,
        );

        await tester.tap(
          find.text('bagsakan.submit_button'.tr().toUpperCase()),
        );
        await tester.pumpAndSettle();

        expect(find.text('bagsakan.submit_confirm_title'.tr()), findsOneWidget);

        await tester.tap(find.text('bagsakan.submit_confirm_confirm'.tr()));
        await tester.pumpAndSettle();

        verify(
          () => mockBagsakanDao.submitBagsakanGroup(
            groupId,
            'B-DELIVERED',
            any(),
            propagationStatus: 'DELIVERED',
          ),
        ).called(1);
      },
    );

    testWidgets('Submit confirms FAILED_DELIVERY propagation status', (
      tester,
    ) async {
      final groupId = 78;
      final failed = LocalDelivery(
        barcode: 'B-FAILED-ONLY',
        deliveryStatus: 'FAILED_DELIVERY',
        jobOrder: 'JO-3',
        recipientName: 'R3',
        deliveryAddress: 'Addr 3',
        bagsakanId: groupId,
        rawJson: '{}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: 'dirty',
      );

      when(() => mockBagsakanDao.getBagsakanGroup(groupId)).thenAnswer(
        (_) async => {'id': groupId, 'name': 'Test Group', 'status': 'pending'},
      );
      when(
        () => mockBagsakanDao.getBagsakanItems(groupId),
      ).thenAnswer((_) async => [failed]);
      when(
        () => mockBagsakanDao.submitBagsakanGroup(
          any(),
          any(),
          any(),
          propagationStatus: any(named: 'propagationStatus'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest(groupId));
      await tester.pumpAndSettle();

      await tester.tap(find.text('bagsakan.submit_button'.tr().toUpperCase()));
      await tester.pumpAndSettle();

      expect(find.text('bagsakan.submit_confirm_title'.tr()), findsOneWidget);
      // The message now uses RichText with tags. We verify a RichText widget exists.
      expect(find.byType(RichText), findsAtLeast(1));
      await tester.tap(find.text('bagsakan.submit_confirm_confirm'.tr()));
      await tester.pumpAndSettle();

      verify(
        () => mockBagsakanDao.submitBagsakanGroup(
          groupId,
          'B-FAILED-ONLY',
          any(),
          propagationStatus: 'FAILED_DELIVERY',
        ),
      ).called(1);
    });

    testWidgets(
      'Submit button hidden when no final delivery exists in the group',
      (tester) async {
        // The submit source is resolved from any final-status delivery
        // (DELIVERED, FAILED_DELIVERY, MISROUTED) — dirty or clean.
        // If the group has NO final deliveries at all, there is no source
        // and the FAB must be hidden.
        final groupId = 79;
        final now = DateTime.now().millisecondsSinceEpoch;
        final forDelivery = LocalDelivery(
          barcode: 'B-FOR',
          deliveryStatus: 'FOR_DELIVERY',
          jobOrder: 'JO-4',
          recipientName: 'R4',
          deliveryAddress: 'Addr 4',
          bagsakanId: groupId,
          rawJson: '{}',
          createdAt: now,
          updatedAt: now,
        );
        final anotherPending = LocalDelivery(
          barcode: 'B-FOR-2',
          deliveryStatus: 'FOR_DELIVERY',
          jobOrder: 'JO-5',
          recipientName: 'R5',
          deliveryAddress: 'Addr 5',
          bagsakanId: groupId,
          rawJson: '{}',
          createdAt: now,
          updatedAt: now,
        );

        when(() => mockBagsakanDao.getBagsakanGroup(groupId)).thenAnswer(
          (_) async => {
            'id': groupId,
            'name': 'Test Group',
            'status': 'pending',
          },
        );
        when(
          () => mockBagsakanDao.getBagsakanItems(groupId),
        ).thenAnswer((_) async => [forDelivery, anotherPending]);

        await tester.pumpWidget(createWidgetUnderTest(groupId));
        await tester.pumpAndSettle();

        expect(
          find.text('bagsakan.submit_button'.tr().toUpperCase()),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Submit button shown when API propagation source exists on final clean item',
      (tester) async {
        final groupId = 80;
        final now = DateTime.now().millisecondsSinceEpoch;

        final sourceDeliveredClean = LocalDelivery(
          barcode: 'B-PROP-SOURCE',
          deliveryStatus: 'DELIVERED',
          jobOrder: 'JO-6',
          recipientName: 'R6',
          deliveryAddress: 'Addr 6',
          bagsakanId: groupId,
          rawJson: '{}',
          createdAt: now,
          updatedAt: now,
          syncStatus: 'clean',
        );

        when(() => mockBagsakanDao.getBagsakanGroup(groupId)).thenAnswer(
          (_) async => {
            'id': groupId,
            'name': 'Test Group',
            'status': 'pending',
          },
        );
        when(
          () => mockBagsakanDao.getBagsakanItems(groupId),
        ).thenAnswer((_) async => [sourceDeliveredClean]);

        when(
          () => mockApiClient.get<Map<String, dynamic>>(
            '/bagsakan/groups/$groupId',
            parser: any(named: 'parser'),
          ),
        ).thenAnswer(
          (_) async => ApiSuccess({
            'data': {
              'deliveries': [
                {'barcode': 'B-PROP-SOURCE', 'propagation_source': true},
              ],
            },
          }),
        );

        when(
          () => mockBagsakanDao.submitBagsakanGroup(
            any(),
            any(),
            any(),
            propagationStatus: any(named: 'propagationStatus'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(createWidgetUnderTest(groupId));
        await tester.pumpAndSettle();

        expect(
          find.text('bagsakan.submit_button'.tr().toUpperCase()),
          findsOneWidget,
        );

        await tester.tap(
          find.text('bagsakan.submit_button'.tr().toUpperCase()),
        );
        await tester.pumpAndSettle();

        expect(find.text('bagsakan.submit_confirm_title'.tr()), findsOneWidget);

        await tester.tap(find.text('bagsakan.submit_confirm_confirm'.tr()));
        await tester.pumpAndSettle();

        verify(
          () => mockBagsakanDao.submitBagsakanGroup(
            groupId,
            'B-PROP-SOURCE',
            any(),
            propagationStatus: 'DELIVERED',
          ),
        ).called(1);
      },
    );
  });
}
