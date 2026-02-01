import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // -- Colors --
  static const Color _lightPrimary = Color(0xFF6200EE);
  static const Color _lightBackground = Color(0xFFF8F9FA); // Minimal Grey-White
  
  static const Color _darkPrimary = Color(0xFFBB86FC);
  static const Color _darkBackground = Color(0xFF121212); // Deep Black
  
  // -- Gradients --
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6200EE), Color(0xFF3700B3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFFBB86FC), Color(0xFF3700B3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [const Color(0xFF121212), const Color(0xFF2C2C2C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // [NEW] HomeScreen Gradients
  static const LinearGradient starryNightGradient = LinearGradient(
    colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient pastelSunsetGradient = LinearGradient(
    colors: [Color(0xFFFFF8E1), Color(0xFFFFE0B2), Color(0xFFF3E5F5)], 
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: _lightBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _lightPrimary,
      surface: Colors.white,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.notoSansTcTextTheme(ThemeData.light().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black,
      centerTitle: true,
      elevation: 0,
    ),
    // cardTheme removed to fix type error
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightPrimary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: _darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _darkPrimary,
      surface: const Color(0xFF1E1E1E), // Slightly lighter card bg
      brightness: Brightness.dark,
    ),
    textTheme: GoogleFonts.notoSansTcTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    // cardTheme removed to fix type error
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _darkPrimary,
        foregroundColor: Colors.black,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
  );
}
