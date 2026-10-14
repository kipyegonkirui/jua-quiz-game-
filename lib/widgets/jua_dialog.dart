import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared game-style dialog system built from the dialog asset sheet.
///
/// The card, frame, close badge and buttons are drawn in Flutter (so they stay
/// sharp and every label is dynamic); only the header artwork (chest, trophy,
/// star, clock, bulb, cloud, mascot) and reward icons come from PNG assets.

enum JuaDialogTone { blue, orange, purple, green, red, brown }

enum JuaDialogButtonStyle { green, blue, red, gold, purple, light, grey }

/// Asset paths for the header artwork and small icons.
class JuaDialogArt {
  JuaDialogArt._();
  static const leaveMascot = 'assets/dialog/leave_mascot.png';
  static const chestOpen = 'assets/dialog/chest_open.png';
  static const chestEarned = 'assets/dialog/chest_earned.png';
  static const starLaurel = 'assets/dialog/star_laurel.png';
  static const trophy = 'assets/dialog/trophy.png';
  static const cloudSad = 'assets/dialog/cloud_sad.png';
  static const bulb = 'assets/dialog/bulb.png';
  static const clock = 'assets/dialog/clock.png';
  static const star = 'assets/dialog/star.png';
  static const coin = 'assets/dialog/coin.png';
  static const gem = 'assets/dialog/gem.png';
  static const heart = 'assets/dialog/heart.png';
}

const _navy = Color(0xFF14235E);
const _navySoft = Color(0xFF2B3A67);

List<Color> _frameColors(JuaDialogTone tone) {
  switch (tone) {
    case JuaDialogTone.blue:
      return const [Color(0xFF63BAF5), Color(0xFF2561C6)];
    case JuaDialogTone.orange:
      return const [Color(0xFFFFCB59), Color(0xFFE08510)];
    case JuaDialogTone.purple:
      return const [Color(0xFFA463F2), Color(0xFF5A2BB6)];
    case JuaDialogTone.green:
      return const [Color(0xFF78DB6C), Color(0xFF2B9A3A)];
    case JuaDialogTone.red:
      return const [Color(0xFFFF6464), Color(0xFFC21E2A)];
    case JuaDialogTone.brown:
      return const [Color(0xFFC9A072), Color(0xFF7A4B26)];
  }
}

/// "REWARD EARNED!" -> "Reward Earned!" (only touches all-caps strings).
String juaTitleCase(String s) {
  if (s != s.toUpperCase()) return s;
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

class JuaDialogButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final JuaDialogButtonStyle style;
  final IconData? icon;

  /// Optional widget shown after the label (e.g. a coin price).
  final Widget? trailing;

  const JuaDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = JuaDialogButtonStyle.green,
    this.icon,
    this.trailing,
  });

  @override
  State<JuaDialogButton> createState() => _JuaDialogButtonState();
}

class _JuaDialogButtonState extends State<JuaDialogButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  (List<Color>, Color, Color) _look() {
    final style = _enabled ? widget.style : JuaDialogButtonStyle.grey;
    switch (style) {
      case JuaDialogButtonStyle.green:
        return (const [Color(0xFF5CDC4C), Color(0xFF1FA02E)], const Color(0xFF157A22), Colors.white);
      case JuaDialogButtonStyle.blue:
        return (const [Color(0xFF4FA0FF), Color(0xFF1C5FD6)], const Color(0xFF1344A0), Colors.white);
      case JuaDialogButtonStyle.red:
        return (const [Color(0xFFFF6262), Color(0xFFD81E2B)], const Color(0xFF9E1019), Colors.white);
      case JuaDialogButtonStyle.gold:
        return (const [Color(0xFFFFD04D), Color(0xFFF08A10)], const Color(0xFFB45F00), Colors.white);
      case JuaDialogButtonStyle.purple:
        return (const [Color(0xFFA06AF7), Color(0xFF6A2FD0)], const Color(0xFF4A1E9A), Colors.white);
      case JuaDialogButtonStyle.light:
        return (const [Color(0xFFF6FAFF), Color(0xFFD3E6F8)], const Color(0xFFA9C6E4), const Color(0xFF1D4A86));
      case JuaDialogButtonStyle.grey:
        return (const [Color(0xFFC3CDD6), Color(0xFF93A0AB)], const Color(0xFF75828D), Colors.white);
    }
  }

  void _setPressed(bool v) {
    if (v) HapticFeedback.selectionClick();
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final (colors, border, textColor) = _look();
    final shadowed = textColor == Colors.white;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
              border: Border.all(color: border, width: 2),
              boxShadow: [
                BoxShadow(color: border.withValues(alpha: 0.55), offset: const Offset(0, 4)),
                BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 8, offset: const Offset(0, 6)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 3,
                  left: 18,
                  right: 18,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: textColor, size: 22),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              shadows: shadowed
                                  ? const [Shadow(color: Color(0x66000000), offset: Offset(0, 1.5), blurRadius: 2)]
                                  : null,
                            ),
                          ),
                          if (widget.trailing != null) ...[
                            const SizedBox(width: 10),
                            widget.trailing!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small "-10 [coin]" pill for the end of a button.
class JuaPricePill extends StatelessWidget {
  final int amount;
  const JuaPricePill({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 6, 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('-$amount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(width: 4),
          Image.asset(JuaDialogArt.coin, height: 20, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reward chips
// ---------------------------------------------------------------------------

class JuaRewardChip {
  final String? asset;
  final IconData? icon;
  final String text;
  const JuaRewardChip({this.asset, this.icon, required this.text});

  factory JuaRewardChip.xp(int amount) => JuaRewardChip(asset: JuaDialogArt.star, text: '+$amount XP');
  factory JuaRewardChip.coins(int amount) => JuaRewardChip(asset: JuaDialogArt.coin, text: '+$amount Coins');
}

class JuaRewardPanel extends StatelessWidget {
  final List<JuaRewardChip> chips;
  const JuaRewardPanel({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F0FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 8,
        children: [
          for (final c in chips)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.asset != null)
                  Image.asset(
                    c.asset!,
                    height: 30,
                    errorBuilder: (_, __, ___) => const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 30),
                  )
                else if (c.icon != null)
                  Icon(c.icon, size: 28, color: const Color(0xFFFFB300)),
                const SizedBox(width: 8),
                Text(c.text, style: const TextStyle(color: _navy, fontWeight: FontWeight.w800, fontSize: 17)),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class JuaDialogCard extends StatelessWidget {
  final String title;
  final String? message;

  /// Extra content between the message and the buttons (reward panel, etc).
  final Widget? content;

  /// Header artwork asset; falls back to [fallbackIcon] in a gold badge.
  final String? art;
  final IconData? fallbackIcon;
  final double artHeight;
  final Alignment artAlignment;
  final JuaDialogTone tone;
  final List<Widget> buttons;

  /// Two buttons side by side (cancel / confirm) instead of stacked.
  final bool buttonsInRow;

  /// Shows the red X badge when set.
  final VoidCallback? onClose;

  const JuaDialogCard({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.art,
    this.fallbackIcon,
    this.artHeight = 100,
    this.artAlignment = Alignment.topCenter,
    this.tone = JuaDialogTone.blue,
    this.buttons = const [],
    this.buttonsInRow = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasArt = art != null || fallbackIcon != null;
    final artH = art != null ? artHeight : (fallbackIcon != null ? 66.0 : 0.0);
    final overlap = hasArt ? artH * 0.72 : 0.0;
    final frame = _frameColors(tone);

    Widget? artWidget;
    if (art != null) {
      artWidget = Image.asset(
        art!,
        height: artH,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else if (fallbackIcon != null) {
      artWidget = Container(
        width: artH,
        height: artH,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD04A), Color(0xFFFF9D1E)],
          ),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Icon(fallbackIcon, color: Colors.white, size: artH * 0.52),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: overlap),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: frame),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
              ],
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, (hasArt ? artH * 0.28 : 0) + 20, 20, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF1F5FA)],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _navy, fontSize: 27, fontWeight: FontWeight.w900, height: 1.15),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _navySoft, fontSize: 15.5, height: 1.4, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (content != null) ...[
                    const SizedBox(height: 14),
                    content!,
                  ],
                  if (buttons.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    if (buttonsInRow && buttons.length == 2)
                      Row(
                        children: [
                          Expanded(child: buttons[0]),
                          const SizedBox(width: 12),
                          Expanded(child: buttons[1]),
                        ],
                      )
                    else
                      for (var i = 0; i < buttons.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        buttons[i],
                      ],
                  ],
                ],
              ),
            ),
          ),
        ),
        if (artWidget != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Align(
              alignment: artAlignment,
              child: Padding(
                padding: EdgeInsets.only(left: artAlignment == Alignment.topLeft ? 10 : 0),
                child: artWidget,
              ),
            ),
          ),
        if (onClose != null)
          Positioned(
            top: overlap - 12,
            right: -6,
            child: _CloseBadge(onTap: onClose!),
          ),
      ],
    );
  }
}

class _CloseBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFF6B6B), Color(0xFFD01F2C)],
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route + helpers
// ---------------------------------------------------------------------------

/// Pops the dialog in with a spring, over a dimmed backdrop.
Future<T?> showJuaDialogRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String label = 'Dialog',
}) {
  HapticFeedback.mediumImpact();
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: label,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: builder(dialogContext),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final scale = TweenSequence<double>([
        TweenSequenceItem(tween: Tween<double>(begin: 0.30, end: 1.05).chain(CurveTween(curve: Curves.easeOut)), weight: 70),
        TweenSequenceItem(tween: Tween<double>(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
      ]).animate(animation);
      return FadeTransition(opacity: animation, child: ScaleTransition(scale: scale, child: child));
    },
  );
}

/// Two-choice dialog. Returns true when the player confirms.
/// Closing with the X or the cancel button returns false.
Future<bool> showJuaConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  JuaDialogTone tone = JuaDialogTone.orange,
  String? art = JuaDialogArt.chestOpen,
  double artHeight = 100,
  Alignment artAlignment = Alignment.topCenter,
  bool destructive = true,
}) async {
  final result = await showJuaDialogRoute<bool>(
    context,
    barrierDismissible: false,
    label: 'Confirmation',
    builder: (c) => JuaDialogCard(
      title: title,
      message: message,
      art: art,
      artHeight: artHeight,
      artAlignment: artAlignment,
      tone: tone,
      buttonsInRow: true,
      onClose: () => Navigator.of(c).pop(false),
      buttons: [
        JuaDialogButton(
          label: cancelLabel.toUpperCase(),
          style: JuaDialogButtonStyle.light,
          onPressed: () => Navigator.of(c).pop(false),
        ),
        JuaDialogButton(
          label: confirmLabel.toUpperCase(),
          style: destructive ? JuaDialogButtonStyle.red : JuaDialogButtonStyle.green,
          onPressed: () => Navigator.of(c).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// One-button notice (no lives, coming soon, errors...).
Future<void> showJuaMessage(
  BuildContext context, {
  required String title,
  String? message,
  String buttonLabel = 'OK',
  JuaDialogButtonStyle buttonStyle = JuaDialogButtonStyle.green,
  IconData? buttonIcon,
  JuaDialogTone tone = JuaDialogTone.blue,
  String? art,
  IconData? fallbackIcon,
  double artHeight = 100,
  Widget? content,
}) async {
  await showJuaDialogRoute<void>(
    context,
    label: title,
    builder: (c) => JuaDialogCard(
      title: title,
      message: message,
      content: content,
      art: art,
      fallbackIcon: fallbackIcon,
      artHeight: artHeight,
      tone: tone,
      onClose: () => Navigator.of(c).pop(),
      buttons: [
        JuaDialogButton(
          label: buttonLabel,
          icon: buttonIcon,
          style: buttonStyle,
          onPressed: () => Navigator.of(c).pop(),
        ),
      ],
    ),
  );
}

/// "Connection Error" with a Retry button. Returns true when Retry is tapped.
Future<bool> showJuaConnectionError(
  BuildContext context, {
  String message = 'Please check your internet connection and try again.',
}) async {
  final retry = await showJuaDialogRoute<bool>(
    context,
    label: 'Connection error',
    builder: (c) => JuaDialogCard(
      title: 'Connection Error',
      message: message,
      art: JuaDialogArt.cloudSad,
      artHeight: 92,
      tone: JuaDialogTone.brown,
      onClose: () => Navigator.of(c).pop(false),
      buttons: [
        JuaDialogButton(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          style: JuaDialogButtonStyle.red,
          onPressed: () => Navigator.of(c).pop(true),
        ),
      ],
    ),
  );
  return retry ?? false;
}

/// "Time's Up!" with a Try Again button. Returns true when it is tapped.
Future<bool> showJuaTimesUp(
  BuildContext context, {
  String message = "That's not the right answer.",
  String buttonLabel = 'Try Again',
}) async {
  final again = await showJuaDialogRoute<bool>(
    context,
    barrierDismissible: false,
    label: "Time's up",
    builder: (c) => JuaDialogCard(
      title: "Time's Up!",
      message: message,
      art: JuaDialogArt.clock,
      artHeight: 100,
      tone: JuaDialogTone.red,
      onClose: () => Navigator.of(c).pop(false),
      buttons: [
        JuaDialogButton(
          label: buttonLabel,
          icon: Icons.refresh_rounded,
          style: JuaDialogButtonStyle.blue,
          onPressed: () => Navigator.of(c).pop(true),
        ),
      ],
    ),
  );
  return again ?? false;
}


// ---------------------------------------------------------------------------
// Text that sits directly on the scenery + full-page state cards
// ---------------------------------------------------------------------------

const juaSceneShadows = [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2))];

/// Page headings drawn straight over the scenery.
const juaSceneTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 30,
  fontWeight: FontWeight.w900,
  shadows: juaSceneShadows,
);

/// Body text drawn straight over the scenery.
const juaSceneBodyStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.35,
  shadows: juaSceneShadows,
);

/// Small captions drawn straight over the scenery.
const juaSceneCaptionStyle = TextStyle(
  color: Colors.white,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  shadows: juaSceneShadows,
);

/// Dark pill with a coin, readable on any background.
class JuaCoinPill extends StatelessWidget {
  final int coins;
  const JuaCoinPill({super.key, required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
      decoration: BoxDecoration(
        color: const Color(0xCC14235E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            JuaDialogArt.coin,
            height: 24,
            errorBuilder: (_, __, ___) => const Icon(Icons.monetization_on_rounded, size: 22, color: Color(0xFFFFB300)),
          ),
          const SizedBox(width: 6),
          Text('$coins', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}

/// A framed card for empty / error states, so they are readable over the
/// scenery. Use it in place of bare centred text.
class JuaStateCard extends StatelessWidget {
  final String title;
  final String? message;
  final String? art;
  final IconData? fallbackIcon;
  final JuaDialogTone tone;
  final String? buttonLabel;
  final IconData? buttonIcon;
  final JuaDialogButtonStyle buttonStyle;
  final VoidCallback? onPressed;

  const JuaStateCard({
    super.key,
    required this.title,
    this.message,
    this.art,
    this.fallbackIcon,
    this.tone = JuaDialogTone.blue,
    this.buttonLabel,
    this.buttonIcon,
    this.buttonStyle = JuaDialogButtonStyle.green,
    this.onPressed,
  });

  /// Connection-error card with a Retry button.
  const JuaStateCard.error({
    super.key,
    this.title = 'Connection Error',
    this.message = 'Please check your internet connection and try again.',
    required VoidCallback this.onPressed,
  })  : art = JuaDialogArt.cloudSad,
        fallbackIcon = null,
        tone = JuaDialogTone.brown,
        buttonLabel = 'Retry',
        buttonIcon = Icons.refresh_rounded,
        buttonStyle = JuaDialogButtonStyle.red;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: JuaDialogCard(
            title: title,
            message: message,
            art: art,
            fallbackIcon: fallbackIcon,
            artHeight: 92,
            tone: tone,
            buttons: [
              if (buttonLabel != null)
                JuaDialogButton(
                  label: buttonLabel!,
                  icon: buttonIcon,
                  style: buttonStyle,
                  onPressed: onPressed,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A cream card with the dialog sheet's coloured frame, for in-page panels
/// (calendars, stat blocks) that sit over the scenery.
class JuaFramePanel extends StatelessWidget {
  final Widget child;
  final JuaDialogTone tone;
  final EdgeInsetsGeometry padding;

  const JuaFramePanel({
    super.key,
    required this.child,
    this.tone = JuaDialogTone.blue,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _frameColors(tone)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 7)),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF1F5FA)],
          ),
        ),
        child: child,
      ),
    );
  }
}
