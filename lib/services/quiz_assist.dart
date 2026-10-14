import 'ads_service.dart';
import 'supabase_service.dart';

/// Outcome of "watch a video to unlock a hint / second chance".
enum RewardOutcome {
  /// Video watched and the server recorded the reward.
  granted,

  /// Video was closed before the reward was earned.
  skipped,

  /// No video could be shown. The game just carries on without the bonus.
  unavailable,
}

/// The one place that ties a rewarded video to a server-side reward, shared by
/// the daily challenge and practice rounds.
class QuizAssist {
  QuizAssist._();

  /// Plays a rewarded video and, if it was earned, asks the server to record
  /// the reward. [kind] is 'hint' or 'second_chance'.
  ///
  /// Throws only if the server refuses or can't be reached AFTER the video was
  /// earned (callers show [messageFor]); ad problems come back as an outcome.
  static Future<RewardOutcome> watchAndClaim({
    required String contextType,
    required String contextId,
    required String questionId,
    required String kind,
  }) async {
    final shown = await AdCoordinator.showRewarded();
    if (shown == RewardedResult.unavailable) return RewardOutcome.unavailable;
    if (shown == RewardedResult.notEarned) return RewardOutcome.skipped;

    Future<void> claim() => SupabaseService.instance.claimReward(
          contextType: contextType,
          contextId: contextId,
          questionId: questionId,
          kind: kind,
        );

    try {
      await claim();
    } catch (e) {
      // The video is already watched, so give a flaky connection one more go
      // before telling the player something went wrong. Server refusals
      // (limit reached etc.) are not retried.
      if (_isServerRefusal(e)) rethrow;
      await Future<void>.delayed(const Duration(seconds: 1));
      await claim();
    }
    return RewardOutcome.granted;
  }

  static bool _isServerRefusal(Object e) {
    final s = e.toString();
    return s.contains('limit_reached') ||
        s.contains('question_answered') ||
        s.contains('not_pending') ||
        s.contains('not today') ||
        s.contains('already');
  }

  /// A friendly sentence for any error raised by the reward / hint calls.
  static String messageFor(Object e) {
    final s = e.toString();
    if (s.contains('limit_reached')) {
      return 'You\'ve used all the help available for this round.';
    }
    if (s.contains('question_answered') || s.contains('not_pending')) {
      return 'That\'s no longer available for this question.';
    }
    if (s.contains('reward_required')) {
      return 'Watch the video first to unlock that.';
    }
    if (s.contains('not_enough_coins')) {
      return 'You don\'t have enough coins for that.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// A friendly sentence for errors from the competition calls.
  static String competitionMessage(Object e) {
    final s = e.toString();
    if (s.contains('not_started')) return 'This competition hasn\'t started yet.';
    if (s.contains('closed')) return 'This competition has closed.';
    if (s.contains('not_settled')) return 'Results aren\'t ready yet. Check back in a moment.';
    return 'Something went wrong. Check your connection and try again.';
  }

  /// Shown when the video didn't play or wasn't finished.
  static String messageForOutcome(RewardOutcome o) {
    switch (o) {
      case RewardOutcome.skipped:
        return 'Watch the whole video to unlock it.';
      case RewardOutcome.unavailable:
        return 'No video is available right now. Try again in a moment.';
      case RewardOutcome.granted:
        return '';
    }
  }
}
