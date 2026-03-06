import 'package:flutter/foundation.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // defaultValue: 'https://staging-gdtms-v2.skyward.com.ph/api/mbl',

  // mar-note
  // debug mode;
  // from our website locally to expose in same wifi network
  // steps 1: run php artisan serve --host=0.0.0.0 && npm run dev -- --host=0.0.0.0
  // step 2: run ipconfig to get IPv4 Address e.g. 'YOUR_LOCAL_IP' to replace http://{replace}:{port}/api/mbl
  // port is from php
  // note this wont work on web, but for emulator and real phones on same wifie network
  defaultValue: 'http://YOUR_API_BASE_URL/api/mbl',
);

const String appVersion = '1.0.0';
const String deviceName = 'Mobile App';
const String appName = 'FSI Courier';
const String packageId = 'com.fsi.courier';

/// True only in debug builds; always false in release/profile.
const bool kAppDebugMode = kDebugMode;

// REDACTED_TEST_NUMBER
