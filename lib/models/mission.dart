enum MissionKind {
  answerQuestions,
  correctAnswers,
  earnXp,
  completeRounds,
  perfectRound,
}

MissionKind missionKindFromString(String value) => switch (value) {
      'answer_questions' => MissionKind.answerQuestions,
      'correct_answers' => MissionKind.correctAnswers,
      'earn_xp' => MissionKind.earnXp,
      'complete_rounds' => MissionKind.completeRounds,
      'perfect_round' => MissionKind.perfectRound,
      _ => throw ArgumentError('Unknown mission kind: $value'),
    };

class Mission {
  final String id;
  final DateTime missionDate;
  final MissionKind kind;
  final String title;
  final String description;
  final int target;
  final int progress;
  final int rewardXp;
  final int rewardCoins;
  final DateTime? claimedAt;

  const Mission({
    required this.id,
    required this.missionDate,
    required this.kind,
    required this.title,
    required this.description,
    required this.target,
    required this.progress,
    required this.rewardXp,
    required this.rewardCoins,
    this.claimedAt,
  });

  bool get completed => progress >= target;
  bool get claimed => claimedAt != null;
  double get progressFraction => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  factory Mission.fromMap(Map<String, dynamic> map) {
    return Mission(
      id: map['id'] as String,
      missionDate: DateTime.parse(map['mission_date'] as String),
      kind: missionKindFromString(map['kind'] as String),
      title: map['title'] as String,
      description: map['description'] as String,
      target: (map['target'] as num).toInt(),
      progress: (map['progress'] as num).toInt(),
      rewardXp: (map['reward_xp'] as num).toInt(),
      rewardCoins: (map['reward_coins'] as num).toInt(),
      claimedAt: map['claimed_at'] == null ? null : DateTime.parse(map['claimed_at'] as String),
    );
  }
}

class MissionClaimResult {
  final bool claimed;
  final int balance;
  final int xpAwarded;
  final int coinsAwarded;
  final int newXp;
  final int newLevel;
  final bool leveledUp;

  const MissionClaimResult({
    required this.claimed,
    required this.balance,
    required this.xpAwarded,
    required this.coinsAwarded,
    required this.newXp,
    required this.newLevel,
    required this.leveledUp,
  });

  factory MissionClaimResult.fromMap(Map<String, dynamic> map) => MissionClaimResult(
        claimed: (map['claimed'] as bool?) ?? false,
        balance: (map['balance'] as num?)?.toInt() ?? 0,
        xpAwarded: (map['xp_awarded'] as num?)?.toInt() ?? 0,
        coinsAwarded: (map['coins_awarded'] as num?)?.toInt() ?? 0,
        newXp: (map['new_xp'] as num?)?.toInt() ?? 0,
        newLevel: (map['new_level'] as num?)?.toInt() ?? 1,
        leveledUp: (map['leveled_up'] as bool?) ?? false,
      );
}
