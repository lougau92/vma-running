import 'package:flutter/material.dart';
import 'theme.dart';

class AppSettings {
  const AppSettings({
    this.localeCode,
    this.themeMode = ThemeMode.dark,
    this.themeId = AppThemes.defaultId,
    this.timesMinSeconds,
    this.timesMaxSeconds,
    this.timesMinDistance,
    this.timesMaxDistance,
    this.intervalsApiKey,
  });

  final String? localeCode;
  final ThemeMode themeMode;
  final String themeId;
  final double? timesMinSeconds;
  final double? timesMaxSeconds;
  final double? timesMinDistance;
  final double? timesMaxDistance;
  final String? intervalsApiKey;

  AppSettings copyWith({
    Object? localeCode = _unset,
    ThemeMode? themeMode,
    String? themeId,
    Object? timesMinSeconds = _unset,
    Object? timesMaxSeconds = _unset,
    Object? timesMinDistance = _unset,
    Object? timesMaxDistance = _unset,
    Object? intervalsApiKey = _unset,
  }) {
    return AppSettings(
      localeCode: _resolve<String?>(localeCode, this.localeCode),
      themeMode: themeMode ?? this.themeMode,
      themeId: themeId ?? this.themeId,
      timesMinSeconds: _resolve<double?>(timesMinSeconds, this.timesMinSeconds),
      timesMaxSeconds: _resolve<double?>(timesMaxSeconds, this.timesMaxSeconds),
      timesMinDistance: _resolve<double?>(
        timesMinDistance,
        this.timesMinDistance,
      ),
      timesMaxDistance: _resolve<double?>(
        timesMaxDistance,
        this.timesMaxDistance,
      ),
      intervalsApiKey: _resolve<String?>(intervalsApiKey, this.intervalsApiKey),
    );
  }

  static const _unset = Object();

  T _resolve<T>(Object? candidate, T current) {
    if (identical(candidate, _unset)) return current;
    return candidate as T;
  }
}
