import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/adapters/speed_quiz_game_adapter.dart';
import '../game/engine/game_controller.dart';
import '../game/engine/game_session.dart';
import '../game/models/game_answer_resolution.dart';
import '../game/models/speed_quiz_answer_result.dart';
import '../game/models/speed_quiz_result.dart';
import '../game/models/game_answer.dart';
import '../game/models/game_question.dart';
import '../game/models/game_mode.dart';
import '../game/models/game_rules.dart';
import '../models/mode_journey.dart';
import '../services/app_events.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/reward_feedback.dart';
import '../widgets/game_effects.dart';
import '../widgets/game_feel.dart';
import '../widgets/question_extras.dart';
import '../widgets/jua_exit_dialog.dart';
import '../widgets/mode_level_summary.dart';
import '../services/sound_service.dart';

class SpeedQuizScreen extends StatefulWidget {
  /// When set, this is a journey level (stars, lives); otherwise a free round.
  final int? levelNumber;

  const SpeedQuizScreen({super.key, this.levelNumber});

  @override
  State<SpeedQuizScreen> createState() => _SpeedQuizScreenState();
}

enum _SpeedPhase { intro, loading, playing, results, error }

class _SpeedQuizScreenState extends State<SpeedQuizScreen> {
  static const _secondsPerQuestion = SpeedQuizGameAdapter.defaultSecondsPerQuestion;
  _SpeedPhase _phase = _SpeedPhase.intro;
  GameController? _controller;
  SpeedQuizAnswerResult? _lastAnswer;
  SpeedQuizResult? _result;
  String? _roundId;
  String? _errorText;
  Timer? _ticker;
  Duration _remaining = const Duration(seconds: _secondsPerQuestion);
  bool _busy = false;
  bool _resolving = false;
  DateTime? _timeoutRetryAfter;
  DateTime? _feedbackUntil;
  String? _lastChosenOption;
  int _lastWarningSecond = -1;
  int _combo = 0; // correct answers in a row this round

  GameSession? get _session => _controller?.session;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    _busy = true;
    setState(() => _phase = _SpeedPhase.loading);
    try {
      final service = SupabaseService.instance;
      final roundId = widget.levelNumber == null
          ? await service.startSpeedQuizRound()
          : await service.startModeLevel(JourneyMode.speedQuiz, widget.levelNumber!);
      _roundId = roundId;
      final questions = await service.getSpeedQuizQuestions(roundId);
      final state = await service.getSpeedQuizState(roundId);
      if (questions.isEmpty) throw StateError('Speed Quiz has no questions.');

      final progress = await service.getSpeedQuizProgress(roundId);
      final gameAnswers = <GameAnswer>[];
      for (var i = 0; i < progress.length; i++) {
        final qIndex = i < questions.length ? i : questions.length - 1;
        final q = questions[qIndex];
        final p = progress[i];
        gameAnswers.add(SpeedQuizGameAdapter.toGameAnswer(
          questionId: q.id,
          result: p,
          answeredAt: DateTime.now(),
        ));
      }

      final controller = GameController(
        rules: const GameRules(
          mode: GameMode.speedQuiz,
          timeLimitPerQuestion: Duration(seconds: _secondsPerQuestion),
          autoAdvance: true,
        ),
        session: SpeedQuizGameAdapter.createSession(
          roundId: roundId,
          questions: questions,
          state: state,
          answers: gameAnswers,
        ),
        resolveAnswer: _resolveAnswer,
        resolveTimeout: _resolveTimeout,
      );

      if (!mounted) return;
      _controller = controller;
      _lastAnswer = null;
      _combo = 0;
      _lastChosenOption = null;
      _lastWarningSecond = -1;
      _result = null;
      _phase = _SpeedPhase.playing;
      _startTicker();
      setState(() {});

      if (state.isFinished) {
        await _finish();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = widget.levelNumber == null ? null : modeLevelErrorText(e);
          _phase = _SpeedPhase.error;
        });
      }
    } finally {
      _busy = false;
    }
  }

  Future<bool> _confirmExit() async {
    final level = widget.levelNumber;
    final leave = await showJuaExitDialog(
      context: context,
      title: level == null ? 'Leave Speed Quiz?' : 'Exit level?',
      message: level == null
          ? 'Your answers are saved. You can pick this round up again later.'
          : 'Leaving this level ends the attempt. It will burst one life and start its 5-minute recharge.',
      keepPlayingLabel: 'Keep playing',
      exitLabel: 'Leave',
    );
    if (!leave) return false;
    final roundId = _roundId;
    if (level != null && roundId != null) {
      try {
        await SupabaseService.instance.abandonModeLevel(roundId);
      } catch (e) {
        debugPrint('Could not close abandoned Speed Quiz level: $e');
      }
    }
    _ticker?.cancel();
    return true;
  }

  void _startTicker() {
    _ticker?.cancel();
    _updateRemaining();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _phase != _SpeedPhase.playing || _resolving) return;
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final session = _session;
    if (session == null || session.currentQuestion == null) return;
    final limit = session.currentQuestion!.timeLimit ?? const Duration(seconds: _secondsPerQuestion);
    final elapsed = DateTime.now().difference(session.questionStartedAt);
    final remaining = limit - elapsed;
    if (remaining <= Duration.zero) {
      // After a failed attempt wait a couple of seconds before retrying so an
      // offline player doesn't trigger a request (and a snackbar) every tick.
      final retryAfter = _timeoutRetryAfter;
      if (retryAfter != null && DateTime.now().isBefore(retryAfter)) return;
      _timeout();
      return;
    }
    final second = remaining.inMilliseconds.ceil() ~/ 1000;
    if (second <= 3 && second != _lastWarningSecond) {
      _lastWarningSecond = second;
      HapticFeedback.mediumImpact();
      SoundService.instance.play(Sfx.tick);
    }
    if (mounted) setState(() => _remaining = remaining);
  }

  Future<void> _timeout() async {
    if (_resolving) return;
    final controller = _controller;
    if (controller == null || controller.session.currentQuestion == null) return;
    _resolving = true;
    setState(() {});
    try {
      final resolution = await controller.submitTimeout();
      if (resolution == null) return;
      _showFeedback(resolution);
    } catch (_) {
      _timeoutRetryAfter = DateTime.now().add(const Duration(seconds: 2));
      if (mounted) {
        _resolving = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time expired, but the answer could not be recorded. Try again.')),
        );
      }
    }
  }

  Future<GameAnswerResolution> _resolveAnswer({
    required GameQuestion question,
    required String chosenOption,
    required Duration timeTaken,
  }) async {
    final result = await SupabaseService.instance.answerSpeedQuizQuestion(
      roundId: _controller!.session.id,
      questionId: question.id,
      choice: chosenOption,
    );
    _lastAnswer = result;
    _combo = result.isCorrect ? _combo + 1 : 0;
    final answer = SpeedQuizGameAdapter.toGameAnswer(
      questionId: question.id,
      result: result,
      answeredAt: DateTime.now(),
    );
    return GameAnswerResolution.settled(answer);
  }

  Future<GameAnswerResolution> _resolveTimeout({
    required GameQuestion question,
    required Duration timeTaken,
  }) async {
    final result = await SupabaseService.instance.answerSpeedQuizQuestion(
      roundId: _controller!.session.id,
      questionId: question.id,
      forceTimeout: true,
    );
    _lastAnswer = result;
    _combo = result.isCorrect ? _combo + 1 : 0;
    final answer = SpeedQuizGameAdapter.toGameAnswer(
      questionId: question.id,
      result: result,
      answeredAt: DateTime.now(),
    );
    return GameAnswerResolution.settled(answer);
  }

  void _select(String option) {
    if (_resolving) return;
    _lastChosenOption = option;
    final controller = _controller;
    if (controller == null || controller.session.status != GameSessionStatus.inProgress) return;
    controller.selectOption(option);
    _submitSelection();
  }

  Future<void> _submitSelection() async {
    final controller = _controller;
    if (controller == null || !controller.canSubmit || _resolving) return;
    _resolving = true;
    setState(() {});
    try {
      final resolution = await controller.submitSelected();
      if (resolution != null) _showFeedback(resolution);
    } catch (_) {
      _resolving = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t record that answer. Please try again.')),
        );
        setState(() {});
      }
    }
  }

  void _showFeedback(GameAnswerResolution resolution) {
    _feedbackUntil = DateTime.now().add(const Duration(milliseconds: 400));
    if (mounted) setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      final until = _feedbackUntil;
      if (until != null && DateTime.now().isBefore(until)) return;
      await _advance();
    });
  }

  Future<void> _advance() async {
    final controller = _controller;
    if (controller == null || !_resolving) return;
    if (controller.session.isLastQuestion) {
      controller.advance();
      _resolving = false;
      await _finish();
      return;
    }
    controller.advance();
    _lastAnswer = null;
    _lastChosenOption = null;
    _resolving = false;
    _feedbackUntil = null;
    if (mounted) {
      setState(() {});
      _updateRemaining();
    }
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    if (mounted) setState(() => _phase = _SpeedPhase.loading);
    try {
      final result = await SupabaseService.instance.submitSpeedQuizRound(
        roundId: _controller!.session.id,
      );
      await SupabaseService.instance.publishConfirmedSpeedQuiz(result: result);
      AppEvents.notifyProgressChanged();
      if (!mounted) return;
      _result = result;
      _controller?.complete();
      setState(() => _phase = _SpeedPhase.results);
    } catch (_) {
      if (mounted) setState(() => _phase = _SpeedPhase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _SpeedPhase.playing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && mounted) Navigator.of(context).pop();
      },
      child: _buildPhase(),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _SpeedPhase.intro:
        return _Intro(onStart: _start, levelNumber: widget.levelNumber);
      case _SpeedPhase.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _SpeedPhase.error:
        return _Error(onRetry: _start, message: _errorText, canGoBack: widget.levelNumber != null);
      case _SpeedPhase.playing:
        return _Playing(
          session: _session!,
          remaining: _remaining,
          answer: _lastAnswer,
          chosenOption: _lastChosenOption,
          resolving: _resolving,
          combo: _combo,
          onSelect: _select,
        );
      case _SpeedPhase.results:
        return _Results(
          result: _result!,
          onAgain: _start,
          questionIds: _controller!.session.questions.map((q) => q.id).toList(),
          bestFuture: SupabaseService.instance.getSpeedQuizBestScore(),
          levelNumber: widget.levelNumber,
          roundId: _roundId,
          onOpenLevel: (next) => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => SpeedQuizScreen(levelNumber: next)),
          ),
        );
    }
  }
}

class _Intro extends StatelessWidget {
  final VoidCallback onStart;
  final int? levelNumber;
  const _Intro({required this.onStart, this.levelNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speed Quiz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('⚡', textAlign: TextAlign.center, style: TextStyle(fontSize: 58)),
              const SizedBox(height: 14),
              Text(levelNumber == null ? 'Speed Quiz' : 'Speed Quiz • Level $levelNumber',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text('10 questions. 10 seconds each. Faster correct answers score more.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const _Rule(icon: Icons.timer_outlined, text: 'The server controls the real time limit.'),
              const _Rule(icon: Icons.bolt_rounded, text: 'Correct + fast + difficult = more points.'),
              const _Rule(icon: Icons.local_fire_department_outlined, text: 'Speed Quiz does not change your daily streak.'),
              if (levelNumber != null)
                const _Rule(icon: Icons.star_rounded, text: 'Earn up to 3 stars. 1 star returns your life and opens the next level.'),
              const SizedBox(height: 28),
              JuaGlossyButton(
                onPressed: onStart,
                label: levelNumber == null ? 'Play' : 'Start level',
                icon: Icons.play_arrow_rounded,
                variant: JuaButtonVariant.play,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Rule({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, color: AppColors.savannaGreen),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ]),
      );
}

class _Playing extends StatelessWidget {
  final GameSession session;
  final Duration remaining;
  final SpeedQuizAnswerResult? answer;
  final String? chosenOption;
  final bool resolving;
  final int combo;
  final ValueChanged<String> onSelect;

  const _Playing({
    required this.session,
    required this.remaining,
    required this.answer,
    required this.chosenOption,
    required this.resolving,
    required this.combo,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final question = session.currentQuestion!;
    final seconds = remaining.inMilliseconds / 1000;
    final ratio = (seconds / (question.timeLimit?.inSeconds ?? 10)).clamp(0.0, 1.0).toDouble();
    final urgent = seconds <= 3;
    return Scaffold(
      appBar: AppBar(title: const Text('Speed Quiz')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text('Question ${session.currentIndex + 1}/${session.questions.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${seconds.ceil()}s', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: urgent ? AppColors.earthRed : AppColors.inkBrown)),
              ]),
              const SizedBox(height: 10),
              SpeedPressureBar(value: ratio, height: 12),
              const SizedBox(height: 10),
              Center(child: ComboMeter(combo: combo)),
              const SizedBox(height: 10),
              Text(question.text, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 22),
              ...['a', 'b', 'c', 'd'].map((letter) {
                final visualState = answer == null
                    ? (session.selectedOption == letter
                        ? AnswerVisualState.selected
                        : AnswerVisualState.idle)
                    : answer!.isCorrect && answer!.correctOption == letter
                        ? AnswerVisualState.correct
                        : !answer!.isCorrect && chosenOption == letter
                            ? AnswerVisualState.wrong
                            : answer!.correctOption == letter
                                ? AnswerVisualState.correct
                                : AnswerVisualState.dimmed;
                final burst = answer == null
                    ? 6
                    : (answer!.elapsedMs <= 2000
                        ? 10
                        : answer!.elapsedMs <= 4000
                            ? 8
                            : answer!.elapsedMs <= 6500
                                ? 6
                                : 4);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedGameAnswerTile(
                    letter: letter,
                    text: question.options[letter]!,
                    state: visualState,
                    rewardBurst: burst,
                    onTap: resolving ? null : () => onSelect(letter),
                  ),
                );
              }),
              if (answer != null) ...[
                const SizedBox(height: 8),
                Text(
                  answer!.timedOut
                      ? '⏱ Time!'
                      : answer!.isCorrect
                          ? '✅ +${answer!.points} points'
                          : '❌ Correct answer: ${answer!.correctOption?.toUpperCase() ?? '-'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends StatefulWidget {
  final SpeedQuizResult result;
  final VoidCallback onAgain;
  final Future<int> bestFuture;
  final int? levelNumber;
  final String? roundId;
  final List<String> questionIds;
  final void Function(int level)? onOpenLevel;

  const _Results({
    required this.result,
    required this.questionIds,
    required this.onAgain,
    required this.bestFuture,
    this.levelNumber,
    this.roundId,
    this.onOpenLevel,
  });

  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results> {
  bool _celebrated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_celebrated) return;
    _celebrated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rewards = <RewardFeedbackItem>[];
      if (widget.result.xpEarned > 0) rewards.add(RewardFeedbackItem.xp(widget.result.xpEarned));
      if (widget.result.coinsEarned > 0) rewards.add(RewardFeedbackItem.coins(widget.result.coinsEarned));
      RewardCelebration.show(context, rewards: rewards, newLevel: widget.result.newLevel, leveledUp: widget.result.leveledUp, title: 'SPEED REWARD', subtitle: 'Fast round complete');
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      appBar: AppBar(title: const Text('Speed Quiz Results')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('⚡', textAlign: TextAlign.center, style: TextStyle(fontSize: 58)),
            const SizedBox(height: 12),
            Text('${result.score}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            Text('${result.correct}/${result.total} correct', textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
              Text('+${result.xpEarned} XP', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(result.leveledUp ? 'Level ${result.newLevel} — level up!' : 'Level ${result.newLevel}'),
              const SizedBox(height: 10),
              FutureBuilder<int>(
                future: widget.bestFuture,
                builder: (context, snapshot) => Text(snapshot.hasData ? 'Personal best: ${snapshot.data}' : 'Checking personal best…'),
              ),
            ]))),
            const SizedBox(height: 12),
            RoundFactsCard(questionIds: widget.questionIds),
            const SizedBox(height: 18),
            if (widget.levelNumber != null && widget.roundId != null && widget.onOpenLevel != null)
              ModeLevelSummary(
                mode: JourneyMode.speedQuiz,
                roundId: widget.roundId!,
                level: widget.levelNumber!,
                onRetry: widget.onAgain,
                onOpenLevel: widget.onOpenLevel!,
              )
            else
              JuaGlossyButton(onPressed: widget.onAgain, label: 'Play again', icon: Icons.refresh_rounded, variant: JuaButtonVariant.action),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  final bool canGoBack;
  const _Error({required this.onRetry, this.message, this.canGoBack = false});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Speed Quiz')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message ?? 'Something went wrong.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
            if (canGoBack)
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to journey')),
          ]),
        )),
      );
}
