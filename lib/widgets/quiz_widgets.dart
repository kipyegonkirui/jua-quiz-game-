import 'jua_dialog.dart';
import 'package:flutter/material.dart';
import '../models/answer_result.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import 'game_effects.dart';
import 'question_extras.dart';

const _correctGreen = Color(0xFF2E9E5B);
const _wrongRed = Color(0xFFD64545);

/// How long a RIGHT answer stays on screen before the next question slides in
/// by itself. The screens use the same value for their timer, and the thin
/// bar under "Correct!" fills over exactly this long.
const Duration kAutoAdvanceDelay = Duration(milliseconds: 1100);

/// One question with its four options. Shared by the daily challenge and
/// practice rounds so they always look and behave identically.
///
/// One tap per question:
///  1. Tap an option. It is checked straight away (no "Check answer" button).
///  2. A RIGHT answer turns green and the next question slides in by itself
///     after [kAutoAdvanceDelay] — no "Next" button, so the round keeps moving.
///     A WRONG answer turns red, the right one turns green, and the player
///     reads the answer and the fun fact, then taps "Next question".
/// Once checked, the answer is locked — options can't be tapped any more.
///
/// Phase 4 adds two optional helpers (both need a rewarded video):
///  * Hint: before answering, two WRONG options disappear.
///  * Second chance: after a wrong first pick the answer is NOT shown yet; the
///    player may watch a video and pick again once, or decline and see it.
class QuizView extends StatelessWidget {
  final Question question;
  final int index;
  final int total;
  final String? selected;
  final ValueChanged<String> onSelect;

  /// Non-null once the server has checked this question.
  final AnswerResult? result;

  /// True while waiting for the server's verdict.
  final bool checking;

  final VoidCallback? onCheck;
  final VoidCallback? onNext;

  /// Small label above the progress bar, e.g. "Practice round".
  final String? heading;

  // ---- Phase 4: hints & second chances ------------------------------------
  /// Options removed by a hint (all wrong ones).
  final Set<String> hiddenOptions;

  /// Show the hint button (nothing answered yet, hint still available).
  final bool canHint;

  /// The hint button can be tapped right now (a video is ready, or the
  /// player can afford coins). The sheet it opens explains the options.
  final bool hintEnabled;
  final bool hintBusy;
  final VoidCallback? onHint;

  /// The second-chance video was watched: the player may pick again.
  final bool retryUnlocked;
  final bool retryBusy;
  final VoidCallback? onSecondChance;
  final VoidCallback? onDeclineSecondChance;

  /// A rewarded video is loaded and ready to play.
  final bool rewardedReady;

  /// Correct answers in a row; shown as a small flame chip from 2 upwards.
  final int combo;

  /// Tapping an option checks it at once. Set false for the old two-step
  /// "pick, then press Check answer" behaviour.
  final bool autoCheck;

  const QuizView({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.selected,
    required this.onSelect,
    required this.onCheck,
    required this.onNext,
    this.result,
    this.checking = false,
    this.heading,
    this.hiddenOptions = const <String>{},
    this.canHint = false,
    this.hintEnabled = true,
    this.hintBusy = false,
    this.onHint,
    this.retryUnlocked = false,
    this.retryBusy = false,
    this.onSecondChance,
    this.onDeclineSecondChance,
    this.rewardedReady = false,
    this.combo = 0,
    this.autoCheck = true,
  });

  OptionState _stateFor(String letter) {
    final r = result;
    if (r != null && r.isFinal) {
      if (letter == r.correctOption) return OptionState.correct;
      // Both wrong picks turn red when a second chance was used and missed.
      if (letter == r.chosen || letter == r.firstChoice) return OptionState.wrong;
      return OptionState.dimmed;
    }
    if (r != null && r.retryOffered) {
      if (letter == r.firstChoice) return OptionState.wrong; // the pick that missed
      return (retryUnlocked && selected == letter) ? OptionState.selected : OptionState.idle;
    }
    return selected == letter ? OptionState.selected : OptionState.idle;
  }

  /// Which options can be tapped right now.
  VoidCallback? _tapFor(String letter, AnswerResult? r) {
    if (checking) return null;
    if (r == null) return () => _pick(letter);
    // Second chance open: only after the video, and never the pick that missed.
    if (r.retryOffered && retryUnlocked && letter != r.firstChoice) {
      return () => _pick(letter);
    }
    return null; // locked
  }

  void _pick(String letter) {
    onSelect(letter);
    if (autoCheck) onCheck?.call();
  }

  Widget _checkButton() {
    final enabled = selected != null && !checking;
    return JuaDialogButton(
      label: checking ? 'Checking…' : 'Check answer',
      icon: checking ? null : Icons.check_circle_outline_rounded,
      style: JuaDialogButtonStyle.blue,
      onPressed: enabled ? onCheck : null,
    );
  }

  static const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 1))];

  @override
  Widget build(BuildContext context) {
    final r = result;
    final isLast = index == total - 1;
    final offered = r != null && r.retryOffered;
    final settled = r != null && r.isFinal;
    final autoAdvancing = r != null && r.isFinal && r.isCorrect; // the screen moves on by itself

    final body = Column(
      key: ValueKey<String>('${question.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        // Scrolls on small phones / long questions instead of overflowing.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuestionBanner(text: question.text),
                const SizedBox(height: 14),
                const Text(
                  'Choose your answer',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: _shadow),
                ),
                const SizedBox(height: 12),
                ...['a', 'b', 'c', 'd']
                    // A hint removes wrong options — until the answer is revealed.
                    .where((letter) => settled || !hiddenOptions.contains(letter))
                    .map((letter) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OptionTile(
                            letter: letter,
                            text: question.options[letter]!,
                            state: _stateFor(letter),
                            onTap: _tapFor(letter, r),
                          ),
                        )),
                if (r != null && r.isFinal && r.isCorrect) ...[
                  // Right answer: a short celebration, then the next question.
                  // Tapping it skips the wait.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onNext,
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        Center(
                          child: Image.asset(
                            'assets/mascot/pose4.png',
                            height: 84,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                        Text(
                          r.secondChanceUsed ? 'Correct on your second try! 🎉' : 'Correct! 🎉',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Colors.white,
                            shadows: [Shadow(color: _correctGreen, blurRadius: 10), Shadow(color: Color(0xCC000000), blurRadius: 3)],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _AutoAdvanceBar(),
                      ],
                    ),
                  ),
                ] else if (r != null && r.isFinal) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Image.asset(
                      'assets/mascot/pose3.png',
                      height: 96,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  // Words as well as colour, so it's clear without relying on colour alone.
                  Text(
                    'Not quite. The answer is ${(r.correctOption ?? '?').toUpperCase()}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                      shadows: [Shadow(color: _wrongRed, blurRadius: 10), Shadow(color: Color(0xCC000000), blurRadius: 3)],
                    ),
                  ),
                  QuestionExtras(key: ValueKey(question.id), questionId: question.id),
                ] else if (offered) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Image.asset(
                      'assets/mascot/pose3.png',
                      height: 80,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  Text(
                    retryUnlocked
                        ? 'Pick a different answer for your second chance.'
                        : 'Not quite. Want a second chance?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                      shadows: [Shadow(color: Color(0xCC000000), blurRadius: 4)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Buttons only appear when the player has something to decide.
        if (r == null) ...[
          const SizedBox(height: 12),
          if (canHint) ...[
            JuaDialogButton(
              label: hintBusy ? 'Loading…' : 'Get a hint',
              icon: hintBusy ? null : Icons.lightbulb_rounded,
              style: JuaDialogButtonStyle.green,
              onPressed: (hintEnabled && !hintBusy && !checking) ? onHint : null,
            ),
            if (!autoCheck) const SizedBox(height: 10),
          ],
          if (!autoCheck) _checkButton(),
        ] else if (offered) ...[
          const SizedBox(height: 12),
          if (retryUnlocked) ...[
            if (!autoCheck) _checkButton(),
          ] else ...[
            JuaDialogButton(
              label: retryBusy
                  ? 'Loading…'
                  : (rewardedReady ? 'Watch a video for a second chance' : 'Second chance (video loading...)'),
              icon: retryBusy ? null : Icons.play_circle_fill_rounded,
              style: JuaDialogButtonStyle.gold,
              onPressed: (rewardedReady && !retryBusy) ? onSecondChance : null,
            ),
            const SizedBox(height: 10),
            JuaDialogButton(
              label: 'No thanks, show the answer',
              style: JuaDialogButtonStyle.light,
              onPressed: retryBusy ? null : onDeclineSecondChance,
            ),
          ],
        ] else if (!autoAdvancing) ...[
          const SizedBox(height: 12),
          JuaDialogButton(
            label: isLast ? 'Finish' : 'Next question',
            icon: isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
            style: isLast ? JuaDialogButtonStyle.green : JuaDialogButtonStyle.blue,
            onPressed: onNext,
          ),
        ],
      ],
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heading != null) ...[
              Text(
                heading!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, shadows: _shadow),
              ),
              const SizedBox(height: 8),
            ],
            // The bar fills smoothly as the player moves through the round.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: (index + 1) / total),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                backgroundColor: Colors.white30,
                color: AppColors.sunGold,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${index + 1} of $total',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, shadows: _shadow),
                  ),
                ),
                if (combo >= 2) _ComboChip(combo: combo),
              ],
            ),
            // Each new question slides in from the right as the old one leaves.
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, anim) {
                  final incoming = child.key == ValueKey<String>('${question.id}');
                  final slide = Tween<Offset>(
                    begin: Offset(incoming ? 0.14 : -0.14, 0),
                    end: Offset.zero,
                  ).animate(anim);
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin gold bar that fills while a right answer is on screen, so the player
/// can see the next question is about to arrive.
class _AutoAdvanceBar extends StatelessWidget {
  const _AutoAdvanceBar();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: kAutoAdvanceDelay,
      curve: Curves.linear,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 5,
          backgroundColor: Colors.white24,
          color: AppColors.sunGold,
        ),
      ),
    );
  }
}

/// "🔥 3" chip beside the question counter once the player is on a streak.
class _ComboChip extends StatelessWidget {
  final int combo;
  const _ComboChip({required this.combo});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey<int>(combo),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.sunGold,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
        ),
        child: Text(
          '🔥 $combo in a row',
          style: const TextStyle(color: Color(0xFF4A2A00), fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }
}

enum OptionState { idle, selected, correct, wrong, dimmed }

class OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final OptionState state;

  /// Null means "not tappable right now".
  final VoidCallback? onTap;

  const OptionTile({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  AnswerVisualState _visualState() {
    switch (state) {
      case OptionState.idle:
        return AnswerVisualState.idle;
      case OptionState.selected:
        return AnswerVisualState.selected;
      case OptionState.correct:
        return AnswerVisualState.correct;
      case OptionState.wrong:
        return AnswerVisualState.wrong;
      case OptionState.dimmed:
        return AnswerVisualState.dimmed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGameAnswerTile(
      letter: letter,
      text: text,
      state: _visualState(),
      onTap: onTap,
    );
  }
}


/// The blue speech-banner the question sits in (matches the asset sheet),
/// so the text stays readable over any scenery.
class _QuestionBanner extends StatelessWidget {
  final String text;
  const _QuestionBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2F7BE0), Color(0xFF1B54B8)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
    );
  }
}
