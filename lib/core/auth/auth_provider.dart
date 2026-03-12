import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';

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
    // Start all reads concurrently to avoid sequential I/O blocking.
    final isAuthFuture = _authStorage.isAuthenticated();
    final courierFuture = _authStorage.getCourier();
    final themeModeFuture = _settings.getThemeMode();
    final lastCourierIdFuture = _authStorage.getLastCourierId();

    final isAuth = await isAuthFuture;
    final courier = await courierFuture;
    final themeMode = await themeModeFuture;
    final lastCourierId = await lastCourierIdFuture;

    if (isAuth && courier != null) {
      final currentCourierId = courier['id']?.toString() ?? '';
      if (currentCourierId.isNotEmpty && lastCourierId != null && currentCourierId != lastCourierId) {
        await AppDatabase.clearAllDeliveryData();
        await _authStorage.setLastCourierId(currentCourierId);
      } else if (lastCourierId == null && currentCourierId.isNotEmpty) {
        await _authStorage.setLastCourierId(currentCourierId);
      }
    }

    state = state.copyWith(
      isAuthenticated: isAuth,
      courier: courier,
      themeMode: themeMode,
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

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setDarkMode(bool enabled) =>
      setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
}
