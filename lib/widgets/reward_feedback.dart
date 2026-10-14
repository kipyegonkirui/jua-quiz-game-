import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../services/sound_service.dart';
import 'jua_dialog.dart';

/// A single reward that can be presented by the shared celebration layer.
class RewardFeedbackItem {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const RewardFeedbackItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  factory RewardFeedbackItem.xp(int amount) => RewardFeedbackItem(
        icon: Icons.bolt_rounded,
        label: 'XP',
        value: '+$amount',
        accent: AppColors.savannaGreen,
      );

  factory RewardFeedbackItem.coins(int amount) => RewardFeedbackItem(
        icon: Icons.monetization_on_rounded,
        label: 'COINS',
        value: '+$amount',
        accent: AppColors.sunGold,
      );

  factory RewardFeedbackItem.generic({
    required String label,
    required String value,
    IconData icon = Icons.card_giftcard_rounded,
    Color accent = AppColors.earthRed,
  }) => RewardFeedbackItem(
        icon: icon,
        label: label,
        value: value,
        accent: accent,
      );
}

/// One consistent, reusable reward presentation for the whole app.
///
/// Game results, missions, achievements and chests should all use this
/// instead of creating their own reward dialogs.
class RewardCelebration {
  RewardCelebration._();

  static Future<void> show(
    BuildContext context, {
    required List<RewardFeedbackItem> rewards,
    String title = 'REWARD EARNED!',
    String? subtitle,
    int? newLevel,
    bool leveledUp = false,
    bool celebrate = true,
  }) async {
    if (!context.mounted || (rewards.isEmpty && !leveledUp)) return;
    if (celebrate) {
      HapticFeedback.mediumImpact();
      SoundService.instance.play(leveledUp ? Sfx.levelUp : Sfx.coin);
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Reward celebration',
      barrierColor: Colors.black.withValues(alpha: .58),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, _, __) => _RewardCelebrationDialog(
        rewards: rewards,
        title: title,
        subtitle: subtitle,
        newLevel: newLevel,
        leveledUp: leveledUp,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }
}

class _RewardCelebrationDialog extends StatefulWidget {
  final List<RewardFeedbackItem> rewards;
  final String title;
  final String? subtitle;
  final int? newLevel;
  final bool leveledUp;

  const _RewardCelebrationDialog({
    required this.rewards,
    required this.title,
    this.subtitle,
    this.newLevel,
    required this.leveledUp,
  });

  @override
  State<_RewardCelebrationDialog> createState() => _RewardCelebrationDialogState();
}

class _RewardCelebrationDialogState extends State<_RewardCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  JuaRewardChip _chipFor(RewardFeedbackItem r) {
    final label = r.label.toUpperCase();
    if (label == 'XP') return JuaRewardChip(asset: JuaDialogArt.star, text: '${r.value} XP');
    if (label == 'COINS') return JuaRewardChip(asset: JuaDialogArt.coin, text: '${r.value} Coins');
    return JuaRewardChip(icon: r.icon, text: '${r.value} ${juaTitleCase(r.label)}');
  }

  @override
  Widget build(BuildContext context) {
    final isAchievement = !widget.leveledUp && widget.title.toUpperCase().contains('ACHIEVEMENT');
    final isChest = !widget.leveledUp && !isAchievement && widget.title.toUpperCase().contains('OPENED');

    final String title;
    final String? message;
    final String art;
    final JuaDialogTone tone;
    final JuaDialogButtonStyle buttonStyle;
    final String buttonLabel;
    if (widget.leveledUp) {
      title = 'Level Up!';
      message = widget.newLevel != null ? "You've reached Level ${widget.newLevel}!" : widget.subtitle;
      art = JuaDialogArt.starLaurel;
      tone = JuaDialogTone.blue;
      buttonStyle = JuaDialogButtonStyle.green;
      buttonLabel = 'Awesome!';
    } else if (isAchievement) {
      title = juaTitleCase(widget.title);
      message = widget.subtitle;
      art = JuaDialogArt.trophy;
      tone = JuaDialogTone.purple;
      buttonStyle = JuaDialogButtonStyle.purple;
      buttonLabel = 'Great!';
    } else {
      title = juaTitleCase(widget.title);
      message = widget.subtitle;
      art = isChest ? JuaDialogArt.chestOpen : JuaDialogArt.chestEarned;
      tone = isChest ? JuaDialogTone.orange : JuaDialogTone.blue;
      buttonStyle = JuaDialogButtonStyle.green;
      buttonLabel = 'Continue';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          JuaDialogCard(
            title: title,
            message: message,
            art: art,
            artHeight: 104,
            tone: tone,
            onClose: () => Navigator.of(context).pop(),
            content: widget.rewards.isEmpty ? null : JuaRewardPanel(chips: widget.rewards.map(_chipFor).toList()),
            buttons: [
              JuaDialogButton(
                label: buttonLabel,
                style: buttonStyle,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_controller.value)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  _ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 24; i++) {
      final x = size.width * random.nextDouble();
      final y = -10 + (size.height * .75) * ((progress * (1.2 + random.nextDouble())) % 1.0);
      final s = 3.0 + random.nextDouble() * 4;
      paint.color = [AppColors.sunGold, AppColors.savannaGreen, AppColors.earthRed, Colors.white][i % 4]
          .withValues(alpha: (1 - progress).clamp(.15, 1));
      canvas.drawCircle(Offset(x, y), s, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
