// DOCS: docs/development-standards.md
// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/constants.dart';
import 'core/database/app_database.dart';
import 'core/services/app_version_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/sync/workmanager_setup.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Read app version once from platform metadata — cached for the session.
  await AppVersionService.init();

  // Initialise the local SQLite database before rendering the first frame.
  await AppDatabase.getInstance();

  // Initialize background tasks
  await BackgroundSyncSetup.init();

  // Initialize Firebase and background push notification handler
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // During hot restart, native Firebase persists while Dart side resets.
    // Gracefully ignore duplicate-app errors and continue.
    if (e.code != 'duplicate-app') rethrow;
  }

  // Fetch and persist FCM token early so it survives login/restarts (offline-safe).
  try {
    final earlyToken = await FirebaseMessaging.instance.getToken();
    if (earlyToken != null) {
      final authStorage = AuthStorage();
      await authStorage.setPendingFcmToken(earlyToken);
      debugPrint('[MAIN] Early FCM token persisted: $earlyToken');
    } else {
      debugPrint('[MAIN] Early FCM getToken returned null');
    }
  } catch (e) {
    debugPrint('[MAIN] Failed to fetch/persist early FCM token: $e');
  }

  await PushNotificationService.initBackgroundHandler();

  // ── Early Theme Resolution ──────────────────────────────────────────────
  // We read the theme mode before runApp so the splash screen renders with
  // the user's preferred theme immediately, avoiding the "light mode flash".
  final prefs = await SharedPreferences.getInstance();
  final themeModeIndex = prefs.getInt(AppKeys.themeMode);
  ThemeMode initialThemeMode = ThemeMode.light;
  if (themeModeIndex != null &&
      themeModeIndex >= 0 &&
      themeModeIndex < ThemeMode.values.length) {
    initialThemeMode = ThemeMode.values[themeModeIndex];
  } else {
    // Fallback to legacy key or system default
    final dark = prefs.getBool(AppKeys.darkMode) ?? false;
    initialThemeMode = dark ? ThemeMode.dark : ThemeMode.light;
  }

  // ── Sentry crash monitoring ───────────────────────────────────────────────
  // Only active when SENTRY_DSN is provided at build time.
  // Captures unhandled Flutter errors and platform-level crashes automatically.
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.tracesSampleRate = kReleaseMode ? 0.2 : 0.0;
      options.attachScreenshot = false; // disable for privacy
      options.sendDefaultPii = false;
    }, appRunner: () => runApp(_buildApp(initialThemeMode)));
  } else {
    // No DSN — run normally (local dev / CI without secrets).
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
    runApp(_buildApp(initialThemeMode));
  }
}

Widget _buildApp(ThemeMode initialThemeMode) {
  return ProviderScope(
    overrides: [initialThemeModeProvider.overrideWithValue(initialThemeMode)],
    child: EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fil')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: const FsiCourierApp(),
    ),
  );
}
