import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/features/delivery/delivery_status_list_screen.dart';
import 'package:fsi_courier_app/features/dispatch/dispatch_list_screen.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';

// Verification test for Scan Mode consistency across different list screens.

class MockLocalDeliveryDao extends Mock implements LocalDeliveryDao {}

class MockSyncOperationsDao extends Mock implements SyncOperationsDao {}

class MockApiClient extends Mock implements ApiClient {}

class MockDeviceInfoService extends Mock implements DeviceInfoService {}

class MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isAuthenticated: false, themeMode: ThemeMode.light);
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
  late MockLocalDeliveryDao mockLocalDeliveryDao;
  late MockSyncOperationsDao mockSyncOperationsDao;
  late MockApiClient mockApiClient;
  late MockDeviceInfoService mockDeviceInfo;

  setUpAll(() {
    EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
    registerFallbackValue(const Locale('en'));
  });

  setUp(() {
    mockLocalDeliveryDao = MockLocalDeliveryDao();
    mockSyncOperationsDao = MockSyncOperationsDao();
    mockApiClient = MockApiClient();
    mockDeviceInfo = MockDeviceInfoService();

    // Default mocks to prevent initialization errors in screens
    when(
      () => mockLocalDeliveryDao.countVisibleDelivered(),
    ).thenAnswer((_) async => 0);
    when(
      () => mockLocalDeliveryDao.countVisibleFailedDelivery(),
    ).thenAnswer((_) async => 0);
    when(
      () => mockLocalDeliveryDao.countVisibleMisrouted(),
    ).thenAnswer((_) async => 0);
    when(
      () => mockLocalDeliveryDao.countByStatus(any()),
    ).thenAnswer((_) async => 0);
    when(
      () => mockLocalDeliveryDao.getByStatusPaged(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => mockLocalDeliveryDao.getVisibleDeliveredPaged(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => mockLocalDeliveryDao.getVisibleFailedDeliveryPaged(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => mockLocalDeliveryDao.getVisibleMisroutedPaged(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => mockSyncOperationsDao.getSyncQueuedBarcodes(any()),
    ).thenAnswer((_) async => <String>{});

    // Mock API Client for DispatchListScreen
    when(
      () => mockApiClient.get<Map<String, dynamic>>(
        any(),
        queryParameters: any(named: 'queryParameters'),
        parser: any(named: 'parser'),
      ),
    ).thenAnswer((_) async => ApiSuccess<Map<String, dynamic>>({}));

    // Mock Device Info for DispatchListScreen
    when(() => mockDeviceInfo.toMap()).thenAnswer((_) async => {});
  });

  group('Scan Mode Consistency Tests', () {
    testWidgets('FOR_DELIVERY list screen shows scanner icon', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DeliveryStatusListScreen(
              status: 'FOR_DELIVERY',
              title: 'FOR DELIVERY',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith(
              (ref) => ConnectionStatus.online,
            ),
            authProvider.overrideWith(MockAuthNotifier.new),
            updateProvider.overrideWith(MockUpdateNotifier.new),
            notificationsUnreadCountProvider.overrideWithValue(0),
            compactModeProvider.overrideWith(MockCompactModeNotifier.new),
            apiClientProvider.overrideWithValue(mockApiClient),
            deviceInfoProvider.overrideWithValue(mockDeviceInfo),
            localDeliveryDaoProvider.overrideWithValue(mockLocalDeliveryDao),
            syncOperationsDaoProvider.overrideWithValue(mockSyncOperationsDao),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Check for any Icon with the scanner data
      final iconFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon?.codePoint == Icons.qr_code_scanner_rounded.codePoint,
      );

      expect(iconFinder, findsAtLeast(1));
    });

    testWidgets('FAILED_DELIVERY list screen shows scanner icon', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DeliveryStatusListScreen(
              status: 'FAILED_DELIVERY',
              title: 'FAILED DELIVERY',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith(
              (ref) => ConnectionStatus.online,
            ),
            authProvider.overrideWith(MockAuthNotifier.new),
            updateProvider.overrideWith(MockUpdateNotifier.new),
            notificationsUnreadCountProvider.overrideWithValue(0),
            compactModeProvider.overrideWith(MockCompactModeNotifier.new),
            apiClientProvider.overrideWithValue(mockApiClient),
            deviceInfoProvider.overrideWithValue(mockDeviceInfo),
            localDeliveryDaoProvider.overrideWithValue(mockLocalDeliveryDao),
            syncOperationsDaoProvider.overrideWithValue(mockSyncOperationsDao),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final iconFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon?.codePoint == Icons.qr_code_scanner_rounded.codePoint,
      );

      expect(iconFinder, findsAtLeast(1));
    });

    testWidgets('Dispatch list screen shows scanner icon', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DispatchListScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectionStatusProvider.overrideWith(
              (ref) => ConnectionStatus.online,
            ),
            authProvider.overrideWith(MockAuthNotifier.new),
            updateProvider.overrideWith(MockUpdateNotifier.new),
            notificationsUnreadCountProvider.overrideWithValue(0),
            compactModeProvider.overrideWith(MockCompactModeNotifier.new),
            apiClientProvider.overrideWithValue(mockApiClient),
            deviceInfoProvider.overrideWithValue(mockDeviceInfo),
            localDeliveryDaoProvider.overrideWithValue(mockLocalDeliveryDao),
            syncOperationsDaoProvider.overrideWithValue(mockSyncOperationsDao),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final iconFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon?.codePoint == Icons.qr_code_scanner_rounded.codePoint,
      );

      expect(iconFinder, findsAtLeast(1));
    });
  });
}
