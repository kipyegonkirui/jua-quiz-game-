import 'package:flutter/material.dart';
import '../services/ads_service.dart';
import '../services/app_events.dart';
import '../theme/app_theme.dart';
import 'competitions_screen.dart';
import 'game_hub_screen.dart';
import 'leaderboard_screen.dart';
import 'stats_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = AppTabs.today;

  // Order must match AppTabs in services/app_events.dart.
  final _screens = const [
    GameHubScreen(),
    CompetitionsScreen(),
    LeaderboardScreen(),
    StatsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AppEvents.tabRequest.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    AppEvents.tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  Future<void> _onTabRequest() async {
    final requested = AppEvents.tabRequest.value;
    if (requested == _index) return;
    // If a round just finished, its interstitial plays now, on the way out.
    await AdCoordinator.showPendingIfAny();
    // Re-read: the player may have tapped another tab while the ad was up.
    if (mounted) setState(() => _index = AppEvents.tabRequest.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The app's single banner. Hidden while a question is on screen.
          ValueListenableBuilder<Set<int>>(
            valueListenable: AppEvents.tabsWithQuiz,
            builder: (context, quizTabs, _) =>
                quizTabs.contains(_index) ? const SizedBox.shrink() : const BannerAdWidget(),
          ),
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed, // required for 4+ tabs to keep labels visible
            currentIndex: _index,
            onTap: AppEvents.goToTab,
            items: [
              BottomNavigationBarItem(
                icon: _JuaNavIcon(icon: Icons.sports_esports_rounded),
                activeIcon: const _JuaNavIcon(icon: Icons.sports_esports_rounded, active: true),
                label: 'Play',
              ),
              BottomNavigationBarItem(
                icon: _JuaNavIcon(icon: Icons.emoji_events_rounded),
                activeIcon: const _JuaNavIcon(icon: Icons.emoji_events_rounded, active: true),
                label: 'Compete',
              ),
              BottomNavigationBarItem(
                icon: _JuaNavIcon(icon: Icons.leaderboard_rounded),
                activeIcon: const _JuaNavIcon(icon: Icons.leaderboard_rounded, active: true),
                label: 'Leaderboard',
              ),
              BottomNavigationBarItem(
                icon: _JuaNavIcon(icon: Icons.insights_rounded),
                activeIcon: const _JuaNavIcon(icon: Icons.insights_rounded, active: true),
                label: 'Stats',
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _JuaNavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;

  const _JuaNavIcon({required this.icon, this.active = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: active ? 1.08 : 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: Container(
          width: 34,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: active ? 0.9 : 0.18),
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x25000000),
                      blurRadius: 7,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? AppColors.juaSkyBlue : Colors.white,
          ),
        ),
      ),
    );
  }
}
