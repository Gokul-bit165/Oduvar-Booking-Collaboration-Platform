import 'package:flutter/material.dart';

class AppTheme {
  // Brand Palette: Culturally Respectful & Devotional
  static const Color primaryMaroon = Color(0xFF8D1B1B);
  static const Color primaryMaroonLight = Color(0xFFA83232);
  static const Color primaryMaroonDark = Color(0xFF5A0E0E);

  static const Color sacredSaffron = Color(0xFFD97706);
  static const Color sacredGold = Color(0xFFB45309);
  static const Color divineAmber = Color(0xFFF59E0B);

  static const Color sandalWood = Color(0xFF78350F);
  static const Color sacredCream = Color(0xFFFAF7F2);
  static const Color sacredSurface = Color(0xFFFFFFFF);
  static const Color sacredBorder = Color(0xFFE5DDD0);

  // Dark palette
  static const Color darkBackground = Color(0xFF141210);
  static const Color darkSurface = Color(0xFF1E1A16);
  static const Color darkCard = Color(0xFF26201B);
  static const Color darkBorder = Color(0xFF3D342C);

  // Status Colors
  static const Color successGreen = Color(0xFF15803D);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFEA580C);
  static const Color infoBlue = Color(0xFF2563EB);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: primaryMaroon,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFDE8E8),
      onPrimaryContainer: primaryMaroonDark,
      secondary: sacredSaffron,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFEF3C7),
      onSecondaryContainer: sacredGold,
      surface: sacredSurface,
      onSurface: const Color(0xFF1F1B18),
      error: errorRed,
      onError: Colors.white,
      outline: sacredBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: sacredCream,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: sacredSurface,
        foregroundColor: primaryMaroon,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: primaryMaroonDark,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: sacredSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: sacredBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryMaroon,
          foregroundColor: Colors.white,
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryMaroon,
          side: const BorderSide(color: primaryMaroon, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: sacredBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: sacredBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: sacredSaffron, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF6B5E53),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFA89F91),
          fontSize: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: divineAmber,
      onPrimary: Colors.black,
      primaryContainer: primaryMaroonDark,
      onPrimaryContainer: Colors.white,
      secondary: sacredSaffron,
      onSecondary: Colors.black,
      surface: darkSurface,
      onSurface: const Color(0xFFE8E0D5),
      error: const Color(0xFFF87171),
      onError: Colors.black,
      outline: darkBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: divineAmber,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divineAmber, width: 2),
        ),
      ),
    );
  }
}
