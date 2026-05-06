import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_screen.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  });

  testWidgets('BagsakanScreen displays under development message', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const BagsakanScreen()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsUnreadCountProvider.overrideWithValue(0),
          authProvider.overrideWith(MockAuthNotifier.new),
          updateProvider.overrideWith(MockUpdateNotifier.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Wait for animations to settle
    await tester.pumpAndSettle();

    // Verify 'Bagsakan' text is present (using translation key as tr() returns it in tests)
    expect(find.text('bagsakan.title'), findsWidgets);

    // Verify 'Under Development' text is present
    expect(find.text('bagsakan.under_development'), findsOneWidget);

    // Verify icon is present
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}

class MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isAuthenticated: false, themeMode: ThemeMode.light);
}

class MockUpdateNotifier extends UpdateNotifier {
  @override
  UpdateState build() => const UpdateState();
}
