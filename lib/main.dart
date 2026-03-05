import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/auth_storage.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/compact_mode_provider.dart';
import 'shared/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final authStorage = AuthStorage();
  final appSettings = AppSettings();

  bool isAuth = false;
  ThemeMode themeMode = ThemeMode.light;
  bool compactMode = false;
  Map<String, dynamic>? courier;

  try {
    isAuth = await authStorage.isAuthenticated().timeout(
      const Duration(seconds: 3),
    );
    themeMode = await appSettings.getThemeMode().timeout(
      const Duration(seconds: 3),
    );
    compactMode = await appSettings.getCompactMode().timeout(
      const Duration(seconds: 3),
    );
    courier = await authStorage.getCourier().timeout(
      const Duration(seconds: 3),
    );
  } catch (_) {
    isAuth = false;
    themeMode = ThemeMode.light;
    compactMode = false;
    courier = null;
  }

  runApp(
    ProviderScope(
      overrides: [
        initialLocationProvider.overrideWithValue('/splash'),
        compactModeProvider.overrideWith((_) => compactMode),
        authProvider.overrideWith(
          (ref) => AuthNotifier(
            authStorage,
            appSettings,
            initialState: AuthState(
              isAuthenticated: isAuth,
              themeMode: themeMode,
              courier: courier,
            ),
          ),
        ),
      ],
      child: const FsiCourierApp(),
    ),
  );
}
