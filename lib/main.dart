// DOCS: docs/development-standards.md
// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants.dart';
import 'core/auth/auth_provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await EasyLocalization.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Cap the image cache once from startup: 80 MB / 150 images max.
  // Default Flutter limits (unlimited count, 100 MB) are too generous for a
  // delivery app that shows many thumbnails on list screens.
  PaintingBinding.instance.imageCache
    ..maximumSize = 150
    ..maximumSizeBytes = 80 << 20; // 80 MB

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

  // ── Deferred: heavy initialisation (Firebase, DB, FCM, Sentry, etc.) ────
  //     moved to SplashScreen._deferredInit() so the first Flutter frame
  //     renders instantly without blocking the main isolate.

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  runApp(_buildApp(initialThemeMode));
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
