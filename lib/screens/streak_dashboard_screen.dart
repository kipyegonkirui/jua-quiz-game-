import 'package:flutter/material.dart';
import '../models/streak_dashboard.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/jua_dialog.dart';
import '../widgets/login_calendar_card.dart';

class StreakDashboardScreen extends StatefulWidget {
  const StreakDashboardScreen({super.key});

  @override
  State<StreakDashboardScreen> createState() => _StreakDashboardScreenState();
}

class _StreakDashboardScreenState extends State<StreakDashboardScreen> {
  StreakDashboardData? _data;
  bool _loading = true;
  String? _error;

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
      final data = await SupabaseService.instance.getStreakDashboard(days: 90);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your streak history could not be loaded. Pull to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Streak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, shadows: juaSceneShadows)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 280), Center(child: CircularProgressIndicator(color: Colors.white))])
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      JuaStateCard.error(title: "Couldn't load your streak", message: _error!, onPressed: _load),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                    children: [
                      _HeroStreakCard(data: _data!),
                      const SizedBox(height: 12),
                      const LoginCalendarCard(),
                      const SizedBox(height: 12),
                      _NextMilestoneCard(data: _data!),
                      const SizedBox(height: 12),
                      _HistoryCard(data: _data!),
                      const SizedBox(height: 12),
                      _MilestonesCard(current: _data!.currentStreak),
                      const SizedBox(height: 8),
                      _ReturnHint(completedToday: _data!.completedToday),
                    ],
                  ),
      ),
    );
  }
}

class _HeroStreakCard extends StatelessWidget {
  final StreakDashboardData data;

  const _HeroStreakCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return JuaDialogCard(
      title: 'Keep the fire going',
      message: data.lastCompletedDate == null
          ? null
          : (data.completedToday
              ? 'Daily Challenge completed today.'
              : 'Last Daily Challenge: ${_shortDate(data.lastCompletedDate!)}'),
      art: 'assets/ui/streak.png',
      artHeight: 86,
      tone: JuaDialogTone.orange,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.completedToday) ...[
            const _StatusPill(icon: Icons.check_circle_rounded, text: 'TODAY DONE'),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F0FA),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(child: _BigStat(value: '${data.currentStreak}', label: 'CURRENT', icon: Image.asset('assets/ui/streak.png', height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE8590C), size: 26)))),
                _VerticalDivider(),
                Expanded(child: _BigStat(value: '${data.longestStreak}', label: 'PERSONAL BEST', icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB300), size: 26))),
                _VerticalDivider(),
                Expanded(child: _BigStat(value: '${data.streakShields}', label: 'SHIELDS', icon: Image.asset('assets/ui/shield.png', height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: Color(0xFF1AA6B7), size: 26)))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextMilestoneCard extends StatelessWidget {
  final StreakDashboardData data;

  const _NextMilestoneCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final milestone = data.nextMilestone;
    if (milestone == null) {
      return _Panel(
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: AppColors.sunGold, size: 30),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All streak milestones reached', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
                  SizedBox(height: 3),
                  Text('Keep building your personal best.', style: TextStyle(fontSize: 12, color: Color(0xFF4A5C85), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final previous = _previousMilestone(milestone);
    final progress = ((data.currentStreak - previous) / (milestone - previous)).clamp(0.0, 1.0);
    final rewards = <Widget>[];
    if (data.nextMilestoneCoins > 0) rewards.add(_RewardChip(icon: Icons.monetization_on_rounded, text: '+${data.nextMilestoneCoins} coins'));
    if (data.nextMilestoneShields > 0) rewards.add(_RewardChip(icon: Icons.shield_rounded, text: '+${data.nextMilestoneShields} shield${data.nextMilestoneShields == 1 ? '' : 's'}'));

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.sunGold),
              const SizedBox(width: 9),
              const Expanded(child: Text('NEXT MILESTONE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.inkBrown, letterSpacing: .8))),
              Text('$milestone days', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.earthRed)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${data.currentStreak}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.inkBrown)),
              const Text(' / ', style: TextStyle(color: Color(0xFF4A5C85), fontWeight: FontWeight.w800)),
              Text('$milestone', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF4A5C85))),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: progress, minHeight: 13, backgroundColor: const Color(0xFFDDE6F1), color: const Color(0xFFFF8A00)),
          ),
          const SizedBox(height: 10),
          if (rewards.isNotEmpty)
            Wrap(spacing: 7, runSpacing: 7, children: rewards),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final StreakDashboardData data;

  const _HistoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cells = <StreakDay?>[];
    if (data.days.isNotEmpty) {
      final first = data.days.first.date;
      final leading = first.weekday % 7; // Sunday = 0.
      cells.addAll(List<StreakDay?>.filled(leading, null));
      cells.addAll(data.days);
    }

    final weeks = <List<StreakDay?>>[];
    for (var i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, i + 7 < cells.length ? i + 7 : cells.length));
    }
    while (weeks.isNotEmpty && weeks.last.length < 7) {
      weeks.last.addAll(List<StreakDay?>.filled(7 - weeks.last.length, null));
    }

    return _Panel(
      tone: JuaDialogTone.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: AppColors.savannaGreen),
              const SizedBox(width: 9),
              const Expanded(child: Text('STREAK HISTORY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.inkBrown, letterSpacing: .8))),
              Text('${data.completedDays} completed', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _WeekLabel('S'), _WeekLabel('M'), _WeekLabel('T'), _WeekLabel('W'), _WeekLabel('T'), _WeekLabel('F'), _WeekLabel('S'),
            ],
          ),
          const SizedBox(height: 6),
          ...weeks.map((week) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: week.map((day) => Expanded(child: _DayCell(day: day))).toList()),
              )),
          const SizedBox(height: 6),
          Row(
            children: [
              const _LegendDot(color: Color(0xFF4CCB54)),
              const SizedBox(width: 5),
              const Text('completed', style: TextStyle(fontSize: 11, color: Color(0xFF2B3A67), fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
              const _LegendDot(color: Color(0xFFF59E0B)),
              const SizedBox(width: 5),
              const Text('shield used', style: TextStyle(fontSize: 11, color: Color(0xFF2B3A67), fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${data.protectedDays} protected', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2B3A67))),
            ],
          ),
        ],
      ),
    );
  }
}

class _MilestonesCard extends StatelessWidget {
  final int current;
  static const milestones = <int>[3, 7, 14, 30, 60, 100];

  const _MilestonesCard({required this.current});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      tone: JuaDialogTone.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: AppColors.sunGold),
              SizedBox(width: 9),
              Text('MILESTONES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.inkBrown, letterSpacing: .8)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: milestones.map((m) {
              final reached = current >= m;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  gradient: reached
                      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5CDC4C), Color(0xFF1FA02E)])
                      : null,
                  color: reached ? null : const Color(0xFFE7F0FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: reached ? const Color(0xFF157A22) : const Color(0xFFB7C9E0), width: 1.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(reached ? Icons.check_circle_rounded : Icons.lock_rounded, size: 17, color: reached ? Colors.white : const Color(0xFF7C8FB0)),
                    const SizedBox(width: 6),
                    Text('$m days', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: reached ? Colors.white : const Color(0xFF2B3A67))),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ReturnHint extends StatelessWidget {
  final bool completedToday;

  const _ReturnHint({required this.completedToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE614235E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.6),
      ),
      child: Row(
        children: [
          Icon(completedToday ? Icons.check_circle_rounded : Icons.schedule_rounded, color: const Color(0xFFFFD95A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              completedToday ? 'Nice work. Your streak is protected for today — come back tomorrow.' : 'Your next Daily Challenge is waiting. Complete it to keep the streak alive.',
              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final JuaDialogTone tone;
  const _Panel({required this.child, this.tone = JuaDialogTone.blue});

  @override
  Widget build(BuildContext context) {
    return JuaFramePanel(tone: tone, padding: const EdgeInsets.all(14), child: child);
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final Widget icon;
  const _BigStat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        icon,
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(color: Color(0xFF14235E), fontWeight: FontWeight.w900, fontSize: 26)),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4A5C85), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .6)),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1.5, height: 56, color: const Color(0xFFC3D3E8));
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatusPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5CDC4C), Color(0xFF1FA02E)]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF157A22), width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: .8)),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _RewardChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFFF0B8), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFFFB300), width: 1.4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: AppColors.sunGold), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.inkBrown))]),
      );
}

class _WeekLabel extends StatelessWidget {
  final String label;
  const _WeekLabel(this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Center(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF4A5C85)))));
}

class _DayCell extends StatelessWidget {
  final StreakDay? day;
  const _DayCell({required this.day});

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox(height: 34);
    final isToday = _sameDate(day!.date, DateTime.now());
    final completed = day!.completed;
    final shield = day!.shieldUsed;

    final List<Color> fill = shield
        ? const [Color(0xFFFFD95A), Color(0xFFF59E0B)]
        : completed
            ? const [Color(0xFF6BE05B), Color(0xFF22A936)]
            : const [Color(0xFFF2F6FB), Color(0xFFDCE6F2)];
    final Color border = isToday
        ? const Color(0xFF2561C6)
        : shield
            ? const Color(0xFFB45F00)
            : completed
                ? const Color(0xFF157A22)
                : const Color(0xFFB7C9E0);

    return Tooltip(
      message: '${_shortDate(day!.date)} — ${!completed ? 'not completed' : shield ? 'streak shield used' : 'completed'}',
      child: Container(
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: fill),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: border, width: isToday ? 2.6 : 1.4),
          boxShadow: isToday
              ? const [BoxShadow(color: Color(0x662561C6), blurRadius: 6)]
              : null,
        ),
        child: Center(
          child: shield
              ? Image.asset('assets/ui/shield.png', height: 20, errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, size: 16, color: Colors.white))
              : completed
                  ? Image.asset('assets/ui/streak.png', height: 21, errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department_rounded, size: 17, color: Colors.white))
                  : Text('${day!.date.day}', style: const TextStyle(fontSize: 11, color: Color(0xFF4A5C85), fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});
  @override
  Widget build(BuildContext context) => Container(width: 13, height: 13, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.black26)));
}

int _previousMilestone(int milestone) {
  const values = [0, 3, 7, 14, 30, 60, 100];
  final index = values.indexOf(milestone);
  return index <= 0 ? 0 : values[index - 1];
}

bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _shortDate(DateTime value) => '${value.day}/${value.month}/${value.year}';
