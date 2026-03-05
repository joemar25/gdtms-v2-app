import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/auth_storage.dart';
import 'core/settings/app_settings.dart';
import 'shared/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final authStorage = AuthStorage();
  final appSettings = AppSettings();

  bool isAuth = false;
  bool darkMode = false;
  Map<String, dynamic>? courier;

  try {
    isAuth = await authStorage.isAuthenticated().timeout(
      const Duration(seconds: 3),
    );
    darkMode = await appSettings.getDarkMode().timeout(
      const Duration(seconds: 3),
    );
    courier = await authStorage.getCourier().timeout(
      const Duration(seconds: 3),
    );
  } catch (_) {
    // Fall back to login if startup hydration fails or stalls.
    isAuth = false;
    darkMode = false;
    courier = null;
  }

  runApp(
    ProviderScope(
      overrides: [
        initialLocationProvider.overrideWithValue(
          isAuth ? '/dashboard' : '/login',
        ),
        authProvider.overrideWith(
          (ref) => AuthNotifier(
            authStorage,
            appSettings,
            initialState: AuthState(
              isAuthenticated: isAuth,
              themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
              courier: courier,
            ),
          ),
        ),
      ],
      child: const FsiCourierApp(),
    ),
  );
}
