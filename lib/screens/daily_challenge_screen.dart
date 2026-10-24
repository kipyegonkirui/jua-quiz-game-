import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/ads_service.dart';
import '../models/question.dart';
import '../models/answer_result.dart';
import '../models/help_state.dart';
import '../services/quiz_assist.dart';
import '../widgets/hint_source_sheet.dart';
import '../models/attempt_result.dart';
import '../game/adapters/daily_game_adapter.dart';
import '../game/engine/game_controller.dart';
import '../game/engine/game_session.dart';
import '../game/models/game_answer_resolution.dart';
import '../game/models/game_question.dart';
import '../services/app_events.dart';
import '../theme/app_theme.dart';
import '../widgets/quiz_widgets.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/reward_feedback.dart';
import '../widgets/streak_celebration.dart';
import '../game/progression/streak_service.dart';
import '../widgets/jua_exit_dialog.dart';
import '../widgets/daily_countdown.dart';
import '../widgets/jua_dialog.dart';
import 'account_screen.dart';
import 'practice_journey_screen.dart';
import 'streak_dashboard_screen.dart';

enum _Status { loading, error, alreadyDone, inProgress, results }

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  _Status _status = _Status.loading;
  String? _challengeId;
  List<Question> _questions = [];
  GameController? _gameController;
  GameSession? get _gameSession => _gameController?.session;
  int get _current => _gameController?.session.currentIndex ?? 0;
  String? get _selected => _gameController?.session.selectedOption;
  AnswerResult? _answerResult; // set once the server has checked this question
  bool _checking = false;
  Timer? _autoNext; // moves on by itself after a right answer
  AttemptResult? _result;
  int? _existingStreak;

  // Hints & second chances (Phase 4).
  HelpState _help = HelpState.empty();
  bool _retryUnlocked = false; // second-chance video watched for this question
  bool _hintBusy = false;
  bool _retryBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final service = SupabaseService.instance;
      final challengeId = await service.getTodayChallengeId();
      final done = await service.hasCompletedChallenge(challengeId);
      if (done) {
        final profile = await service.getMyProfile();
        setState(() {
          _challengeId = challengeId;
          _existingStreak = profile.currentStreak;
          _status = _Status.alreadyDone;
        });
        return;
      }
      final questions = await service.getChallengeQuestions(challengeId);
      // If they left mid-challenge, pick up at the first unanswered question.
      final progress = await service.getDailyProgress(challengeId);
      final firstOpen = questions.indexWhere((q) => !progress.containsKey(q.id));
      final help = await _loadHelp(challengeId);
      AdCoordinator.preloadRewarded();
      final session = DailyGameAdapter.createSession(
        challengeId: challengeId,
        questions: questions,
        progress: progress,
        currentIndex: firstOpen == -1 ? questions.length - 1 : firstOpen,
      );
      final controller = GameController(
        session: session,
        resolveAnswer: _resolveDailyAnswer,
      );
      setState(() {
        _challengeId = challengeId;
        _questions = questions;
        _gameController = controller;
        _help = help;
        _answerResult = null;
        _retryUnlocked = false;
        _checking = false;
        _status = _Status.inProgress;
      });
      if (firstOpen != -1) _restorePending();
      if (firstOpen == -1) {
        // Everything was answered but never submitted: finish it now.
        setState(() => _status = _Status.loading);
        await _finish();
      }
    } catch (_) {
      if (mounted) setState(() => _status = _Status.error);
    }
  }

  void _pickOption(String letter) {
    final controller = _gameController;
    if (controller == null) return;
    setState(() => controller.selectOption(letter));
  }

  void _clearSelection() {
    final controller = _gameController;
    if (controller == null || !mounted) return;
    setState(controller.clearSelection);
  }

  Future<GameAnswerResolution> _resolveDailyAnswer({
    required GameQuestion question,
    required String chosenOption,
    required Duration timeTaken,
  }) async {
    final result = await SupabaseService.instance.answerDailyQuestion(
      challengeId: _challengeId!,
      questionId: question.id,
      choice: chosenOption,
    );
    _answerResult = result;
    if (result.retryOffered) {
      return GameAnswerResolution.retryOffered(
        firstChoice: result.firstChoice ?? result.chosen,
        retryGranted: result.retryGranted,
      );
    }
    final gameAnswer = DailyGameAdapter.toGameAnswer(
      questionId: question.id,
      result: result,
      answeredAt: DateTime.now(),
      timeTaken: timeTaken,
    );
    if (gameAnswer == null) {
      throw StateError('Daily challenge returned a non-final answer without a game answer.');
    }
    return GameAnswerResolution.settled(gameAnswer);
  }

  /// Help state is a bonus: if it can't be loaded the quiz still works.
  Future<HelpState> _loadHelp(String challengeId) async {
    try {
      return await SupabaseService.instance
          .getHelpState(contextType: 'daily', contextId: challengeId);
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
              contextType: 'daily',
              contextId: _challengeId!,
              questionId: qId,
            );
            qh.hintGranted = true;
          } else {
            final outcome = await QuizAssist.watchAndClaim(
              contextType: 'daily',
              contextId: _challengeId!,
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
            .useHint(contextType: 'daily', contextId: _challengeId!, questionId: qId);
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
          contextType: 'daily',
          contextId: _challengeId!,
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
        });
        _clearSelection();
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
        contextType: 'daily',
        contextId: _challengeId!,
        questionId: _questions[_current].id,
      );
      if (!mounted) return;
      final answeredAt = DateTime.now();
      final gameAnswer = DailyGameAdapter.toGameAnswer(
        questionId: _questions[_current].id,
        result: r,
        answeredAt: answeredAt,
        timeTaken: answeredAt.difference(_gameSession!.questionStartedAt),
      );
      setState(() {
        _answerResult = r;
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

  /// Asks the server to check the picked option. It comes back with the right
  /// answer and locks the pick, so it can't be changed afterwards.
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
      if (!mounted || _current != index || _status != _Status.inProgress) return;
      final now = _answerResult;
      if (now == null || !now.isFinal || !now.isCorrect) return;
      _nextQuestion();
    });
  }

  @override
  void dispose() {
    _autoNext?.cancel();
    super.dispose();
  }

  Future<void> _nextQuestion() async {
    _autoNext?.cancel();
    final controller = _gameController;
    if (controller == null || controller.session.status != GameSessionStatus.answerPending) return;

    if (_current < _questions.length - 1) {
      setState(() {
        controller.advance();
        _answerResult = null;
        _retryUnlocked = false;
      });
      return;
    }

    setState(() {
      controller.advance();
      _status = _Status.loading;
    });
    try {
      await _finish();
    } catch (_) {
      if (mounted) setState(() => _status = _Status.error);
    }
  }

  /// Scores the challenge from the answers the server has recorded.
  Future<void> _finish() async {
    final result = await SupabaseService.instance.submitAttempt(challengeId: _challengeId!);
    await SupabaseService.instance.publishConfirmedRound(
      result: result,
      dailyChallenge: true,
    );
    AppEvents.notifyProgressChanged();
    if (!mounted) return;
    setState(() {
      _result = result;
      _gameController?.complete();
      _status = _Status.results;
    });
    // The ad is shown when they leave the results (see HomeShell), not on top of them.
    AdCoordinator.roundFinished();
  }

  Future<bool> _handleBack() async {
    if (_status != _Status.inProgress) return true;
    final shouldExit = await showJuaExitDialog(
      context: context,
      title: 'Exit daily challenge?',
      message: 'Your progress is saved. You can come back and continue this challenge later.',
      keepPlayingLabel: 'Keep playing',
      exitLabel: 'Exit',
    );
    return shouldExit;
  }

  @override
  Widget build(BuildContext context) {
    // Tell the shell whether a question is on screen (hides the banner).
    final quizOnScreen = _status == _Status.inProgress;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => AppEvents.setQuizActive(AppTabs.today, quizOnScreen),
    );

    late final Widget content;
    switch (_status) {
      case _Status.loading:
        content = const Center(child: CircularProgressIndicator());
      case _Status.error:
        content = _ErrorView(onRetry: _load);
      case _Status.alreadyDone:
        content = _AlreadyDoneView(streak: _existingStreak ?? 0);
      case _Status.inProgress:
        final qh = _help.of(_questions[_current].id);
        content = ValueListenableBuilder<bool>(
          valueListenable: AdCoordinator.rewardedReady,
          builder: (context, videoReady, _) => QuizView(
            question: _questions[_current],
            index: _current,
            total: _questions.length,
            selected: _selected,
            onSelect: _pickOption,
            result: _answerResult,
            checking: _checking,
            onCheck: _check,
            onNext: _nextQuestion,
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
      case _Status.results:
        content = _ResultsView(result: _result!);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _handleBack() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () async {
              if (await _handleBack() && mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Daily Challenge'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: JuaExitButton(
                onPressed: () async {
                  if (await _handleBack() && mounted) Navigator.of(context).pop();
                },
                size: 52,
              ),
            ),
          ],
        ),
        body: SafeArea(child: content),
      ),
    );
  }
}

class _ResultsView extends StatefulWidget {
  final AttemptResult result;

  const _ResultsView({required this.result});

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> {
  bool _celebrated = false;
  late Future<int> _bestFuture;

  @override
  void initState() {
    super.initState();
    _bestFuture = SupabaseService.instance.getDailyBestScore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_celebrated) return;
    _celebrated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final rewards = <RewardFeedbackItem>[];
      if (widget.result.xpEarned > 0) rewards.add(RewardFeedbackItem.xp(widget.result.xpEarned));
      if (widget.result.coinsEarned > 0) rewards.add(RewardFeedbackItem.coins(widget.result.coinsEarned));
      await RewardCelebration.show(
        context,
        rewards: rewards,
        newLevel: widget.result.newLevel,
        leveledUp: widget.result.leveledUp,
        title: 'DAILY REWARD',
        subtitle: 'Daily challenge complete',
      );
      if (!mounted) return;
      final streak = widget.result.currentStreak;
      if (streak > 0) {
        await StreakCelebration.show(
          context,
          streak: streak,
          longestStreak: widget.result.longestStreak,
          milestone: StreakService.milestoneReached(streak - 1, streak) != null,
          shieldsAwarded: widget.result.streakShieldsAwarded,
          shieldUsed: widget.result.streakShieldUsed,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final accuracy = result.total == 0 ? 0 : ((result.score / result.total) * 100).round();
    final intoLevel = result.newXp % 100;
    final progress = intoLevel / 100;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
        children: [
          Center(child: Text(result.leveledUp ? '🎉' : accuracy == 100 ? '🔥' : '✅', style: const TextStyle(fontSize: 58))),
          const SizedBox(height: 12),
          Center(child: Text('Daily challenge complete', style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: 6),
          Center(child: Text('${result.score} / ${result.total} correct • $accuracy%', style: Theme.of(context).textTheme.headlineMedium)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    const Text('LEVEL UP! Keep the streak going tomorrow.', style: TextStyle(color: AppColors.sunGold, fontWeight: FontWeight.w800)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const DailyCountdownPanel(),
          const SizedBox(height: 12),
          StreakReturnCard(
            streak: result.currentStreak,
            onPlay: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PracticeJourneyScreen()),
            ),
          ),
          if (result.streakShields > 0 || result.streakShieldUsed) ...[
            const SizedBox(height: 12),
            _ShieldStatusCard(
              shields: result.streakShields,
              awarded: result.streakShieldsAwarded,
              used: result.streakShieldUsed,
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ResultStat(icon: Icons.local_fire_department_rounded, label: 'Streak', value: '${result.currentStreak} days')),
            const SizedBox(width: 12),
            Expanded(child: _ResultStat(icon: Icons.emoji_events_rounded, label: 'Best streak', value: '${result.longestStreak} days')),
          ]),
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: _bestFuture,
            builder: (context, snapshot) => _ResultStat(
              icon: Icons.workspace_premium_rounded,
              label: 'Personal best',
              value: snapshot.hasData ? '${snapshot.data} / ${result.total}' : 'Loading…',
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StreakDashboardScreen()),
            ),
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text('View streak history'),
          ),
          const SizedBox(height: 12),
          const _PracticeButton(),
          const SizedBox(height: 12),
          const Center(child: Text('Come back tomorrow for a new daily challenge.', style: TextStyle(color: Colors.black54))),
          if (SupabaseService.instance.isGuest) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountScreen(mode: AccountFlowMode.createAccount)),
              ),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Save this progress with an account'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShieldStatusCard extends StatelessWidget {
  final int shields;
  final int awarded;
  final bool used;

  const _ShieldStatusCard({
    required this.shields,
    required this.awarded,
    required this.used,
  });

  @override
  Widget build(BuildContext context) {
    final message = used
        ? 'Your shield protected the streak from a missed day.'
        : awarded > 0
            ? 'You earned $awarded new streak shield${awarded == 1 ? '' : 's'}.'
            : 'A shield protects one missed Daily Challenge day.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$shields Streak Shield${shields == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(message, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(icon, size: 22, color: AppColors.savannaGreen),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ])),
      ]),
    ),
  );
}

class _AlreadyDoneView extends StatelessWidget {
  final int streak;

  const _AlreadyDoneView({required this.streak});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: JuaDialogCard(
              title: "Today's challenge is done",
              message: streak > 0 ? '🔥 $streak-day streak. Come back tomorrow to keep it alive.' : 'Come back tomorrow for a new one.',
              art: JuaDialogArt.starLaurel,
              artHeight: 104,
              tone: JuaDialogTone.orange,
              content: const DailyCountdownPanel(),
              buttons: [
                JuaDialogButton(
                  label: 'Keep playing',
                  icon: Icons.bolt_rounded,
                  style: JuaDialogButtonStyle.green,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PracticeJourneyScreen()),
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

class _PracticeButton extends StatelessWidget {
  const _PracticeButton();

  @override
  Widget build(BuildContext context) {
    return JuaGlossyButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PracticeJourneyScreen()),
      ),
      icon: Icons.bolt_rounded,
      label: 'Keep playing',
      variant: JuaButtonVariant.action,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Couldn\'t load today\'s challenge.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
