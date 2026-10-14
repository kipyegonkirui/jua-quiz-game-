import '../widgets/jua_dialog.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/app_events.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _future;
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.instance.getLeaderboard();
    AppEvents.dataVersion.addListener(_onProgressChanged);
    AppEvents.tabRequest.addListener(_onTabRequested);
    AppEvents.profile.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    AppEvents.dataVersion.removeListener(_onProgressChanged);
    AppEvents.profile.removeListener(_onProfileChanged);
    AppEvents.tabRequest.removeListener(_onTabRequested);
    super.dispose();
  }

  // A round publishes the confirmed profile before the network refresh.
  // Rebuild immediately so the player's own XP changes without waiting for
  // the leaderboard query to finish.
  void _onProgressChanged() {
    if (!mounted) return;
    setState(() {});
    _refreshInBackground();
  }

  // Keep the row responsive even when the profile notifier changes directly.
  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  // IndexedStack keeps this screen alive, so initState is not called again
  // when the user returns to the tab. Refresh quietly so the current snapshot
  // remains visible while the remote leaderboard is re-read.
  void _onTabRequested() {
    if (!mounted || AppEvents.tabRequest.value != AppTabs.leaderboard) return;
    _refreshInBackground();
  }

  Future<void> _refresh() async {
    final token = ++_refreshToken;
    final future = SupabaseService.instance.getLeaderboard();
    if (mounted) setState(() => _future = future);
    try {
      final entries = await future;
      if (!mounted || token != _refreshToken) return;
      setState(() => _future = Future.value(entries));
    } catch (_) {
      if (!mounted || token != _refreshToken) return;
      // Keep the currently displayed snapshot when a manual refresh fails.
    }
  }

  Future<void> _refreshInBackground() async {
    final token = ++_refreshToken;
    try {
      final entries = await SupabaseService.instance.getLeaderboard();
      if (!mounted || token != _refreshToken) return;
      setState(() => _future = Future.value(entries));
    } catch (_) {
      // The optimistic current-user row is already visible; keep it on error.
    }
  }

  List<LeaderboardEntry> _withCurrentProfile(List<LeaderboardEntry> entries) {
    final profile = AppEvents.profile.value;
    final uid = SupabaseService.instance.currentUser?.id;
    if (profile == null || uid == null) return entries;

    final updated = List<LeaderboardEntry>.from(entries);
    final current = LeaderboardEntry(
      id: uid,
      username: profile.username,
      xp: profile.xp,
      level: profile.level,
      currentStreak: profile.currentStreak,
    );
    final index = updated.indexWhere((e) => e.id == uid);
    if (index >= 0) {
      updated[index] = current;
    } else {
      updated.add(current);
    }
    updated.sort((a, b) {
      final xp = b.xp.compareTo(a.xp);
      if (xp != 0) return xp;
      return a.username.compareTo(b.username);
    });
    return updated;
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.instance.currentUser?.id;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Leaderboard', style: juaSceneTitleStyle),
            ),
          ),
          if (SupabaseService.instance.isGuest)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6D6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFC53D), width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_outlined, color: AppColors.sunGold),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Guest scores appear here too. Create an account only if you want to restore your progress after reinstalling.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF14235E)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Create account',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AccountScreen(mode: AccountFlowMode.createAccount)),
                      ),
                      icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF14235E)),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<LeaderboardEntry>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final entries = _withCurrentProfile(snapshot.data!);
                if (entries.isEmpty) {
                  return const JuaStateCard(
                    title: 'No scores yet',
                    message: 'Be the first on the board!',
                    art: JuaDialogArt.starLaurel,
                    tone: JuaDialogTone.blue,
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = entries[i];
                      final isMe = e.id == myId;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFFFFF0B8) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isMe ? const Color(0xFFFFB300) : Colors.black12, width: isMe ? 2 : 1),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text('${i + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(e.username,
                                  style: TextStyle(fontWeight: isMe ? FontWeight.w800 : FontWeight.w500)),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department_rounded, size: 16, color: AppColors.earthRed),
                                const SizedBox(width: 2),
                                Text('${e.currentStreak}', style: const TextStyle(color: Colors.black54)),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Text('${e.xp} XP', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
