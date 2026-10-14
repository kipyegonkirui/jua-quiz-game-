import '../models/game_answer.dart';
import '../models/game_mode.dart';
import '../models/game_question.dart';
import 'game_score.dart';

/// Deterministic score calculation for local/new game modes.
///
/// The server remains authoritative for existing Practice, Daily Challenge,
/// and Competition scoring. This service is intentionally pure so the same
/// policy can later be mirrored by a Supabase function for server validation.
class GameScorer {
  final int basePoints;
  final int maxSpeedBonus;
  final Map<String, double> difficultyMultipliers;
  final Map<GameMode, int> modeBonuses;

  const GameScorer({
    this.basePoints = 100,
    this.maxSpeedBonus = 50,
    this.difficultyMultipliers = const {
      'easy': 1.0,
      'medium': 1.15,
      'hard': 1.35,
      'expert': 1.6,
    },
    this.modeBonuses = const {},
  });

  GameScoreBreakdown score({
    required GameQuestion question,
    required GameAnswer answer,
    required GameMode mode,
  }) {
    if (!answer.isCorrect) {
      return GameScoreBreakdown(modeBonus: 0, basePoints: 0);
    }

    final multiplier = _difficultyMultiplier(question.difficulty);
    final difficultyBonus = (basePoints * (multiplier - 1)).round();
    final speedBonus = _speedBonus(
      timeTaken: answer.timeTaken,
      timeLimit: question.timeLimit,
    );

    return GameScoreBreakdown(
      basePoints: basePoints,
      speedBonus: speedBonus,
      difficultyBonus: difficultyBonus,
      modeBonus: modeBonuses[mode] ?? 0,
    );
  }

  double _difficultyMultiplier(String? difficulty) {
    if (difficulty == null) return 1.0;
    return difficultyMultipliers[difficulty.toLowerCase()] ?? 1.0;
  }

  int _speedBonus({Duration? timeTaken, Duration? timeLimit}) {
    if (timeTaken == null || timeLimit == null || timeLimit <= Duration.zero) {
      return 0;
    }

    final remaining = timeLimit - timeTaken;
    if (remaining <= Duration.zero) return 0;

    final ratio = remaining.inMicroseconds / timeLimit.inMicroseconds;
    return (maxSpeedBonus * ratio.clamp(0.0, 1.0)).round();
  }
}
