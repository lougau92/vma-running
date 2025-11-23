import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.localeCode,
    this.themeMode = ThemeMode.dark,
  });

  final String? localeCode;
  final ThemeMode themeMode;

  AppSettings copyWith({
    String? localeCode,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      localeCode: localeCode ?? this.localeCode,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
