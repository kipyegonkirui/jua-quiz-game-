/// Result of a practice round. Mirrors AttemptResult minus the streak
/// fields — practice never touches the daily streak, so there are none to
/// report.
class PracticeResult {
  final int score;
  final int total;
  final int xpEarned;
  final int newXp;
  final int newLevel;
  final bool leveledUp;

  PracticeResult({
    required this.score,
    required this.total,
    required this.xpEarned,
    required this.newXp,
    required this.newLevel,
    required this.leveledUp,
  });

  factory PracticeResult.fromMap(Map<String, dynamic> map) {
    return PracticeResult(
      score: map['score'] as int,
      total: map['total'] as int,
      xpEarned: map['xp_earned'] as int,
      newXp: map['new_xp'] as int,
      newLevel: map['new_level'] as int,
      leveledUp: map['leveled_up'] as bool,
    );
  }
}