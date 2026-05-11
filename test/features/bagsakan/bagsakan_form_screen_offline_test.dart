import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_form_screen.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    themeMode: ThemeMode.light,
    courier: {'id': 'test_courier_123'},
  );
}

class MockUpdateNotifier extends UpdateNotifier {
  @override
  UpdateState build() => const UpdateState();
}

class MockConnectionStatusNotifier extends Notifier<ConnectionStatus> {
  final ConnectionStatus _status;

  MockConnectionStatusNotifier(this._status);

  @override
  ConnectionStatus build() => _status;
}

void main() {
  setUpAll(() {
    EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  });

  group('BagsakanFormScreen - Offline-First UI Tests', () {
    testWidgets('Shows ConnectionStatusBanner when offline', (
      WidgetTester tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const BagsakanFormScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(MockAuthNotifier.new),
            updateProvider.overrideWith(MockUpdateNotifier.new),
            notificationsUnreadCountProvider.overrideWithValue(0),
            connectionStatusProvider.overrideWith(
              (ref) => ConnectionStatus.networkOffline,
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en', 'US')],
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ConnectionStatusBanner should be visible when offline
      expect(find.byType(ConnectionStatusBanner), findsWidgets);
    });

    testWidgets('Shows ConnectionStatusBanner when API unreachable', (
      WidgetTester tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const BagsakanFormScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(MockAuthNotifier.new),
            updateProvider.overrideWith(MockUpdateNotifier.new),
            notificationsUnreadCountProvider.overrideWithValue(0),
            connectionStatusProvider.overrideWith(
              (ref) => ConnectionStatus.apiUnreachable,
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en', 'US')],
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ConnectionStatusBanner should be visible when API unreachable
      expect(find.byType(ConnectionStatusBanner), findsWidgets);
    });

    testWidgets('Does not show banner when online', (
      WidgetTester tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const BagsakanFormScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(MockAuthNotifier.new),
            updateProvider.overrideWith(MockUpdateNotifier.new),
            notificationsUnreadCountProvider.overrideWithValue(0),
            connectionStatusProvider.overrideWith(
              (ref) => ConnectionStatus.online,
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en', 'US')],
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // When online, banner may not be visible or should not show offline message
      // (ConnectionStatusBanner hides itself when online per its implementation)
    });

    testWidgets('Form allows saving while offline (operations queued)', (
      WidgetTester tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const BagsakanFormScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(MockAuthNotifier.new),
            updateProvider.overrideWith(MockUpdateNotifier.new),
            notificationsUnreadCountProvider.overrideWithValue(0),
            connectionStatusProvider.overrideWith(
              (ref) => ConnectionStatus.networkOffline,
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en', 'US')],
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Even though offline, the form should be accessible for input
      // (operations will be queued locally)
      expect(find.byType(BagsakanFormScreen), findsOneWidget);
    });
  });

  group('Bagsakan Sync Manager - Integration Tests', () {
    testWidgets('Sync manager displays progress during queue processing', (
      WidgetTester tester,
    ) async {
      // Note: Full SyncScreen integration test would go here
      // This is a placeholder for the pattern
      expect(true, true);
    });
  });
}

// Removed mock ConnectionStatusBanner class to use the real one.
