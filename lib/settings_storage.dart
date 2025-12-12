import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'theme.dart';

class SettingsStorage {
  static const _localeKey = 'settings_locale';
  static const _themeKey = 'settings_theme';
  static const _themeIdKey = 'settings_theme_id';
  static const _timesMinSecondsKey = 'times_min_seconds';
  static const _timesMaxSecondsKey = 'times_max_seconds';
  static const _timesMinDistanceKey = 'times_min_distance';
  static const _timesMaxDistanceKey = 'times_max_distance';
  static const _intervalsApiKeyKey = 'intervals_api_key';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString(_localeKey);
    final themeString = prefs.getString(_themeKey);
    final themeMode = _parseTheme(themeString);
    final themeId = _parseThemeId(prefs.getString(_themeIdKey));
    return AppSettings(
      localeCode: locale,
      themeMode: themeMode,
      themeId: themeId,
      timesMinSeconds: prefs.getDouble(_timesMinSecondsKey),
      timesMaxSeconds: prefs.getDouble(_timesMaxSecondsKey),
      timesMinDistance: prefs.getDouble(_timesMinDistanceKey),
      timesMaxDistance: prefs.getDouble(_timesMaxDistanceKey),
      intervalsApiKey: prefs.getString(_intervalsApiKeyKey),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.localeCode == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, settings.localeCode!);
    }
    await prefs.setString(_themeKey, settings.themeMode.name);
    await prefs.setString(_themeIdKey, settings.themeId);
    _writeNullableDouble(prefs, _timesMinSecondsKey, settings.timesMinSeconds);
    _writeNullableDouble(prefs, _timesMaxSecondsKey, settings.timesMaxSeconds);
    _writeNullableDouble(
      prefs,
      _timesMinDistanceKey,
      settings.timesMinDistance,
    );
    _writeNullableDouble(
      prefs,
      _timesMaxDistanceKey,
      settings.timesMaxDistance,
    );
    _writeNullableString(
      prefs,
      _intervalsApiKeyKey,
      settings.intervalsApiKey?.trim(),
    );
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

  String _parseThemeId(String? raw) {
    if (AppThemes.isValid(raw)) {
      return raw!;
    }
    return AppThemes.defaultId;
  }

  Future<void> _writeNullableDouble(
    SharedPreferences prefs,
    String key,
    double? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setDouble(key, value);
    }
  }

  Future<void> _writeNullableString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }
}
