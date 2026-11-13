import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryPink = Color(0xFFD81B60);
  static const Color softPinkSurface = Color(0xFFFFF5F8);
  static const Color cardPink = Color(0xFFFFFFFF);
  static const Color accentPinkContainer = Color(0xFFFCE4EC);
  static const Color borderPink = Color(0xFFF8BBD0);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryPink,
      brightness: Brightness.light,
      surface: softPinkSurface,
      primaryContainer: accentPinkContainer,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: softPinkSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFCE4EC),
        foregroundColor: Color(0xFF880E4F),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardPink,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderPink, width: 1),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderPink),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderPink),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryPink, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: accentPinkContainer,
        selectedColor: primaryPink,
        labelStyle: const TextStyle(fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
