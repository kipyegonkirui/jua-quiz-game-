import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import 'odd_item_view.dart';

/// A reusable tactile surface. Presses squish the widget, release adds a
/// small bounce, and a light haptic makes the interaction feel physical.
class JuaTactile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool haptics;
  final double pressedScale;

  const JuaTactile({
    super.key,
    required this.child,
    required this.onTap,
    this.haptics = true,
    this.pressedScale = 0.96,
  });

  @override
  State<JuaTactile> createState() => _JuaTactileState();
}

class _JuaTactileState extends State<JuaTactile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.0, end: widget.pressedScale)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: widget.pressedScale, end: 1.045)
          .chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.045, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
  ]).animate(_controller);

  bool get _enabled => widget.onTap != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down() {
    if (!_enabled) return;
    if (widget.haptics) HapticFeedback.selectionClick();
    _controller.stop();
    _controller.value = 0;
    _controller.animateTo(
      0.30,
      duration: const Duration(milliseconds: 70),
      curve: Curves.easeOut,
    );
  }

  void _up() {
    if (!_enabled) return;
    _controller.forward(from: 0.30);
  }

  void _cancel() {
    if (!_enabled) return;
    _controller.forward(from: 0.30);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => _down() : null,
      onTapUp: _enabled ? (_) {
        _up();
        widget.onTap!();
      } : null,
      onTapCancel: _enabled ? _cancel : null,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// Full-width answer option with tactile feedback, correct/wrong animations,
/// and a small coin burst on correct answers.
class AnimatedGameAnswerTile extends StatefulWidget {
  final String letter;
  final String text;
  final AnswerVisualState state;
  final VoidCallback? onTap;
  final int rewardBurst;

  const AnimatedGameAnswerTile({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
    this.rewardBurst = 6,
  });

  @override
  State<AnimatedGameAnswerTile> createState() => _AnimatedGameAnswerTileState();
}

class _AnimatedGameAnswerTileState extends State<AnimatedGameAnswerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _effectController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  late final Animation<double> _correctScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.0, end: 1.06).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.06, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 70,
    ),
  ]).animate(_effectController);

  late final Animation<double> _shake = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -9.0), weight: 12),
    TweenSequenceItem(tween: Tween<double>(begin: -9.0, end: 9.0), weight: 18),
    TweenSequenceItem(tween: Tween<double>(begin: 9.0, end: -7.0), weight: 18),
    TweenSequenceItem(tween: Tween<double>(begin: -7.0, end: 6.0), weight: 18),
    TweenSequenceItem(tween: Tween<double>(begin: 6.0, end: -3.0), weight: 16),
    TweenSequenceItem(tween: Tween<double>(begin: -3.0, end: 0.0), weight: 18),
  ]).animate(
    CurvedAnimation(parent: _effectController, curve: Curves.easeOut),
  );

  AnswerVisualState _previousState = AnswerVisualState.idle;

  @override
  void initState() {
    super.initState();
    _previousState = widget.state;
  }

  @override
  void didUpdateWidget(covariant AnimatedGameAnswerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != _previousState) {
      _previousState = widget.state;
      if (widget.state == AnswerVisualState.correct) {
        HapticFeedback.mediumImpact();
        SoundService.instance.play(Sfx.correct);
        _effectController.forward(from: 0);
      } else if (widget.state == AnswerVisualState.wrong) {
        HapticFeedback.heavyImpact();
        SoundService.instance.play(Sfx.wrong);
        _effectController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(widget.state);
    final highlighted = widget.state == AnswerVisualState.selected ||
        widget.state == AnswerVisualState.correct ||
        widget.state == AnswerVisualState.wrong;

    return AnimatedBuilder(
      animation: _effectController,
      builder: (context, child) {
        final offset = widget.state == AnswerVisualState.wrong ? _shake.value : 0.0;
        final scale = widget.state == AnswerVisualState.correct
            ? _correctScale.value
            : 1.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _outerBubbleTop(widget.state),
                        _outerBubbleBottom(widget.state),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: highlighted ? 0.20 : 0.14),
                        blurRadius: highlighted ? 11 : 7,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.32),
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: JuaTactile(
                    onTap: widget.onTap,
                    pressedScale: 0.975,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.all(5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.background,
                            _innerBubbleBottom(widget.state),
                          ],
                        ),
                        border: Border.all(
                          color: colors.border,
                          width: highlighted ? 1.8 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 4,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: -13,
                            left: 8,
                            right: 8,
                            child: IgnorePointer(
                              child: Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.badgeBackground,
                                ),
                                child: Center(
                                  child: Text(
                                    widget.letter.toUpperCase(),
                                    style: TextStyle(
                                      color: colors.badgeForeground,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: OddItemRef.parse(widget.text).isImage
                                    ? Align(
                                        alignment: Alignment.centerLeft,
                                        child: OddItemView(
                                          item: widget.text,
                                          imageSize: 64,
                                          textStyle: TextStyle(color: colors.text),
                                        ),
                                      )
                                    : Text(
                                        widget.text,
                                        style: TextStyle(
                                          color: colors.text,
                                          fontWeight: widget.state == AnswerVisualState.correct
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                        ),
                                      ),
                              ),
                              if (widget.state == AnswerVisualState.correct)
                                const Icon(Icons.check_circle_rounded, color: Colors.white),
                              if (widget.state == AnswerVisualState.wrong)
                                const Icon(Icons.cancel_rounded, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.state == AnswerVisualState.correct)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CoinBurst(count: widget.rewardBurst),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum AnswerVisualState { idle, selected, correct, wrong, dimmed }

Color _outerBubbleTop(AnswerVisualState state) {
  switch (state) {
    case AnswerVisualState.correct:
      return const Color(0xFF8CEB6A);
    case AnswerVisualState.wrong:
      return const Color(0xFFFF7B76);
    case AnswerVisualState.selected:
      return const Color(0xFFFFE07A);
    case AnswerVisualState.idle:
      return const Color(0xFFEFF8F4);
    case AnswerVisualState.dimmed:
      return const Color(0xFFD8E1E0);
  }
}

Color _outerBubbleBottom(AnswerVisualState state) {
  switch (state) {
    case AnswerVisualState.correct:
      return const Color(0xFF45C83A);
    case AnswerVisualState.wrong:
      return const Color(0xFFD93E46);
    case AnswerVisualState.selected:
      return const Color(0xFFFFB62C);
    case AnswerVisualState.idle:
      return const Color(0xFFBFDCCF);
    case AnswerVisualState.dimmed:
      return const Color(0xFFB9C5C3);
  }
}

Color _innerBubbleBottom(AnswerVisualState state) {
  switch (state) {
    case AnswerVisualState.correct:
      return const Color(0xFF62D94B);
    case AnswerVisualState.wrong:
      return const Color(0xFFE45158);
    case AnswerVisualState.selected:
      return const Color(0xFFFFC94D);
    case AnswerVisualState.idle:
      return Colors.white;
    case AnswerVisualState.dimmed:
      return const Color(0xFFE2E8E6);
  }
}


class _AnswerColors {
  final Color background;
  final Color border;
  final Color text;
  final Color badgeBackground;
  final Color badgeForeground;

  const _AnswerColors({
    required this.background,
    required this.border,
    required this.text,
    required this.badgeBackground,
    required this.badgeForeground,
  });
}

_AnswerColors _colorsFor(AnswerVisualState state) {
  switch (state) {
    case AnswerVisualState.correct:
      return const _AnswerColors(
        background: Color(0xFF2E9E5B),
        border: Color(0xFF2E9E5B),
        text: Colors.white,
        badgeBackground: Colors.white24,
        badgeForeground: Colors.white,
      );
    case AnswerVisualState.wrong:
      return const _AnswerColors(
        background: Color(0xFFD64545),
        border: Color(0xFFD64545),
        text: Colors.white,
        badgeBackground: Colors.white24,
        badgeForeground: Colors.white,
      );
    case AnswerVisualState.selected:
      return _AnswerColors(
        background: AppColors.sunGold.withValues(alpha: 0.12),
        border: AppColors.sunGold,
        text: AppColors.inkBrown,
        badgeBackground: AppColors.sunGold,
        badgeForeground: Colors.white,
      );
    case AnswerVisualState.dimmed:
      return const _AnswerColors(
        background: Colors.white,
        border: Colors.black12,
        text: Colors.black38,
        badgeBackground: Colors.black12,
        badgeForeground: Colors.black38,
      );
    case AnswerVisualState.idle:
      return const _AnswerColors(
        background: Colors.white,
        border: Colors.black12,
        text: Colors.black87,
        badgeBackground: Colors.black12,
        badgeForeground: Colors.black54,
      );
  }
}

/// A deterministic burst so the reward feels consistent and testable.
class CoinBurst extends StatefulWidget {
  final int count;

  const CoinBurst({super.key, this.count = 6});

  @override
  State<CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<CoinBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  )..forward();

  static const _paths = <Offset>[
    Offset(-70, -28),
    Offset(-45, -58),
    Offset(-10, -74),
    Offset(32, -66),
    Offset(65, -42),
    Offset(76, -8),
    Offset(55, 22),
    Offset(12, 34),
    Offset(-35, 28),
    Offset(-68, 8),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count.clamp(1, _paths.length).toInt();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < count; i++)
              Center(
                child: Transform.translate(
                  offset: _paths[i] * Curves.easeOutCubic.transform(progress),
                  child: Transform.rotate(
                    angle: ((i.isEven ? 1 : -1) * 0.35) * progress * math.pi,
                    child: Opacity(
                      opacity: (1 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0).toDouble(),
                      child: Transform.scale(
                        scale: (0.5 + 0.7 * Curves.easeOutBack.transform(progress).clamp(0.0, 1.0)).toDouble(),
                        child: const Icon(
                          Icons.monetization_on_rounded,
                          size: 20,
                          color: AppColors.sunGold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Speed Quiz pressure indicator. The color is driven by a TweenSequence,
/// while the last red segment pulses when the player is critically low.
class SpeedPressureBar extends StatefulWidget {
  final double value;
  final double height;

  const SpeedPressureBar({
    super.key,
    required this.value,
    this.height = 12,
  });

  @override
  State<SpeedPressureBar> createState() => _SpeedPressureBarState();
}

class _SpeedPressureBarState extends State<SpeedPressureBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final Animation<double> _flash = Tween<double>(begin: 0.15, end: 0.95).animate(
    CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _syncFlash(widget.value);
  }

  @override
  void didUpdateWidget(covariant SpeedPressureBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFlash(widget.value);
  }

  void _syncFlash(double value) {
    if (value <= 0.30) {
      if (!_flashController.isAnimating) {
        _flashController.repeat(reverse: true);
      }
    } else if (_flashController.isAnimating) {
      _flashController.stop();
      _flashController.value = 0;
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  Color _colorFor(double value) {
    final pressure = (1 - value).clamp(0.0, 1.0).toDouble();
    final base = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(begin: const Color(0xFF38C172), end: const Color(0xFFFFD54A)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: const Color(0xFFFFD54A), end: const Color(0xFFFFA726)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: const Color(0xFFFFA726), end: const Color(0xFFD81B36)),
        weight: 30,
      ),
    ]).evaluate(AlwaysStoppedAnimation<double>(pressure)) ?? const Color(0xFF38C172);

    if (value <= 0.30) {
      return Color.lerp(base, const Color(0xFFFF5252), _flash.value) ?? base;
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value.clamp(0.0, 1.0).toDouble();
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(widget.height),
      ),
      clipBehavior: Clip.antiAlias,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value,
        child: AnimatedBuilder(
          animation: _flashController,
          builder: (context, _) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_colorFor(value), _colorFor(value).withValues(alpha: 0.86)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
