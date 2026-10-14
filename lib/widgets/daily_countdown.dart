import 'dart:async';

import 'package:flutter/material.dart';

/// Time left until the next daily challenge unlocks (the next local midnight,
/// which is the same moment `UserProfile.completedToday` flips back to false).
class DailyClock {
  DailyClock._();

  static Duration untilNextChallenge([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day + 1).difference(n);
  }

  /// 05:12:33
  static String format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Live-ticking "HH:MM:SS" until the next daily challenge.
/// [onElapsed] fires once when the countdown reaches zero (new day).
class DailyCountdownText extends StatefulWidget {
  final String prefix;
  final TextStyle? style;
  final VoidCallback? onElapsed;

  const DailyCountdownText({super.key, this.prefix = '', this.style, this.onElapsed});

  @override
  State<DailyCountdownText> createState() => _DailyCountdownTextState();
}

class _DailyCountdownTextState extends State<DailyCountdownText> {
  Timer? _timer;
  Duration _remaining = DailyClock.untilNextChallenge();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = DailyClock.untilNextChallenge();
      // The remaining time jumps back up to ~24h when midnight passes.
      final wrapped = next > _remaining + const Duration(seconds: 2);
      setState(() => _remaining = next);
      if (wrapped) widget.onElapsed?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix}${DailyClock.format(_remaining)}',
      maxLines: 1,
      style: widget.style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// Big "Next challenge in 05:12:33" panel for the done / results screens.
class DailyCountdownPanel extends StatefulWidget {
  const DailyCountdownPanel({super.key});

  @override
  State<DailyCountdownPanel> createState() => _DailyCountdownPanelState();
}

class _DailyCountdownPanelState extends State<DailyCountdownPanel> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF14235E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC53D), width: 2),
      ),
      child: _ready
          ? const Text(
              'A new challenge is ready!\nGo back and play.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, height: 1.3),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '⏳ NEXT CHALLENGE IN',
                  style: TextStyle(color: Color(0xFFFFD95A), fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 1.1),
                ),
                const SizedBox(height: 4),
                DailyCountdownText(
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 38),
                  onElapsed: () {
                    if (mounted) setState(() => _ready = true);
                  },
                ),
              ],
            ),
    );
  }
}
