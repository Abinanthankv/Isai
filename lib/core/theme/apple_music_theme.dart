import 'dart:ui';
import 'package:flutter/material.dart';

class AppleMusicTheme {
  // Brand Colors
  static const Color primaryPink = Color(0xFFFC3C71);
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color primaryBlue = Color(0xFF0A84FF);
  
  // Gradient Colors
  static const List<Color> pinkGradient = [Color(0xFFFC3C71), Color(0xFFFF2D55)];
  static const List<Color> purpleGradient = [Color(0xFF8B5CF6), Color(0xFF6366F1)];
  static const List<Color> orangeGradient = [Color(0xFFFF6B35), Color(0xFFFF9500)];
  static const List<Color> blueGradient = [Color(0xFF0A84FF), Color(0xFF5AC8FA)];
  
  // Light Theme Colors
  static const Color lightBackground = Color(0xFFFBFBFD);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF5F5F7);
  static const Color lightText = Color(0xFF1D1D1F);
  static const Color lightTextSecondary = Color(0xFF86868B);
  
  // Dark Theme Colors  
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkCard = Color(0xFF2C2C2E);
  static const Color darkText = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFF98989D);
  
  // Glass Colors
  static Color glassWhite = Colors.white.withOpacity(0.7);
  static Color glassBlack = Colors.black.withOpacity(0.5);
  
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryPink,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryPink,
        secondary: primaryPurple,
        tertiary: primaryOrange,
        surface: lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: lightText),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: lightText),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: lightText),
        displaySmall: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: lightText),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: lightText),
        titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: lightText),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: lightText),
        bodyLarge: TextStyle(fontSize: 17, color: lightText),
        bodyMedium: TextStyle(fontSize: 15, color: lightText),
        bodySmall: TextStyle(fontSize: 13, color: lightTextSecondary),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: lightTextSecondary),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface.withOpacity(0.85),
        indicatorColor: primaryPink.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryPink);
          }
          return const TextStyle(fontSize: 10, color: lightTextSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryPink, size: 24);
          }
          return const IconThemeData(color: lightTextSecondary, size: 24);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
  
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryPink,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryPink,
        secondary: primaryPurple,
        tertiary: primaryOrange,
        surface: darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: darkText),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: darkText),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkText),
        displaySmall: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkText),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkText),
        titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: darkText),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: darkText),
        bodyLarge: TextStyle(fontSize: 17, color: darkText),
        bodyMedium: TextStyle(fontSize: 15, color: darkText),
        bodySmall: TextStyle(fontSize: 13, color: darkTextSecondary),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: darkTextSecondary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface.withOpacity(0.85),
        indicatorColor: primaryPink.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryPink);
          }
          return const TextStyle(fontSize: 10, color: darkTextSecondary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryPink, size: 24);
          }
          return const IconThemeData(color: darkTextSecondary, size: 24);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
