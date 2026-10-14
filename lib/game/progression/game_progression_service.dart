import '../../models/user_profile.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import 'streak_service.dart';
import 'xp_progression_service.dart';

/// Projects one authoritative game result onto the player's local profile
/// snapshot. This is a pure projection: it does not award XP/coins itself
/// and it does not talk to Supabase.
class GameProgressionService {
  const GameProgressionService._();

  static UserProfile applyResult({
    required UserProfile base,
    required GameResult result,
    DateTime? completedAt,
  }) {
    final nextXp = result.newXp ?? (base.xp + result.xpEarned);
    // The server-provided level wins when present. Otherwise derive the level
    // from the resulting XP through the centralized XP policy.
    final derivedLevel = XpProgressionService.fromXp(nextXp).level;
    final nextLevel = result.newLevel ?? derivedLevel;
    final correct = result.correct ?? 0;

    final countsAsAttempt = switch (result.mode) {
      GameMode.practice => false,
      GameMode.dailyChallenge => true,
      GameMode.speedQuiz => true,
      _ => false,
    };

    final practiceRound = result.mode == GameMode.practice;
    final dailyChallenge = result.mode == GameMode.dailyChallenge;

    int nextCurrentStreak = result.currentStreak ?? base.currentStreak;
    int nextLongestStreak = result.longestStreak ?? base.longestStreak;
    if (dailyChallenge && (result.currentStreak == null || result.longestStreak == null)) {
      final completion = StreakService.previewCompletion(
        currentStreak: base.currentStreak,
        longestStreak: base.longestStreak,
        lastCompletedDate: base.lastCompletedDate,
        completedOn: completedAt ?? DateTime.now(),
      );
      nextCurrentStreak = completion.current;
      nextLongestStreak = completion.longest;
    }

    return base.copyWith(
      xp: nextXp,
      level: nextLevel,
      currentStreak: nextCurrentStreak,
      longestStreak: nextLongestStreak,
      totalAttempts: countsAsAttempt
          ? base.totalAttempts + 1
          : base.totalAttempts,
      totalCorrect: base.totalCorrect + correct,
      totalQuestions: base.totalQuestions + result.total,
      practiceRounds: practiceRound
          ? base.practiceRounds + 1
          : base.practiceRounds,
      coins: base.coins + result.coinsEarned,
      streakShields: result.mode == GameMode.dailyChallenge ? result.streakShields : base.streakShields,
      lastCompletedDate: dailyChallenge
          ? (completedAt ?? DateTime.now())
          : base.lastCompletedDate,
    );
  }
}
