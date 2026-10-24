import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/answer_result.dart';
import '../models/football_journey.dart';
import '../models/question.dart';
import '../services/app_events.dart';
import '../services/sound_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/jua_dialog.dart';
import '../widgets/jua_exit_dialog.dart';
import '../widgets/quiz_widgets.dart';
import '../widgets/reward_feedback.dart';

const String _ballAsset = 'assets/football/fb_ball.png';
const String _starAsset = 'assets/football/fb_star.png';

/// A 5-kick penalty shootout of football trivia.
///
/// Every question is a kick: a RIGHT answer is a GOAL, a WRONG answer is a
/// SAVE. 3 goals earn 1 star, 4 goals 2 stars, 5 goals 3 stars. The server
/// picks the questions and decides every verdict (see 031_football_challenge.sql).
/// Pops with `true` when the level was finished, so the road can refresh.
class FootballPlayScreen extends StatefulWidget {
  final int level;

  const FootballPlayScreen({super.key, required this.level});

  @override
  State<FootballPlayScreen> createState() => _FootballPlayScreenState();
}

class _FootballPlayScreenState extends State<FootballPlayScreen> {
  static const Duration _autoNextDelay = kAutoAdvanceDelay;

  bool _loading = true;
  String? _error;
  String? _roundId;
  List<Question> _questions = const [];
  final List<bool?> _kicks = List<bool?>.filled(5, null);
  int _index = 0;
  String? _selected;
  AnswerResult? _result;
  bool _checking = false;
  bool _submitting = false;
  int _kickId = 0; // bumps on every kick so the pitch animates again
  FootballRoundResult? _final;
  Timer? _autoNext;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _autoNext?.cancel();
    super.dispose();
  }

  String _friendly(Object e) {
    final raw = e.toString();
    if (raw.contains('previous_level_required')) return 'Win at least one star on the previous level first.';
    if (raw.contains('level_not_available')) return 'That level is not open yet.';
    if (raw.contains('no questions available')) return 'No football questions are available yet.';
    return 'Could not load the match. Check your connection and try again.';
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = SupabaseService.instance;
      final roundId = await service.startFootballLevel(widget.level);
      final questions = await service.getFootballQuestions(roundId);
      if (questions.isEmpty) throw StateError('no questions available');
      final progress = await service.getFootballProgress(roundId);
      for (var i = 0; i < questions.length && i < _kicks.length; i++) {
        final done = progress[questions[i].id];
        _kicks[i] = done?.isCorrect;
      }
      final firstOpen = questions.indexWhere((q) => !progress.containsKey(q.id));
      if (!mounted) return;
      setState(() {
        _roundId = roundId;
        _questions = questions;
        _index = firstOpen == -1 ? questions.length - 1 : firstOpen;
        _loading = false;
      });
      if (firstOpen == -1) await _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(e);
      });
    }
  }

  void _select(String letter) {
    if (_checking || _result != null) return;
    SoundService.instance.play(Sfx.tap);
    setState(() => _selected = letter);
  }

  Future<void> _check() async {
    final roundId = _roundId;
    final choice = _selected;
    if (roundId == null || choice == null || _checking || _result != null) return;
    setState(() => _checking = true);
    try {
      final q = _questions[_index];
      final res = await SupabaseService.instance.answerFootballQuestion(
        roundId: roundId,
        questionId: q.id,
        choice: choice,
      );
      if (!mounted) return;
      setState(() {
        _result = res;
        _kicks[_index] = res.isCorrect;
        _kickId++;
        _checking = false;
      });
      if (res.isCorrect) {
        HapticFeedback.mediumImpact();
        SoundService.instance.play(Sfx.correct);
        _autoNext?.cancel();
        final at = _index;
        _autoNext = Timer(_autoNextDelay, () {
          if (mounted && _index == at && _result?.isCorrect == true) _next();
        });
      } else {
        HapticFeedback.heavyImpact();
        SoundService.instance.play(Sfx.wrong);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _next() async {
    _autoNext?.cancel();
    if (_result == null || _submitting) return;
    if (_index + 1 >= _questions.length) {
      await _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _result = null;
    });
  }

  Future<void> _finish() async {
    final roundId = _roundId;
    if (roundId == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final res = await SupabaseService.instance.submitFootballRound(roundId);
      if (!mounted) return;
      setState(() {
        _final = res;
        _submitting = false;
      });
      AppEvents.notifyProgressChanged();
      if (res.stars > 0) SoundService.instance.play(Sfx.starPop);
      if (res.xpEarned > 0 || res.leveledUp) {
        await RewardCelebration.show(
          context,
          rewards: [if (res.xpEarned > 0) RewardFeedbackItem.xp(res.xpEarned)],
          title: res.stars > 0 ? 'FULL TIME!' : 'FINAL WHISTLE',
          subtitle: '${res.goals}/${res.kicks} goals',
          newLevel: res.newLevel,
          leveledUp: res.leveledUp,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<bool> _confirmExit() async {
    if (_final != null || _loading || _error != null) return true;
    return showJuaExitDialog(
      context: context,
      title: 'Leave the match?',
      message: 'Your kicks so far are saved. You can pick this level up again from the road.',
      keepPlayingLabel: 'Keep playing',
      exitLabel: 'Leave',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop(_final != null);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('LEVEL ${widget.level}'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmExit() && context.mounted) Navigator.of(context).pop(_final != null);
            },
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: SoundService.instance.enabled,
              builder: (_, on, _) => IconButton(
                tooltip: on ? 'Mute sound' : 'Turn sound on',
                icon: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                onPressed: () => SoundService.instance.setEnabled(!on),
              ),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 16),
              JuaGlossyButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                variant: JuaButtonVariant.action,
                onPressed: _start,
              ),
            ],
          ),
        ),
      );
    }
    final done = _final;
    if (done != null) return _ResultView(result: done, onClose: () => Navigator.of(context).pop(true), onRetry: _retry);
    if (_submitting) return const Center(child: CircularProgressIndicator());

    final q = _questions[_index];
    return Column(
      children: [
        _PenaltyPanel(kicks: _kicks, kickId: _kickId, lastWasGoal: _result?.isCorrect),
        Expanded(
          child: QuizView(
            question: q,
            index: _index,
            total: _questions.length,
            selected: _selected,
            onSelect: _select,
            onCheck: _check,
            onNext: _next,
            result: _result,
            checking: _checking,
            heading: 'Penalty shootout',
          ),
        ),
      ],
    );
  }

  void _retry() {
    setState(() {
      _final = null;
      _roundId = null;
      _selected = null;
      _result = null;
      _index = 0;
      for (var i = 0; i < _kicks.length; i++) {
        _kicks[i] = null;
      }
    });
    _start();
  }
}

// ============================================================================
// The pitch strip: goal, keeper, ball, scoreboard.
// ============================================================================

class _PenaltyPanel extends StatefulWidget {
  final List<bool?> kicks;
  final int kickId;
  final bool? lastWasGoal;

  const _PenaltyPanel({required this.kicks, required this.kickId, required this.lastWasGoal});

  @override
  State<_PenaltyPanel> createState() => _PenaltyPanelState();
}

class _PenaltyPanelState extends State<_PenaltyPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int _lastKick = 0;
  bool _goal = true;
  bool _toLeft = true;

  @override
  void didUpdateWidget(covariant _PenaltyPanel old) {
    super.didUpdateWidget(old);
    if (widget.kickId != _lastKick && widget.lastWasGoal != null) {
      _lastKick = widget.kickId;
      _goal = widget.lastWasGoal!;
      _toLeft = widget.kickId.isOdd;
      _c.forward(from: 0);
    } else if (widget.lastWasGoal == null && _c.value != 0) {
      _c.value = 0; // next question: ball back on the spot
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          SizedBox(
            height: 132,
            child: LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                const h = 132.0;
                return AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_c.value.clamp(0.0, 1.0));
                    // Ball: from the spot to a top corner (goal) or the keeper's gloves (save).
                    const spot = Offset(0.5, 0.88);
                    final target = _goal
                        ? Offset(_toLeft ? 0.2 : 0.8, 0.34)
                        : Offset(_toLeft ? 0.36 : 0.64, 0.5);
                    final pos = Offset.lerp(spot, target, t)!;
                    final ballSize = 30.0 - 10 * t;
                    // Keeper dives the other way on a goal, the same way on a save.
                    final dir = (_goal ? !_toLeft : _toLeft) ? -1.0 : 1.0;
                    final keeperX = 0.5 + dir * 0.17 * t;
                    final shown = _c.value > 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _GoalPainter())),
                        Positioned(
                          left: w * keeperX - 24,
                          top: h * 0.36,
                          child: Transform.rotate(
                            angle: dir * 0.9 * t,
                            child: const Text('🧤', style: TextStyle(fontSize: 38)),
                          ),
                        ),
                        Positioned(
                          left: w * pos.dx - ballSize / 2,
                          top: h * pos.dy - ballSize / 2,
                          child: Image.asset(_ballAsset, width: ballSize, height: ballSize),
                        ),
                        if (shown && _c.value > 0.55)
                          Positioned.fill(
                            child: Center(
                              child: Transform.scale(
                                scale: 0.6 + 0.4 * ((_c.value - 0.55) / 0.45).clamp(0.0, 1.0),
                                child: Text(
                                  _goal ? 'GOAL!' : 'SAVED!',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: _goal ? AppColors.sunGold : Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: _goal ? const Color(0xFF05B416) : const Color(0xFFD7263D),
                                        blurRadius: 14,
                                      ),
                                      const Shadow(color: Color(0xCC000000), blurRadius: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in widget.kicks)
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: k == null
                        ? Colors.white24
                        : (k ? const Color(0xFF2EB82E) : const Color(0xFFD7263D)),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(
                    k == null ? Icons.sports_soccer_rounded : (k ? Icons.check_rounded : Icons.close_rounded),
                    size: 16,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final goal = Rect.fromLTWH(size.width * 0.08, size.height * 0.06, size.width * 0.84, size.height * 0.6);
    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    for (var x = goal.left; x <= goal.right; x += 14) {
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), net);
    }
    for (var y = goal.top; y <= goal.bottom; y += 14) {
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), net);
    }
    final post = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(goal.left, goal.bottom)
        ..lineTo(goal.left, goal.top)
        ..lineTo(goal.right, goal.top)
        ..lineTo(goal.right, goal.bottom),
      post,
    );
    // Grass line and penalty spot.
    final grass = Paint()..color = const Color(0xFF2EB82E).withValues(alpha: 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
        const Radius.circular(14),
      ),
      grass,
    );
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.88), 3, Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// Results
// ============================================================================

class _ResultView extends StatelessWidget {
  final FootballRoundResult result;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  const _ResultView({required this.result, required this.onClose, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final won = result.stars > 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              won ? 'Level ${result.level} cleared!' : 'So close!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6)],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < FootballJourneyRules.starsPerLevel; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Image.asset(
                      _starAsset,
                      width: 54,
                      height: 54,
                      color: i < result.stars ? null : const Color(0x80203050),
                      colorBlendMode: i < result.stars ? null : BlendMode.srcATop,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${result.goals} goals from ${result.kicks} kicks',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              won
                  ? (result.nextLevelUnlocked ? 'The next level is open.' : 'Top of the road. Well played!')
                  : 'Score 3 goals or more to earn a star and open the next level.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
            if (result.xpCapped)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Daily Football XP limit reached. Come back tomorrow for more.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            const SizedBox(height: 26),
            JuaGlossyButton(
              label: 'Back to the road',
              icon: Icons.route_rounded,
              variant: JuaButtonVariant.action,
              onPressed: onClose,
            ),
            const SizedBox(height: 10),
            JuaDialogButton(
              label: 'Play again',
              icon: Icons.replay_rounded,
              style: JuaDialogButtonStyle.blue,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
