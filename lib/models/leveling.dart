/// Pure XP -> level math. No Flutter, no Firestore, so it is trivially
/// unit-testable and the same numbers drive every screen.
class LevelInfo {
  final int level;
  final int xpIntoLevel;   // XP accumulated within the current level
  final int xpForThisLevel; // XP span of the current level
  final int totalXp;

  const LevelInfo({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForThisLevel,
    required this.totalXp,
  });

  /// 0..1 progress toward the next level.
  double get progress => xpForThisLevel == 0 ? 1 : (xpIntoLevel / xpForThisLevel).clamp(0.0, 1.0);

  /// XP still needed to reach the next level.
  int get xpToNext => (xpForThisLevel - xpIntoLevel).clamp(0, xpForThisLevel);
}

class Leveling {
  Leveling._();

  /// XP awarded for completing one task.
  static const int xpPerTask = 10;

  /// Default daily XP goal (3 tasks).
  static const int defaultDailyGoal = 30;

  /// Cumulative XP required to *reach* [level] (level 1 is 0 XP).
  /// reach(1)=0, reach(2)=50, reach(3)=150, reach(4)=300, reach(5)=500 ...
  /// Each level costs 50 XP more than the one before, a gentle ramp.
  static int totalXpToReach(int level) => 25 * (level - 1) * level;

  /// Resolves a total-XP figure into the current level and progress.
  static LevelInfo fromXp(int totalXp) {
    final xp = totalXp < 0 ? 0 : totalXp;
    var level = 1;
    while (xp >= totalXpToReach(level + 1)) {
      level++;
    }
    final base = totalXpToReach(level);
    final next = totalXpToReach(level + 1);
    return LevelInfo(
      level: level,
      xpIntoLevel: xp - base,
      xpForThisLevel: next - base,
      totalXp: xp,
    );
  }

  /// A short earned title per level band. Distinct from the streak-based
  /// rank in Settings: that one reflects your current streak, this one
  /// reflects lifetime XP and never goes down.
  static String titleFor(int level) {
    if (level >= 20) return 'Mastermind';
    if (level >= 15) return 'Scholar';
    if (level >= 10) return 'Achiever';
    if (level >= 5) return 'Apprentice';
    return 'Beginner';
  }
}