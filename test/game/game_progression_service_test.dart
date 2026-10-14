import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/models/game_mode.dart';
import 'package:jua_quiz/game/models/game_result.dart';
import 'package:jua_quiz/game/progression/game_progression_service.dart';
import 'package:jua_quiz/models/user_profile.dart';

UserProfile profile({int xp = 120, int level = 2, int coins = 40}) => UserProfile(
      id: 'u1',
      username: 'Player',
      xp: xp,
      level: level,
      currentStreak: 4,
      longestStreak: 7,
      totalAttempts: 3,
      totalCorrect: 10,
      totalQuestions: 15,
      practiceRounds: 2,
      coins: coins,
      isGuest: false,
    );

void main() {
  test('practice increments practice rounds but not challenge attempts', () {
    final updated = GameProgressionService.applyResult(
      base: profile(),
      result: const GameResult(
        mode: GameMode.practice,
        score: 4,
        total: 5,
        correct: 4,
        xpEarned: 30,
        coinsEarned: 5,
        newXp: 150,
        newLevel: 2,
        currentStreak: 4,
        longestStreak: 7,
      ),
    );

    expect(updated.xp, 150);
    expect(updated.coins, 45);
    expect(updated.practiceRounds, 3);
    expect(updated.totalAttempts, 3);
    expect(updated.totalCorrect, 14);
    expect(updated.totalQuestions, 20);
  });

  test('daily challenge increments attempts and records completion date', () {
    final completedAt = DateTime.utc(2026, 10, 3, 1, 0);
    final updated = GameProgressionService.applyResult(
      base: profile(),
      completedAt: completedAt,
      result: const GameResult(
        mode: GameMode.dailyChallenge,
        score: 5,
        total: 5,
        correct: 5,
        xpEarned: 50,
        newXp: 170,
        newLevel: 2,
        currentStreak: 5,
        longestStreak: 7,
      ),
    );

    expect(updated.totalAttempts, 4);
    expect(updated.practiceRounds, 2);
    expect(updated.currentStreak, 5);
    expect(updated.lastCompletedDate, completedAt);
  });

  test('speed quiz increments attempts and does not change streak fields when absent', () {
    final updated = GameProgressionService.applyResult(
      base: profile(),
      result: const GameResult(
        mode: GameMode.speedQuiz,
        score: 820,
        total: 10,
        correct: 8,
        xpEarned: 40,
        coinsEarned: 10,
        newXp: 160,
        newLevel: 2,
      ),
    );

    expect(updated.totalAttempts, 4);
    expect(updated.totalCorrect, 18);
    expect(updated.totalQuestions, 25);
    expect(updated.coins, 50);
    expect(updated.currentStreak, 4);
    expect(updated.longestStreak, 7);
  });
  test('daily streak falls back to streak service when server omits streak', () {
    final base = profile();
    final result = const GameResult(
      mode: GameMode.dailyChallenge,
      score: 5,
      total: 5,
      correct: 5,
      xpEarned: 50,
      newXp: 170,
      newLevel: 2,
    );
    final updated = GameProgressionService.applyResult(
      base: base.copyWith(lastCompletedDate: DateTime.utc(2026, 10, 2)),
      result: result,
      completedAt: DateTime.utc(2026, 10, 3),
    );
    expect(updated.currentStreak, 5);
    expect(updated.longestStreak, 7);
  });
  test('derives level from resulting XP when the server omits level', () {
    final updated = GameProgressionService.applyResult(
      base: profile(xp: 90, level: 1),
      result: const GameResult(
        mode: GameMode.practice,
        score: 5,
        total: 5,
        correct: 5,
        xpEarned: 20,
        newXp: 110,
      ),
    );

    expect(updated.xp, 110);
    expect(updated.level, 2);
  });
}
