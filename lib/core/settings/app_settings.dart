// DOCS: docs/development-standards.md
// DOCS: docs/core/settings.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/constants.dart';

final appSettingsProvider = Provider<AppSettings>((ref) => AppSettings());

class AppSettings {
  Future<bool> getAutoAcceptDispatch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.autoAcceptDispatch) ?? false;
  }

  Future<void> setAutoAcceptDispatch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.autoAcceptDispatch, value);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.darkMode) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.darkMode, value);
  }

  Future<bool> getCompactMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.compactMode) ?? false;
  }

  Future<void> setCompactMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.compactMode, value);
  }

  /// Returns true if the "New Feel" dashboard layout is enabled.
  Future<bool> getDashboardFeel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.dashboardFeel) ?? false;
  }

  /// Persists the user preference for the dashboard layout style.
  Future<void> setDashboardFeel(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.dashboardFeel, value);
  }

  Future<bool> getFollowSystemTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppKeys.followSystemTheme) ?? false;
  }

  Future<void> setFollowSystemTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppKeys.followSystemTheme, value);
  }

  /// Returns the stored ThemeMode (light/system/dark).
  /// Falls back to the legacy dark-mode bool for users upgrading.
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(AppKeys.themeMode);
    if (stored != null && stored >= 0 && stored < ThemeMode.values.length) {
      return ThemeMode.values[stored];
    }
    // Backward compat: read old bool key
    final dark = prefs.getBool(AppKeys.darkMode) ?? false;
    return dark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.themeMode, mode.index);
    // Keep old key in sync so old code paths still work
    await prefs.setBool(AppKeys.darkMode, mode == ThemeMode.dark);
  }

  /// Returns the number of days to retain synced delivery-update queue entries.
  /// Defaults to [kDefaultSyncRetentionDays] (1 day) if unset.
  Future<int> getSyncRetentionDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppKeys.syncRetentionDays) ?? kDefaultSyncRetentionDays;
  }

  Future<void> setSyncRetentionDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppKeys.syncRetentionDays, days);
  }
}
