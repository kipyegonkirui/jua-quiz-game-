import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/app_events.dart';

/// The scenery behind every screen, replacing the old flat blue.
///
/// Picks Meadow / Forest / Mountain / Adventure from the player's level
/// (1-5, 6-10, 11-15, 16+), cross-fades when the level crosses a band, and
/// drifts very slowly (a gentle pan/zoom) so the world feels alive without
/// costing battery. A soft gradient keeps white text readable on top.
class JuaScene extends StatelessWidget {
  final Widget child;
  const JuaScene({super.key, required this.child});

  /// Asset for a given level.
  static String assetForLevel(int level) {
    if (level >= 16) return 'assets/scene/adventure.jpg';
    if (level >= 11) return 'assets/scene/mountain.jpg';
    if (level >= 6) return 'assets/scene/forest.jpg';
    return 'assets/scene/meadow.jpg';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<UserProfile?>(
          valueListenable: AppEvents.profile,
          builder: (context, profile, _) {
            final asset = assetForLevel(profile?.level ?? 1);
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: _DriftingImage(key: ValueKey(asset), asset: asset),
            );
          },
        ),
        // Readability: darker at the top (title/HUD) and bottom (buttons),
        // clear in the middle so the scenery still shows.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x80000000), Color(0x30000000), Color(0x38000000), Color(0x99000000)],
                stops: [0, 0.3, 0.6, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _DriftingImage extends StatefulWidget {
  final String asset;
  const _DriftingImage({super.key, required this.asset});

  @override
  State<_DriftingImage> createState() => _DriftingImageState();
}

class _DriftingImageState extends State<_DriftingImage> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(
          scale: 1.08 + 0.06 * t,
          alignment: Alignment(-0.3 + 0.6 * t, 0.2),
          child: child,
        );
      },
      child: Image.asset(
        widget.asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF5291BE)),
      ),
    );
  }
}
