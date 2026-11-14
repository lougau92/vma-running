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

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: white,
      appBarBackgroundColor: white,
      appBarForegroundColor: navy,
      buttonBackgroundColor: orange,
      buttonForegroundColor: white,
      cardColor: const Color(0xFFFFF5EE),
      textColor: navy,
      inputFillColor: white,
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
      cardColor: const Color(0xFFF0F6FF),
      textColor: const Color(0xFF0C1D37),
      inputFillColor: Colors.white,
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
      cardColor: const Color(0xFFECF8F3),
      textColor: const Color(0xFF0E2B2A),
      inputFillColor: Colors.white,
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
  final isLight = colorScheme.brightness == Brightness.light;
  if (isLight) {
    // Keep surfaces opaque and pair every default text style with the ink color.
    // Translucent Material cards can pick up a muddy gray elevation shadow.
    colorScheme = colorScheme.copyWith(
      surface: scaffoldBackgroundColor,
      surfaceContainerLowest: inputFillColor,
      surfaceContainerLow: cardColor,
      surfaceContainer: cardColor,
      surfaceContainerHigh: cardColor,
      surfaceContainerHighest: cardColor,
      onSurface: textColor,
      onSurfaceVariant: Color.alphaBlend(
        textColor.withValues(alpha: 0.78),
        scaffoldBackgroundColor,
      ),
      outline: Color.alphaBlend(
        textColor.withValues(alpha: 0.35),
        scaffoldBackgroundColor,
      ),
      outlineVariant: Color.alphaBlend(
        colorScheme.primary.withValues(alpha: 0.18),
        scaffoldBackgroundColor,
      ),
    );
  }
  final textTheme = ThemeData(
    colorScheme: colorScheme,
  ).textTheme.apply(bodyColor: textColor, displayColor: textColor);
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
      elevation: isLight ? 0 : null,
      surfaceTintColor: isLight ? Colors.transparent : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: textTheme.copyWith(
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFillColor,
      labelStyle: isLight
          ? TextStyle(color: colorScheme.onSurfaceVariant)
          : null,
      helperStyle: isLight
          ? TextStyle(color: colorScheme.onSurfaceVariant)
          : null,
      enabledBorder: isLight
          ? OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            )
          : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
