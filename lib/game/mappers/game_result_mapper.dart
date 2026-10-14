import '../../models/attempt_result.dart';
import '../models/game_mode.dart';
import '../models/game_result.dart';
import '../models/speed_quiz_result.dart';

/// Converts mode-specific server completion payloads into one shared result.
class GameResultMapper {
  const GameResultMapper._();

  static GameResult fromAttemptResult({
    required GameMode mode,
    required AttemptResult result,
  }) {
    return GameResult(
      mode: mode,
      score: result.score,
      total: result.total,
      correct: result.score,
      xpEarned: result.xpEarned,
      coinsEarned: result.coinsEarned,
      streakShields: result.streakShields,
      newXp: result.newXp,
      newLevel: result.newLevel,
      leveledUp: result.leveledUp,
      currentStreak: result.currentStreak,
      longestStreak: result.longestStreak,
      xpCapped: result.xpCapped,
      practiceXpToday: result.practiceXpToday,
      practiceXpCap: result.practiceXpCap,
    );
  }

  static GameResult fromSpeedQuizResult(SpeedQuizResult result) {
    return GameResult(
      mode: GameMode.speedQuiz,
      score: result.score,
      total: result.total,
      correct: result.correct,
      xpEarned: result.xpEarned,
      coinsEarned: result.coinsEarned,
      newXp: result.newXp,
      newLevel: result.newLevel,
      leveledUp: result.leveledUp,
      currentStreak: result.currentStreak,
      longestStreak: result.longestStreak,
    );
  }
}
