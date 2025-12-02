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
  });

  final String? localeCode;
  final ThemeMode themeMode;
  final String themeId;
  final double? timesMinSeconds;
  final double? timesMaxSeconds;
  final double? timesMinDistance;
  final double? timesMaxDistance;

  AppSettings copyWith({
    String? localeCode,
    ThemeMode? themeMode,
    String? themeId,
    double? timesMinSeconds,
    double? timesMaxSeconds,
    double? timesMinDistance,
    double? timesMaxDistance,
  }) {
    return AppSettings(
      localeCode: localeCode ?? this.localeCode,
      themeMode: themeMode ?? this.themeMode,
      themeId: themeId ?? this.themeId,
      timesMinSeconds: timesMinSeconds ?? this.timesMinSeconds,
      timesMaxSeconds: timesMaxSeconds ?? this.timesMaxSeconds,
      timesMinDistance: timesMinDistance ?? this.timesMinDistance,
      timesMaxDistance: timesMaxDistance ?? this.timesMaxDistance,
    );
  }
}
