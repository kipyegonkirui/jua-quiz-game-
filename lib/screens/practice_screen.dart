import 'dart:async';

import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/answer_result.dart';
import '../models/help_state.dart';
import '../services/quiz_assist.dart';
import '../widgets/hint_source_sheet.dart';
import '../models/attempt_result.dart';
import '../models/practice_journey.dart';
import '../models/practice_lives.dart';
import '../models/question.dart';
import '../game/adapters/practice_game_adapter.dart';
import '../game/engine/game_controller.dart';
import '../game/engine/game_session.dart';
import '../game/models/game_answer_resolution.dart';
import '../game/models/game_question.dart';
import '../services/ads_service.dart';
import '../services/app_events.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/quiz_widgets.dart';
import '../widgets/game_feel.dart';
import '../widgets/share_button.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/reward_feedback.dart';
import '../widgets/jua_exit_dialog.dart';

enum _Phase { intro, loading, error, inProgress, results }

/// Endless practice rounds: 5 fresh questions at a time, as many rounds as
/// you like. Earns XP and counts toward accuracy/lifetime stats, but never
/// touches the streak — that belongs to the daily challenge alone.
class PracticeScreen extends StatefulWidget {
  final int? levelNumber;

  const PracticeScreen({super.key, this.levelNumber});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  _Phase _phase = _Phase.intro;
  String? _loadError;
  String? _roundId;
  List<Question> _questions = [];
  GameController? _gameController;
  GameSession? get _gameSession => _gameController?.session;
  int get _current => _gameController?.session.currentIndex ?? 0;
  String? get _selected => _gameController?.session.selectedOption;
  int _combo = 0; // correct answers in a row this round
  AnswerResult? _answerResult; // set once the server has checked this question
  bool _checking = false;
  AttemptResult? _result;
  bool _busy = false; // guards against double-taps creating/submitting twice
  bool _waitingOnAd = false;
  PracticeLives? _lives;
  Timer? _lifeTimer;
  Timer? _autoNext; // moves on by itself after a right answer
  DateTime _lifeClock = DateTime.now();

  // Hints & second chances (Phase 4).
  HelpState _help = HelpState.empty();
  bool _retryUnlocked = false; // second-chance video watched for this question
  bool _hintBusy = false;
  bool _retryBusy = false;

  Future<void> _refreshLives() async {
    if (widget.levelNumber == null) return;
    try {
      final lives = await SupabaseService.instance.getPracticeLives();
      if (!mounted) return;
      setState(() {
        _lives = lives;
        _lifeClock = DateTime.now();
      });
    } catch (_) {
      // Lives are enforced server-side; a display refresh failure must not
      // interrupt an already-started level.
    }
  }

  void _startLifeTicker() {
    _lifeTimer?.cancel();
    _lifeTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || widget.levelNumber == null) return;
      final now = DateTime.now();
      setState(() => _lifeClock = now);
      if (_lives?.nextRechargeAt != null && !now.isBefore(_lives!.nextRechargeAt!)) {
        await _refreshLives();
      }
    });
  }

  Future<void> _start() async {
    if (_busy) return;
    _busy = true;
    setState(() {
      _phase = _Phase.loading;
      _loadError = null;
    });
    try {
      final service = SupabaseService.instance;
      final roundId = widget.levelNumber == null
          ? await service.startPracticeRound()
          : await service.startPracticeLevelRound(widget.levelNumber!);
      final questions = await service.getPracticeQuestions(roundId);
      if (questions.isEmpty) throw StateError('round has no questions');
      // If this is a round that was left half-finished, pick up where it stopped.
      final progress = await service.getPracticeProgress(roundId);
      final firstOpen = questions.indexWhere((q) => !progress.containsKey(q.id));
      final help = await _loadHelp(roundId);
      AdCoordinator.preloadRewarded();
      if (widget.levelNumber != null) {
        await _refreshLives();
        _startLifeTicker();
      }
      if (!mounted) return;
      final session = PracticeGameAdapter.createSession(
        roundId: roundId,
        questions: questions,
        progress: progress,
        currentIndex: firstOpen == -1 ? questions.length - 1 : firstOpen,
      );
      final controller = GameController(
        session: session,
        resolveAnswer: _resolvePracticeAnswer,
      );
      setState(() {
        _roundId = roundId;
        _questions = questions;
        _gameController = controller;
        _help = help;
        _answerResult = null;
        _combo = 0;
        _retryUnlocked = false;
        _checking = false;
        _result = null;
        _phase = _Phase.inProgress;
      });
      if (firstOpen != -1) _restorePending();
      if (firstOpen == -1) {
        // Everything was answered but the round was never submitted.
        setState(() => _phase = _Phase.loading);
        await _finish();
      }
    } catch (error, stackTrace) {
      // Keep the real server/client error visible during development.
      // The previous generic message made it impossible to distinguish
      // an unlock problem, stale open round, missing questions, or an
      // unapplied Supabase migration.
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _loadError = error.toString();
        });
      }
      debugPrint('Practice level start failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _busy = false;
    }
  }

  /// Help state is a bonus: if it can't be loaded the round still works.
  Future<HelpState> _loadHelp(String roundId) async {
    try {
      return await SupabaseService.instance
          .getHelpState(contextType: 'practice', contextId: roundId);
    } catch (_) {
      return HelpState.empty();
    }
  }

  /// If the player left while a second chance was being offered, offer it again.
  void _restorePending() {
    final qh = _help.of(_questions[_current].id);
    final first = qh.pendingFirstChoice;
    if (first == null) return;
    setState(() {
      _gameController?.restoreRetryPending();
      _answerResult = AnswerResult.pendingRetry(firstChoice: first, granted: qh.retryGranted);
      _retryUnlocked = qh.retryGranted;
    });
  }

  void _selectOption(String letter) {
    final controller = _gameController;
    if (controller == null) return;
    setState(() => controller.selectOption(letter));
  }

  void _clearSelection() {
    final controller = _gameController;
    if (controller == null || !mounted) return;
    setState(controller.clearSelection);
  }

  Future<GameAnswerResolution> _resolvePracticeAnswer({
    required GameQuestion question,
    required String chosenOption,
    required Duration timeTaken,
  }) async {
    final result = await SupabaseService.instance.answerPracticeQuestion(
      roundId: _roundId!,
      questionId: question.id,
      choice: chosenOption,
    );
    _answerResult = result;
    if (result.isFinal) _combo = result.isCorrect ? _combo + 1 : 0;
    if (result.retryOffered) {
      return GameAnswerResolution.retryOffered(
        firstChoice: result.firstChoice ?? result.chosen,
        retryGranted: result.retryGranted,
      );
    }
    final gameAnswer = PracticeGameAdapter.toGameAnswer(
      questionId: question.id,
      result: result,
      answeredAt: DateTime.now(),
      timeTaken: timeTaken,
    );
    if (gameAnswer == null) {
      throw StateError('Practice returned a non-final answer without a game answer.');
    }
    return GameAnswerResolution.settled(gameAnswer);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Hint: pay with a video or with coins, then two wrong options disappear.
  Future<void> _useHint() async {
    if (_hintBusy) return;
    setState(() => _hintBusy = true);
    try {
      final qId = _questions[_current].id;
      final qh = _help.of(qId);
      if (qh.hintWrong.isEmpty) {
        if (!qh.hintGranted) {
          final source = await pickHintSource(
            context,
            videoAvailable: _help.hintsLeft > 0,
            videoReady: AdCoordinator.rewardedReady.value,
            coins: _help.coins,
            price: _help.hintPrice,
          );
          if (source == null) return; // dismissed
          if (source == HintSource.coins) {
            _help.coins = await SupabaseService.instance.buyHint(
              contextType: 'practice',
              contextId: _roundId!,
              questionId: qId,
            );
            qh.hintGranted = true;
          } else {
            final outcome = await QuizAssist.watchAndClaim(
              contextType: 'practice',
              contextId: _roundId!,
              questionId: qId,
              kind: 'hint',
            );
            if (outcome != RewardOutcome.granted) {
              _snack(QuizAssist.messageForOutcome(outcome));
              return;
            }
            qh.hintGranted = true;
            if (_help.hintsLeft > 0) _help.hintsLeft--;
          }
        }
        final wrong = await SupabaseService.instance
            .useHint(contextType: 'practice', contextId: _roundId!, questionId: qId);
        qh.hintWrong = wrong;
        qh.hintGranted = false;
        if (mounted && wrong.contains(_selected)) {
          _clearSelection();
        }
      }
    } catch (e) {
      _snack(QuizAssist.messageFor(e));
    } finally {
      if (mounted) setState(() => _hintBusy = false);
    }
  }

  /// Second chance: watch a video, then pick again (once).
  Future<void> _startSecondChance() async {
    if (_retryBusy) return;
    setState(() => _retryBusy = true);
    try {
      final qId = _questions[_current].id;
      final qh = _help.of(qId);
      if (!qh.retryGranted) {
        final outcome = await QuizAssist.watchAndClaim(
          contextType: 'practice',
          contextId: _roundId!,
          questionId: qId,
          kind: 'second_chance',
        );
        if (outcome != RewardOutcome.granted) {
          _snack(QuizAssist.messageForOutcome(outcome));
          return; // the player can still tap "No thanks" and carry on
        }
        qh.retryGranted = true;
        if (_help.retriesLeft > 0) _help.retriesLeft--;
      }
      if (mounted) {
        setState(() {
          _retryUnlocked = true;
          _clearSelection();
        });
      }
    } catch (e) {
      _snack(QuizAssist.messageFor(e));
    } finally {
      if (mounted) setState(() => _retryBusy = false);
    }
  }

  /// "No thanks": the wrong answer is locked and the right one is shown.
  Future<void> _declineSecondChance() async {
    if (_retryBusy) return;
    setState(() => _retryBusy = true);
    try {
      final r = await SupabaseService.instance.declineSecondChance(
        contextType: 'practice',
        contextId: _roundId!,
        questionId: _questions[_current].id,
      );
      if (!mounted) return;
      final answeredAt = DateTime.now();
      final gameAnswer = PracticeGameAdapter.toGameAnswer(
        questionId: _questions[_current].id,
        result: r,
        answeredAt: answeredAt,
        timeTaken: answeredAt.difference(_gameSession!.questionStartedAt),
      );
      setState(() {
        _answerResult = r;
        if (r.isFinal) _combo = r.isCorrect ? _combo + 1 : 0;
        if (gameAnswer != null) {
          _gameController?.recordSettledAnswer(gameAnswer);
        }
        _retryUnlocked = false;
      });
    } catch (e) {
      _snack(QuizAssist.messageFor(e));
    } finally {
      if (mounted) setState(() => _retryBusy = false);
    }
  }

  /// Asks the server to check the picked option. A right answer is locked in
  /// and shown; a wrong one may come back as a second-chance offer instead.
  Future<void> _check() async {
    final controller = _gameController;
    if (_checking || controller == null || !controller.canSubmit) return;
    setState(() => _checking = true);
    try {
      final resolution = await controller.submitSelected();
      if (!mounted) return;
      setState(() {
        _checking = false;
        if (resolution?.isRetryOffered == true) {
          _retryUnlocked = _answerResult?.retryGranted ?? false;
        } else {
          _retryUnlocked = false;
        }
      });
      _scheduleAutoNext();
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t check your answer. Please try again.')),
      );
    }
  }

  /// A right answer slides to the next question by itself; a wrong one waits
  /// for the player to read the answer and tap Next.
  void _scheduleAutoNext() {
    final r = _answerResult;
    if (r == null || !r.isFinal || !r.isCorrect) return;
    final index = _current;
    _autoNext?.cancel();
    _autoNext = Timer(kAutoAdvanceDelay, () {
      if (!mounted || _current != index || _phase != _Phase.inProgress) return;
      final now = _answerResult;
      if (now == null || !now.isFinal || !now.isCorrect) return;
      _next();
    });
  }

  Future<void> _next() async {
    _autoNext?.cancel();
    if (_busy) return;
    final controller = _gameController;
    if (controller == null) return;
    if (_current < _questions.length - 1) {
      if (controller.session.status != GameSessionStatus.answerPending) return;
      setState(() {
        controller.advance();
        _answerResult = null;
        _retryUnlocked = false;
      });
      return;
    }

    _busy = true;
    setState(() {
      controller.advance();
      _phase = _Phase.loading;
    });
    try {
      await _finish();
    } catch (error, stackTrace) {
      // Keep the real server/client error visible during development.
      // The previous generic message made it impossible to distinguish
      // an unlock problem, stale open round, missing questions, or an
      // unapplied Supabase migration.
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _loadError = error.toString();
        });
      }
      debugPrint('Practice level start failed: $error');
      debugPrint('$stackTrace');
    } finally {
      _busy = false;
    }
  }

  /// Scores the round from the answers the server has recorded.
  Future<void> _finish() async {
    final result = await SupabaseService.instance.submitPracticeRound(roundId: _roundId!);
    await SupabaseService.instance.publishConfirmedRound(
      result: result,
      dailyChallenge: false,
    );
    AppEvents.notifyProgressChanged();
    if (widget.levelNumber != null) {
      await _refreshLives();
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      _gameController?.complete();
      _phase = _Phase.results;
    });
    // The ad is shown when they tap "Play another round" or leave the tab.
    AdCoordinator.roundFinished();
  }

  /// "Play another round": the interstitial owed for the round just finished
  /// plays first, then the next round loads.
  Future<void> _playAnother() async {
    if (_waitingOnAd) return; // ignore extra taps while the ad is up
    _waitingOnAd = true;
    try {
      await AdCoordinator.showPendingIfAny();
    } finally {
      _waitingOnAd = false;
    }
    if (mounted) _start();
  }

  Future<bool> _handleExit() async {
    if (!mounted) return false;
    if (_phase == _Phase.inProgress) {
      final shouldExit = await showJuaExitDialog(
        context: context,
        title: 'Exit level?',
        message: widget.levelNumber == null
            ? 'Your answered questions are saved. You can return to this round later.'
            : 'Leaving this level ends the current attempt. This attempt will burst one life and start its 5-minute recharge.',
        keepPlayingLabel: 'Keep playing',
        exitLabel: 'Exit',
      );
      if (!shouldExit) return false;

      if (widget.levelNumber != null && _roundId != null) {
        try {
          await SupabaseService.instance.abandonPracticeLevelRound(_roundId!);
          await _refreshLives();
        } catch (error) {
          debugPrint('Could not close abandoned practice level: $error');
        }
      }
      _lifeTimer?.cancel();
      return true;
    }
    return true;
  }

  @override
  void dispose() {
    _autoNext?.cancel();
    _lifeTimer?.cancel();
    super.dispose();
  }

  Widget _contentForPhase() {
    switch (_phase) {
      case _Phase.intro:
        return _IntroView(onStart: _start, levelNumber: widget.levelNumber);
      case _Phase.loading:
        return const Center(child: CircularProgressIndicator());
      case _Phase.error:
        return _ErrorView(
          onRetry: _start,
          message: _loadError,
          onBack: widget.levelNumber == null
              ? null
              : () => Navigator.of(context).pop(),
        );
      case _Phase.inProgress:
        final qh = _help.of(_questions[_current].id);
        return ValueListenableBuilder<bool>(
          valueListenable: AdCoordinator.rewardedReady,
          builder: (context, videoReady, _) => QuizView(
            heading: widget.levelNumber == null
                ? 'Practice round'
                : (widget.levelNumber! % 10 == 0 ? 'Level ${widget.levelNumber} • Math' : 'Level ${widget.levelNumber}'),
            question: _questions[_current],
            index: _current,
            total: _questions.length,
            selected: _selected,
            onSelect: _selectOption,
            result: _answerResult,
            checking: _checking,
            onCheck: _check,
            onNext: _next,
            hiddenOptions: qh.hintWrong,
            canHint: _answerResult == null &&
                qh.hintWrong.isEmpty &&
                (qh.hintGranted || _help.hintsLeft > 0 || _help.coins >= _help.hintPrice),
            hintEnabled: qh.hintGranted ||
                (_help.hintsLeft > 0 && videoReady) ||
                _help.coins >= _help.hintPrice,
            hintBusy: _hintBusy,
            onHint: _useHint,
            retryUnlocked: _retryUnlocked,
            retryBusy: _retryBusy,
            onSecondChance: _startSecondChance,
            onDeclineSecondChance: _declineSecondChance,
            rewardedReady: videoReady || qh.retryGranted || qh.hintGranted,
          ),
        );
      case _Phase.results:
        return _ResultsView(result: _result!, onAgain: _playAnother, levelNumber: widget.levelNumber, lives: _lives);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizOnScreen = _phase == _Phase.inProgress;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppEvents.setQuizActive(AppTabs.today, quizOnScreen),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _handleExit() && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Practice'),
          actions: [
            if (widget.levelNumber != null && _lives != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _LivesBadge(lives: _lives!, now: _lifeClock),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: JuaExitButton(
                onPressed: () async {
                  if (await _handleExit() && mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              _contentForPhase(),
              if (_phase == _Phase.inProgress)
                Positioned(top: 2, right: 12, child: IgnorePointer(child: ComboMeter(combo: _combo))),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  final VoidCallback onStart;
  final int? levelNumber;

  const _IntroView({required this.onStart, this.levelNumber});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 46),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/mascot/pose1.png', height: 120,
                  errorBuilder: (_, __, ___) =>
                      const Text('🎯', textAlign: TextAlign.center, style: TextStyle(fontSize: 56))),
              const SizedBox(height: 12),
              Text(
                levelNumber == null
                    ? 'Practice rounds'
                    : (levelNumber! % 10 == 0 ? 'Level $levelNumber • Math' : 'Level $levelNumber'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1))]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(children: [
                  _Point(Icons.autorenew_rounded,
                      levelNumber == null ? '${AppConfig.practiceRoundSize} fresh questions per round' : 'Earn up to 3 stars • Replay to master the level'),
                  const _Point(Icons.bolt_rounded, 'Earn XP and build your accuracy stats'),
                  const _Point(Icons.local_fire_department_rounded,
                      'Your streak only counts the daily challenge, so practice never puts it at risk'),
                ]),
              ),
              const SizedBox(height: 22),
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

class _Point extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Point(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.savannaGreen),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}


class _ResultsView extends StatefulWidget {
  final AttemptResult result;
  final VoidCallback onAgain;
  final int? levelNumber;
  final PracticeLives? lives;

  const _ResultsView({required this.result, required this.onAgain, this.levelNumber, this.lives});

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> {
  bool _celebrated = false;
  late Future<int> _bestFuture;

  @override
  void initState() {
    super.initState();
    _bestFuture = SupabaseService.instance.getPracticeBestScore();
  }

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
      RewardCelebration.show(
        context,
        rewards: rewards,
        newLevel: widget.result.newLevel,
        leveledUp: widget.result.leveledUp,
        title: 'PRACTICE REWARD',
        subtitle: 'Round complete',
      );
    });
  }

  Future<void> _openNextLevel(int level) async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(levelNumber: level),
      ),
    );
  }

  Widget _journeyActions(BuildContext context) {
    final level = widget.levelNumber;
    final stars = widget.result.practiceStars ?? 0;

    if (level == null) {
      return JuaGlossyButton(
        onPressed: widget.onAgain,
        label: 'Play again',
        icon: Icons.refresh_rounded,
        variant: JuaButtonVariant.action,
      );
    }

    // A zero-star result does not unlock the next level. The player must
    // retry until they earn at least one star.
    if (stars < 1) {
      return Column(
        children: [
          const Text(
            'Earn at least ⭐ 1 to unlock the next level.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          JuaGlossyButton(
            onPressed: widget.onAgain,
            label: 'RETRY LEVEL',
            icon: Icons.refresh_rounded,
            variant: JuaButtonVariant.action,
          ),
        ],
      );
    }

    return FutureBuilder<PracticeJourneyData>(
      future: SupabaseService.instance.getPracticeJourney(throughLevel: level + 1),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final journey = snapshot.data;
        final matching = journey?.levels.where((item) => item.level == level + 1).toList() ?? const [];
        final next = matching.isEmpty ? null : matching.first;

        if (journey != null && next?.unlocked == true) {
          return Column(
            children: [
              JuaGlossyButton(
                onPressed: () => _openNextLevel(level + 1),
                label: 'NEXT LEVEL',
                icon: Icons.arrow_forward_rounded,
                variant: JuaButtonVariant.action,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: widget.onAgain,
                child: const Text('Replay this level'),
              ),
            ],
          );
        }

        final required = journey?.nextBatchRequirement ?? widget.result.nextPracticeBatchRequirement ?? 0;
        final cumulative = journey?.cumulativeStars ?? widget.result.cumulativePracticeStars ?? 0;
        final remaining = (required - cumulative).clamp(0, required);
        final nextBatch = journey?.nextBatch ?? widget.result.nextPracticeBatch ?? 0;

        // This is the end of the currently unlocked batch. Keep the player
        // here until the cumulative mastery gate is reached (or the batch is
        // unlocked through the rewarded-ad flow from the journey screen).
        return Column(
          children: [
            if (remaining > 0 && nextBatch > 1)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sunGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Batch $nextBatch locked',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$remaining more ⭐ needed to unlock the next batch',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text('$cumulative / $required cumulative ⭐'),
                  ],
                ),
              ),
            if (remaining > 0) const SizedBox(height: 12),
            JuaGlossyButton(
              onPressed: widget.onAgain,
              label: 'RETRY LEVEL',
              icon: Icons.refresh_rounded,
              variant: JuaButtonVariant.action,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final accuracy = result.total == 0 ? 0 : ((result.score / result.total) * 100).round();
    final intoLevel = result.newXp % 100;
    final progress = intoLevel / 100;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        children: [
          Center(
            child: Image.asset(
              accuracy >= 70 ? 'assets/mascot/pose4.png' : 'assets/mascot/pose3.png',
              height: 110,
              errorBuilder: (_, __, ___) => Text(result.leveledUp ? '🎉' : accuracy == 100 ? '🔥' : '✅',
                  style: const TextStyle(fontSize: 56)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              (result.practiceStars ?? 1) == 0
                  ? 'Level ${widget.levelNumber ?? ''} failed'
                  : (widget.levelNumber == null ? 'Practice round complete' : 'Level ${widget.levelNumber} complete'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1))]),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('${result.score} / ${result.total} correct • $accuracy%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1))])),
          ),
          if (result.practiceStars != null) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AnimatedStars(stars: result.practiceStars ?? 0),
                    const SizedBox(height: 4),
                    Text('Level ${result.practiceLevel ?? ''} mastery', style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (result.cumulativePracticeStars != null && result.cumulativePracticeAvailableStars != null)
                      Text('${result.cumulativePracticeStars} / ${result.cumulativePracticeAvailableStars} cumulative ⭐', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ],
          if (widget.levelNumber != null) ...[
            const SizedBox(height: 12),
            _LifeOutcomeCard(
              stars: widget.result.practiceStars ?? 0,
              lives: widget.lives,
            ),
          ],
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.bolt_rounded, color: AppColors.sunGold),
                  const SizedBox(width: 8),
                  Text('+${result.xpEarned} XP', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('Level ${result.newLevel}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: progress, minHeight: 9),
                ),
                const SizedBox(height: 6),
                Text('${100 - intoLevel} XP to level ${result.newLevel + 1}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (result.leveledUp) ...[
                  const SizedBox(height: 10),
                  Text('LEVEL UP! You are now level ${result.newLevel}.', style: const TextStyle(color: AppColors.sunGold, fontWeight: FontWeight.w800)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.levelNumber != null && widget.lives != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      (result.practiceStars ?? 0) == 0 ? '💔' : '❤️',
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (result.practiceStars ?? 0) == 0
                            ? 'LIFE BUSTED • This attempt failed. The used life is recharging.'
                            : 'Life used • ${widget.lives!.availableLives}/${widget.lives!.maxLives} available',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (widget.lives!.nextRechargeAt != null)
                      Text(
                        widget.lives!.remainingLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                  ],
                ),
              ),
            ),
          ],
          FutureBuilder<int>(
            future: _bestFuture,
            builder: (context, snapshot) => Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_rounded, color: AppColors.savannaGreen),
                title: Text(snapshot.hasData ? '${snapshot.data} / ${result.total}' : 'Loading…', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Practice personal best'),
              ),
            ),
          ),
          if (result.xpCapped) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'You\'ve reached today\'s practice XP limit (${result.practiceXpCap}). Rounds still count toward your stats, and the limit resets at midnight.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
            ),
          ] else if (result.practiceXpToday != null && result.practiceXpCap != null) ...[
            const SizedBox(height: 12),
            Center(child: Text('Practice XP today: ${result.practiceXpToday} / ${result.practiceXpCap}', style: const TextStyle(color: Colors.white, fontSize: 13, shadows: [Shadow(color: Color(0xCC000000), blurRadius: 4)]))),
          ],
          const SizedBox(height: 24),
          _journeyActions(context),
          const SizedBox(height: 4),
          WhatsAppShareButton(
            text: widget.levelNumber == null
                ? 'I got ${result.score}/${result.total} in a Jua Quiz practice round! Can you beat me? 🇰🇪'
                : 'I just got ${result.practiceStars ?? 0}⭐ on Jua Quiz level ${widget.levelNumber}! Can you beat me? 🇰🇪',
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              if (widget.levelNumber != null) {
                Navigator.of(context).pop();
              } else {
                AppEvents.goToTab(AppTabs.today);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(widget.levelNumber == null ? 'Back to games' : 'Back to journey'),
          ),
        ],
      ),
    );
  }
}

class _LifeOutcomeCard extends StatelessWidget {
  final int stars;
  final PracticeLives? lives;

  const _LifeOutcomeCard({required this.stars, required this.lives});

  @override
  Widget build(BuildContext context) {
    final passed = stars >= 1;
    final label = passed
        ? '❤️ LIFE RETURNED'
        : '💔 LIFE BUSTED';
    final detail = passed
        ? 'You earned at least 1 star, so your life is refunded. You can start the next level without spending a life.'
        : lives?.nextRechargeAt == null
            ? 'This failed attempt used one life. It will recharge in 5 minutes.'
            : 'This failed attempt used one life. Recharge: ${lives!.remainingLabel}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: passed
            ? AppColors.savannaGreen.withValues(alpha: 0.14)
            : Colors.redAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: passed ? AppColors.savannaGreen : Colors.redAccent)),
          const SizedBox(height: 4),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LivesBadge extends StatelessWidget {
  final PracticeLives lives;
  final DateTime now;

  const _LivesBadge({required this.lives, required this.now});

  @override
  Widget build(BuildContext context) {
    final remaining = lives.nextRechargeAt == null
        ? 0
        : lives.nextRechargeAt!.difference(now).inSeconds.clamp(0, 3599);
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        lives.full ? '❤️ ${lives.availableLives}' : '❤️ ${lives.availableLives}  ${minutes}:${seconds}',
        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;
  final VoidCallback? onBack;

  const _ErrorView({
    required this.onRetry,
    this.message,
    this.onBack,
  });

  String _friendlyMessage(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'Couldn\'t load your practice round.';
    }
    final value = raw.toLowerCase();
    if (value.contains('finish_current_practice_level')) {
      return 'Another practice level is still open. Finish or resume that level before starting this one.';
    }
    if (value.contains('previous_level_required')) {
      return 'The previous level must be completed with at least ⭐ 1 before this level opens.';
    }
    if (value.contains('practice_batch_locked')) {
      return 'This batch is still locked. Earn the required cumulative stars first.';
    }
    if (value.contains('no_practice_lives')) {
      return 'No lives available right now. Your next life will recharge in the countdown shown on the Practice Journey.';
    }
    if (value.contains('no questions available')) {
      return 'There are not enough active questions available for this level yet.';
    }
    if (value.contains('not authenticated')) {
      return 'Your session has expired. Please sign in again and retry.';
    }
    return 'Couldn\'t load this level.\n\nServer error: $raw';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 14),
            Text(
              _friendlyMessage(message),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onBack != null) ...[
                  OutlinedButton(
                    onPressed: onBack,
                    child: const Text('Back to journey'),
                  ),
                  const SizedBox(width: 10),
                ],
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
