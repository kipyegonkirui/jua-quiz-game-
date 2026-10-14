import '../../models/reward_chest.dart';

class RewardChestService {
  const RewardChestService._();

  static int availableCount(List<RewardChest> chests) => chests.where((c) => c.available).length;

  static int claimedCount(List<RewardChest> chests) => chests.where((c) => c.claimed).length;

  static RewardChest? firstAvailable(List<RewardChest> chests) {
    for (final chest in chests) {
      if (chest.available) return chest;
    }
    return null;
  }
}
