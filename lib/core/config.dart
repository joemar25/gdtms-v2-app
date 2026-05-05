// DOCS: docs/development-standards.md
// DOCS: docs/core/settings.md — update that file when you edit this one.

import 'package:flutter/foundation.dart';

/// - Set via --dart-define=API_BASE_URL at build/run time.
/// - Default: Local dev server (for emulator/real device on same WiFi).
///   To expose locally: run `php artisan serve --host=0.0.0.0` and
///   `npm run dev --host=0.0.0.0`, then use your IPv4 address from `ipconfig`.
/// - Note: This will not work for web builds.
/// - Combination: flutter analyze; flutter test; dart format .
/// - Run :  flutter run --dart-define-from-file=dart_defines.json
/// - Prod:  flutter build apk --dart-define-from-file=dart_defines.json
// ─────────────────────────────────────────────────────────────────────────────
//  FSI Courier App Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Device name for identification.
const String deviceName = 'Mobile App';

/// Application display name.
const String appName = 'FSI Courier';

/// Android/iOS package identifier.
const String packageId = 'com.fsi.courier';

/// Base URL for API requests.
const String apiBaseUrl = String.fromEnvironment(
  // 'API_BASE_URL_PROD',
  // 'API_BASE_URL_DEMO',
  'API_BASE_URL',
  defaultValue: 'http://YOUR_API_BASE_URL/api/mbl',
);

// ─────────────────────────────────────────────────────────────────────────────
//  AWS S3 Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// AWS credentials and bucket info for direct S3 uploads.
/// Set via --dart-define or dart_defines.json.
const String kAwsAccessKeyId = String.fromEnvironment(
  'AWS_ACCESS_KEY_ID',
  defaultValue: '',
);
const String kAwsSecretAccessKey = String.fromEnvironment(
  'AWS_SECRET_ACCESS_KEY',
  defaultValue: '',
);
const String kAwsRegion = String.fromEnvironment(
  'AWS_REGION',
  defaultValue: 'ap-southeast-1',
);
const String kAwsBucket = String.fromEnvironment(
  'AWS_BUCKET',
  defaultValue: '',
);

// ─────────────────────────────────────────────────────────────────────────────
//  Firebase Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Firebase Web API key.
///
/// Set via --dart-define=FIREBASE_API_KEY_WEB at build/run time.
const String firebaseApiKeyWeb = String.fromEnvironment(
  'FIREBASE_API_KEY_WEB',
  defaultValue: '',
);

/// Firebase Android API key.
///
/// Set via --dart-define=FIREBASE_API_KEY_ANDROID at build/run time.
const String firebaseApiKeyAndroid = String.fromEnvironment(
  'FIREBASE_API_KEY_ANDROID',
  defaultValue: '',
);

/// Firebase iOS API key.
///
/// Set via --dart-define=FIREBASE_API_KEY_IOS at build/run time.
const String firebaseApiKeyIos = String.fromEnvironment(
  'FIREBASE_API_KEY_IOS',
  defaultValue: '',
);

/// Firebase Windows API key.
///
/// Set via --dart-define=FIREBASE_API_KEY_WINDOWS at build/run time.
const String firebaseApiKeyWindows = String.fromEnvironment(
  'FIREBASE_API_KEY_WINDOWS',
  defaultValue: '',
);

// ─────────────────────────────────────────────────────────────────────────────
//  Sentry Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Sentry DSN for crash reporting.
///
/// - Set via --dart-define=SENTRY_DSN=https://... at build/run time.
/// - Leave empty to disable Sentry (default for local dev without a DSN).
/// - Add to dart_defines.json for prod/demo builds.
const String sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

// ─────────────────────────────────────────────────────────────────────────────
//  Security Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Toggle for screenshot and screen recording protection.
///
/// - Set via --dart-define=SECURE_SCREENSHOTS=true/false.
/// - Default: true (protection enabled).
const bool kSecureScreenshots = bool.fromEnvironment(
  'SECURE_SCREENSHOTS',
  defaultValue: true,
);

/// API connection timeout.
const Duration kApiConnectTimeout = Duration(seconds: 30);

/// API receive timeout.
const Duration kApiReceiveTimeout = Duration(seconds: 60);

/// API send timeout.
const Duration kApiSendTimeout = Duration(seconds: 60);

// ─────────────────────────────────────────────────────────────────────────────
//  Feature Toggles
// ─────────────────────────────────────────────────────────────────────────────

/// Toggle for global search functionality in the dashboard.
///
/// - Set via --dart-define=ENABLE_GLOBAL_SEARCH=true/false.
/// - Default: false (not yet confirmed).
const bool kEnableGlobalSearch = bool.fromEnvironment(
  'ENABLE_GLOBAL_SEARCH',
  defaultValue: false,
);

// ─────────────────────────────────────────────────────────────────────────────
//  Debug Mode
// ─────────────────────────────────────────────────────────────────────────────

/// True only in debug builds; always false in release/profile.
const bool kAppDebugMode = kDebugMode;

// ─────────────────────────────────────────────────────────────────────────────
//  Payout Request Time Window
// ─────────────────────────────────────────────────────────────────────────────

/// The earliest hour (inclusive, local time) at which a courier may submit a
/// payout request. Currently 06:00 AM.
const int kPayoutWindowStartHour = 6;

/// The latest hour (exclusive, local time) at which a courier may submit a
/// payout request. Currently 12:00 PM (noon).
const int kPayoutWindowEndHour = 12;

/// Returns `true` when a payout request is currently allowed.
///
/// The window is **06:00 AM – 11:59 AM** local time (i.e. `hour >= 6 && hour < 12`).
/// In debug builds ([kAppDebugMode] == true) this restriction is lifted and the
/// function always returns `true`, allowing developers to test at any time.
bool isWithinPayoutRequestWindow() {
  if (kAppDebugMode) return true;
  final now = DateTime.now();
  return now.hour >= kPayoutWindowStartHour && now.hour < kPayoutWindowEndHour;
}

// ─────────────────────────────────────────────────────────────────────────────
//  End of config.dart
// ─────────────────────────────────────────────────────────────────────────────
