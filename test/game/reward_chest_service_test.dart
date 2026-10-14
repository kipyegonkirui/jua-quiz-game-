import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/progression/reward_chest_service.dart';
import 'package:jua_quiz/models/reward_chest.dart';

RewardChest chest(String code, {DateTime? unlockedAt, DateTime? claimedAt}) => RewardChest(
      id: code,
      code: code,
      title: code,
      description: code,
      icon: 'inventory_2',
      requiredLevel: 2,
      minCoins: 10,
      maxCoins: 20,
      rewardXp: 0,
      sortOrder: 1,
      unlockedAt: unlockedAt,
      claimedAt: claimedAt,
    );

void main() {
  test('counts only available chests', () {
    final now = DateTime(2026, 1, 1);
    expect(RewardChestService.availableCount([
      chest('a', unlockedAt: now),
      chest('b'),
      chest('c', unlockedAt: now, claimedAt: now),
    ]), 1);
  });

  test('finds first available chest', () {
    final now = DateTime(2026, 1, 1);
    expect(RewardChestService.firstAvailable([
      chest('a'),
      chest('b', unlockedAt: now),
    ])?.code, 'b');
  });
}
