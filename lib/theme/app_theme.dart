import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_game_colors.dart';

class AppSpacing {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32;
}

class AppRadius {
  static const double pill = 24, card = 20, chip = 16;
}

class AppTheme {
  // ---- Light (warm ceramic ramp) ----
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF5A38E0), onPrimary: Colors.white,
    primaryContainer: Color(0xFFE6E0FF), onPrimaryContainer: Color(0xFF1E1147),
    secondary: Color(0xFF0EA5C4), onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD4F1F6), onSecondaryContainer: Color(0xFF06363F),
    tertiary: Color(0xFF0EA5C4), onTertiary: Colors.white,
    error: Color(0xFFD8403A), onError: Colors.white,
    errorContainer: Color(0xFFFADAD8), onErrorContainer: Color(0xFF5C1714),
    surface: Color(0xFFF6F5F1), onSurface: Color(0xFF1C1B1A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAF9F5),
    surfaceContainer: Color(0xFFF1F0EA),
    surfaceContainerHigh: Color(0xFFEDECE5),
    surfaceContainerHighest: Color(0xFFE6E5DD),
    onSurfaceVariant: Color(0xFF6B6A66),
    outline: Color(0xFFC9C8C1), outlineVariant: Color(0xFFE2E1DA),
  );

  // ---- Dark (cool obsidian ramp, faint blue, NOT violet-tinted) ----
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFB3A1FF), onPrimary: Color(0xFF1B1240),
    primaryContainer: Color(0xFF2B2552), onPrimaryContainer: Color(0xFFE6E0FF),
    secondary: Color(0xFF48D6E8), onSecondary: Color(0xFF052E36),
    secondaryContainer: Color(0xFF0C3A42), onSecondaryContainer: Color(0xFFD4F1F6),
    tertiary: Color(0xFF48D6E8), onTertiary: Color(0xFF052E36),
    error: Color(0xFFFF8A82), onError: Color(0xFF3A0D0A),
    errorContainer: Color(0xFF4A1714), onErrorContainer: Color(0xFFFADAD8),
    surface: Color(0xFF0E0F13), onSurface: Color(0xFFE7E8EE),
    surfaceContainerLowest: Color(0xFF0B0C10),
    surfaceContainerLow: Color(0xFF15161C),
    surfaceContainer: Color(0xFF1B1C24),
    surfaceContainerHigh: Color(0xFF22232E),
    surfaceContainerHighest: Color(0xFF2A2B38),
    onSurfaceVariant: Color(0xFFA0A2AE),
    outline: Color(0xFF3A3B47), outlineVariant: Color(0xFF2A2B36),
  );

  static final ThemeData lightTheme = _build(_lightScheme, AppGameColors.light);
  static final ThemeData darkTheme = _build(_darkScheme, AppGameColors.dark);

  /// Bold rounded display style for numbers/ranks that should pop.
  static TextStyle display({required double size, Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.fredoka(fontSize: size, fontWeight: weight, color: color);

  static ThemeData _build(ColorScheme scheme, AppGameColors game) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      // Transparent so the AppBackground gradient shows through every screen.
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      extensions: [game],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
        titleTextStyle: GoogleFonts.inter(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardTheme(
        elevation: 0, margin: EdgeInsets.zero, color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.secondaryContainer,
        labelStyle: GoogleFonts.inter(color: scheme.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.pill), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface, indicatorColor: scheme.primaryContainer, elevation: 0, height: 64,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}