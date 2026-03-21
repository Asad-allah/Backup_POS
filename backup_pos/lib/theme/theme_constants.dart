import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors - Silver & Dark Monochrome
  static const Color primary = Color(
    0xFFECECEC,
  ); // Shine Silver (High Brightness)
  static const Color backgroundDark = Color(0xFF121212); // Deep Black/Dark Grey
  static const Color surfaceDark = Color(0xFF2C2C2C); // Rich Charcoal
  static const Color surfaceDarker = Color(0xFF1E1E1E); // Darker Grey
  static const Color textSecondary = Color(0xFFB0B0B0); // Metallic Grey
  static const Color error = Color(0xFFCF6679);

  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Text Styles (Legacy/Fallback)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: white,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: white,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: white,
  );

  // Theme Data
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: primary, // Silver secondary too
      surface: surfaceDark,
      error: error,
      onPrimary: backgroundDark, // Black text on Silver buttons
      onSurface: white,
      outline: textSecondary,
    ),
    fontFamily: GoogleFonts.outfit().fontFamily,
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: GoogleFonts.inter(color: Colors.white, fontSize: 16),
      bodyMedium: GoogleFonts.inter(color: textSecondary, fontSize: 14),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: white.withValues(alpha: 0.1),
        ), // Subtle silver border
      ),
    ),

    // App Bar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: displayMedium,
      iconTheme: IconThemeData(color: white),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5), // Silver glow
      ),
      hintStyle: const TextStyle(color: textSecondary),
      prefixIconColor: textSecondary,
    ),

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary, // Silver
        foregroundColor: backgroundDark, // Black Text
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shadowColor: primary.withValues(alpha: 0.3),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: white,
        side: BorderSide(color: white.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
