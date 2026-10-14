/// Pure streak rules used by the client for presentation and fallback
/// projection. The Daily Challenge RPC remains authoritative for persisted
/// streak values.
class StreakState {
  final int current;
  final int longest;
  final bool completedToday;
  final StreakOutcome outcome;
  final int? milestone;

  const StreakState({
    required this.current,
    required this.longest,
    required this.completedToday,
    required this.outcome,
    this.milestone,
  });
}

enum StreakOutcome { firstDay, continued, alreadyCompleted, broken }

class StreakService {
  StreakService._();

  static const List<int> milestones = <int>[3, 7, 14, 30, 60, 100];

  static StreakState previewCompletion({
    required int currentStreak,
    required int longestStreak,
    required DateTime? lastCompletedDate,
    required DateTime completedOn,
  }) {
    final today = _dateOnly(completedOn);
    final last = lastCompletedDate == null ? null : _dateOnly(lastCompletedDate);

    if (last == null) {
      return _state(
        current: 1,
        longest: longestStreak < 1 ? 1 : longestStreak,
        outcome: StreakOutcome.firstDay,
      );
    }

    if (last == today) {
      return _state(
        current: currentStreak,
        longest: longestStreak,
        outcome: StreakOutcome.alreadyCompleted,
      );
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (last == yesterday) {
      final next = currentStreak + 1;
      return _state(
        current: next,
        longest: next > longestStreak ? next : longestStreak,
        outcome: StreakOutcome.continued,
      );
    }

    return _state(
      current: 1,
      longest: longestStreak < 1 ? 1 : longestStreak,
      outcome: StreakOutcome.broken,
    );
  }

  static int? milestoneReached(int previousStreak, int nextStreak) {
    for (final milestone in milestones) {
      if (previousStreak < milestone && nextStreak >= milestone) {
        return milestone;
      }
    }
    return null;
  }

  static int daysSince({required DateTime? lastCompletedDate, required DateTime on}) {
    if (lastCompletedDate == null) return 1 << 20;
    final last = _dateOnly(lastCompletedDate);
    final today = _dateOnly(on);
    return today.difference(last).inDays;
  }

  static DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  static StreakState _state({
    required int current,
    required int longest,
    required StreakOutcome outcome,
  }) {
    return StreakState(
      current: current,
      longest: longest,
      completedToday: outcome == StreakOutcome.alreadyCompleted,
      outcome: outcome,
      milestone: milestoneReached(current - 1, current),
    );
  }
}
