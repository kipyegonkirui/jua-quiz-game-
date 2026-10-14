import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class StreakCelebration {
  StreakCelebration._();

  static Future<void> show(
    BuildContext context, {
    required int streak,
    required int longestStreak,
    bool milestone = false,
    int shieldsAwarded = 0,
    bool shieldUsed = false,
  }) async {
    if (!context.mounted || streak <= 0) return;
    HapticFeedback.heavyImpact();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Streak celebration',
      barrierColor: Colors.black.withValues(alpha: .62),
      transitionDuration: const Duration(milliseconds: 460),
      pageBuilder: (context, _, __) => _StreakDialog(
        streak: streak,
        longestStreak: longestStreak,
        milestone: milestone,
        shieldsAwarded: shieldsAwarded,
        shieldUsed: shieldUsed,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curve, child: child),
        );
      },
    );
  }
}

class _StreakDialog extends StatefulWidget {
  final int streak;
  final int longestStreak;
  final bool milestone;
  final int shieldsAwarded;
  final bool shieldUsed;

  const _StreakDialog({
    required this.streak,
    required this.longestStreak,
    required this.milestone,
    required this.shieldsAwarded,
    required this.shieldUsed,
  });

  @override
  State<_StreakDialog> createState() => _StreakDialogState();
}

class _StreakDialogState extends State<_StreakDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.milestone ? 'STREAK MILESTONE!' : 'STREAK ALIVE!';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 26, offset: Offset(0, 12)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
                  child: const Text('🔥', style: TextStyle(fontSize: 68)),
                ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: AppColors.inkBrown,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${widget.streak} days in a row',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.earthRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.streak >= widget.longestStreak
                      ? 'New personal best!'
                      : 'Keep it going tomorrow.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                _StreakMeter(streak: widget.streak),
                if (widget.shieldsAwarded > 0 || widget.shieldUsed) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.juaSkyBlue.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Text('🛡️', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.shieldUsed
                                ? 'Streak Shield used — your streak survived the missed day.'
                                : '+${widget.shieldsAwarded} Streak Shield${widget.shieldsAwarded == 1 ? '' : 's'} earned',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const _TomorrowPreview(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.local_fire_department_rounded),
                    label: const Text('KEEP THE STREAK'),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => CustomPaint(
                  painter: _StreakSparkPainter(_controller.value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakMeter extends StatelessWidget {
  final int streak;
  const _StreakMeter({required this.streak});

  @override
  Widget build(BuildContext context) {
    const milestones = <int>[3, 7, 14, 30, 60, 100];
    final next = milestones.firstWhere((value) => value > streak, orElse: () => streak + 10);
    final previous = milestones.lastWhere((value) => value <= streak, orElse: () => 0);
    final span = (next - previous).clamp(1, 1000);
    final progress = ((streak - previous) / span).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_rounded, color: AppColors.earthRed, size: 20),
            const SizedBox(width: 7),
            Text('$streak days'),
            const Spacer(),
            Text('Next: $next', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.black12,
            color: AppColors.earthRed,
          ),
        ),
      ],
    );
  }
}

class _TomorrowPreview extends StatefulWidget {
  const _TomorrowPreview();

  @override
  State<_TomorrowPreview> createState() => _TomorrowPreviewState();
}

class _TomorrowPreviewState extends State<_TomorrowPreview> {
  late Timer _timer;
  Duration _remaining = _untilTomorrow();

  static Duration _untilTomorrow() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _untilTomorrow());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);
    final text = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.juaSkyBlue.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny_rounded, color: AppColors.sunGold),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'New daily challenge',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class StreakReturnCard extends StatefulWidget {
  final int streak;
  final VoidCallback? onPlay;
  final bool completedToday;

  const StreakReturnCard({
    super.key,
    required this.streak,
    this.onPlay,
    this.completedToday = true,
  });

  @override
  State<StreakReturnCard> createState() => _StreakReturnCardState();
}

class _StreakReturnCardState extends State<StreakReturnCard> {
  late Timer _timer;
  Duration _remaining = _untilTomorrow();

  static Duration _untilTomorrow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1).difference(now);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _remaining = _untilTomorrow());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    final countdown = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.earthRed.withValues(alpha: .18)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.earthRed.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🔥', style: TextStyle(fontSize: 27)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.streak}-day streak', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 3),
                Text(
                  widget.completedToday ? 'Come back tomorrow to keep it alive.' : 'Complete today\'s challenge to start it.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (widget.completedToday) ...[
                  const SizedBox(height: 6),
                  Text('Next challenge in $countdown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ],
            ),
          ),
          if (widget.onPlay != null)
            IconButton(
              tooltip: 'Keep playing',
              onPressed: widget.onPlay,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
        ],
      ),
    );
  }
}

class _StreakSparkPainter extends CustomPainter {
  final double progress;
  _StreakSparkPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 18; i++) {
      final angle = (i / 18) * math.pi * 2;
      final distance = 30 + progress * 150;
      final center = Offset(
        size.width / 2 + 90 * progress * (i.isEven ? 1 : -1),
        40 + distance * 0.22 * (i % 3),
      );
      paint.color = [AppColors.sunGold, AppColors.earthRed, AppColors.savannaGreen][i % 3]
          .withValues(alpha: (1 - progress).clamp(.0, 1.0));
      canvas.drawCircle(
        Offset(center.dx + distance * .25 * (i.isEven ? 1 : -1) * math.cos(angle), center.dy + distance * .12 * math.sin(angle)),
        3 + (i % 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StreakSparkPainter oldDelegate) => oldDelegate.progress != progress;
}
