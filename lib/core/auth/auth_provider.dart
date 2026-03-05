import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import 'auth_storage.dart';

class AuthState {
  const AuthState({
    required this.isAuthenticated,
    required this.themeMode,
    this.courier,
  });

  final bool isAuthenticated;
  final ThemeMode themeMode;
  final Map<String, dynamic>? courier;

  AuthState copyWith({
    bool? isAuthenticated,
    ThemeMode? themeMode,
    Map<String, dynamic>? courier,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      themeMode: themeMode ?? this.themeMode,
      courier: courier ?? this.courier,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authStorageProvider), ref.read(appSettingsProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(
    this._authStorage,
    this._settings, {
    AuthState? initialState,
  }) : super(
         initialState ??
             const AuthState(isAuthenticated: false, themeMode: ThemeMode.light),
       );

  final AuthStorage _authStorage;
  final AppSettings _settings;

  Future<void> initialize() async {
    final isAuth = await _authStorage.isAuthenticated();
    final courier = await _authStorage.getCourier();
    final darkMode = await _settings.getDarkMode();
    state = state.copyWith(
      isAuthenticated: isAuth,
      courier: courier,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
    );
  }

  Future<void> setAuthenticated({required Map<String, dynamic> courier}) async {
    await _authStorage.setCourier(courier);
    state = state.copyWith(isAuthenticated: true, courier: courier);
  }

  Future<void> clearAuth() async {
    await _authStorage.clearAll();
    state = state.copyWith(isAuthenticated: false, courier: null);
  }

  Future<void> setDarkMode(bool enabled) async {
    await _settings.setDarkMode(enabled);
    state = state.copyWith(themeMode: enabled ? ThemeMode.dark : ThemeMode.light);
  }
}
