/// Odd One Out "Survival Run" models (server: supabase/027_odd_survival_run.sql).
class SurvivalPuzzle {
  final String id;
  final String type;
  final String difficulty;
  final int seq;
  final Map<String, String> items;
  final int timeLimitMs;
  final int remainingMs;

  const SurvivalPuzzle({
    required this.id,
    required this.type,
    required this.difficulty,
    required this.seq,
    required this.items,
    required this.timeLimitMs,
    required this.remainingMs,
  });

  factory SurvivalPuzzle.fromMap(Map<String, dynamic> m) => SurvivalPuzzle(
        id: m['id'] as String,
        type: (m['puzzle_type'] as String?) ?? 'category',
        difficulty: (m['difficulty'] as String?) ?? 'medium',
        seq: (m['seq'] as num?)?.toInt() ?? 1,
        items: {
          'a': m['item_a'] as String,
          'b': m['item_b'] as String,
          'c': m['item_c'] as String,
          'd': m['item_d'] as String,
        },
        timeLimitMs: (m['time_limit_ms'] as num).toInt(),
        remainingMs: (m['remaining_ms'] as num).toInt(),
      );
}

/// The run as the server sees it right now.
class SurvivalState {
  final String runId;
  final String status; // playing | offer | over
  final int strikes;
  final int maxStrikes;
  final int streak;
  final int bestStreak;
  final int savedStreak;
  final int score;
  final int correct;
  final int answered;
  final double multiplier;
  final int bestBefore;
  final int windCost;
  final SurvivalPuzzle? puzzle;

  const SurvivalState({
    required this.runId,
    required this.status,
    required this.strikes,
    required this.maxStrikes,
    required this.streak,
    required this.bestStreak,
    required this.savedStreak,
    required this.score,
    required this.correct,
    required this.answered,
    required this.multiplier,
    required this.bestBefore,
    required this.windCost,
    required this.puzzle,
  });

  bool get isHot => streak >= 5;
  int get strikesLeft => (maxStrikes - strikes).clamp(0, maxStrikes);

  factory SurvivalState.fromMap(Map<String, dynamic> m) => SurvivalState(
        runId: m['run_id'] as String,
        status: m['status'] as String,
        strikes: (m['strikes'] as num).toInt(),
        maxStrikes: (m['max_strikes'] as num).toInt(),
        streak: (m['streak'] as num).toInt(),
        bestStreak: (m['best_streak'] as num).toInt(),
        savedStreak: (m['saved_streak'] as num).toInt(),
        score: (m['score'] as num).toInt(),
        correct: (m['correct'] as num).toInt(),
        answered: (m['answered'] as num).toInt(),
        multiplier: (m['multiplier'] as num).toDouble(),
        bestBefore: (m['best_before'] as num).toInt(),
        windCost: (m['wind_cost'] as num?)?.toInt() ?? 40,
        puzzle: m['puzzle'] == null
            ? null
            : SurvivalPuzzle.fromMap(Map<String, dynamic>.from(m['puzzle'] as Map)),
      );
}

/// The state after an answer, plus what that answer was worth.
class SurvivalAnswer {
  final SurvivalState state;
  final bool isCorrect;
  final bool timedOut;
  final int points;
  final String oddOption;
  final String explanation;
  final String answeredPuzzleId;
  final bool hotStreak;
  final bool streakBroken;
  final int lostStreak;

  const SurvivalAnswer({
    required this.state,
    required this.isCorrect,
    required this.timedOut,
    required this.points,
    required this.oddOption,
    required this.explanation,
    required this.answeredPuzzleId,
    required this.hotStreak,
    required this.streakBroken,
    required this.lostStreak,
  });

  factory SurvivalAnswer.fromMap(Map<String, dynamic> m) => SurvivalAnswer(
        state: SurvivalState.fromMap(m),
        isCorrect: m['is_correct'] as bool,
        timedOut: (m['timed_out'] as bool?) ?? false,
        points: (m['points'] as num).toInt(),
        oddOption: m['odd_option'] as String,
        explanation: (m['explanation'] as String?) ?? '',
        answeredPuzzleId: m['answered_puzzle_id'] as String,
        hotStreak: (m['hot_streak'] as bool?) ?? false,
        streakBroken: (m['streak_broken'] as bool?) ?? false,
        lostStreak: (m['lost_streak'] as num?)?.toInt() ?? 0,
      );
}

class SurvivalResult {
  final int score;
  final int correct;
  final int answered;
  final int bestStreak;
  final int bestBefore;
  final bool newBest;
  final int missedBestBy;
  final int xpEarned;
  final int coinsEarned;
  final bool rewardsCapped;
  final int newLevel;
  final bool leveledUp;
  final bool windUsed;

  const SurvivalResult({
    required this.score,
    required this.correct,
    required this.answered,
    required this.bestStreak,
    required this.bestBefore,
    required this.newBest,
    required this.missedBestBy,
    required this.xpEarned,
    required this.coinsEarned,
    required this.rewardsCapped,
    required this.newLevel,
    required this.leveledUp,
    required this.windUsed,
  });

  factory SurvivalResult.fromMap(Map<String, dynamic> m) => SurvivalResult(
        score: (m['score'] as num).toInt(),
        correct: (m['correct'] as num).toInt(),
        answered: (m['answered'] as num).toInt(),
        bestStreak: (m['best_streak'] as num).toInt(),
        bestBefore: (m['best_before'] as num).toInt(),
        newBest: (m['new_best'] as bool?) ?? false,
        missedBestBy: (m['missed_best_by'] as num?)?.toInt() ?? 0,
        xpEarned: (m['xp_earned'] as num?)?.toInt() ?? 0,
        coinsEarned: (m['coins_earned'] as num?)?.toInt() ?? 0,
        rewardsCapped: (m['rewards_capped'] as bool?) ?? false,
        newLevel: (m['new_level'] as num?)?.toInt() ?? 1,
        leveledUp: (m['leveled_up'] as bool?) ?? false,
        windUsed: ((m['wind_used'] as num?)?.toInt() ?? 0) > 0,
      );
}

class SurvivalStatus {
  final int bestScore;
  final int bestStreak;
  final int bestCorrect;
  final int runs;
  final int rewardedLeft;
  final bool hasActiveRun;

  const SurvivalStatus({
    required this.bestScore,
    required this.bestStreak,
    required this.bestCorrect,
    required this.runs,
    required this.rewardedLeft,
    required this.hasActiveRun,
  });

  factory SurvivalStatus.fromMap(Map<String, dynamic> m) => SurvivalStatus(
        bestScore: (m['best_score'] as num?)?.toInt() ?? 0,
        bestStreak: (m['best_streak'] as num?)?.toInt() ?? 0,
        bestCorrect: (m['best_correct'] as num?)?.toInt() ?? 0,
        runs: (m['runs'] as num?)?.toInt() ?? 0,
        rewardedLeft: (m['rewarded_left'] as num?)?.toInt() ?? 0,
        hasActiveRun: (m['has_active_run'] as bool?) ?? false,
      );
}
