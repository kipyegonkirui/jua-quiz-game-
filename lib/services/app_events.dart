import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// Tab positions in the bottom navigation bar. Index 0 is the Play/game hub.
class AppTabs {
  static const today = 0;
  static const compete = 1;
  static const leaderboard = 2;
  static const stats = 3;
}

/// Tiny app-wide signals so screens can talk to each other without knowing
/// about each other.
class AppEvents {
  AppEvents._();

  /// The shell listens to this and switches tabs. Any screen can call
  /// [goToTab] to return to the main Play, Compete, Leaderboard, or Stats tabs.
  static final ValueNotifier<int> tabRequest = ValueNotifier<int>(AppTabs.today);
  static void goToTab(int index) => tabRequest.value = index;

  /// Bumped after any round is submitted. Stats and Leaderboard listen and
  /// reload themselves, so they're never stale when you switch to them.
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  /// The latest confirmed profile snapshot. Screens render this immediately
  /// after a round instead of waiting for a network read to finish.
  static final ValueNotifier<UserProfile?> profile = ValueNotifier<UserProfile?>(null);

  static void publishProfile(UserProfile value) {
    profile.value = value;
    dataVersion.value++;
  }

  static void notifyProgressChanged() => dataVersion.value++;

  /// Main tabs that currently have a question on screen. The shell hides the
  /// banner on those tabs so it never sits next to answer buttons. Full-screen
  /// game routes (Practice/Daily/Speed Quiz) use the Play tab's slot.
  static final ValueNotifier<Set<int>> tabsWithQuiz = ValueNotifier<Set<int>>(<int>{});
  static void setQuizActive(int tab, bool active) {
    final current = tabsWithQuiz.value;
    if (current.contains(tab) == active) return; // no change, no rebuild
    final next = Set<int>.of(current);
    active ? next.add(tab) : next.remove(tab);
    tabsWithQuiz.value = next;
  }
}
