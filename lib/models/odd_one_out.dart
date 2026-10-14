import 'dart:math' as math;

/// How a round is played.
///  - [daily]: one shared set per Nairobi day, one attempt per day.
///  - [quick]: endless rounds.
enum OddOneOutMode {
  daily,
  quick;

  /// The value the database expects in start_odd_one_out_round(p_mode).
  String get value => name;
}

/// One puzzle: four items, one of which does not belong.
///
/// The odd option and explanation are only filled in for puzzles that have
/// already been answered (used when resuming an interrupted round).
class OddOneOutPuzzle {
  final String id;
  final String type;
  final Map<String, String> items;
  final int position;
  final int timeLimitSeconds;
  final String difficulty;

  final bool answered;
  final String? chosen;
  final bool isCorrect;
  final String? oddOption;
  final String? explanation;
  final int score;
  final int combo;
  final bool hintUsed;
  final Set<String> eliminated;

  const OddOneOutPuzzle({
    required this.id,
    required this.type,
    required this.items,
    required this.position,
    this.timeLimitSeconds = 12,
    this.difficulty = 'medium',
    this.answered = false,
    this.chosen,
    this.isCorrect = false,
    this.oddOption,
    this.explanation,
    this.score = 0,
    this.combo = 0,
    this.hintUsed = false,
    this.eliminated = const <String>{},
  });

  factory OddOneOutPuzzle.fromMap(Map<String, dynamic> map) {
    return OddOneOutPuzzle(
      id: map['id'] as String,
      type: (map['puzzle_type'] as String?) ?? 'category',
      items: {
        'a': map['item_a'] as String,
        'b': map['item_b'] as String,
        'c': map['item_c'] as String,
        'd': map['item_d'] as String,
      },
      position: (map['position'] as num?)?.toInt() ?? 0,
      timeLimitSeconds: (map['time_limit_seconds'] as num?)?.toInt() ?? 12,
      difficulty: (map['difficulty'] as String?) ?? 'medium',
      answered: map['answered'] as bool? ?? false,
      chosen: map['chosen'] as String?,
      isCorrect: map['is_correct'] as bool? ?? false,
      oddOption: map['odd_option'] as String?,
      explanation: map['explanation'] as String?,
      score: (map['score'] as num?)?.toInt() ?? 0,
      combo: (map['combo'] as num?)?.toInt() ?? 0,
      hintUsed: map['hint_used'] as bool? ?? false,
      eliminated: ((map['eliminated_options'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
    );
  }

  /// Short label shown on the puzzle card.
  String get typeLabel => switch (type) {
        'local' => 'LOCAL CULTURE',
        'visual' => 'VISUAL',
        'wordplay' => 'WORDPLAY',
        'tricky' => 'TRICKY',
        _ => 'CATEGORY',
      };

  /// Emoji-only puzzles are drawn with bigger tiles.
  bool get isVisual => type == 'visual';
}

class OddOneOutAnswerResult {
  final String puzzleId;
  final String chosen;
  final String oddOption;
  final bool isCorrect;
  final int score;
  final int combo;
  final int timeMs;
  final bool hintUsed;
  final String explanation;

  const OddOneOutAnswerResult({
    required this.puzzleId,
    required this.chosen,
    required this.oddOption,
    required this.isCorrect,
    required this.score,
    required this.combo,
    required this.timeMs,
    required this.hintUsed,
    required this.explanation,
  });

  factory OddOneOutAnswerResult.fromMap(Map<String, dynamic> map) {
    return OddOneOutAnswerResult(
      puzzleId: map['puzzle_id'] as String,
      chosen: map['chosen'] as String,
      oddOption: map['odd_option'] as String,
      isCorrect: map['is_correct'] as bool? ?? false,
      score: (map['score'] as num?)?.toInt() ?? 0,
      combo: (map['combo'] as num?)?.toInt() ?? 0,
      timeMs: (map['time_ms'] as num?)?.toInt() ?? 0,
      hintUsed: map['hint_used'] as bool? ?? false,
      explanation: (map['explanation'] as String?) ?? '',
    );
  }

  /// Rebuilds the result of a puzzle that was answered before the player left.
  factory OddOneOutAnswerResult.fromAnsweredPuzzle(OddOneOutPuzzle p) {
    return OddOneOutAnswerResult(
      puzzleId: p.id,
      chosen: p.chosen ?? 'timeout',
      oddOption: p.oddOption ?? '',
      isCorrect: p.isCorrect,
      score: p.score,
      combo: p.combo,
      timeMs: 0,
      hintUsed: p.hintUsed,
      explanation: p.explanation ?? '',
    );
  }
}

class OddOneOutHintResult {
  final Set<String> eliminatedOptions;
  final int coinsSpent;
  final int coinsBalance;

  const OddOneOutHintResult({
    required this.eliminatedOptions,
    required this.coinsSpent,
    required this.coinsBalance,
  });

  factory OddOneOutHintResult.fromMap(Map<String, dynamic> map) {
    return OddOneOutHintResult(
      eliminatedOptions: ((map['eliminated_options'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      coinsSpent: (map['coins_spent'] as num?)?.toInt() ?? 0,
      coinsBalance: (map['coins_balance'] as num?)?.toInt() ?? 0,
    );
  }
}

class OddOneOutResult {
  final OddOneOutMode mode;
  final int score;
  final int total;
  final int correct;
  final int maxCombo;
  final int xpEarned;
  final int coinsEarned;
  final bool rewardsCapped;
  final int? newXp;
  final int? newLevel;
  final bool leveledUp;
  final int bestScore;
  final int dailyStreak;

  /// One 🟩 or 🟥 per puzzle, in order.
  final String pattern;

  const OddOneOutResult({
    required this.mode,
    required this.score,
    required this.total,
    required this.correct,
    required this.maxCombo,
    required this.xpEarned,
    required this.coinsEarned,
    required this.rewardsCapped,
    required this.newXp,
    required this.newLevel,
    required this.leveledUp,
    required this.bestScore,
    required this.dailyStreak,
    required this.pattern,
  });

  factory OddOneOutResult.fromMap(Map<String, dynamic> map) {
    return OddOneOutResult(
      mode: map['mode'] == 'daily' ? OddOneOutMode.daily : OddOneOutMode.quick,
      score: (map['score'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      correct: (map['correct'] as num?)?.toInt() ?? 0,
      maxCombo: (map['max_combo'] as num?)?.toInt() ?? 0,
      xpEarned: (map['xp_earned'] as num?)?.toInt() ?? 0,
      coinsEarned: (map['coins_earned'] as num?)?.toInt() ?? 0,
      rewardsCapped: map['rewards_capped'] as bool? ?? false,
      newXp: (map['new_xp'] as num?)?.toInt(),
      newLevel: (map['new_level'] as num?)?.toInt(),
      leveledUp: map['leveled_up'] as bool? ?? false,
      bestScore: (map['best_score'] as num?)?.toInt() ?? 0,
      dailyStreak: (map['daily_streak'] as num?)?.toInt() ?? 0,
      pattern: (map['pattern'] as String?) ?? '',
    );
  }

  bool get isDaily => mode == OddOneOutMode.daily;

  String get shareText => buildOddOneOutShareText(
        pattern: pattern,
        correct: correct,
        total: total,
        score: score,
        streak: dailyStreak,
      );
}

/// What the lobby needs to know before the player chooses a mode.
class OddOneOutStatus {
  final bool dailyDone;
  final bool dailyInProgress;
  final int dailyScore;
  final int dailyCorrect;
  final int dailyTotal;
  final String dailyPattern;
  final int dailyStreak;
  final int bestQuickScore;
  final int rewardedRoundsLeft;

  const OddOneOutStatus({
    required this.dailyDone,
    required this.dailyInProgress,
    required this.dailyScore,
    required this.dailyCorrect,
    required this.dailyTotal,
    required this.dailyPattern,
    required this.dailyStreak,
    required this.bestQuickScore,
    required this.rewardedRoundsLeft,
  });

  factory OddOneOutStatus.fromMap(Map<String, dynamic> map) {
    return OddOneOutStatus(
      dailyDone: map['daily_done'] as bool? ?? false,
      dailyInProgress: map['daily_in_progress'] as bool? ?? false,
      dailyScore: (map['daily_score'] as num?)?.toInt() ?? 0,
      dailyCorrect: (map['daily_correct'] as num?)?.toInt() ?? 0,
      dailyTotal: (map['daily_total'] as num?)?.toInt() ?? 0,
      dailyPattern: (map['daily_pattern'] as String?) ?? '',
      dailyStreak: (map['daily_streak'] as num?)?.toInt() ?? 0,
      bestQuickScore: (map['best_quick_score'] as num?)?.toInt() ?? 0,
      rewardedRoundsLeft: (map['rewarded_rounds_left'] as num?)?.toInt() ?? 0,
    );
  }

  String get dailyShareText => buildOddOneOutShareText(
        pattern: dailyPattern,
        correct: dailyCorrect,
        total: dailyTotal,
        score: dailyScore,
        streak: dailyStreak,
      );
}

/// Score multiplier shown on the combo badge. Mirrors the database formula
/// (1.0 on the first correct answer, +0.1 per extra, capped at 1.5). The
/// server remains the only authority for the actual score.
double oddOneOutComboMultiplier(int combo) {
  if (combo <= 0) return 1.0;
  return 1 + 0.1 * (math.min(combo, 6) - 1);
}

/// Headline for the results screen. Near-misses are phrased so the player
/// wants "one more round".
String oddOneOutVerdict(int correct, int total) {
  if (total <= 0) return 'Round complete';
  if (correct == total) return 'Perfect round! 🔥';
  if (correct == total - 1) return 'So close! One away from perfect';
  final ratio = correct / total;
  if (ratio >= 0.6) return 'Sharp eyes! Can you go perfect?';
  if (ratio >= 0.35) return 'Not bad. The next round is yours';
  return 'Tough one. Every round makes you sharper';
}

/// Wordle-style text for sharing (e.g. on WhatsApp).
String buildOddOneOutShareText({
  required String pattern,
  required int correct,
  required int total,
  required int score,
  int streak = 0,
}) {
  final b = StringBuffer('Jua Quiz • Odd One Out 🔎\n');
  b.writeln('$pattern  $correct/$total');
  b.write('Score $score');
  if (streak > 1) b.write(' • $streak-day streak 🔥');
  b.write('\nCan you beat me?');
  return b.toString();
}

/// Time left until the next Daily set unlocks. Daily sets roll over at
/// midnight Kenya time (UTC+3, no daylight saving).
Duration timeUntilNextNairobiDay([DateTime? nowUtc]) {
  final now = (nowUtc ?? DateTime.now().toUtc()).add(const Duration(hours: 3));
  return DateTime.utc(now.year, now.month, now.day + 1).difference(now);
}

/// "5h 12m" / "42m".
String formatOddOneOutCountdown(Duration d) {
  final minutes = d.inMinutes <= 0 ? 1 : d.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}
