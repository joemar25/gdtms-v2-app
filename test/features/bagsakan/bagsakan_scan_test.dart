import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/features/scan/scan_screen.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:go_router/go_router.dart';

class MockLocalDeliveryDao extends Mock implements LocalDeliveryDao {}

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
  late MockLocalDeliveryDao mockLocalDao;

  setUpAll(() {
    EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  });

  setUp(() {
    mockLocalDao = MockLocalDeliveryDao();
  });

  Widget createTestWidget() {
    final router = GoRouter(
      initialLocation: '/scan',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
          routes: [
            GoRoute(
              path: 'scan',
              builder: (context, state) =>
                  const ScanScreen(mode: ScanMode.bagsakan),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        localDeliveryDaoProvider.overrideWithValue(mockLocalDao),
        connectionStatusProvider.overrideWith((ref) => ConnectionStatus.online),
        authProvider.overrideWith(MockAuthNotifier.new),
        updateProvider.overrideWith(MockUpdateNotifier.new),
        compactModeProvider.overrideWith(MockCompactModeNotifier.new),
        notificationsUnreadCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('ScanScreen in bagsakan mode handles manual input successfully', (
    tester,
  ) async {
    final delivery = LocalDelivery(
      barcode: 'BAG123',
      deliveryStatus: 'FOR_DELIVERY',
      recipientName: 'Test User',
      rawJson: '{}',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    when(
      () => mockLocalDao.searchByQuery('BAG123'),
    ).thenAnswer((_) async => [delivery]);

    await tester.pumpWidget(createTestWidget());
    await tester.pump(const Duration(milliseconds: 100));

    // Open manual input
    final manualButton = find.byIcon(Icons.keyboard_alt_outlined);
    await tester.tap(manualButton);
    await tester.pump(const Duration(seconds: 1));

    // Enter barcode and simulate "Done" action
    await tester.enterText(find.byType(TextField), 'BAG123');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 1));

    verify(() => mockLocalDao.searchByQuery('BAG123')).called(1);

    // Check if we popped to Home
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('ScanScreen shows error for ineligible delivery status', (
    tester,
  ) async {
    final delivery = LocalDelivery(
      barcode: 'BAG456',
      deliveryStatus: 'DELIVERED', // Ineligible
      recipientName: 'Done User',
      rawJson: '{}',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    when(
      () => mockLocalDao.searchByQuery('BAG456'),
    ).thenAnswer((_) async => [delivery]);

    await tester.pumpWidget(createTestWidget());
    await tester.pump(const Duration(milliseconds: 100));

    // Open manual input
    await tester.tap(find.byIcon(Icons.keyboard_alt_outlined));
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(find.byType(TextField), 'BAG456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(seconds: 1));

    // Verify error notification text appears (at least one)
    expect(find.textContaining('not eligible for Bagsakan'), findsAtLeast(1));

    // Wait for notification timer to avoid pending timer error
    await tester.pump(const Duration(seconds: 5));
  });
}
