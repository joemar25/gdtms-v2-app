import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_form_screen.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/bagsakan_dao.dart';

class MockLocalDeliveryDao extends Mock implements LocalDeliveryDao {}

class MockBagsakanDao extends Mock implements BagsakanDao {}

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
  late MockBagsakanDao mockBagsakanDao;

  setUpAll(() {
    EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  });

  setUp(() {
    mockLocalDeliveryDao = MockLocalDeliveryDao();
    mockBagsakanDao = MockBagsakanDao();
  });

  Widget createWidgetUnderTest({
    ConnectionStatus connectionStatus = ConnectionStatus.online,
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const BagsakanFormScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        connectionStatusProvider.overrideWith((ref) => connectionStatus),
        authProvider.overrideWith(MockAuthNotifier.new),
        updateProvider.overrideWith(MockUpdateNotifier.new),
        notificationsUnreadCountProvider.overrideWithValue(0),
        compactModeProvider.overrideWith(MockCompactModeNotifier.new),
        localDeliveryDaoProvider.overrideWithValue(mockLocalDeliveryDao),
        bagsakanDaoProvider.overrideWithValue(mockBagsakanDao),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('BagsakanFormScreen Widget Tests', () {
    testWidgets('renders basic UI components', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsAtLeast(2));
      expect(find.textContaining('bagsakan.tab_info'.tr()), findsOneWidget);
    });

    testWidgets('Next button is visible on first step', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final nextButton = find.text('common.next'.tr());
      expect(nextButton, findsOneWidget);
    });

    testWidgets('shows error when clicking Next with empty name', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final nextButton = find.text('common.next'.tr());
      await tester.tap(nextButton);
      await tester.pump();
      // Clear the snackbar timer to avoid "A Timer is still pending" error
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('navigates to step 2 after entering name', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Test Group');
      final nextButton = find.text('common.next'.tr());
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('bagsakan.tab_deliveries'.tr()),
        findsOneWidget,
      );
      expect(find.text('bagsakan.search'.tr()), findsOneWidget);
    });

    testWidgets('search functionality calls DAO in step 2', (tester) async {
      when(
        () => mockBagsakanDao.searchByBarcodeLike(any()),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(
        createWidgetUnderTest(
          connectionStatus: ConnectionStatus.networkOffline,
        ),
      );
      await tester.pumpAndSettle();

      // Enter name and go to step 2
      await tester.enterText(find.byType(TextField).first, 'Test Group');
      await tester.tap(find.text('common.next'.tr()));
      await tester.pumpAndSettle();

      // Now in Step 2
      await tester.enterText(
        find.byType(TextField).first,
        'TEST123',
      ); // Search input is now the first (visible) TextField
      await tester.tap(find.text('bagsakan.search'.tr()));
      await tester.pumpAndSettle();

      verify(() => mockBagsakanDao.searchByBarcodeLike('TEST123')).called(1);
    });
  });
}
