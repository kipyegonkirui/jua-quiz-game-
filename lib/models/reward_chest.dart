enum RewardChestStatus { locked, available, claimed }

class RewardChest {
  final String id;
  final String code;
  final String title;
  final String description;
  final String icon;
  final int requiredLevel;
  final int minCoins;
  final int maxCoins;
  final int rewardXp;
  final int sortOrder;
  final DateTime? unlockedAt;
  final DateTime? claimedAt;

  const RewardChest({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.requiredLevel,
    required this.minCoins,
    required this.maxCoins,
    required this.rewardXp,
    required this.sortOrder,
    this.unlockedAt,
    this.claimedAt,
  });

  RewardChestStatus get status => claimedAt != null
      ? RewardChestStatus.claimed
      : unlockedAt != null
          ? RewardChestStatus.available
          : RewardChestStatus.locked;

  bool get available => unlockedAt != null && claimedAt == null;
  bool get claimed => claimedAt != null;

  factory RewardChest.fromMap(Map<String, dynamic> map) => RewardChest(
        id: map['id'] as String,
        code: map['code'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        icon: map['icon'] as String,
        requiredLevel: (map['required_level'] as num).toInt(),
        minCoins: (map['min_coins'] as num).toInt(),
        maxCoins: (map['max_coins'] as num).toInt(),
        rewardXp: (map['reward_xp'] as num).toInt(),
        sortOrder: (map['sort_order'] as num).toInt(),
        unlockedAt: map['unlocked_at'] == null ? null : DateTime.parse(map['unlocked_at'] as String),
        claimedAt: map['claimed_at'] == null ? null : DateTime.parse(map['claimed_at'] as String),
      );
}

class RewardChestClaimResult {
  final bool claimed;
  final int balance;
  final int coinsAwarded;
  final int xpAwarded;
  final int newXp;
  final int newLevel;
  final bool leveledUp;

  const RewardChestClaimResult({
    required this.claimed,
    required this.balance,
    required this.coinsAwarded,
    required this.xpAwarded,
    required this.newXp,
    required this.newLevel,
    required this.leveledUp,
  });

  factory RewardChestClaimResult.fromMap(Map<String, dynamic> map) => RewardChestClaimResult(
        claimed: (map['claimed'] as bool?) ?? false,
        balance: (map['balance'] as num?)?.toInt() ?? 0,
        coinsAwarded: (map['coins_awarded'] as num?)?.toInt() ?? 0,
        xpAwarded: (map['xp_awarded'] as num?)?.toInt() ?? 0,
        newXp: (map['new_xp'] as num?)?.toInt() ?? 0,
        newLevel: (map['new_level'] as num?)?.toInt() ?? 1,
        leveledUp: (map['leveled_up'] as bool?) ?? false,
      );
}
