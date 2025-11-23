import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';

class SettingsStorage {
  static const _localeKey = 'settings_locale';
  static const _themeKey = 'settings_theme';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString(_localeKey);
    final themeString = prefs.getString(_themeKey);
    final themeMode = _parseTheme(themeString);
    return AppSettings(localeCode: locale, themeMode: themeMode);
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.localeCode == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, settings.localeCode!);
    }
    await prefs.setString(_themeKey, settings.themeMode.name);
  }

  ThemeMode _parseTheme(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }
}
