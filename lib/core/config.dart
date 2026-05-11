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
//  Delivery Visibility Windows
// ─────────────────────────────────────────────────────────────────────────────
//
// Controls how long each delivery status remains visible in the courier's
// active list before the local DB query filters it out.
//
// ## Production rules (default — all windows = 0)
//
//   FOR_DELIVERY   → visible forever until archived by the server.
//   FAILED_DELIVERY→ visible forever until verified by hub OR archived.
//   MISROUTED      → visible forever until archived by the server.
//   DELIVERED      → ALWAYS today-only (not configurable — payout law).
//
// ## Testing rules (set window > 0)
//
//   A positive value N means: show the item for N hours from its
//   `completed_at` timestamp (FAILED_DELIVERY, MISROUTED) or from `created_at`
//   (FOR_DELIVERY). After N hours the item is filtered from the list query
//   as if it had been archived, without touching the database.
//
//   Example — simulate midnight clearing at 1 hour window:
//     dart_defines.json:
//       "FAILED_DELIVERY_VISIBILITY_MINUTES": 60
//       "MISROUTED_VISIBILITY_MINUTES": 60
//
//   Example — simulate a 1-minute test window (fastest test):
//     flutter run --dart-define=FAILED_DELIVERY_VISIBILITY_MINUTES=1 ...
//
//   Example — simulate a 30-minute test window:
//     dart_defines.json:
//       "FAILED_DELIVERY_VISIBILITY_MINUTES": 30
//
// ⚠️  PRODUCTION SAFETY: All three defaults are 0 (disabled).
//     NEVER ship a build with non-zero values in release/prod defines.

/// Visibility window for FAILED_DELIVERY items, in **minutes**.
///
/// - `0` = no window (production default — items persist until verified/archived).
/// - `60` = items disappear 60 min after their `completed_at` timestamp.
/// - `1` = items disappear after 1 minute (fastest test scenario).
///
/// Set via `--dart-define=FAILED_DELIVERY_VISIBILITY_MINUTES=<n>`
/// or in `dart_defines.json`.
const int kFailedDeliveryVisibilityWindowMinutes = int.fromEnvironment(
  'FAILED_DELIVERY_VISIBILITY_MINUTES',
  defaultValue: 0,
);

/// Visibility window for MISROUTED items, in **minutes**.
///
/// - `0` = no window (production default — items persist until archived).
/// - `60` = items disappear 60 min after their `completed_at` timestamp.
const int kMisroutedVisibilityWindowMinutes = int.fromEnvironment(
  'MISROUTED_VISIBILITY_MINUTES',
  defaultValue: 0,
);

/// Visibility window for FOR_DELIVERY items, in **minutes**.
///
/// - `0` = no window (production default — items persist until archived).
///
/// Use this to test that pending items correctly disappear when the server
/// removes them from a courier's workload after a set time window.
const int kForDeliveryVisibilityWindowMinutes = int.fromEnvironment(
  'FOR_DELIVERY_VISIBILITY_MINUTES',
  defaultValue: 0,
);

/// True when ANY visibility window is active.
/// Useful for logging / asserting that production builds are always clean.
const bool kVisibilityWindowsActive =
    kFailedDeliveryVisibilityWindowMinutes > 0 ||
    kMisroutedVisibilityWindowMinutes > 0 ||
    kForDeliveryVisibilityWindowMinutes > 0;

// ─────────────────────────────────────────────────────────────────────────────
//  PASSWORD
// ─────────────────────────────────────────────────────────────────────────────
const String kDeveloperPassword = String.fromEnvironment(
  'PASSWORD',
  defaultValue: '',
);

// ─────────────────────────────────────────────────────────────────────────────
//  Delivery Rules
// ─────────────────────────────────────────────────────────────────────────────

/// Maximum number of delivery attempts allowed for an item to remain
/// "valid for delivery".
///
/// If an item reaches this number of attempts in FAILED_DELIVERY status,
/// it becomes terminal (RTS).
const int kMaxDeliveryAttempts = 3;

// ─────────────────────────────────────────────────────────────────────────────
//  Delivery Status Codes (Canonical)
// ─────────────────────────────────────────────────────────────────────────────

const String kStatusForDelivery = 'FOR_DELIVERY';
const String kStatusForRedelivery = 'FOR_REDELIVERY';
const String kStatusFailedDelivery = 'FAILED_DELIVERY';
const String kStatusDelivered = 'DELIVERED';
const String kStatusMisrouted = 'MISROUTED';
const String kStatusDispatched = 'DISPATCHED';
const String kStatusPending = 'PENDING';
const String kStatusRts = 'RTS';

/// Statuses that are potentially valid for delivery.
/// Note: FAILED_DELIVERY is only valid if attempts < [kMaxDeliveryAttempts].
const List<String> kValidForDeliveryStatuses = [
  kStatusForDelivery,
  kStatusForRedelivery,
  kStatusFailedDelivery,
];

/// Statuses that are considered terminal and no longer valid for delivery.
const List<String> kTerminalDeliveryStatuses = [
  kStatusDelivered,
  kStatusMisrouted,
];

// ─────────────────────────────────────────────────────────────────────────────
//  Debug Mode
// ─────────────────────────────────────────────────────────────────────────────

/// True only in debug builds; always false in release/profile.
const bool kAppDebugMode = kDebugMode;

// ─────────────────────────────────────────────────────────────────────────────
//  End of config.dart
// ─────────────────────────────────────────────────────────────────────────────
