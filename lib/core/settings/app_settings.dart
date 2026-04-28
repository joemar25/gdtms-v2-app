// DOCS: docs/development-standards.md
// DOCS: docs/core/settings.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/constants.dart';

const _autoAcceptKey = 'auto_accept_dispatch';
const _darkModeKey = 'dark_mode';
const _compactModeKey = 'compact_mode';
const _followSystemThemeKey = 'follow_system_theme';
const _themeModeKey = 'theme_mode';
const _syncRetentionKey = 'sync_retention_days';

final appSettingsProvider = Provider<AppSettings>((ref) => AppSettings());

class AppSettings {
  Future<bool> getAutoAcceptDispatch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoAcceptKey) ?? false;
  }

  Future<void> setAutoAcceptDispatch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAcceptKey, value);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<bool> getCompactMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_compactModeKey) ?? false;
  }

  Future<void> setCompactMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_compactModeKey, value);
  }

  Future<bool> getFollowSystemTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_followSystemThemeKey) ?? false;
  }

  Future<void> setFollowSystemTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_followSystemThemeKey, value);
  }

  /// Returns the stored ThemeMode (light/system/dark).
  /// Falls back to the legacy dark-mode bool for users upgrading.
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_themeModeKey);
    if (stored != null && stored >= 0 && stored < ThemeMode.values.length) {
      return ThemeMode.values[stored];
    }
    // Backward compat: read old bool key
    final dark = prefs.getBool(_darkModeKey) ?? false;
    return dark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
    // Keep old key in sync so old code paths still work
    await prefs.setBool(_darkModeKey, mode == ThemeMode.dark);
  }

  /// Returns the number of days to retain synced delivery-update queue entries.
  /// Defaults to [kDefaultSyncRetentionDays] (1 day) if unset.
  Future<int> getSyncRetentionDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_syncRetentionKey) ?? kDefaultSyncRetentionDays;
  }

  Future<void> setSyncRetentionDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncRetentionKey, days);
  }
}
