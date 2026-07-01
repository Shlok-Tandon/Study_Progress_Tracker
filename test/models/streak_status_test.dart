import 'package:flutter_test/flutter_test.dart';
import 'package:study_progress_tracker/models/streak_status.dart';

void main() {
  final now = DateTime(2026, 7, 2, 15, 30); // an arbitrary "today", mid-afternoon

  DateTime daysAgo(int days) => now.subtract(Duration(days: days));

  group('computeStreakStatus — no streak yet', () {
    test('storedStreak of 0 is always {0, not broken}, regardless of other fields', () {
      final status = computeStreakStatus(
        storedStreak: 0,
        lastCompletedAt: daysAgo(30), // even a stale date shouldn't matter
        freezeCount: 0,
        now: now,
      );
      expect(status.current, 0);
      expect(status.isBroken, false);
    });
  });

  group('computeStreakStatus — inconsistent state', () {
    test('a positive stored streak with no completion date is trusted as-is', () {
      final status = computeStreakStatus(
        storedStreak: 7,
        lastCompletedAt: null,
        freezeCount: 0,
        now: now,
      );
      expect(status.current, 7);
      expect(status.isBroken, false);
    });
  });

  group('computeStreakStatus — still alive', () {
    test('completed earlier today (gap 0) keeps the streak', () {
      final status = computeStreakStatus(
        storedStreak: 5,
        lastCompletedAt: now,
        freezeCount: 0,
        now: now,
      );
      expect(status.current, 5);
      expect(status.isBroken, false);
    });

    test('completed yesterday (gap 1) keeps the streak with no freeze needed', () {
      final status = computeStreakStatus(
        storedStreak: 5,
        lastCompletedAt: daysAgo(1),
        freezeCount: 0,
        now: now,
      );
      expect(status.current, 5);
      expect(status.isBroken, false);
    });

    test('a future/clock-skewed completion date is treated as alive, not broken', () {
      final status = computeStreakStatus(
        storedStreak: 5,
        lastCompletedAt: now.add(const Duration(days: 1)),
        freezeCount: 0,
        now: now,
      );
      expect(status.current, 5);
      expect(status.isBroken, false);
    });
  });

  group('computeStreakStatus — freeze protection', () {
    test('exactly enough freezes rescue a gap and the streak stays alive', () {
      // gap 2 -> 1 missed day, covered by 1 freeze.
      final status = computeStreakStatus(
        storedStreak: 5,
        lastCompletedAt: daysAgo(2),
        freezeCount: 1,
        now: now,
      );
      expect(status.current, 5);
      expect(status.isBroken, false);
    });

    test('freezes covering exactly a multi-day gap still rescue it', () {
      // gap 3 -> 2 missed days, covered by exactly 2 freezes.
      final status = computeStreakStatus(
        storedStreak: 5,
        lastCompletedAt: daysAgo(3),
        freezeCount: 2,
        now: now,
      );
      expect(status.current, 5);
      expect(status.isBroken, false);
    });

    test('one missed day short of the freeze cushion still rescues the streak', () {
      // gap 3 -> 2 missed days, 3 freezes is more than enough.
      final status = computeStreakStatus(
        storedStreak: 5,
        lastCompletedAt: daysAgo(3),
        freezeCount: 3,
        now: now,
      );
      expect(status.current, 5);
      expect(status.isBroken, false);
    });
  });

  group('computeStreakStatus — broken', () {
    test('a gap beyond freeze protection breaks the streak', () {
      // gap 2 -> 1 missed day, but 0 freezes available.
      final status = computeStreakStatus(
        storedStreak: 5,
        lastCompletedAt: daysAgo(2),
        freezeCount: 0,
        now: now,
      );
      expect(status.current, 0);
      expect(status.isBroken, true);
    });

    test('missed days exceeding available freezes by just one still breaks', () {
      // gap 4 -> 3 missed days, only 2 freezes.
      final status = computeStreakStatus(
        storedStreak: 5,
        lastCompletedAt: daysAgo(4),
        freezeCount: 2,
        now: now,
      );
      expect(status.current, 0);
      expect(status.isBroken, true);
    });

    test('a long-lapsed streak with no freezes reports broken, not just "never had one"', () {
      final status = computeStreakStatus(
        storedStreak: 20,
        lastCompletedAt: daysAgo(10),
        freezeCount: 0,
        now: now,
      );
      expect(status.current, 0);
      expect(status.isBroken, true);
      // Distinguishing signal from the "storedStreak == 0" case above: this
      // one really did break, it didn't just never exist.
    });
  });

  group('computeStreakStatus — day boundary, not wall-clock time', () {
    test('completions at opposite ends of the same calendar day both count as gap 0', () {
      final earlyThisMorning = DateTime(2026, 7, 2, 0, 5);
      final lateThisEvening = DateTime(2026, 7, 2, 23, 55);
      final status = computeStreakStatus(
        storedStreak: 3,
        lastCompletedAt: earlyThisMorning,
        freezeCount: 0,
        now: lateThisEvening,
      );
      expect(status.current, 3);
      expect(status.isBroken, false);
    });
  });
}