// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/design_system/widgets/molecules/ds_secure_view.dart';

enum RuntimeAppMode { production, developer }

/// Holds the runtime API environment mode and persists it locally.
class RuntimeEnvironmentService {
  RuntimeEnvironmentService._();

  static final RuntimeEnvironmentService instance =
      RuntimeEnvironmentService._();

  bool _isDeveloperMode = false;

  bool get isDeveloperMode => _isDeveloperMode;

  RuntimeAppMode get mode =>
      _isDeveloperMode ? RuntimeAppMode.developer : RuntimeAppMode.production;

  String get activeApiBaseUrl => apiBaseUrl;

  String get modeLabel =>
      _isDeveloperMode ? 'Developer Mode' : 'Production Mode';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDeveloperMode = prefs.getBool(AppKeys.developerMode) ?? false;
    // Apply screenshot bypass immediately based on persisted developer mode.
    SecureViewManager.setDeveloperModeOverride(_isDeveloperMode);
  }

  Future<void> setDeveloperMode(bool enabled) async {
    _isDeveloperMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.developerMode, enabled);
    // Propagate to screenshot protection in real time.
    SecureViewManager.setDeveloperModeOverride(enabled);
  }
}
