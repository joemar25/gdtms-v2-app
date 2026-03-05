import 'package:flutter/foundation.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // defaultValue: 'https://staging-gdtms-v2.skyward.com.ph/api/mbl',
  
  // mar-note
  // debug mode; requires php artisan serve --host=0.0.0.0 && npm run dev -- --host=0.0.0.0
  // from our website locally to expose in same wifi network
  defaultValue: 'http://YOUR_API_BASE_URL/api/mbl',
);

const String appVersion = '1.0.0';
const String deviceName = 'Mobile App';
const String appName = 'FSI Courier';
const String packageId = 'com.fsi.courier';

/// True only in debug builds; always false in release/profile.
const bool kAppDebugMode = kDebugMode;

// REDACTED_TEST_NUMBER