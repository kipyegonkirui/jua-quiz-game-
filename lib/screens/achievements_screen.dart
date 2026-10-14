import '../widgets/jua_dialog.dart';
import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../game/progression/achievement_service.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/reward_feedback.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _loading = true;
  String? _error;
  List<Achievement> _items = const [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      await SupabaseService.instance.syncAchievements();
      final items = await SupabaseService.instance.getAchievements();
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _claim(Achievement item) async {
    if (!AchievementService.canClaim(item)) return;
    try {
      final result = await SupabaseService.instance.claimAchievement(item.id);
      if (!mounted || !result.claimed) return;
      final rewards = <RewardFeedbackItem>[];
      if (result.xpAwarded > 0) rewards.add(RewardFeedbackItem.xp(result.xpAwarded));
      if (result.coinsAwarded > 0) rewards.add(RewardFeedbackItem.coins(result.coinsAwarded));
      await RewardCelebration.show(context, rewards: rewards, title: 'ACHIEVEMENT UNLOCKED!', subtitle: item.title, newLevel: result.newLevel, leveledUp: result.leveledUp);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not claim reward: $e')));
    }
  }

  IconData _icon(String name) => switch (name) {
        'flag' => Icons.flag_rounded,
        'quiz' => Icons.quiz_rounded,
        'target' => Icons.track_changes_rounded,
        'trophy' => Icons.emoji_events_rounded,
        'star' => Icons.star_rounded,
        'local_fire_department' => Icons.local_fire_department_rounded,
        'whatshot' => Icons.whatshot_rounded,
        'military_tech' => Icons.military_tech_rounded,
        'workspace_premium' => Icons.workspace_premium_rounded,
        _ => Icons.emoji_events_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final unlocked = AchievementService.unlockedCount(_items);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Achievements', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _error != null
                ? JuaStateCard.error(onPressed: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: .22)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 34),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('ACHIEVEMENTS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text('$unlocked/${_items.length} unlocked', style: TextStyle(color: Colors.white.withValues(alpha: .86), fontWeight: FontWeight.w700)),
                            ])),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        ..._items.map((item) => _AchievementCard(item: item, icon: _icon(item.icon), onClaim: () => _claim(item))),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Achievement item;
  final IconData icon;
  final VoidCallback onClaim;
  const _AchievementCard({required this.item, required this.icon, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final locked = !item.unlocked;
    final claimable = AchievementService.canClaim(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: locked ? Colors.white.withValues(alpha: .72) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: locked ? Colors.black12 : AppColors.sunGold),
          child: Icon(locked ? Icons.lock_rounded : icon, color: locked ? Colors.black38 : Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.title, style: const TextStyle(color: AppColors.inkBrown, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text(item.description, style: const TextStyle(color: Colors.black54, height: 1.25)),
          const SizedBox(height: 7),
          Text('+${item.rewardXp} XP  +${item.rewardCoins} coins', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54)),
        ])),
        const SizedBox(width: 8),
        if (item.claimed)
          const Icon(Icons.check_circle_rounded, color: AppColors.savannaGreen, size: 30)
        else if (claimable)
          JuaGlossyButton(label: 'Claim', icon: Icons.redeem_rounded, variant: JuaButtonVariant.play, onPressed: onClaim)
        else
          const Icon(Icons.lock_outline_rounded, color: Colors.black26, size: 26),
      ]),
    );
  }
}
