import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/services/runtime_environment_service.dart';
import 'package:fsi_courier_app/core/settings/debug_ui_provider.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';
import 'package:fsi_courier_app/shared/widgets/debug_ui_toggle.dart';

import '../../helpers/screen_protector_channel_mock.dart';

/// Mirrors production: chip is a Stack sibling of navigator content, and
/// sheets must go through [rootNavigatorKey].
Widget _harness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      home: const Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [SizedBox.expand(), DebugUiToggle()],
        ),
      ),
    ),
  );
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    mockScreenProtectorChannel();
    SharedPreferences.setMockInitialValues({});
    await RuntimeEnvironmentService.instance.setDeveloperMode(false);
    debugResetDevShortcutsSheetGate();
    container = ProviderContainer();
    container.read(debugToolsProvider.notifier).syncFromRuntime();
  });

  tearDown(() {
    debugResetDevShortcutsSheetGate();
    container.dispose();
    clearScreenProtectorChannelMock();
  });

  testWidgets('shows DEBUG chip when tools available and pref on', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(container));
    expect(find.text('DEBUG'), findsOneWidget);
    expect(find.text('UI'), findsNothing);
  });

  testWidgets('tap opens dev shortcuts sheet', (tester) async {
    await tester.pumpWidget(_harness(container));

    await tester.tap(find.text('DEBUG'));
    await tester.pumpAndSettle();

    expect(find.text('DEV SHORTCUTS'), findsOneWidget);
    expect(find.text('Splash screen'), findsOneWidget);
    expect(find.text('Initial sync'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Hide debug chrome'), findsOneWidget);
  });

  testWidgets('second tap does not stack sheets — closes instead', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(container));

    await tester.tap(find.text('DEBUG'));
    await tester.pumpAndSettle();
    expect(find.text('DEV SHORTCUTS'), findsOneWidget);

    // Chip sits above the modal barrier in production; tap again = toggle close.
    await tester.tap(find.text('DEBUG'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('DEV SHORTCUTS'), findsNothing);

    // Re-open once — still a single sheet.
    await tester.tap(find.text('DEBUG'));
    await tester.pumpAndSettle();
    expect(find.text('DEV SHORTCUTS'), findsOneWidget);
  });

  testWidgets('chip can be dragged on screen', (tester) async {
    await tester.pumpWidget(_harness(container));

    final chip = find.text('DEBUG');
    final before = tester.getTopLeft(chip);

    await tester.drag(chip, const Offset(120, 180));
    await tester.pumpAndSettle();

    final after = tester.getTopLeft(chip);
    expect(after.dx, greaterThan(before.dx + 40));
    expect(after.dy, greaterThan(before.dy + 40));
    // Still tappable after drag.
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('DEV SHORTCUTS'), findsOneWidget);
  });

  testWidgets('sheet can hide debug chrome', (tester) async {
    await tester.pumpWidget(_harness(container));

    await tester.tap(find.text('DEBUG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide debug chrome'));
    await tester.pumpAndSettle();

    expect(find.text('UI'), findsOneWidget);
    expect(container.read(debugUiProvider), isFalse);
    expect(container.read(showDebugUiProvider), isFalse);
  });

  testWidgets(
    'chip still visible when chrome hidden (pref off) so it can be re-enabled',
    (tester) async {
      container.read(debugUiProvider.notifier).setValue(false);
      await tester.pumpWidget(_harness(container));
      expect(find.text('UI'), findsOneWidget);
      expect(container.read(showDebugUiProvider), isFalse);

      await tester.tap(find.text('UI'));
      await tester.pumpAndSettle();
      expect(find.text('Show debug chrome'), findsOneWidget);
    },
  );

  testWidgets('hides chip entirely when tools forced off', (tester) async {
    // Simulate production without developer mode by forcing provider state.
    // (kAppDebugMode is true in tests; override notifier after sync.)
    container.read(debugToolsProvider.notifier).debugSetAvailable(false);
    await tester.pumpWidget(_harness(container));
    expect(find.text('DEBUG'), findsNothing);
    expect(find.text('UI'), findsNothing);
  });

  testWidgets(
    'production path: tools off → enable developer mode → chip appears',
    (tester) async {
      container.read(debugToolsProvider.notifier).debugSetAvailable(false);
      container.read(debugUiProvider.notifier).setValue(false);
      await tester.pumpWidget(_harness(container));
      expect(find.text('DEBUG'), findsNothing);
      expect(find.text('UI'), findsNothing);

      // Courier enables developer mode (profile handshake).
      await RuntimeEnvironmentService.instance.setDeveloperMode(true);
      container.read(debugToolsProvider.notifier).syncFromRuntime();
      await tester.pump();

      // Pref still off → label UI, but chip is usable again.
      expect(find.text('UI'), findsOneWidget);
      expect(container.read(showDebugUiProvider), isFalse);

      await tester.tap(find.text('UI'));
      await tester.pumpAndSettle();
      expect(find.text('DEV SHORTCUTS'), findsOneWidget);
      await tester.tap(find.text('Show debug chrome'));
      await tester.pumpAndSettle();
      expect(find.text('DEBUG'), findsOneWidget);
      expect(container.read(showDebugUiProvider), isTrue);
    },
  );
}
