import '../widgets/jua_dialog.dart';
import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../game/progression/mission_service.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/reward_feedback.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  bool _loading = true;
  String? _error;
  List<Mission> _missions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final missions = await SupabaseService.instance.getDailyMissions();
      if (!mounted) return;
      setState(() { _missions = missions; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _claim(Mission mission) async {
    if (!MissionService.canClaim(mission)) return;
    try {
      final result = await SupabaseService.instance.claimMission(mission.id);
      if (!mounted || !result.claimed) return;
      final rewards = <RewardFeedbackItem>[];
      if (result.xpAwarded > 0) rewards.add(RewardFeedbackItem.xp(result.xpAwarded));
      if (result.coinsAwarded > 0) rewards.add(RewardFeedbackItem.coins(result.coinsAwarded));
      await RewardCelebration.show(context, rewards: rewards, title: 'MISSION COMPLETE!', subtitle: mission.title, newLevel: result.newLevel, leveledUp: result.leveledUp);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not claim reward: $e')));
    }
  }

  IconData _icon(MissionKind kind) => switch (kind) {
        MissionKind.answerQuestions => Icons.quiz_rounded,
        MissionKind.correctAnswers => Icons.check_circle_rounded,
        MissionKind.earnXp => Icons.bolt_rounded,
        MissionKind.completeRounds => Icons.sports_esports_rounded,
        MissionKind.perfectRound => Icons.star_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final completed = MissionService.completedCount(_missions);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Daily Missions', style: TextStyle(fontWeight: FontWeight.w900)),
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
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.flag_rounded, color: Colors.white, size: 34),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('TODAY\'S MISSIONS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  Text('$completed/${_missions.length} completed', style: TextStyle(color: Colors.white.withValues(alpha: .86), fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ..._missions.map((mission) => _MissionCard(mission: mission, icon: _icon(mission.kind), onClaim: () => _claim(mission))),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Mission mission;
  final IconData icon;
  final VoidCallback onClaim;

  const _MissionCard({required this.mission, required this.icon, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final finished = mission.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.sunGold, const Color(0xFFFF941A)]),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mission.title, style: const TextStyle(color: AppColors.inkBrown, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 4),
              Text(mission.description, style: const TextStyle(color: Colors.black54, height: 1.25)),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: mission.progressFraction,
                  minHeight: 8,
                  backgroundColor: const Color(0x16000000),
                  valueColor: AlwaysStoppedAnimation(finished ? AppColors.savannaGreen : AppColors.juaSkyBlue),
                ),
              ),
              const SizedBox(height: 5),
              Text('${mission.progress}/${mission.target}  •  +${mission.rewardXp} XP  +${mission.rewardCoins} coins', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
            ]),
          ),
          const SizedBox(width: 10),
          mission.claimed
              ? const Icon(Icons.check_circle_rounded, color: AppColors.savannaGreen, size: 30)
              : JuaGlossyButton(
                  label: finished ? 'Claim' : 'Locked',
                  icon: finished ? Icons.redeem_rounded : Icons.lock_rounded,
                  variant: finished ? JuaButtonVariant.play : JuaButtonVariant.action,
                  onPressed: finished ? onClaim : null,
                ),
        ],
      ),
    );
  }
}
