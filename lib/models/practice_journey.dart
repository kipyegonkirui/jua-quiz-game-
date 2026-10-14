class PracticeLevelProgress {
  final int level;
  final int batch;
  final int questionCount;
  final String difficulty;
  final int stars;
  final bool completed;
  final bool unlocked;

  /// Every 10th level is a Math level (matches practice_is_math_level in SQL).
  bool get isMath => level % 10 == 0;

  const PracticeLevelProgress({
    required this.level,
    required this.batch,
    required this.questionCount,
    required this.difficulty,
    required this.stars,
    required this.completed,
    required this.unlocked,
  });

  factory PracticeLevelProgress.fromMap(Map<String, dynamic> map) {
    return PracticeLevelProgress(
      level: (map['level'] as num).toInt(),
      batch: (map['batch'] as num).toInt(),
      questionCount: (map['question_count'] as num).toInt(),
      difficulty: (map['difficulty'] as String?) ?? 'medium',
      stars: (map['stars'] as num?)?.toInt() ?? 0,
      completed: map['completed'] as bool? ?? false,
      unlocked: map['unlocked'] as bool? ?? false,
    );
  }
}

class PracticeJourneyData {
  final int currentLevel;
  final int cumulativeStars;
  final int cumulativeAvailableStars;
  final int nextBatch;
  final int nextBatchRequirement;
  final int nextBatchAvailableStars;
  final int nextBatchRequirementPercent;
  final int adUnlocksUsed;
  final int adUnlocksPerBatch;
  final List<PracticeLevelProgress> levels;

  const PracticeJourneyData({
    required this.currentLevel,
    required this.cumulativeStars,
    required this.cumulativeAvailableStars,
    required this.nextBatch,
    required this.nextBatchRequirement,
    required this.nextBatchAvailableStars,
    required this.nextBatchRequirementPercent,
    required this.adUnlocksUsed,
    required this.adUnlocksPerBatch,
    required this.levels,
  });

  factory PracticeJourneyData.fromMap(Map<String, dynamic> map) {
    final rawLevels = (map['levels'] as List?) ?? const [];
    return PracticeJourneyData(
      currentLevel: (map['current_level'] as num?)?.toInt() ?? 1,
      cumulativeStars: (map['cumulative_stars'] as num?)?.toInt() ?? 0,
      cumulativeAvailableStars:
          (map['cumulative_available_stars'] as num?)?.toInt() ?? 30,
      nextBatch: (map['next_batch'] as num?)?.toInt() ?? 0,
      nextBatchRequirement: (map['next_batch_requirement'] as num?)?.toInt() ?? 0,
      nextBatchAvailableStars:
          (map['next_batch_available_stars'] as num?)?.toInt() ?? 0,
      nextBatchRequirementPercent:
          (map['next_batch_requirement_percent'] as num?)?.toInt() ?? 0,
      adUnlocksUsed: (map['ad_unlocks_used'] as num?)?.toInt() ?? 0,
      adUnlocksPerBatch: (map['ad_unlocks_per_batch'] as num?)?.toInt() ?? 3,
      levels: rawLevels
          .whereType<Map>()
          .map((row) => PracticeLevelProgress.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false),
    );
  }

  int get nextBatchStarsRemaining =>
      (nextBatchRequirement - cumulativeStars).clamp(0, nextBatchRequirement);

  double get masteryProgress => cumulativeAvailableStars == 0
      ? 0
      : (cumulativeStars / cumulativeAvailableStars).clamp(0, 1).toDouble();
}

class PracticeJourneyRules {
  const PracticeJourneyRules._();

  static int batchForLevel(int level) => ((level - 1) ~/ 10) + 1;

  static int questionCountForLevel(int level) {
    final tier = (level - 1) ~/ 10;
    return 5 + (tier > 5 ? 5 : tier);
  }

  static String difficultyForBatch(int batch) {
    if (batch <= 2) return 'easy';
    if (batch <= 4) return 'medium';
    return 'hard';
  }

  static int requiredPercentForBatch(int batch) {
    if (batch == 2) return 50;
    if (batch == 3) return 75;
    if (batch == 4) return 80;
    if (batch == 5) return 85;
    if (batch == 6) return 88;
    return 90;
  }

  static int cumulativeAvailableStarsForBatch(int batch) => (batch - 1) * 10 * 3;

  static int requirementForBatch(int batch) {
    if (batch <= 1) return 0;
    final available = cumulativeAvailableStarsForBatch(batch);
    final percent = requiredPercentForBatch(batch);
    return ((available * percent) + 99) ~/ 100;
  }

  static int starsForScore({required int score, required int total}) {
    if (total <= 0 || score <= 0) return 0;
    final percent = (score * 100) ~/ total;
    if (percent >= 100) return 3;
    if (percent >= 70) return 2;
    return 1;
  }
}
