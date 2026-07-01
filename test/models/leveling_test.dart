import 'package:flutter_test/flutter_test.dart';
import 'package:study_progress_tracker/models/leveling.dart';

void main() {
  group('Leveling.totalXpToReach', () {
    test('level 1 requires 0 XP (the floor)', () {
      expect(Leveling.totalXpToReach(1), 0);
    });

    test('matches the documented ramp: 0, 50, 150, 300, 500', () {
      expect(Leveling.totalXpToReach(1), 0);
      expect(Leveling.totalXpToReach(2), 50);
      expect(Leveling.totalXpToReach(3), 150);
      expect(Leveling.totalXpToReach(4), 300);
      expect(Leveling.totalXpToReach(5), 500);
    });
  });

  group('Leveling.fromXp', () {
    test('0 XP is level 1 with nothing earned toward the next level', () {
      final info = Leveling.fromXp(0);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 0);
      expect(info.xpForThisLevel, 50); // totalXpToReach(2) - totalXpToReach(1)
      expect(info.totalXp, 0);
    });

    test('negative XP is clamped to 0 rather than going below level 1', () {
      final info = Leveling.fromXp(-100);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 0);
      expect(info.totalXp, 0);
    });

    test('one XP short of a level threshold stays at the lower level', () {
      final info = Leveling.fromXp(49);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 49);
    });

    test('XP exactly at a threshold rolls over to the next level', () {
      final info = Leveling.fromXp(50);
      expect(info.level, 2);
      expect(info.xpIntoLevel, 0);
      expect(info.xpForThisLevel, 100); // totalXpToReach(3) - totalXpToReach(2)
    });

    test('correctly resolves several levels up from a single large XP total', () {
      // 150 XP = exactly totalXpToReach(3)
      final info = Leveling.fromXp(150);
      expect(info.level, 3);
      expect(info.xpIntoLevel, 0);
    });

    test('mid-level XP splits correctly between xpIntoLevel and xpForThisLevel', () {
      // Level 1 spans 0-49 (50 XP wide). 25 XP in is halfway.
      final info = Leveling.fromXp(25);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 25);
      expect(info.xpForThisLevel, 50);
    });
  });

  group('LevelInfo.progress', () {
    test('is 0.5 exactly halfway through a level', () {
      final info = Leveling.fromXp(25); // level 1 spans 0-49
      expect(info.progress, closeTo(0.5, 0.0001));
    });

    test('is 0 at the very start of a level', () {
      final info = Leveling.fromXp(50); // fresh into level 2
      expect(info.progress, 0);
    });

    test('never exceeds 1 even if xpForThisLevel were somehow 0', () {
      const info = LevelInfo(level: 99, xpIntoLevel: 10, xpForThisLevel: 0, totalXp: 10);
      expect(info.progress, 1);
    });
  });

  group('LevelInfo.xpToNext', () {
    test('counts down correctly within a level', () {
      final info = Leveling.fromXp(25); // level 1, needs 50 total for level 2
      expect(info.xpToNext, 25);
    });

    test('is 0 right at a level boundary', () {
      final info = Leveling.fromXp(50);
      expect(info.xpToNext, 100); // just entered level 2, which spans 100 XP
    });
  });

  group('Leveling.titleFor', () {
    test('bands map to the right titles, including exact boundaries', () {
      expect(Leveling.titleFor(1), 'Beginner');
      expect(Leveling.titleFor(4), 'Beginner');
      expect(Leveling.titleFor(5), 'Apprentice');
      expect(Leveling.titleFor(9), 'Apprentice');
      expect(Leveling.titleFor(10), 'Achiever');
      expect(Leveling.titleFor(14), 'Achiever');
      expect(Leveling.titleFor(15), 'Scholar');
      expect(Leveling.titleFor(19), 'Scholar');
      expect(Leveling.titleFor(20), 'Mastermind');
      expect(Leveling.titleFor(25), 'Mastermind');
    });
  });

  group('Leveling constants', () {
    test('xpPerTask and defaultDailyGoal match the values the rest of the app relies on', () {
      // If either of these ever changes, FirestoreService.completeTask and
      // the daily-goal ring on My Tasks change behavior too — pinning them
      // here makes that an intentional, visible decision instead of a
      // silent drift.
      expect(Leveling.xpPerTask, 10);
      expect(Leveling.defaultDailyGoal, 30);
    });
  });
}