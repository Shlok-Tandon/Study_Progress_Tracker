/// Read-time view of a streak. The stored `streak` field is only accurate
/// as of the last completion; this re-derives what the streak actually is
/// *right now* from how many days have passed, so a lapsed streak shows as
/// broken immediately instead of lingering at its old value. Pure (no
/// Firestore, no Flutter), so it is trivially unit-testable.
class StreakStatus {
  /// The streak to display right now.
  final int current;

  /// True when there was a real streak (stored > 0) that has now lapsed
  /// beyond freeze protection. Lets the UI distinguish "broke a streak"
  /// from "never had one" if it wants to; both show current == 0.
  final bool isBroken;

  const StreakStatus({required this.current, required this.isBroken});
}

/// Derives the live streak from stored state. [now] is injectable for tests.
StreakStatus computeStreakStatus({
  required int storedStreak,
  required DateTime? lastCompletedAt,
  required int freezeCount,
  DateTime? now,
}) {
  if (storedStreak <= 0) {
    return const StreakStatus(current: 0, isBroken: false);
  }
  if (lastCompletedAt == null) {
    // Inconsistent state (a streak with no completion date): trust stored.
    return StreakStatus(current: storedStreak, isBroken: false);
  }

  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final last = DateTime(lastCompletedAt.year, lastCompletedAt.month, lastCompletedAt.day);
  final gap = today.difference(last).inDays;

  // Completed today (gap 0) or yesterday (gap 1): firmly alive. gap < 0 only
  // happens on clock skew / a future timestamp; treat as alive too.
  if (gap <= 1) {
    return StreakStatus(current: storedStreak, isBroken: false);
  }

  // Missed days = gap - 1 (the day you completed isn't "missed").
  final missed = gap - 1;
  if (missed <= freezeCount) {
    // Freezes would still rescue it on the next completion: alive.
    return StreakStatus(current: storedStreak, isBroken: false);
  }

  // Lapsed beyond freeze protection: broken.
  return const StreakStatus(current: 0, isBroken: true);
}