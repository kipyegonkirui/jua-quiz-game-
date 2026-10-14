import 'package:flutter/material.dart';

import '../game/progression/reward_chest_service.dart';
import '../models/reward_chest.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/jua_dialog.dart';
import '../widgets/reward_feedback.dart';

class RewardChestsScreen extends StatefulWidget {
  const RewardChestsScreen({super.key});

  @override
  State<RewardChestsScreen> createState() => _RewardChestsScreenState();
}

class _RewardChestsScreenState extends State<RewardChestsScreen> {
  List<RewardChest> _chests = const [];
  bool _loading = true;
  String? _error;
  String? _claimingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService.instance.syncRewardChests();
      final chests = await SupabaseService.instance.getRewardChests();
      if (!mounted) return;
      setState(() => _chests = chests);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Rewards could not be loaded. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claim(RewardChest chest) async {
    if (_claimingId != null || !chest.available) return;
    setState(() => _claimingId = chest.id);
    try {
      final result = await SupabaseService.instance.claimRewardChest(chest.id);
      if (!mounted) return;
      if (!result.claimed) return;
      final rewards = <RewardFeedbackItem>[];
      if (result.coinsAwarded > 0) rewards.add(RewardFeedbackItem.coins(result.coinsAwarded));
      if (result.xpAwarded > 0) rewards.add(RewardFeedbackItem.xp(result.xpAwarded));
      await RewardCelebration.show(context, rewards: rewards, title: '${chest.title.toUpperCase()} OPENED!', subtitle: 'Your reward is now in your account.', newLevel: result.newLevel, leveledUp: result.leveledUp);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That chest could not be opened. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = RewardChestService.availableCount(_chests);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('REWARD CHESTS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const _ChestIcon(size: 62, locked: false),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Open your rewards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
                                  const SizedBox(height: 4),
                                  Text('$available chest${available == 1 ? '' : 's'} ready to open', style: const TextStyle(color: Colors.black54)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._chests.map((chest) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChestCard(
                              chest: chest,
                              claiming: _claimingId == chest.id,
                              onClaim: () => _claim(chest),
                            ),
                          )),
                    ],
                  ),
                ),
    );
  }
}

class _ChestCard extends StatelessWidget {
  final RewardChest chest;
  final bool claiming;
  final VoidCallback onClaim;

  const _ChestCard({required this.chest, required this.claiming, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final available = chest.available;
    final claimed = chest.claimed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Row(
        children: [
          _ChestIcon(size: 66, locked: !available && !claimed),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chest.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
                const SizedBox(height: 3),
                Text(chest.description, style: const TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.25)),
                const SizedBox(height: 6),
                Text(
                  available ? '🪙 ${chest.minCoins}–${chest.maxCoins} coins${chest.rewardXp > 0 ? '  •  +${chest.rewardXp} XP' : ''}' :
                      claimed ? 'Already claimed' : 'Unlocks at Level ${chest.requiredLevel}',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: available ? AppColors.savannaGreen : Colors.black45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (available)
            SizedBox(
              width: 88,
              child: JuaGlossyButton(
                label: claiming ? '...' : 'OPEN',
                icon: Icons.lock_open_rounded,
                variant: JuaButtonVariant.action,
                onPressed: claiming ? null : onClaim,
              ),
            )
          else if (claimed)
            const Icon(Icons.check_circle_rounded, color: AppColors.savannaGreen, size: 30)
          else
            const Icon(Icons.lock_rounded, color: Colors.black26, size: 27),
        ],
      ),
    );
  }
}

class _ChestIcon extends StatelessWidget {
  final double size;
  final bool locked;
  const _ChestIcon({required this.size, required this.locked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: locked ? Colors.black12 : AppColors.sunGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(locked ? Icons.lock_rounded : Icons.inventory_2_rounded, size: size * .48, color: locked ? Colors.black38 : AppColors.sunGold),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => JuaStateCard.error(message: message, onPressed: onRetry);
}
