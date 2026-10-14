class AttemptResult {
  final int score;
  final int total;
  final int xpEarned;
  final int newXp;
  final int newLevel;
  final bool leveledUp;
  final int currentStreak;
  final int longestStreak;
  final int coinsEarned;
  final int streakShields;
  final int streakShieldsAwarded;
  final bool streakShieldUsed;

  // Only sent for practice rounds (null for the daily challenge).
  final bool xpCapped;
  final int? practiceXpToday;
  final int? practiceXpCap;

  // Practice Journey metadata. Null for daily challenge results.
  final int? practiceLevel;
  final int? practiceStars;
  final int? cumulativePracticeStars;
  final int? cumulativePracticeAvailableStars;
  final int? nextPracticeBatch;
  final int? nextPracticeBatchRequirement;

  AttemptResult({
    required this.score,
    required this.total,
    required this.xpEarned,
    required this.newXp,
    required this.newLevel,
    required this.leveledUp,
    required this.currentStreak,
    required this.longestStreak,
    this.coinsEarned = 0,
    this.streakShields = 0,
    this.streakShieldsAwarded = 0,
    this.streakShieldUsed = false,
    this.xpCapped = false,
    this.practiceXpToday,
    this.practiceXpCap,
    this.practiceLevel,
    this.practiceStars,
    this.cumulativePracticeStars,
    this.cumulativePracticeAvailableStars,
    this.nextPracticeBatch,
    this.nextPracticeBatchRequirement,
  });

  factory AttemptResult.fromMap(Map<String, dynamic> map) {
    return AttemptResult(
      score: map['score'] as int,
      total: map['total'] as int,
      xpEarned: map['xp_earned'] as int,
      newXp: map['new_xp'] as int,
      newLevel: map['new_level'] as int,
      leveledUp: map['leveled_up'] as bool,
      currentStreak: map['current_streak'] as int,
      longestStreak: map['longest_streak'] as int,
      coinsEarned: (map['coins_earned'] as num?)?.toInt() ?? 0,
      streakShields: (map['streak_shields'] as num?)?.toInt() ?? 0,
      streakShieldsAwarded: (map['streak_shields_awarded'] as num?)?.toInt() ?? 0,
      streakShieldUsed: (map['streak_shield_used'] as bool?) ?? false,
      xpCapped: (map['xp_capped'] as bool?) ?? false,
      practiceXpToday: map['practice_xp_today'] as int?,
      practiceXpCap: (map['practice_xp_cap'] as num?)?.toInt(),
      practiceLevel: (map['practice_level'] as num?)?.toInt(),
      practiceStars: (map['practice_stars'] as num?)?.toInt(),
      cumulativePracticeStars: (map['cumulative_practice_stars'] as num?)?.toInt(),
      cumulativePracticeAvailableStars: (map['cumulative_practice_available_stars'] as num?)?.toInt(),
      nextPracticeBatch: (map['next_practice_batch'] as num?)?.toInt(),
      nextPracticeBatchRequirement: (map['next_practice_batch_requirement'] as num?)?.toInt(),
    );
  }
}
