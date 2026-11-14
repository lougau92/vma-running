import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'theme.dart';
import 'presets.dart';

class SettingsStorage {
  static const _localeKey = 'settings_locale';
  static const _themeKey = 'settings_theme';
  static const _themeIdKey = 'settings_theme_id';
  static const _timesMinSecondsKey = 'times_min_seconds';
  static const _timesMaxSecondsKey = 'times_max_seconds';
  static const _timesMinDistanceKey = 'times_min_distance';
  static const _timesMaxDistanceKey = 'times_max_distance';
  static const _timesCustomDistancesKey = 'times_custom_distances';
  static const _timesCustomSecondsKey = 'times_custom_seconds';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLocale = prefs.getString(_localeKey);
    final locale = storedLocale == null
        ? 'fr'
        : storedLocale == 'system'
        ? null
        : storedLocale;
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
      timesCustomDistances: _readValues(prefs, _timesCustomDistancesKey),
      timesCustomSeconds: _readValues(prefs, _timesCustomSecondsKey),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, settings.localeCode ?? 'system');
    await prefs.setString(_themeKey, settings.themeMode.name);
    await prefs.setString(_themeIdKey, settings.themeId);
    await _writeNullableDouble(
      prefs,
      _timesMinSecondsKey,
      settings.timesMinSeconds,
    );
    await _writeNullableDouble(
      prefs,
      _timesMaxSecondsKey,
      settings.timesMaxSeconds,
    );
    await _writeNullableDouble(
      prefs,
      _timesMinDistanceKey,
      settings.timesMinDistance,
    );
    await _writeNullableDouble(
      prefs,
      _timesMaxDistanceKey,
      settings.timesMaxDistance,
    );
    await prefs.setStringList(
      _timesCustomDistancesKey,
      mergePresetValues(
        const [],
        settings.timesCustomDistances,
      ).map((value) => value.toString()).toList(),
    );
    await prefs.setStringList(
      _timesCustomSecondsKey,
      mergePresetValues(
        const [],
        settings.timesCustomSeconds,
      ).map((value) => value.toString()).toList(),
    );
  }

  List<double> _readValues(SharedPreferences prefs, String key) =>
      mergePresetValues(
        const [],
        (prefs.getStringList(key) ?? const [])
            .map(double.tryParse)
            .whereType<double>(),
      );

  ThemeMode _parseTheme(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.light;
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
}
