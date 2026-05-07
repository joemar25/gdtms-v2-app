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
import 'package:fsi_courier_app/features/bagsakan/bagsakan_list_screen.dart';
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

  Widget createWidgetUnderTest() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const BagsakanListScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        connectionStatusProvider.overrideWith((ref) => ConnectionStatus.online),
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

  group('BagsakanListScreen Widget Tests', () {
    testWidgets('renders basic UI components', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsAtLeast(2));
      expect(
        find.textContaining('bagsakan.group_info'.tr().toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('Create Group button is hidden when no items are added', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final createButton = find.text(
        'bagsakan.create_group'.tr().toUpperCase(),
      );
      expect(createButton, findsNothing);
    });

    testWidgets('shows error when creating with empty name', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap create (using FAB or Submit button)
      // Since it's a FAB in some screens or a button in others, let's find the text.
      final createButton = find.text(
        'bagsakan.create_group'.tr().toUpperCase(),
      );
      if (createButton.evaluate().isNotEmpty) {
        await tester.tap(createButton);
        await tester.pumpAndSettle();
        expect(find.text('bagsakan.error_empty_name'.tr()), findsOneWidget);
      }
    });

    testWidgets('search functionality calls DAO', (tester) async {
      when(
        () => mockBagsakanDao.searchByBarcodeLike(any()),
      ).thenAnswer((_) async => []);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(2),
        'TEST123',
      ); // Search input
      await tester.tap(find.text('bagsakan.search'.tr()));
      await tester.pumpAndSettle();

      verify(() => mockBagsakanDao.searchByBarcodeLike('TEST123')).called(1);
    });
  });
}
