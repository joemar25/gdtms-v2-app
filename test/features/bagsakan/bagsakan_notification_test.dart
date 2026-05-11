import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_form_screen.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/database/bagsakan_dao.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_submit_fab.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:go_router/go_router.dart';

class MockBagsakanDao extends Mock implements BagsakanDao {}

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
  late MockBagsakanDao mockDao;
  late MockLocalDeliveryDao mockLocalDao;

  setUpAll(() {
    EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  });

  setUp(() {
    mockDao = MockBagsakanDao();
    mockLocalDao = MockLocalDeliveryDao();
  });

  Widget createTestWidget() {
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
        bagsakanDaoProvider.overrideWithValue(mockDao),
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

  testWidgets(
    'BagsakanFormScreen shows premium notification when name is empty',
    (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the Next button
      final nextButton = find.byType(DeliverySubmitFab);
      expect(nextButton, findsOneWidget);

      // Tap Next with empty name
      await tester.tap(nextButton);
      // Pump once to trigger the overlay notification
      await tester.pump();

      // Verify Premium Notification appears with the translation key
      // The text on screen will be the key because easy_localization is not initialized
      expect(find.text('bagsakan.error_empty_name'), findsOneWidget);

      // Wait for auto-dismiss timer to avoid "A Timer is still pending" error
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
