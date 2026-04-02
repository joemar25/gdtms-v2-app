import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FSI Courier App Configuration
// ─────────────────────────────────────────────────────────────────────────────

/// App version string.
const String appVersion = '1.0.0';

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
  'API_BASE_URL_DEMO',
  // 'API_BASE_URL',
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
//  Debug Mode
// ─────────────────────────────────────────────────────────────────────────────

/// True only in debug builds; always false in release/profile.
const bool kAppDebugMode = kDebugMode;

// ─────────────────────────────────────────────────────────────────────────────
//  End of config.dart
// ─────────────────────────────────────────────────────────────────────────────

// to emphasize:
// rule - if payout na yung delivery, then atleast 1 day yung retainability neto sa database before it was to be cleared.
// or if delivery is paid, strictly no need to put it in the database so if system detected if the dlelivery is paid then no need for it to be in the our local database unless it was today for record only but cannot be opened since we have locked it.
