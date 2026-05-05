// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'package:package_info_plus/package_info_plus.dart';
import '../config.dart';

/// Single source of truth for the app's version string.
///
/// Reads from the actual build metadata (pubspec.yaml `version` field) via
/// [PackageInfo], eliminating the risk of the hardcoded `appVersion` constant
/// in config.dart drifting out of sync with the installed build.
///
/// **Initialisation** — call [AppVersionService.init()] once in `main()` before
/// [runApp]. All subsequent calls to [version] and [buildNumber] are synchronous.
class AppVersionService {
  AppVersionService._();

  static String _version = kAppVersion;
  static String _buildNumber = kAppBuildNumber;

  /// Reads version info from the platform. Safe to call multiple times.
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {
      // Keep fallback values on error.
    }
  }

  /// Semantic version from pubspec.yaml (e.g. "1.2.3").
  static String get version => _version;

  /// Build number from pubspec.yaml (e.g. "42").
  static String get buildNumber => _buildNumber;

  /// Display string for UI (e.g. "v1.2.3 (42)").
  static String get displayVersion =>
      _buildNumber.isNotEmpty ? 'v$_version ($_buildNumber)' : 'v$_version';
}
