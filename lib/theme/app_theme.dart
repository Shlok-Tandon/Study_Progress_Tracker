import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_game_colors.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  static const double pill = 24;
  static const double card = 20;
  static const double chip = 16;
}

class AppTheme {
  static const Color _lightPrimary = Color(0xFF5B3DF5); // deep playful violet
  static const Color _lightBackground = Color(0xFFFAF9F6); // ceramic / milk
  static const Color _darkPrimary = Color(0xFFA78BFA); // electric violet
  static const Color _darkBackground = Color(0xFF14151B); // obsidian, not pure black

  static ThemeData lightTheme = _build(
    ColorScheme.fromSeed(seedColor: _lightPrimary, brightness: Brightness.light, primary: _lightPrimary),
    _lightBackground,
    AppGameColors.light,
  );

  static ThemeData darkTheme = _build(
    ColorScheme.fromSeed(seedColor: _darkPrimary, brightness: Brightness.dark, primary: _darkPrimary),
    _darkBackground,
    AppGameColors.dark,
  );

  /// A bold, rounded display style for things that should "pop" — stat
  /// numbers, podium ranks, streak counts. Inter stays for everything
  /// else so the app doesn't tip into cartoonish.
  static TextStyle display({required double size, Color? color, FontWeight weight = FontWeight.w700}) {
    return GoogleFonts.fredoka(fontSize: size, fontWeight: weight, color: color);
  }

  static ThemeData _build(ColorScheme scheme, Color background, AppGameColors game) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [game],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer,
        labelStyle: GoogleFonts.inter(color: scheme.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.pill), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
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