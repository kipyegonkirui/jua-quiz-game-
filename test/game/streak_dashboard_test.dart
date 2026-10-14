import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/models/streak_dashboard.dart';

void main() {
  test('parses dashboard summary and history', () {
    final data = StreakDashboardData.fromMap({
      'current_streak': 14,
      'longest_streak': 21,
      'streak_shields': 2,
      'last_completed_date': '2026-10-03',
      'next_milestone': 30,
      'next_milestone_coins': 0,
      'next_milestone_shields': 1,
      'days': [
        {
          'date': '2026-10-02',
          'completed': true,
          'streak_value': 13,
          'shield_used': false,
        },
        {
          'date': '2026-10-03',
          'completed': true,
          'streak_value': 14,
          'shield_used': true,
        },
        {
          'date': '2026-10-04',
          'completed': false,
          'streak_value': 0,
          'shield_used': false,
        },
      ],
    });

    expect(data.currentStreak, 14);
    expect(data.longestStreak, 21);
    expect(data.streakShields, 2);
    expect(data.nextMilestone, 30);
    expect(data.nextMilestoneShields, 1);
    expect(data.days.length, 3);
    expect(data.completedDays, 2);
    expect(data.protectedDays, 1);
    expect(data.completedToday, isFalse);
  });

  test('completedToday follows the final calendar day', () {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final iso = (DateTime d) => d.toIso8601String().substring(0, 10);

    final data = StreakDashboardData.fromMap({
      'current_streak': 3,
      'longest_streak': 3,
      'streak_shields': 0,
      'days': [
        {
          'date': iso(yesterday),
          'completed': true,
          'streak_value': 2,
          'shield_used': false,
        },
        {
          'date': iso(today),
          'completed': true,
          'streak_value': 3,
          'shield_used': false,
        },
      ],
    });

    expect(data.completedToday, isTrue);
  });
}
