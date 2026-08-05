// DOCS: docs/development-standards.md
// DOCS: docs/core/settings.md — update that file when you edit this one.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/services/runtime_environment_service.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';

// ── Pure gates (unit-tested; release/dev/debug combos) ───────────────────────

/// Tools exist when this is a debug build **or** developer mode is on
/// (including release/profile production builds with dev mode enabled).
bool computeDebugToolsAvailable({
  required bool isDebugBuild,
  required bool isDeveloperMode,
}) => isDebugBuild || isDeveloperMode;

/// Screens show debug chrome only when tools exist and the user left it on.
bool computeShowDebugUi({
  required bool toolsAvailable,
  required bool preferenceOn,
}) => toolsAvailable && preferenceOn;

// ── Reactive providers ──────────────────────────────────────────────────────

/// Live tools gate. Call [DebugToolsNotifier.syncFromRuntime] after
/// [RuntimeEnvironmentService.init] and after [setDeveloperMode].
class DebugToolsNotifier extends Notifier<bool> {
  @override
  bool build() => _fromRuntime();

  bool _fromRuntime() => computeDebugToolsAvailable(
    isDebugBuild: kAppDebugMode,
    isDeveloperMode: RuntimeEnvironmentService.instance.isDeveloperMode,
  );

  void syncFromRuntime() => state = _fromRuntime();

  /// Test helper: force tools on/off without touching runtime prefs.
  @visibleForTesting
  void debugSetAvailable(bool value) => state = value;
}

final debugToolsProvider = NotifierProvider<DebugToolsNotifier, bool>(
  DebugToolsNotifier.new,
);

/// Preference only (default true). Loaded at splash; flipped by the chip.
class DebugUiNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setValue(bool value) => state = value;

  Future<void> toggle() async {
    state = !state;
    await ref.read(appSettingsProvider).setDebugUiVisible(state);
  }
}

final debugUiProvider = NotifierProvider<DebugUiNotifier, bool>(
  DebugUiNotifier.new,
);

/// Screens: `if (ref.watch(showDebugUiProvider)) ...`
final showDebugUiProvider = Provider<bool>((ref) {
  return computeShowDebugUi(
    toolsAvailable: ref.watch(debugToolsProvider),
    preferenceOn: ref.watch(debugUiProvider),
  );
});
