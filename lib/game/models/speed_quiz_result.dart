class SpeedQuizResult {
  final int score;
  final int total;
  final int correct;
  final int xpEarned;
  final int newXp;
  final int newLevel;
  final bool leveledUp;
  final int currentStreak;
  final int longestStreak;
  final int coinsEarned;

  const SpeedQuizResult({
    required this.score,
    required this.total,
    required this.correct,
    required this.xpEarned,
    required this.newXp,
    required this.newLevel,
    required this.leveledUp,
    required this.currentStreak,
    required this.longestStreak,
    this.coinsEarned = 0,
  });

  factory SpeedQuizResult.fromMap(Map<String, dynamic> map) {
    return SpeedQuizResult(
      score: (map['score'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      correct: (map['correct'] as num?)?.toInt() ?? 0,
      xpEarned: (map['xp_earned'] as num?)?.toInt() ?? 0,
      newXp: (map['new_xp'] as num?)?.toInt() ?? 0,
      newLevel: (map['new_level'] as num?)?.toInt() ?? 1,
      leveledUp: map['leveled_up'] as bool? ?? false,
      currentStreak: (map['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longest_streak'] as num?)?.toInt() ?? 0,
      coinsEarned: (map['coins_earned'] as num?)?.toInt() ?? 0,
    );
  }
}
