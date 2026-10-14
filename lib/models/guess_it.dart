class GuessItQuestion {
  final String id;
  final String prompt;
  final String imageUrl;
  final Map<String, String> options;
  final int position;
  final int timeLimitSeconds;
  final String difficulty;

  /// Resume state: already answered, and hints already bought for it.
  final bool answered;
  final int hintLevel;
  final Set<String> eliminated;

  /// Flutter cannot draw SVG with Image.asset, so older rows that still point
  /// at a .svg file are served from the matching .png.
  String get displayImage => imageUrl.toLowerCase().endsWith('.svg')
      ? '${imageUrl.substring(0, imageUrl.length - 4)}.png'
      : imageUrl;

  const GuessItQuestion({
    required this.id,
    required this.prompt,
    required this.imageUrl,
    required this.options,
    required this.position,
    this.timeLimitSeconds = 15,
    this.difficulty = 'medium',
    this.answered = false,
    this.hintLevel = 0,
    this.eliminated = const <String>{},
  });

  factory GuessItQuestion.fromMap(Map<String, dynamic> map) {
    return GuessItQuestion(
      id: map['id'] as String,
      prompt: map['prompt'] as String,
      imageUrl: map['image_url'] as String,
      options: {
        'a': map['option_a'] as String,
        'b': map['option_b'] as String,
        'c': map['option_c'] as String,
        'd': map['option_d'] as String,
      },
      position: (map['position'] as num?)?.toInt() ?? 0,
      timeLimitSeconds: (map['time_limit_seconds'] as num?)?.toInt() ?? 15,
      difficulty: (map['difficulty'] as String?) ?? 'medium',
      answered: map['answered'] as bool? ?? false,
      hintLevel: (map['hint_level'] as num?)?.toInt() ?? 0,
      eliminated: ((map['eliminated_options'] as List?) ?? const []).map((e) => e.toString()).toSet(),
    );
  }
}

class GuessItAnswerResult {
  final String questionId;
  final String chosen;
  final String? correctOption;
  final bool isCorrect;
  final int score;
  final int timeMs;
  final int hintLevel;

  /// "Did you know?" line shown after the answer (may be null).
  final String? fact;

  const GuessItAnswerResult({
    required this.questionId,
    required this.chosen,
    required this.correctOption,
    required this.isCorrect,
    required this.score,
    required this.timeMs,
    required this.hintLevel,
    this.fact,
  });

  factory GuessItAnswerResult.fromMap(Map<String, dynamic> map) {
    return GuessItAnswerResult(
      questionId: map['question_id'] as String,
      chosen: map['chosen'] as String,
      correctOption: map['correct_option'] as String?,
      isCorrect: map['is_correct'] as bool? ?? false,
      score: (map['score'] as num?)?.toInt() ?? 0,
      timeMs: (map['time_ms'] as num?)?.toInt() ?? 0,
      hintLevel: (map['hint_level'] as num?)?.toInt() ?? 0,
      fact: (map['fact'] as String?)?.trim().isEmpty ?? true ? null : (map['fact'] as String).trim(),
    );
  }
}

class GuessItHintResult {
  final int hintLevel;
  final Set<String> eliminatedOptions;
  final int coinsSpent;
  final int coinsBalance;
  final bool free;

  const GuessItHintResult({
    required this.hintLevel,
    required this.eliminatedOptions,
    required this.coinsSpent,
    required this.coinsBalance,
    this.free = false,
  });

  factory GuessItHintResult.fromMap(Map<String, dynamic> map) {
    return GuessItHintResult(
      hintLevel: (map['hint_level'] as num?)?.toInt() ?? 0,
      eliminatedOptions: ((map['eliminated_options'] as List?) ?? const [])
          .map((e) => e as String)
          .toSet(),
      coinsSpent: (map['coins_spent'] as num?)?.toInt() ?? 0,
      coinsBalance: (map['coins_balance'] as num?)?.toInt() ?? 0,
      free: map['free'] as bool? ?? false,
    );
  }
}

class GuessItGameResult {
  final int score;
  final int total;
  final int correct;
  final int xpEarned;
  final int coinsEarned;
  final int? newXp;
  final int? newLevel;
  final bool leveledUp;
  final int bestScore;

  const GuessItGameResult({
    required this.score,
    required this.total,
    required this.correct,
    required this.xpEarned,
    required this.coinsEarned,
    required this.newXp,
    required this.newLevel,
    required this.leveledUp,
    required this.bestScore,
  });

  factory GuessItGameResult.fromMap(Map<String, dynamic> map) {
    return GuessItGameResult(
      score: (map['score'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      correct: (map['correct'] as num?)?.toInt() ?? 0,
      xpEarned: (map['xp_earned'] as num?)?.toInt() ?? 0,
      coinsEarned: (map['coins_earned'] as num?)?.toInt() ?? 0,
      newXp: (map['new_xp'] as num?)?.toInt(),
      newLevel: (map['new_level'] as num?)?.toInt(),
      leveledUp: map['leveled_up'] as bool? ?? false,
      bestScore: (map['best_score'] as num?)?.toInt() ?? 0,
    );
  }
}
