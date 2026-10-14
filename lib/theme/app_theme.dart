import 'package:flutter/material.dart';

/// Palette pulled from Kenya itself rather than default Material blue/purple:
/// savanna green, sun gold ("jua" = sun/to know in Swahili), and the red
/// earth/flag red, used sparingly for streaks and alerts.
class AppColors {
  static const savannaGreen = Color(0xFF1B4332);
  static const savannaGreenLight = Color(0xFF2D6A4F);
  static const sunGold = Color(0xFFF0A500);
  static const earthRed = Color(0xFFC1440E);
  static const ivory = Color(0xFFFBF7F0);
  static const juaSkyBlue = Color(0xFF5291BE);
  static const inkBrown = Color(0xFF2A2118);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.savannaGreen,
      brightness: Brightness.light,
      primary: AppColors.savannaGreen,
      secondary: AppColors.sunGold,
      tertiary: AppColors.earthRed,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent, // JuaScene paints the world behind every screen
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: AppColors.inkBrown),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkBrown),
        bodyLarge: TextStyle(color: AppColors.inkBrown, height: 1.4),
        bodyMedium: TextStyle(color: AppColors.inkBrown, height: 1.4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.savannaGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.savannaGreen.withValues(alpha: 0.2)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xE62B5F8A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.savannaGreen.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}
