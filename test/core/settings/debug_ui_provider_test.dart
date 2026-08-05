import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/services/runtime_environment_service.dart';
import 'package:fsi_courier_app/core/settings/debug_ui_provider.dart';

void main() {
  group('computeDebugToolsAvailable', () {
    test('debug build always has tools', () {
      expect(
        computeDebugToolsAvailable(isDebugBuild: true, isDeveloperMode: false),
        isTrue,
      );
    });

    test('release + developer mode has tools', () {
      expect(
        computeDebugToolsAvailable(isDebugBuild: false, isDeveloperMode: true),
        isTrue,
      );
    });

    test('release production has no tools', () {
      expect(
        computeDebugToolsAvailable(isDebugBuild: false, isDeveloperMode: false),
        isFalse,
      );
    });

    test('debug + developer mode still has tools', () {
      expect(
        computeDebugToolsAvailable(isDebugBuild: true, isDeveloperMode: true),
        isTrue,
      );
    });
  });

  group('computeShowDebugUi', () {
    test('tools + pref on → show', () {
      expect(
        computeShowDebugUi(toolsAvailable: true, preferenceOn: true),
        isTrue,
      );
    });

    test('tools + pref off → hide chrome (chip still allowed separately)', () {
      expect(
        computeShowDebugUi(toolsAvailable: true, preferenceOn: false),
        isFalse,
      );
    });

    test('no tools + pref on → never show chrome', () {
      expect(
        computeShowDebugUi(toolsAvailable: false, preferenceOn: true),
        isFalse,
      );
    });

    test('no tools + pref off → never show chrome', () {
      expect(
        computeShowDebugUi(toolsAvailable: false, preferenceOn: false),
        isFalse,
      );
    });
  });

  group('providers (runtime)', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await RuntimeEnvironmentService.instance.setDeveloperMode(false);
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('default: preference on, showDebugUi follows tools', () {
      // flutter test runs as debug → tools on via kAppDebugMode
      container.read(debugToolsProvider.notifier).syncFromRuntime();
      expect(container.read(debugToolsProvider), isTrue);
      expect(container.read(debugUiProvider), isTrue);
      expect(container.read(showDebugUiProvider), isTrue);
    });

    test('toggle preference hides chrome but tools stay', () async {
      container.read(debugToolsProvider.notifier).syncFromRuntime();
      await container.read(debugUiProvider.notifier).toggle();

      expect(container.read(debugUiProvider), isFalse);
      expect(container.read(debugToolsProvider), isTrue);
      expect(container.read(showDebugUiProvider), isFalse);

      await container.read(debugUiProvider.notifier).toggle();
      expect(container.read(showDebugUiProvider), isTrue);
    });

    test('preference persists via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({AppKeys.debugUiVisible: false});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppKeys.debugUiVisible), isFalse);

      container.read(debugUiProvider.notifier).setValue(false);
      expect(container.read(showDebugUiProvider), isFalse);

      await container.read(debugUiProvider.notifier).toggle();
      expect(container.read(debugUiProvider), isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(AppKeys.debugUiVisible),
        isTrue,
      );
    });

    test('developer mode on then sync enables tools path', () async {
      // Simulate: tools forced off, then runtime says developer mode.
      // In real release kAppDebugMode is false; here we only assert sync
      // picks up RuntimeEnvironmentService after setDeveloperMode.
      await RuntimeEnvironmentService.instance.setDeveloperMode(true);
      container.read(debugToolsProvider.notifier).syncFromRuntime();

      expect(RuntimeEnvironmentService.instance.isDeveloperMode, isTrue);
      expect(container.read(debugToolsProvider), isTrue);
      expect(container.read(showDebugUiProvider), isTrue);
    });

    test(
      'release-like: tools off until developer mode + sync (pref can be off)',
      () async {
        // Force tools false as if release production, then enable like a
        // courier who turned on developer mode with chrome previously hidden.
        await RuntimeEnvironmentService.instance.setDeveloperMode(false);
        container.read(debugToolsProvider.notifier).syncFromRuntime();
        // In debug test env tools stay true from kAppDebugMode — assert pure
        // gate for the release matrix instead.
        expect(
          computeDebugToolsAvailable(
            isDebugBuild: false,
            isDeveloperMode: false,
          ),
          isFalse,
        );
        expect(
          computeShowDebugUi(toolsAvailable: false, preferenceOn: false),
          isFalse,
        );

        // After enabling developer mode in production:
        expect(
          computeDebugToolsAvailable(
            isDebugBuild: false,
            isDeveloperMode: true,
          ),
          isTrue,
        );
        // Pref was off — chrome stays hidden, but chip should still show
        // because tools are available (chip watches tools, not showDebugUi).
        expect(
          computeShowDebugUi(toolsAvailable: true, preferenceOn: false),
          isFalse,
        );
        // Chip visibility rule:
        final chipVisible = computeDebugToolsAvailable(
          isDebugBuild: false,
          isDeveloperMode: true,
        );
        expect(chipVisible, isTrue);
      },
    );

    test('disabling developer mode after sync drops tools in pure gate', () {
      expect(
        computeShowDebugUi(
          toolsAvailable: computeDebugToolsAvailable(
            isDebugBuild: false,
            isDeveloperMode: false,
          ),
          preferenceOn: true,
        ),
        isFalse,
      );
    });
  });
}
