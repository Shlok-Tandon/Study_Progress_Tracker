import 'package:flutter/material.dart';

/// Gamification-specific semantic colors that live alongside ColorScheme.
/// ColorScheme covers structural roles (surface, primary, error); this
/// covers the playful roles the UI actually needs (streak fire, success
/// emerald, podium metals) that don't map onto Material's roles.
class AppGameColors extends ThemeExtension<AppGameColors> {
  final Color success;
  final Color successContainer;
  final Color streak;
  final Color streakContainer;
  final Color accent;
  final Color accentContainer;
  final Color gold;
  final Color silver;
  final Color bronze;

  const AppGameColors({
    required this.success,
    required this.successContainer,
    required this.streak,
    required this.streakContainer,
    required this.accent,
    required this.accentContainer,
    required this.gold,
    required this.silver,
    required this.bronze,
  });

  static const light = AppGameColors(
    success: Color(0xFF0E9F6E),
    successContainer: Color(0xFFD7F5E9),
    streak: Color(0xFFE8590C),
    streakContainer: Color(0xFFFFE8D9),
    accent: Color(0xFF6D4AFF),
    accentContainer: Color(0xFFE7E0FF),
    gold: Color(0xFFE8A613),
    silver: Color(0xFF9AA3B2),
    bronze: Color(0xFFC97A4A),
  );

  static const dark = AppGameColors(
    success: Color(0xFF34E0A1),
    successContainer: Color(0xFF103B2D),
    streak: Color(0xFFFF8A3D),
    streakContainer: Color(0xFF3D2412),
    accent: Color(0xFFA78BFA),
    accentContainer: Color(0xFF2C2350),
    gold: Color(0xFFFFC94A),
    silver: Color(0xFFC7CDD9),
    bronze: Color(0xFFE0A36F),
  );

  @override
  AppGameColors copyWith({
    Color? success, Color? successContainer, Color? streak, Color? streakContainer,
    Color? accent, Color? accentContainer, Color? gold, Color? silver, Color? bronze,
  }) {
    return AppGameColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      streak: streak ?? this.streak,
      streakContainer: streakContainer ?? this.streakContainer,
      accent: accent ?? this.accent,
      accentContainer: accentContainer ?? this.accentContainer,
      gold: gold ?? this.gold,
      silver: silver ?? this.silver,
      bronze: bronze ?? this.bronze,
    );
  }

  @override
  AppGameColors lerp(ThemeExtension<AppGameColors>? other, double t) {
    if (other is! AppGameColors) return this;
    return AppGameColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      streakContainer: Color.lerp(streakContainer, other.streakContainer, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      silver: Color.lerp(silver, other.silver, t)!,
      bronze: Color.lerp(bronze, other.bronze, t)!,
    );
  }
}