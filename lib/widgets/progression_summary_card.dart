import 'package:flutter/material.dart';

import '../game/progression/achievement_service.dart';
import '../game/progression/mission_service.dart';
import '../game/progression/xp_progression_service.dart';
import '../game/progression/reward_chest_service.dart';
import '../models/achievement.dart';
import '../models/mission.dart';
import '../models/reward_chest.dart';
import '../models/user_profile.dart';
import '../services/app_events.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../screens/achievements_screen.dart';
import '../screens/missions_screen.dart';
import '../screens/reward_chests_screen.dart';
import '../screens/streak_dashboard_screen.dart';

/// A compact projection of the player's progression state on the Play home.
/// The server remains authoritative; this widget only renders the latest
/// AppEvents profile snapshot and refreshes mission/achievement summaries.
class ProgressionSummaryCard extends StatefulWidget {
  /// Compact layout for the game hub: shorter header and a single row of
  /// icon tiles, so the game cards get most of the screen.
  final bool compact;

  const ProgressionSummaryCard({super.key, this.compact = false});

  @override
  State<ProgressionSummaryCard> createState() => _ProgressionSummaryCardState();
}

class _ProgressionSummaryCardState extends State<ProgressionSummaryCard> {
  List<Mission> _missions = const [];
  List<Achievement> _achievements = const [];
  List<RewardChest> _chests = const [];
  bool _loadingExtras = false;

  @override
  void initState() {
    super.initState();
    AppEvents.dataVersion.addListener(_refreshExtras);
    _refreshExtras();
  }

  @override
  void dispose() {
    AppEvents.dataVersion.removeListener(_refreshExtras);
    super.dispose();
  }

  Future<void> _refreshExtras() async {
    final profile = AppEvents.profile.value;
    if (!mounted || profile == null || profile.isGuest || _loadingExtras) return;

    _loadingExtras = true;
    try {
      final results = await Future.wait<dynamic>([
        SupabaseService.instance.getDailyMissions(),
        SupabaseService.instance.syncAchievements().then((_) => SupabaseService.instance.getAchievements()),
        SupabaseService.instance.syncRewardChests().then((_) => SupabaseService.instance.getRewardChests()),
      ]);
      if (!mounted) return;
      setState(() {
        _missions = results[0] as List<Mission>;
        _achievements = results[1] as List<Achievement>;
        _chests = results[2] as List<RewardChest>;
      });
    } catch (_) {
      // Progression must never block the game hub if a summary RPC fails.
    } finally {
      _loadingExtras = false;
    }
  }

  void _openMissions() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MissionsScreen()));
  }

  void _openAchievements() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen()));
  }

  void _openStreak() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StreakDashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AppEvents.profile,
      builder: (context, profile, _) {
        if (profile == null) return const SizedBox.shrink();

        final xpState = XpProgressionService.fromXp(profile.xp);
        final completedMissions = MissionService.completedCount(_missions);
        final unlockedAchievements = AchievementService.unlockedCount(_achievements);
        final claimableAchievements = _achievements.where(AchievementService.canClaim).length;
        final claimableMissions = _missions.where(MissionService.canClaim).length;
        final availableChests = RewardChestService.availableCount(_chests);

        return Container(
          margin: EdgeInsets.fromLTRB(14, 4, 14, widget.compact ? 6 : 10),
          padding: EdgeInsets.fromLTRB(16, widget.compact ? 10 : 14, 16, widget.compact ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.savannaGreen.withValues(alpha: 0.10)),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.sunGold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: AppColors.sunGold, size: 25),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Level ${xpState.level}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.inkBrown)),
                        const SizedBox(height: 2),
                        Text(widget.compact ? '${xpState.xpIntoLevel}/${XpProgressionService.xpPerLevel} XP' : '${xpState.xpIntoLevel}/${XpProgressionService.xpPerLevel} XP to next level', style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
                      ],
                    ),
                  ),
                  _MiniBalance(icon: Icons.monetization_on_rounded, value: '${profile.coins}'),
                  const SizedBox(width: 8),
                  _MiniBalance(icon: Icons.local_fire_department_rounded, value: '${profile.currentStreak}'),
                  const SizedBox(width: 8),
                  _MiniBalance(icon: Icons.shield_rounded, value: '${profile.streakShields}'),
                ],
              ),
              SizedBox(height: widget.compact ? 8 : 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: xpState.progress,
                  minHeight: widget.compact ? 8 : 9,
                  backgroundColor: Colors.black12,
                  color: AppColors.sunGold,
                ),
              ),
              SizedBox(height: widget.compact ? 8 : 10),
              if (widget.compact)
                Row(
                  children: [
                    Expanded(child: _CompactAction(icon: Icons.flag_rounded, label: 'Missions', badge: claimableMissions > 0 ? '$claimableMissions' : null, onTap: _openMissions)),
                    const SizedBox(width: 6),
                    Expanded(child: _CompactAction(icon: Icons.workspace_premium_rounded, label: 'Awards', badge: claimableAchievements > 0 ? '$claimableAchievements' : null, onTap: _openAchievements)),
                    const SizedBox(width: 6),
                    Expanded(child: _CompactAction(icon: Icons.local_fire_department_rounded, label: 'Streak', onTap: _openStreak)),
                    if (_chests.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(child: _CompactAction(icon: Icons.inventory_2_rounded, label: 'Chests', badge: availableChests > 0 ? '$availableChests' : null, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardChestsScreen())))),
                    ],
                  ],
                )
              else ...[
              Row(
                children: [
                  Expanded(
                    child: _ProgressionAction(
                      icon: Icons.flag_rounded,
                      label: 'Missions',
                      detail: _missions.isEmpty ? 'Today' : '$completedMissions/${_missions.length} done',
                      badge: claimableMissions > 0 ? '$claimableMissions' : null,
                      onTap: _openMissions,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ProgressionAction(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Achievements',
                      detail: _achievements.isEmpty ? 'Progress' : '$unlockedAchievements/${_achievements.length} unlocked',
                      badge: claimableAchievements > 0 ? '$claimableAchievements' : null,
                      onTap: _openAchievements,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _ProgressionAction(
                icon: Icons.local_fire_department_rounded,
                label: 'Streak',
                detail: profile.currentStreak > 0
                    ? '${profile.currentStreak}-day streak • ${profile.streakShields} shield${profile.streakShields == 1 ? '' : 's'}'
                    : 'Start your streak',
                onTap: _openStreak,
              ),
              if (_chests.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ProgressionAction(
                  icon: Icons.inventory_2_rounded,
                  label: 'Reward Chests',
                  detail: availableChests > 0 ? '$availableChests ready to open' : '${RewardChestService.claimedCount(_chests)} claimed',
                  badge: availableChests > 0 ? '$availableChests' : null,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RewardChestsScreen())),
                ),
              ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MiniBalance extends StatelessWidget {
  final IconData icon;
  final String value;

  const _MiniBalance({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.juaSkyBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.juaSkyBlue),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.inkBrown)),
        ],
      ),
    );
  }
}

class _ProgressionAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final String? badge;
  final VoidCallback onTap;

  const _ProgressionAction({required this.icon, required this.label, required this.detail, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivory,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.savannaGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: AppColors.inkBrown)),
                    const SizedBox(height: 1),
                    Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.earthRed, borderRadius: BorderRadius.circular(999)),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CompactAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _CompactAction({required this.icon, required this.label, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivory,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22, color: AppColors.savannaGreen),
                    const SizedBox(height: 2),
                    Text(label, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10.5, color: AppColors.inkBrown)),
                  ],
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -5,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.earthRed, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 1.5)),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
