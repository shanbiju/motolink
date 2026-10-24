import 'package:flutter/material.dart';

/// MotoLink Official Color Palette & Dual Themes (Dark & Light)
/// Curated luxury automotive aesthetics:
/// - Dark: #111111 background, #2F2F2F surfaces, #FFCB74 gold
/// - Light: #F8F9FA pearl white, #FFFFFF surfaces, #D49B24 gold
class AppColors {
  AppColors._();

  // Dark Palette
  static const Color background = Color(0xFF111111);
  static const Color surface = Color(0xFF2F2F2F);
  static const Color surfaceLight = Color(0xFF3A3A3A);
  static const Color textLight = Color(0xFFF6F6F6);
  static const Color textMuted = Color(0xFFAAAAAA);
  static const Color accent = Color(0xFFFFCB74); // Warm Gold

  // Light Palette
  static const Color lightBackground = Color(0xFFF4F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFE9ECEF);
  static const Color lightText = Color(0xFF1A1D20);
  static const Color lightTextMuted = Color(0xFF6C757D);
  static const Color lightAccent = Color(0xFFD49B24); // Metallic Gold for Light Mode
  static const Color lightBorder = Color(0xFFDEE2E6);

  // Derived Accents & Glows
  static const Color accentGlow = Color(0x33FFCB74);
  static const Color accentSubtle = Color(0x1AFFCB74);
  static const Color border = Color(0x26FFFFFF);
  static const Color borderLight = Color(0x40FFFFFF);

  // Status Colors
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFCB74);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF80D8FF);

  // Dynamic Theme Helpers
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color bgOf(BuildContext context) => isDark(context) ? background : lightBackground;
  static Color surfaceOf(BuildContext context) => isDark(context) ? surface : lightSurface;
  static Color surfaceLightOf(BuildContext context) => isDark(context) ? surfaceLight : lightSurfaceLight;
  static Color textOf(BuildContext context) => isDark(context) ? textLight : lightText;
  static Color textMutedOf(BuildContext context) => isDark(context) ? textMuted : lightTextMuted;
  static Color accentOf(BuildContext context) => isDark(context) ? accent : lightAccent;
  static Color borderOf(BuildContext context) => isDark(context) ? border : lightBorder;

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      canvasColor: background,
      cardColor: surface,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        surfaceContainerHighest: surfaceLight,
        onPrimary: background,
        onSecondary: background,
        onSurface: textLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // Light Theme (Beautiful Pearl White & Gold)
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightAccent,
      canvasColor: lightBackground,
      cardColor: lightSurface,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        secondary: lightAccent,
        surface: lightSurface,
        surfaceContainerHighest: lightSurfaceLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightText,
        elevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightAccent,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightAccent,
        unselectedItemColor: lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
