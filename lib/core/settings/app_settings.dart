import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _autoAcceptKey = 'auto_accept_dispatch';
const _darkModeKey = 'dark_mode';

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
}
