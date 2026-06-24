import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared spacing scale, so paddings stay consistent without every
/// widget hardcoding its own magic numbers.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppTheme {
  // A restrained indigo/slate palette — one confident accent color and
  // neutral surfaces, instead of the previous pastel mint/lavender mix.
  static const Color _lightPrimary = Color(0xFF4F46E5);
  static const Color _lightBackground = Color(0xFFF7F7FB);
  static const Color _darkPrimary = Color(0xFF818CF8);
  static const Color _darkBackground = Color(0xFF0E0F13);

  static ThemeData lightTheme = _build(
    ColorScheme.fromSeed(seedColor: _lightPrimary, brightness: Brightness.light, primary: _lightPrimary),
    _lightBackground,
  );

  static ThemeData darkTheme = _build(
    ColorScheme.fromSeed(seedColor: _darkPrimary, brightness: Brightness.dark, primary: _darkPrimary),
    _darkBackground,
  );

  static ThemeData _build(ColorScheme scheme, Color background) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer,
        labelStyle: GoogleFonts.inter(color: scheme.onSecondaryContainer, fontSize: 12),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 64,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}