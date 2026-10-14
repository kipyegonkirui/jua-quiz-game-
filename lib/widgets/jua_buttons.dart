import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sound_service.dart';

enum JuaButtonVariant { play, action }

/// Primary Jua Quiz button inspired by the provided glossy game-menu button.
/// It is intentionally implemented as a widget rather than using the source
/// image so the label, size, accessibility and tap target remain dynamic.
class JuaGlossyButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final JuaButtonVariant variant;
  final IconData? icon;

  const JuaGlossyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = JuaButtonVariant.play,
    this.icon,
  });

  @override
  State<JuaGlossyButton> createState() => _JuaGlossyButtonState();
}

class _JuaGlossyButtonState extends State<JuaGlossyButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _bounceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _bounce = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.95).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.95, end: 1.05).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
  ]).animate(_bounceController);

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_enabled || !mounted) return;
    if (value) {
      HapticFeedback.selectionClick();
      SoundService.instance.play(Sfx.tap);
      _bounceController.stop();
      _bounceController.value = 0;
    } else {
      _bounceController.forward(from: 0);
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isPlay = widget.variant == JuaButtonVariant.play;
    final outerStart = _enabled ? const Color(0xFF8DBDDA) : const Color(0xFF9FAEB8);
    final outerEnd = _enabled ? const Color(0xFF6A9FC8) : const Color(0xFF87939C);
    final innerTop = isPlay ? const Color(0xFFFFD04A) : const Color(0xFF8DEB62);
    final innerMiddle = isPlay ? const Color(0xFFFFC02E) : const Color(0xFF69DD3B);
    final innerBottom = isPlay ? const Color(0xFFFF941A) : const Color(0xFF35BF2D);
    final textColor = isPlay ? const Color(0xFFB84D08) : const Color(0xFF26701D);

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: ScaleTransition(
          scale: _pressed ? const AlwaysStoppedAnimation(0.97) : _bounce,
          child: Container(
            height: 72,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(38),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [outerStart, outerEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _enabled ? 0.18 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.35),
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(33),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [innerTop, innerMiddle, innerBottom],
                  stops: const [0, 0.52, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: -18,
                    left: 16,
                    right: 16,
                    child: Container(
                      height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white.withValues(alpha: 0.20),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: textColor, size: 23),
                          const SizedBox(width: 9),
                        ],
                        Text(
                          widget.label.toUpperCase(),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            fontFamily: 'serif',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 19,
                    bottom: 7,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          width: 7,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Glossy circular exit control inspired by the provided reference.
/// The red treatment makes it clear that this action leaves the current mode.
class JuaExitButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final double size;

  const JuaExitButton({
    super.key,
    required this.onPressed,
    this.size = 58,
  });

  @override
  State<JuaExitButton> createState() => _JuaExitButtonState();
}

class _JuaExitButtonState extends State<JuaExitButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.92).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.92, end: 1.06).chain(
        CurveTween(curve: Curves.easeOutBack),
      ),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.06, end: 1.0).chain(
        CurveTween(curve: Curves.easeInOut),
      ),
      weight: 30,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (widget.onPressed == null || !mounted) return;
    if (value) {
      HapticFeedback.selectionClick();
      SoundService.instance.play(Sfx.tap);
      _controller.stop();
      _controller.value = 0;
    } else {
      _controller.forward(from: 0);
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final size = widget.size;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Exit',
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: ScaleTransition(
          scale: _pressed ? const AlwaysStoppedAnimation(0.94) : _scale,
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: enabled
                    ? const [Color(0xFFDFF2FF), Color(0xFF75A8CC)]
                    : const [Color(0xFFD1D8DD), Color(0xFF9AA4AA)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: enabled ? 0.22 : 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFF6B5B),
                    Color(0xFFE8483D),
                    Color(0xFFB92525),
                  ],
                  stops: [0, 0.48, 1],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 5,
                    left: size * 0.22,
                    right: size * 0.22,
                    child: Container(
                      height: size * 0.17,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withValues(alpha: 0.23),
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.close_rounded,
                      size: size * 0.48,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
