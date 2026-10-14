import 'package:flutter/material.dart';
import '../services/sound_service.dart';

/// Three stars that pop in one after another. Earned stars are gold and play
/// a sound; the rest stay as grey outlines. Plays once when first shown.
class AnimatedStars extends StatefulWidget {
  final int stars; // 0..3
  final double size;
  final bool onDark;
  const AnimatedStars({super.key, required this.stars, this.size = 44, this.onDark = false});

  @override
  State<AnimatedStars> createState() => _AnimatedStarsState();
}

class _AnimatedStarsState extends State<AnimatedStars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  int _lastPopped = -1;

  @override
  void initState() {
    super.initState();
    final earned = widget.stars.clamp(0, 3);
    _c.addListener(() {
      // One sound per earned star, at the moment it starts to pop.
      for (var i = 0; i < earned; i++) {
        if (i > _lastPopped && _c.value >= _start(i)) {
          _lastPopped = i;
          SoundService.instance.play(Sfx.starPop);
        }
      }
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && earned == 3) SoundService.instance.play(Sfx.levelUp);
    });
    _c.forward();
  }

  double _start(int i) => 0.1 + i * 0.25;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earned = widget.stars.clamp(0, 3);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.06),
              child: _star(i, i < earned),
            ),
        ],
      ),
    );
  }

  Widget _star(int i, bool on) {
    if (!on) {
      return Icon(Icons.star_border_rounded,
          size: widget.size, color: widget.onDark ? Colors.white54 : Colors.black26);
    }
    final t = ((_c.value - _start(i)) / 0.35).clamp(0.0, 1.0);
    final scale = Curves.elasticOut.transform(t);
    return Opacity(
      opacity: t == 0 ? 0 : 1,
      child: Transform.scale(
        scale: scale,
        child: Transform.rotate(
          angle: (1 - t) * -0.5,
          child: Icon(Icons.star_rounded,
              size: widget.size,
              color: const Color(0xFFF0A500),
              shadows: const [Shadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(0, 1))]),
        ),
      ),
    );
  }
}

/// Streak-of-correct-answers pill. Shows from 2 in a row; pulses when it grows.
class ComboMeter extends StatelessWidget {
  final int combo;
  const ComboMeter({super.key, required this.combo});

  static String labelFor(int c) {
    if (c >= 10) return 'UNSTOPPABLE';
    if (c >= 7) return 'ON FIRE';
    if (c >= 5) return 'HOT STREAK';
    if (c >= 3) return 'NICE';
    return 'COMBO';
  }

  @override
  Widget build(BuildContext context) {
    final show = combo >= 2;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: !show
          ? const SizedBox(key: ValueKey('none'), height: 30)
          : Container(
              key: ValueKey(combo),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: combo >= 5
                      ? const [Color(0xFFFF7A00), Color(0xFFE53935)]
                      : const [Color(0xFFF0A500), Color(0xFFFF9800)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(combo >= 5 ? '🔥' : '⚡', style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text('${labelFor(combo)}  x$combo',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
              ]),
            ),
    );
  }
}
