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
    streak: Color(0xFFEA580C),
    streakContainer: Color(0xFFFFE7D6),
    accent: Color(0xFF0EA5C4),
    accentContainer: Color(0xFFD4F1F6),
    gold: Color(0xFFE0A312),
    silver: Color(0xFF98A0AE),
    bronze: Color(0xFFC2773F),
  );

  static const dark = AppGameColors(
    success: Color(0xFF3DDC97),
    successContainer: Color(0xFF0E3528),
    streak: Color(0xFFFF7A33),
    streakContainer: Color(0xFF36210F),
    accent: Color(0xFF48D6E8),
    accentContainer: Color(0xFF0C3A42),
    gold: Color(0xFFFFCB47),
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