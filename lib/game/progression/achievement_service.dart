import '../../models/achievement.dart';

class AchievementService {
  const AchievementService._();

  static int unlockedCount(Iterable<Achievement> achievements) => achievements.where((a) => a.unlocked).length;
  static int claimedCount(Iterable<Achievement> achievements) => achievements.where((a) => a.claimed).length;
  static bool canClaim(Achievement achievement) => achievement.unlocked && !achievement.claimed;
}
