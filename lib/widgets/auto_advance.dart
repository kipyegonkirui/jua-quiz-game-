import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A thin gold bar that fills over [duration] while a RIGHT answer is on
/// screen, so the player can see the next question is about to arrive.
/// Tapping it calls [onSkip] to move on straight away.
///
/// Use [dark] on light panels (dark text), leave it false on the scenery.
class AutoAdvanceBar extends StatelessWidget {
  final Duration duration;
  final String label;
  final VoidCallback? onSkip;
  final bool dark;

  const AutoAdvanceBar({
    super.key,
    required this.duration,
    this.label = 'Next question…',
    this.onSkip,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? const Color(0xFF2B3A67) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSkip,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: duration,
              curve: Curves.linear,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 5,
                  backgroundColor: dark ? const Color(0x22000000) : Colors.white24,
                  color: AppColors.sunGold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$label  •  tap to skip',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                shadows: dark ? null : const [Shadow(color: Color(0x99000000), blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
