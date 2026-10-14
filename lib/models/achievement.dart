enum AchievementStatus { locked, unlocked, claimed }

class Achievement {
  final String id;
  final String code;
  final String title;
  final String description;
  final String icon;
  final int target;
  final int rewardXp;
  final int rewardCoins;
  final int sortOrder;
  final DateTime? unlockedAt;
  final DateTime? claimedAt;

  const Achievement({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
    required this.rewardXp,
    required this.rewardCoins,
    required this.sortOrder,
    this.unlockedAt,
    this.claimedAt,
  });

  AchievementStatus get status => claimedAt != null
      ? AchievementStatus.claimed
      : unlockedAt != null
          ? AchievementStatus.unlocked
          : AchievementStatus.locked;

  bool get unlocked => unlockedAt != null;
  bool get claimed => claimedAt != null;

  factory Achievement.fromMap(Map<String, dynamic> map) => Achievement(
        id: map['id'] as String,
        code: map['code'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        icon: map['icon'] as String,
        target: (map['target'] as num).toInt(),
        rewardXp: (map['reward_xp'] as num).toInt(),
        rewardCoins: (map['reward_coins'] as num).toInt(),
        sortOrder: (map['sort_order'] as num).toInt(),
        unlockedAt: map['unlocked_at'] == null ? null : DateTime.parse(map['unlocked_at'] as String),
        claimedAt: map['claimed_at'] == null ? null : DateTime.parse(map['claimed_at'] as String),
      );
}

class AchievementClaimResult {
  final bool claimed;
  final int balance;
  final int xpAwarded;
  final int coinsAwarded;
  final int newXp;
  final int newLevel;
  final bool leveledUp;

  const AchievementClaimResult({
    required this.claimed,
    required this.balance,
    required this.xpAwarded,
    required this.coinsAwarded,
    required this.newXp,
    required this.newLevel,
    required this.leveledUp,
  });

  factory AchievementClaimResult.fromMap(Map<String, dynamic> map) => AchievementClaimResult(
        claimed: (map['claimed'] as bool?) ?? false,
        balance: (map['balance'] as num?)?.toInt() ?? 0,
        xpAwarded: (map['xp_awarded'] as num?)?.toInt() ?? 0,
        coinsAwarded: (map['coins_awarded'] as num?)?.toInt() ?? 0,
        newXp: (map['new_xp'] as num?)?.toInt() ?? 0,
        newLevel: (map['new_level'] as num?)?.toInt() ?? 1,
        leveledUp: (map['leveled_up'] as bool?) ?? false,
      );
}
