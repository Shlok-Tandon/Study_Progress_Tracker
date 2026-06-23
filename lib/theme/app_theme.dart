import 'package:flutter/material.dart';

class AppTheme {
  static const Color mint = Color(0xFFA8E6CF);
  static const Color lavender = Color(0xFFDCC6E0);
  static const Color softBlue = Color(0xFFBDE0FE);
  static const Color peach = Color(0xFFFFD6A5);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: mint,
      brightness: Brightness.light,
      primary: const Color(0xFF66BB9A),
      secondary: const Color(0xFF90CAF9),
    ),
    scaffoldBackgroundColor: const Color(0xFFF6FBFA),
    cardTheme: const CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: softBlue,
      brightness: Brightness.dark,
      primary: const Color(0xFF80CBC4),
      secondary: const Color(0xFFB39DDB),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F1720),
    cardTheme: const CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
  );
}