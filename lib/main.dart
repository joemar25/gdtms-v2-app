// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/database/app_database.dart';
import 'core/services/app_version_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/sync/workmanager_setup.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Read app version once from platform metadata — cached for the session.
  await AppVersionService.init();

  // Initialise the local SQLite database before rendering the first frame.
  await AppDatabase.getInstance();

  // Initialize background tasks
  await BackgroundSyncSetup.init();

  // Initialize Firebase and background push notification handler
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService.initBackgroundHandler();

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
    }, appRunner: () => runApp(const ProviderScope(child: FsiCourierApp())));
  } else {
    // No DSN — run normally (local dev / CI without secrets).
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
    runApp(const ProviderScope(child: FsiCourierApp()));
  }
}
