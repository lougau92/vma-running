import 'package:flutter/material.dart';

class ThemeOption {
  const ThemeOption({
    required this.id,
    required this.labelKey,
    required this.light,
    required this.dark,
  });

  final String id;
  final String labelKey;
  final ThemeData light;
  final ThemeData dark;
}

class EnjambeeTheme {
  static const Color orange = Color(0xFFF05F0D);
  static const Color white = Color(0xFFFFFFFF);
  static const Color navy = Color(0xFF1A265A);

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: orange,
      primary: orange,
      secondary: navy,
      background: const Color(0xFF0F142F),
      brightness: Brightness.dark,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.06),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        bodyMedium: TextStyle(color: white),
        bodyLarge: TextStyle(color: white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: orange,
      primary: orange,
      secondary: navy,
      background: white,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: white,
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: navy,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: navy.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: navy,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        bodyMedium: TextStyle(color: navy),
        bodyLarge: TextStyle(color: navy),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: navy.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class SummitTheme {
  static const Color blue = Color(0xFF1E6ED7);
  static const Color sky = Color(0xFF7CC8FF);
  static const Color midnight = Color(0xFF0C1D37);
  static const Color cloud = Color(0xFFF3F7FD);

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      secondary: sky,
      background: midnight,
      brightness: Brightness.dark,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      appBarBackgroundColor: const Color(0xFF10294A),
      appBarForegroundColor: Colors.white,
      buttonBackgroundColor: blue,
      buttonForegroundColor: Colors.white,
      cardColor: Colors.white.withOpacity(0.06),
      textColor: Colors.white,
      inputFillColor: Colors.white.withOpacity(0.05),
    );
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      secondary: sky,
      background: cloud,
      brightness: Brightness.light,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: cloud,
      appBarBackgroundColor: cloud,
      appBarForegroundColor: colorScheme.primary,
      buttonBackgroundColor: blue,
      buttonForegroundColor: Colors.white,
      cardColor: const Color(0xFFE4EEFB),
      textColor: const Color(0xFF0C1D37),
      inputFillColor: const Color(0xFFDCE9FB),
    );
  }
}

class LagoonTheme {
  static const Color teal = Color(0xFF1A9C85);
  static const Color coral = Color(0xFFFF784F);
  static const Color deepSea = Color(0xFF0A1E24);
  static const Color mist = Color(0xFFF1F6F4);
  static const Color deepTeal = Color(0xFF0E3534);

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: teal,
      primary: teal,
      secondary: coral,
      background: deepSea,
      brightness: Brightness.dark,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      appBarBackgroundColor: deepTeal,
      appBarForegroundColor: Colors.white,
      buttonBackgroundColor: coral,
      buttonForegroundColor: Colors.white,
      cardColor: Colors.white.withOpacity(0.08),
      textColor: Colors.white,
      inputFillColor: Colors.white.withOpacity(0.06),
    );
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: teal,
      primary: teal,
      secondary: coral,
      background: mist,
      brightness: Brightness.light,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: mist,
      appBarBackgroundColor: mist,
      appBarForegroundColor: deepTeal,
      buttonBackgroundColor: teal,
      buttonForegroundColor: Colors.white,
      cardColor: const Color(0xFFD9F0EA),
      textColor: const Color(0xFF0E2B2A),
      inputFillColor: const Color(0xFFDCEFEA),
    );
  }
}

class AppThemes {
  static const defaultId = 'enjambee';

  static final Map<String, ThemeOption> _themes = {
    'enjambee': ThemeOption(
      id: 'enjambee',
      labelKey: 'enjambeeTheme',
      light: EnjambeeTheme.lightTheme(),
      dark: EnjambeeTheme.darkTheme(),
    ),
    'summit': ThemeOption(
      id: 'summit',
      labelKey: 'summitTheme',
      light: SummitTheme.lightTheme(),
      dark: SummitTheme.darkTheme(),
    ),
    'lagoon': ThemeOption(
      id: 'lagoon',
      labelKey: 'lagoonTheme',
      light: LagoonTheme.lightTheme(),
      dark: LagoonTheme.darkTheme(),
    ),
  };

  static ThemeOption resolve(String? id) => _themes[id] ?? _themes[defaultId]!;

  static List<ThemeOption> get all => _themes.values.toList(growable: false);

  static bool isValid(String? id) => id != null && _themes.containsKey(id);
}

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color scaffoldBackgroundColor,
  required Color appBarBackgroundColor,
  required Color appBarForegroundColor,
  required Color buttonBackgroundColor,
  required Color buttonForegroundColor,
  required Color cardColor,
  required Color textColor,
  required Color inputFillColor,
}) {
  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBackgroundColor,
      foregroundColor: appBarForegroundColor,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonBackgroundColor,
        foregroundColor: buttonForegroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      bodyMedium: TextStyle(color: textColor),
      bodyLarge: TextStyle(color: textColor),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
