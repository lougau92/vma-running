import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.localeCode,
    this.themeMode = ThemeMode.dark,
    this.timesMinSeconds,
    this.timesMaxSeconds,
    this.timesMinDistance,
    this.timesMaxDistance,
  });

  final String? localeCode;
  final ThemeMode themeMode;
  final double? timesMinSeconds;
  final double? timesMaxSeconds;
  final double? timesMinDistance;
  final double? timesMaxDistance;

  AppSettings copyWith({
    String? localeCode,
    ThemeMode? themeMode,
    double? timesMinSeconds,
    double? timesMaxSeconds,
    double? timesMinDistance,
    double? timesMaxDistance,
  }) {
    return AppSettings(
      localeCode: localeCode ?? this.localeCode,
      themeMode: themeMode ?? this.themeMode,
      timesMinSeconds: timesMinSeconds ?? this.timesMinSeconds,
      timesMaxSeconds: timesMaxSeconds ?? this.timesMaxSeconds,
      timesMinDistance: timesMinDistance ?? this.timesMinDistance,
      timesMaxDistance: timesMaxDistance ?? this.timesMaxDistance,
    );
  }
}
