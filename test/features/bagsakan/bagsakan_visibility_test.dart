import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/features/delivery/delivery_status_list_screen.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';
import 'package:go_router/go_router.dart';

class MockLocalDeliveryDao extends Mock implements LocalDeliveryDao {}

class MockSyncOperationsDao extends Mock implements SyncOperationsDao {}

class MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isAuthenticated: true, themeMode: ThemeMode.light);
}

class MockUpdateNotifier extends UpdateNotifier {
  @override
  UpdateState build() => const UpdateState();
}

class MockCompactModeNotifier extends CompactModeNotifier {
  @override
  bool build() => false;
}

void main() {
  late MockLocalDeliveryDao mockLocalDao;
  late MockSyncOperationsDao mockSyncDao;

  setUpAll(() {
    EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  });

  setUp(() {
    mockLocalDao = MockLocalDeliveryDao();
    mockSyncDao = MockSyncOperationsDao();
  });

  Widget createTestWidget({String status = 'FOR_DELIVERY'}) {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/deliveries?status=$status',
      routes: [
        GoRoute(
          path: '/deliveries',
          builder: (context, state) {
            final s = state.uri.queryParameters['status'] ?? status;
            return DeliveryStatusListScreen(status: s, title: 'Deliveries');
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        localDeliveryDaoProvider.overrideWithValue(mockLocalDao),
        syncOperationsDaoProvider.overrideWithValue(mockSyncDao),
        connectionStatusProvider.overrideWith((ref) => ConnectionStatus.online),
        authProvider.overrideWith(MockAuthNotifier.new),
        updateProvider.overrideWith(MockUpdateNotifier.new),
        compactModeProvider.overrideWith(MockCompactModeNotifier.new),
        notificationsUnreadCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        scaffoldMessengerKey: appScaffoldMessengerKey,
      ),
    );
  }

  group('Bagsakan Visibility Edge Cases', () {
    testWidgets(
      'Items re-appear in standard list after being unassigned (Refresh trigger)',
      (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final delivery = LocalDelivery(
          barcode: 'REFRESH123',
          deliveryStatus: 'FOR_DELIVERY',
          recipientName: 'Refresh User',
          rawJson: '{}',
          createdAt: now,
          updatedAt: now,
        );

        when(
          () => mockLocalDao.countByStatus(any()),
        ).thenAnswer((_) async => 0);
        when(
          () => mockLocalDao.getByStatusPaged(
            any(),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockSyncDao.getSyncQueuedBarcodes(any()),
        ).thenAnswer((_) async => {});

        await tester.pumpWidget(createTestWidget());
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.text('Refresh User'), findsNothing);

        when(
          () => mockLocalDao.countByStatus('FOR_DELIVERY'),
        ).thenAnswer((_) async => 1);
        when(
          () => mockLocalDao.getByStatusPaged(
            'FOR_DELIVERY',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [delivery]);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DeliveryStatusListScreen)),
        );
        container.read(deliveryRefreshProvider.notifier).increment();

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(find.text('Refresh User'), findsOneWidget);
      },
    );

    testWidgets('Search correctly respects bagsakan_id filter', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ungrouped = LocalDelivery(
        barcode: 'SEARCH123',
        deliveryStatus: 'FOR_DELIVERY',
        recipientName: 'Searchable User',
        rawJson: '{}',
        createdAt: now,
        updatedAt: now,
      );

      when(() => mockLocalDao.countByStatus(any())).thenAnswer((_) async => 0);
      when(
        () => mockLocalDao.getByStatusPaged(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockSyncDao.getSyncQueuedBarcodes(any()),
      ).thenAnswer((_) async => {});

      when(
        () => mockLocalDao.searchByStatusAndQuery('FOR_DELIVERY', 'SEARCH'),
      ).thenAnswer((_) async => [ungrouped]);

      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'SEARCH');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Searchable User'), findsOneWidget);
    });

    testWidgets(
      'Locked items message is shown on tap if item is in bagsakan group',
      (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final grouped = LocalDelivery(
          barcode: 'LOCKED123',
          deliveryStatus: 'FOR_DELIVERY',
          recipientName: 'Locked User',
          bagsakanId: 999,
          rawJson: '{}',
          createdAt: now,
          updatedAt: now,
        );

        when(
          () => mockLocalDao.countByStatus(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockLocalDao.getByStatusPaged(
            any(),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [grouped]);
        when(
          () => mockSyncDao.getSyncQueuedBarcodes(any()),
        ).thenAnswer((_) async => {});

        await tester.pumpWidget(createTestWidget());

        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pumpAndSettle();

        expect(find.text('LOCKED123'), findsOneWidget);

        await tester.tap(find.text('LOCKED123'));
        // The overlay notification takes time to animate in
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        expect(
          find.textContaining('Bagsakan group', skipOffstage: true),
          findsOneWidget,
        );

        // Clean up: Wait for the 3-second auto-dismiss timer to finish
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
