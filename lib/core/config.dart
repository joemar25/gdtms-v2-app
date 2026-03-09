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
///   `npm run dev -- --host=0.0.0.0`, then use your IPv4 address from `ipconfig`.
/// - Note: This will not work for web builds.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // 'API_BASE_URL_PROD',
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













// rule - if payout na yung delivery, then atleast 1 day yung retainability neto sa database before it was to be cleared. 