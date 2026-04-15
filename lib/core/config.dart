// DOCS: docs/core/settings.md — update that file when you edit this one.

import 'package:flutter/foundation.dart';

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
///
/// - Set via --dart-define=API_BASE_URL at build/run time.
/// - Default: Local dev server (for emulator/real device on same WiFi).
///   To expose locally: run `php artisan serve --host=0.0.0.0` and
///   `npm run dev --host=0.0.0.0`, then use your IPv4 address from `ipconfig`.
/// - Note: This will not work for web builds.
/// - Run :  flutter run --dart-define-from-file=dart_defines.json
/// - Prod:  flutter build apk --dart-define-from-file=dart_defines.json
const String apiBaseUrl = String.fromEnvironment(
  // 'API_BASE_URL_PROD',
  // 'API_BASE_URL_DEMO',
  'API_BASE_URL',
  defaultValue: 'http://YOUR_API_BASE_URL/api/mbl',
);

// ─────────────────────────────────────────────────────────────────────────────
//  Media Upload Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Toggle for uploading media directly to AWS S3.
///
/// - If true, uploads go to S3 instead of API endpoint (/deliveries/:barcode/media).
/// - Enable at build/run time:
///   flutter run --dart-define=USE_S3_UPLOAD=true \
///                --dart-define=AWS_ACCESS_KEY_ID=... \
///                --dart-define=AWS_SECRET_ACCESS_KEY=...
/// - NEVER commit actual AWS credentials as a defaultValue.
const bool kUseS3Upload = bool.fromEnvironment(
  'USE_S3_UPLOAD',
  defaultValue: false,
);

/// When true, S3 upload failures are treated as fatal — no API fallback.
///
/// Only meaningful when [kUseS3Upload] is also true. Use this to verify that
/// uploads are genuinely reaching S3 without the API silently absorbing failures.
///
/// - false (default): S3 failure falls through to the API upload endpoint.
/// - true:            S3 failure immediately returns an error; API is never tried.
///
/// Enable at build/run time:
///   flutter run --dart-define=USE_S3_UPLOAD=true \
///                --dart-define=S3_STRICT_MODE=true \
///                --dart-define=AWS_ACCESS_KEY_ID=... \
///                --dart-define=AWS_SECRET_ACCESS_KEY=...
const bool kS3StrictMode = bool.fromEnvironment(
  'S3_STRICT_MODE',
  defaultValue: false,
);

// ─────────────────────────────────────────────────────────────────────────────
//  AWS S3 Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// AWS Access Key ID (never hard-code; use --dart-define).
const String awsAccessKeyId = String.fromEnvironment(
  'AWS_ACCESS_KEY_ID',
  defaultValue: '',
);

/// AWS Secret Access Key (never hard-code; use --dart-define).
const String awsSecretAccessKey = String.fromEnvironment(
  'AWS_SECRET_ACCESS_KEY',
  defaultValue: '',
);

/// AWS region for S3 bucket.
const String awsRegion = String.fromEnvironment(
  'AWS_REGION',
  defaultValue: 'ap-southeast-1',
);

/// AWS S3 bucket name.
const String awsBucket = String.fromEnvironment(
  'AWS_BUCKET',
  defaultValue: 'REDACTED_BUCKET_NAME',
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
