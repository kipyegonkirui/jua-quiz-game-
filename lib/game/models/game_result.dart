import 'game_mode.dart';

/// Normalized completion payload shared by every game mode.
///
/// Server-backed modes map their authoritative result into this contract.
/// Reward fields represent what the server awarded; the client never
/// calculates or grants persistent rewards from this model alone.
class GameResult {
  final GameMode mode;
  final int score;
  final int total;
  final int? correct;
  final int xpEarned;
  final int coinsEarned;
  final int streakShields;
  final int? newXp;
  final int? newLevel;
  final bool leveledUp;
  final int? currentStreak;
  final int? longestStreak;
  final Duration? totalTime;
  final bool xpCapped;
  final int? practiceXpToday;
  final int? practiceXpCap;

  const GameResult({
    required this.mode,
    required this.score,
    required this.total,
    this.correct,
    this.xpEarned = 0,
    this.coinsEarned = 0,
    this.streakShields = 0,
    this.newXp,
    this.newLevel,
    this.leveledUp = false,
    this.currentStreak,
    this.longestStreak,
    this.totalTime,
    this.xpCapped = false,
    this.practiceXpToday,
    this.practiceXpCap,
  });

  double get accuracy => total <= 0
      ? 0
      : ((correct ?? score) / total).clamp(0.0, 1.0);
}
