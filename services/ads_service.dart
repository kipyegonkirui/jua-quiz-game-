enum RewardedResult { unavailable, notEarned, earned }

class AdCoordinator {
  static void preloadRewarded() {}
  static Future<RewardedResult> showRewarded() async {
    return RewardedResult.earned;
  }
}
