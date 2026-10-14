import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/progression/streak_service.dart';

void main() {
  test('first completion starts a one day streak', () {
    final state = StreakService.previewCompletion(
      currentStreak: 0,
      longestStreak: 0,
      lastCompletedDate: null,
      completedOn: DateTime(2026, 10, 3),
    );
    expect(state.current, 1);
    expect(state.longest, 1);
    expect(state.outcome, StreakOutcome.firstDay);
  });

  test('consecutive completion increments the streak', () {
    final state = StreakService.previewCompletion(
      currentStreak: 6,
      longestStreak: 6,
      lastCompletedDate: DateTime(2026, 10, 2, 22),
      completedOn: DateTime(2026, 10, 3, 9),
    );
    expect(state.current, 7);
    expect(state.longest, 7);
    expect(state.milestone, 7);
    expect(state.outcome, StreakOutcome.continued);
  });

  test('streak milestone is detected when crossing it', () {
    expect(StreakService.milestoneReached(2, 3), 3);
    expect(StreakService.milestoneReached(6, 7), 7);
    expect(StreakService.milestoneReached(7, 8), isNull);
  });

  test('same day is already completed', () {
    final state = StreakService.previewCompletion(
      currentStreak: 8,
      longestStreak: 8,
      lastCompletedDate: DateTime(2026, 10, 3, 8),
      completedOn: DateTime(2026, 10, 3, 21),
    );
    expect(state.current, 8);
    expect(state.completedToday, isTrue);
    expect(state.outcome, StreakOutcome.alreadyCompleted);
  });
}
