import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/progression/achievement_service.dart';
import 'package:jua_quiz/models/achievement.dart';

Achievement _a({DateTime? unlockedAt, DateTime? claimedAt}) => Achievement(
      id: '1', code: 'test', title: 'Test', description: 'Test', icon: 'star',
      target: 1, rewardXp: 10, rewardCoins: 5, sortOrder: 1,
      unlockedAt: unlockedAt, claimedAt: claimedAt,
    );

void main() {
  test('counts unlocked and claimed achievements', () {
    final items = [_a(), _a(unlockedAt: DateTime.utc(2026, 1, 1)), _a(unlockedAt: DateTime.utc(2026, 1, 1), claimedAt: DateTime.utc(2026, 1, 1))];
    expect(AchievementService.unlockedCount(items), 2);
    expect(AchievementService.claimedCount(items), 1);
  });

  test('only unlocked unclaimed achievements can be claimed', () {
    expect(AchievementService.canClaim(_a()), isFalse);
    expect(AchievementService.canClaim(_a(unlockedAt: DateTime.utc(2026, 1, 1))), isTrue);
    expect(AchievementService.canClaim(_a(unlockedAt: DateTime.utc(2026, 1, 1), claimedAt: DateTime.utc(2026, 1, 1))), isFalse);
  });
}
