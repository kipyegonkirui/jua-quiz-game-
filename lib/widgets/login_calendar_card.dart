import 'package:flutter/material.dart';
import '../services/app_events.dart';
import '../services/sound_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'jua_buttons.dart';

/// The 7-day daily reward calendar. Claim today's coins; miss a day and it
/// starts again at day 1. All rules live on the server (025 migration).
class LoginCalendarCard extends StatefulWidget {
  const LoginCalendarCard({super.key});

  @override
  State<LoginCalendarCard> createState() => _LoginCalendarCardState();
}

class _LoginCalendarCardState extends State<LoginCalendarCard> {
  Map<String, dynamic>? _state;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await SupabaseService.instance.getLoginCalendar();
      if (mounted) setState(() => _state = s);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _claim() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await SupabaseService.instance.claimLoginReward();
      final granted = (s['granted'] as num?)?.toInt() ?? 0;
      if (granted > 0) {
        SoundService.instance.play(Sfx.coin);
        await SupabaseService.instance.getCoinBalance();
        AppEvents.notifyProgressChanged();
      }
      if (!mounted) return;
      setState(() => _state = s);
      if (granted > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+$granted coins! See you tomorrow 🎁')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not claim your reward. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s == null) {
      if (_failed) return const SizedBox.shrink(); // optional card
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    final claimed = s['claimed_today'] == true;
    final day = (s['day'] as num).toInt();
    final done = (s['days_done'] as num).toInt();
    final rewards = (s['rewards'] as List).map((e) => (e as num).toInt()).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC3D3E8), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Text('🎁', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Daily rewards', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ),
            Text(claimed ? 'Come back tomorrow' : 'Day $day ready',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: claimed ? Colors.black54 : AppColors.savannaGreen)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: _DayTile(
                    day: i,
                    coins: rewards[i - 1],
                    state: i <= done
                        ? _TileState.claimed
                        : (i == day && !claimed ? _TileState.today : _TileState.upcoming),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!claimed)
            JuaGlossyButton(
              onPressed: _busy ? null : _claim,
              label: 'CLAIM +${rewards[day - 1]}',
              icon: Icons.card_giftcard_rounded,
              variant: JuaButtonVariant.play,
            )
          else
            const Text('Reward claimed. Miss a day and the calendar starts over.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}

enum _TileState { claimed, today, upcoming }

class _DayTile extends StatelessWidget {
  final int day;
  final int coins;
  final _TileState state;
  const _DayTile({required this.day, required this.coins, required this.state});

  @override
  Widget build(BuildContext context) {
    final today = state == _TileState.today;
    final claimed = state == _TileState.claimed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: claimed ? const Color(0xFFE3F5E9) : (today ? const Color(0xFFFFF3CC) : const Color(0xFFF2F5F9)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: today ? AppColors.sunGold : Colors.transparent, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('D$day', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 4),
          claimed
              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2E9E5B), size: 20)
              : Text(day == 7 ? '🏆' : '🪙', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text('$coins', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
