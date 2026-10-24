import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/mode_journey.dart';
import '../models/odd_one_out.dart';
import '../services/ads_service.dart';
import '../services/app_events.dart';
import '../services/odd_one_out_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auto_advance.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/jua_exit_dialog.dart';
import '../widgets/mode_level_summary.dart';
import '../widgets/odd_item_view.dart';
import '../widgets/reward_feedback.dart';
import '../models/odd_survival.dart';
import 'odd_survival_screen.dart';

enum _Stage { lobby, loading, playing, results }

/// Odd One Out: tap the item that does not belong.
///
/// Lobby -> Daily set (one shared attempt per day) or Quick Play (endless).
/// Every answer reveals a one-line explanation, correct answers build a combo
/// that multiplies the score, and the daily set can be shared as an emoji grid.
class OddOneOutScreen extends StatefulWidget {
  /// When set, this is a journey level (stars, lives, quick-play puzzles, no
  /// lobby); otherwise the usual lobby with the Daily Set and Quick Play.
  final int? levelNumber;

  const OddOneOutScreen({super.key, this.levelNumber});

  @override
  State<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

class _OddOneOutScreenState extends State<OddOneOutScreen> {
  static const int _hintCost = 30; // must match v_cost in use_odd_one_out_hint()

  _Stage _stage = _Stage.lobby;

  // Lobby
  String? _levelError;
  bool get _isLevel => widget.levelNumber != null;

  OddOneOutStatus? _status;
  bool _statusLoading = true;
  String? _statusError;

  // Round
  OddOneOutMode _mode = OddOneOutMode.quick;
  String? _roundId;
  List<OddOneOutPuzzle> _puzzles = const [];
  int _index = 0;
  int _combo = 0;
  bool _hintUsed = false;
  bool _hintBusy = false;
  bool _watchBusy = false;
  Set<String> _eliminated = <String>{};
  OddOneOutAnswerResult? _answer;
  bool _answering = false;
  bool _submitting = false;
  bool _waitingOnAd = false;
  OddOneOutResult? _result;

  Timer? _timer;
  Timer? _autoNext; // right answers roll on by themselves
  static const Duration _autoNextDelay = Duration(milliseconds: 2200);
  int _remainingMs = 12000;
  DateTime? _startedAt;

  OddOneOutPuzzle? get _puzzle => _puzzles.isEmpty ? null : _puzzles[_index];
  bool get _answered => _answer != null;

  @override
  void initState() {
    super.initState();
    if (_isLevel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start(OddOneOutMode.quick);
      });
    } else {
      _loadStatus();
    }
  }

  @override
  void dispose() {
    _autoNext?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- helpers --

  String _friendly(Object e) {
    final raw = e.toString();
    if (raw.contains('daily_already_played')) {
      return "You've already played today's set. Come back tomorrow!";
    }
    if (raw.contains('not_enough_coins')) return 'Not enough coins for a hint.';
    if (raw.contains('watch_limit_reached')) return "You've used today's free hints. Come back tomorrow, or use coins.";
    if (raw.contains('no_puzzles_available')) {
      return 'No puzzles are available yet. Please try again later.';
    }
    if (raw.contains('round_expired')) return 'That round expired. Start a new one.';
    return raw.replaceFirst('Exception: ', '');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------------------- lobby --

  Future<void> _loadStatus() async {
    setState(() {
      _statusLoading = true;
      _statusError = null;
    });
    try {
      final status = await OddOneOutService.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _statusLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLoading = false;
        _statusError = _friendly(e);
      });
    }
  }

  Future<void> _copyShare(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    _toast('Result copied. Paste it in WhatsApp and challenge a friend!');
  }

  // ---------------------------------------------------------------- round --

  Future<void> _start(OddOneOutMode mode) async {
    setState(() {
      _stage = _Stage.loading;
      _mode = mode;
      _result = null;
      _levelError = null;
    });
    try {
      final roundId = _isLevel
          ? await SupabaseService.instance.startModeLevel(JourneyMode.oddOneOut, widget.levelNumber!)
          : await OddOneOutService.startRound(mode);
      final puzzles = await OddOneOutService.getPuzzles(roundId);
      if (!mounted) return;
      if (puzzles.isEmpty) throw StateError('no_puzzles_available');

      // Resume at the first puzzle that has not been answered yet.
      final firstOpen = puzzles.indexWhere((p) => !p.answered);
      final index = firstOpen == -1 ? puzzles.length - 1 : firstOpen;
      final previous = firstOpen == -1
          ? puzzles.last
          : (firstOpen > 0 ? puzzles[firstOpen - 1] : null);

      setState(() {
        _roundId = roundId;
        _puzzles = puzzles;
        _index = index;
        _combo = previous?.combo ?? 0;
        _hintUsed = puzzles[index].hintUsed;
        _eliminated = puzzles[index].eliminated;
        // A fully answered but unsubmitted round shows its last reveal so the
        // player can tap "See Results".
        _answer = firstOpen == -1
            ? OddOneOutAnswerResult.fromAnsweredPuzzle(puzzles[index])
            : null;
        _stage = _Stage.playing;
      });
      if (firstOpen != -1) {
        _startPuzzleTimer();
      } else if (_answer?.isCorrect == true) {
        _scheduleAutoNext(); // the bar is showing, so it must actually finish
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.lobby;
        if (_isLevel) _levelError = modeLevelErrorText(e);
      });
      if (_isLevel) return;
      _toast(_friendly(e));
      _loadStatus();
    }
  }

  /// Starts the countdown. With [resume] the original start time is kept, so a
  /// failed network call can never buy the player extra time.
  void _startPuzzleTimer({bool resume = false}) {
    _timer?.cancel();
    final limit = (_puzzle?.timeLimitSeconds ?? 12) * 1000;
    if (!resume || _startedAt == null) {
      _remainingMs = limit;
      _startedAt = DateTime.now();
    }
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _answered || _answering) return;
      final started = _startedAt;
      if (started == null) return;
      final left = limit - DateTime.now().difference(started).inMilliseconds;
      if (left <= 0) {
        _remainingMs = 0;
        _timer?.cancel();
        _answerChoice('timeout');
      } else {
        setState(() => _remainingMs = left);
      }
    });
  }

  Future<void> _answerChoice(String choice) async {
    final roundId = _roundId;
    final puzzle = _puzzle;
    if (roundId == null || puzzle == null || _answering || _answered) return;
    _timer?.cancel();
    setState(() => _answering = true);
    final limitMs = puzzle.timeLimitSeconds * 1000;
    final elapsed = _startedAt == null
        ? limitMs
        : DateTime.now().difference(_startedAt!).inMilliseconds.clamp(0, limitMs).toInt();
    try {
      final result = await OddOneOutService.answer(
        roundId: roundId,
        puzzleId: puzzle.id,
        choice: choice,
        timeMs: elapsed,
      );
      if (!mounted) return;
      if (result.isCorrect) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
      setState(() {
        _answer = result;
        _combo = result.combo;
        _answering = false;
      });
      if (result.isCorrect) _scheduleAutoNext();
    } catch (e) {
      if (!mounted) return;
      setState(() => _answering = false);
      _toast(_friendly(e));
      if (choice == 'timeout') {
        // Time is already up: try to record it again shortly instead of
        // hammering the server every tick.
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted && !_answered && !_answering) _answerChoice('timeout');
        });
      } else {
        _startPuzzleTimer(resume: true);
      }
    }
  }

  Future<void> _useHint() async {
    final roundId = _roundId;
    final puzzle = _puzzle;
    if (roundId == null || puzzle == null || _answered || _answering || _hintUsed || _hintBusy) {
      return;
    }
    setState(() => _hintBusy = true);
    try {
      final result = await OddOneOutService.useHint(roundId: roundId, puzzleId: puzzle.id);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _hintUsed = true;
        _eliminated = result.eliminatedOptions;
        _hintBusy = false;
      });
      if (result.coinsSpent > 0) _toast('Two wrong items removed • ${result.coinsSpent} coins');
    } catch (e) {
      if (!mounted) return;
      setState(() => _hintBusy = false);
      _toast(_friendly(e));
    }
  }

  /// Time spent watching the video is not taken from the puzzle clock.
  void _resumeAfterAd(DateTime? pausedAt) {
    final started = _startedAt;
    if (pausedAt != null && started != null) {
      _startedAt = started.add(DateTime.now().difference(pausedAt));
    }
    _startPuzzleTimer(resume: true);
  }

  /// Watch a rewarded video, then the server removes ONE wrong item (free).
  Future<void> _useWatchHint() async {
    final roundId = _roundId;
    final puzzle = _puzzle;
    if (roundId == null || puzzle == null || _answered || _answering || _hintUsed || _hintBusy || _watchBusy) {
      return;
    }
    DateTime? pausedAt;
    setState(() => _watchBusy = true);
    try {
      _timer?.cancel();
      pausedAt = DateTime.now();
      final shown = await AdCoordinator.showRewarded();
      if (!mounted) return;
      if (shown != RewardedResult.earned) {
        setState(() => _watchBusy = false);
        _resumeAfterAd(pausedAt);
        _toast(shown == RewardedResult.notEarned
            ? 'Watch the whole video to remove an item.'
            : 'No video is available right now. Try again in a moment.');
        return;
      }
      final result = await OddOneOutService.useWatchHint(roundId: roundId, puzzleId: puzzle.id);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _hintUsed = true;
        _eliminated = result.eliminatedOptions;
        _watchBusy = false;
      });
      _resumeAfterAd(pausedAt);
      _toast('One wrong item removed');
    } catch (e) {
      if (!mounted) return;
      setState(() => _watchBusy = false);
      _resumeAfterAd(pausedAt);
      _toast(_friendly(e));
    }
  }

  /// A right answer moves on by itself after a moment (long enough to read the
  /// explanation); a wrong one waits for the player to tap Next.
  void _scheduleAutoNext() {
    final index = _index;
    _autoNext?.cancel();
    _autoNext = Timer(_autoNextDelay, () {
      if (!mounted || _index != index || !_answered || _submitting) return;
      if (_answer?.isCorrect != true) return;
      _next();
    });
  }

  Future<void> _next() async {
    _autoNext?.cancel();
    if (!_answered) return;
    if (_index + 1 < _puzzles.length) {
      final next = _puzzles[_index + 1];
      setState(() {
        _index++;
        _hintUsed = next.hintUsed;
        _eliminated = next.eliminated;
        _answer = null;
      });
      _startPuzzleTimer();
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_submitting) return;
    final roundId = _roundId;
    if (roundId == null) return;
    setState(() => _submitting = true);
    try {
      final result = await OddOneOutService.submit(roundId);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _result = result;
        _submitting = false;
        _stage = _Stage.results;
      });
      // The interstitial owed for this round plays when they tap "Play Again"
      // or leave the results screen.
      AdCoordinator.roundFinished();

      final rewards = <RewardFeedbackItem>[
        if (result.xpEarned > 0) RewardFeedbackItem.xp(result.xpEarned),
        if (result.coinsEarned > 0) RewardFeedbackItem.coins(result.coinsEarned),
      ];
      await RewardCelebration.show(
        context,
        rewards: rewards,
        title: result.isDaily ? 'DAILY SET COMPLETE!' : 'ODD ONE OUT COMPLETE!',
        subtitle: '${result.correct}/${result.total} correct • ${result.score} points',
        newLevel: result.newLevel,
        leveledUp: result.leveledUp,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(_friendly(e));
    }
  }

  Future<void> _showAdThen(VoidCallback action) async {
    if (_waitingOnAd) return; // ignore extra taps while the ad is up
    _waitingOnAd = true;
    try {
      await AdCoordinator.showPendingIfAny();
    } finally {
      _waitingOnAd = false;
    }
    if (mounted) action();
  }

  Future<void> _playAgain() => _showAdThen(() => _start(OddOneOutMode.quick));

  Future<void> _backToLobby() => _showAdThen(() {
        setState(() {
          _stage = _Stage.lobby;
          _result = null;
          _answer = null;
        });
        _loadStatus();
      });

  Future<bool> _confirmExit() async {
    if (_stage != _Stage.playing) return true;
    final daily = _mode == OddOneOutMode.daily;
    if (_isLevel) {
      final leave = await showJuaExitDialog(
        context: context,
        title: 'Exit level?',
        message: 'Leaving this level ends the attempt. It will burst one life and start its 5-minute recharge.',
        keepPlayingLabel: 'Keep playing',
        exitLabel: 'Leave',
      );
      final roundId = _roundId;
      if (leave && roundId != null) {
        _timer?.cancel();
        try {
          await SupabaseService.instance.abandonModeLevel(roundId);
        } catch (e) {
          debugPrint('Could not close abandoned Odd One Out level: $e');
        }
      }
      return leave;
    }
    return showJuaExitDialog(
      context: context,
      title: 'Leave Odd One Out?',
      message: daily
          ? "Your progress is saved and you can resume today's set, but you only get one attempt per day."
          : 'Your progress is saved. You can pick this round up again later.',
      keepPlayingLabel: 'Keep playing',
      exitLabel: 'Leave',
    );
  }

  // --------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.juaSkyBlue,
        appBar: AppBar(
          title: Text(_isLevel ? 'ODD ONE OUT • LEVEL ${widget.levelNumber}' : 'ODD ONE OUT'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: switch (_stage) {
          _Stage.lobby => _buildLobby(),
          _Stage.loading => const Center(child: CircularProgressIndicator()),
          _Stage.playing => _buildGame(),
          _Stage.results => _buildResults(_result!),
        },
      ),
    );
  }

  // --------------------------------------------------------------- lobby --

  Widget _buildLevelError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_rounded, size: 54, color: Colors.white),
            const SizedBox(height: 14),
            Text(
              _levelError ?? 'Could not start this level.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            JuaGlossyButton(label: 'Try Again', icon: Icons.refresh_rounded, onPressed: () => _start(OddOneOutMode.quick)),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to journey'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobby() {
    if (_isLevel) return _buildLevelError();
    if (_statusLoading) return const Center(child: CircularProgressIndicator());
    if (_statusError != null || _status == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_alt_rounded, size: 54, color: Colors.white),
              const SizedBox(height: 14),
              Text(
                _statusError ?? 'Could not load Odd One Out.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              JuaGlossyButton(label: 'Try Again', icon: Icons.refresh_rounded, onPressed: _loadStatus),
            ],
          ),
        ),
      );
    }
    final s = _status!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        children: [
          const Center(child: Text('🔎', style: TextStyle(fontSize: 54))),
          const SizedBox(height: 4),
          const Text(
            'Spot the one that does not belong',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          _buildSurvivalCard(),
          const SizedBox(height: 14),
          _buildDailyCard(s),
          const SizedBox(height: 14),
          _buildQuickCard(s),
        ],
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 8))],
      );

  Widget _buildSurvivalCard() {
    return FutureBuilder<SurvivalStatus>(
      future: SupabaseService.instance.getOddSurvivalStatus(),
      builder: (context, snap) {
        final st = snap.data;
        final best = st == null || st.bestScore == 0 ? null : 'Best: ${st.bestScore}  •  streak x${st.bestStreak}';
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFE8590C)]),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Text('🔥', style: TextStyle(fontSize: 26)),
                SizedBox(width: 8),
                Expanded(child: Text('Survival Run', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white))),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Three strikes. Puzzles get harder and faster. Chain correct answers for a Hot Streak and see how long you last.',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
              if (best != null) ...[
                const SizedBox(height: 8),
                Text(best, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFE9A8))),
              ],
              const SizedBox(height: 14),
              JuaGlossyButton(
                label: st?.hasActiveRun == true ? 'Resume Run' : 'Start Run',
                icon: Icons.local_fire_department_rounded,
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const OddSurvivalScreen()));
                  if (mounted) setState(() {}); // refresh best score
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyCard(OddOneOutStatus s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('☀️', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Daily Set', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
              ),
              if (s.dailyStreak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.sunGold.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                  child: Text('🔥 ${s.dailyStreak}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (s.dailyDone) ...[
            Center(child: Text(s.dailyPattern, style: const TextStyle(fontSize: 26, letterSpacing: 2))),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '${s.dailyCorrect}/${s.dailyTotal} • ${s.dailyScore} pts',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.inkBrown),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Next set in ${formatOddOneOutCountdown(timeUntilNextNairobiDay())}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 14),
            JuaGlossyButton(
              label: 'Copy Result',
              icon: Icons.share_rounded,
              variant: JuaButtonVariant.action,
              onPressed: () => _copyShare(s.dailyShareText),
            ),
          ] else ...[
            Text(
              s.dailyStreak > 0
                  ? "Same puzzles for everyone, one try a day. Play today to keep your ${s.dailyStreak}-day streak!"
                  : 'Same puzzles for everyone, one try a day. Start your streak today!',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            JuaGlossyButton(
              label: s.dailyInProgress ? "Resume Today's Set" : "Play Today's Set",
              icon: Icons.wb_sunny_rounded,
              onPressed: () => _start(OddOneOutMode.daily),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickCard(OddOneOutStatus s) {
    final left = s.rewardedRoundsLeft;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('⚡', style: TextStyle(fontSize: 26)),
              SizedBox(width: 8),
              Text('Quick Play', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Endless rounds. Answer fast and chain correct answers to build a combo for bonus points.',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Text(
            [
              if (s.bestQuickScore > 0) 'Best: ${s.bestQuickScore}',
              left > 0 ? '$left rewarded ${left == 1 ? 'round' : 'rounds'} left today' : 'Rewards reset at midnight',
            ].join('  •  '),
            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          JuaGlossyButton(
            label: 'Play',
            icon: Icons.play_arrow_rounded,
            variant: JuaButtonVariant.action,
            onPressed: () => _start(OddOneOutMode.quick),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- game --

  Widget _buildGame() {
    final q = _puzzle!;
    final seconds = (_remainingMs / 1000).ceil();
    final timerFraction = (_remainingMs / (q.timeLimitSeconds * 1000)).clamp(0.0, 1.0);
    final progress = _puzzles.isEmpty ? 0.0 : (_index + 1) / _puzzles.length;
    final answer = _answer;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('${_index + 1}/${_puzzles.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    if (_combo >= 2)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.sunGold, borderRadius: BorderRadius.circular(99)),
                        child: Text(
                          '🔥 x${oddOneOutComboMultiplier(_combo).toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.inkBrown, fontSize: 13),
                        ),
                      ),
                    const Spacer(),
                    const Icon(Icons.monetization_on_rounded, color: AppColors.sunGold, size: 18),
                    const SizedBox(width: 4),
                    ValueListenableBuilder(
                      valueListenable: AppEvents.profile,
                      builder: (_, profile, __) => Text('${profile?.coins ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: Colors.white24),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: answer == null ? timerFraction : 0,
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(AppColors.earthRed),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(answer == null ? '$seconds s' : '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35), borderRadius: BorderRadius.circular(99)),
                    child: Text(q.typeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Which one does NOT belong?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  _buildTiles(q),
                  const SizedBox(height: 14),
                  _buildHintBar(),
                  if (answer != null) ...[
                    _buildReveal(answer),
                    const SizedBox(height: 14),
                    if (answer.isCorrect)
                      AutoAdvanceBar(
                        duration: _autoNextDelay,
                        label: _index + 1 == _puzzles.length ? 'Finishing up…' : 'Next puzzle…',
                        onSkip: _submitting ? null : _next,
                      )
                    else
                      JuaGlossyButton(
                        label: _index + 1 == _puzzles.length ? 'See Results' : 'Next',
                        icon: _index + 1 == _puzzles.length ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
                        variant: JuaButtonVariant.action,
                        onPressed: _submitting ? null : _next,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiles(OddOneOutPuzzle q) {
    Widget pair(String left, String right) => Row(
          children: [
            Expanded(child: _buildTile(q, left)),
            const SizedBox(width: 12),
            Expanded(child: _buildTile(q, right)),
          ],
        );
    return Column(children: [pair('a', 'b'), const SizedBox(height: 12), pair('c', 'd')]);
  }

  Widget _buildTile(OddOneOutPuzzle q, String key) {
    final answer = _answer;
    final label = q.items[key] ?? '';
    final hasImages = OddItemRef.anyImage(q.items.values);
    final removed = _eliminated.contains(key);
    final isOdd = answer?.oddOption == key;
    final isChosen = answer?.chosen == key;

    var fill = Colors.white;
    var textColor = AppColors.inkBrown;
    if (answer != null && isOdd) {
      fill = AppColors.savannaGreen.withValues(alpha: .92);
      textColor = Colors.white;
    } else if (answer != null && isChosen) {
      fill = AppColors.earthRed.withValues(alpha: .92);
      textColor = Colors.white;
    }

    return Opacity(
      opacity: removed && answer == null ? .28 : 1,
      child: IgnorePointer(
        ignoring: removed || answer != null || _answering,
        child: GestureDetector(
          onTap: () => _answerChoice(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: hasImages ? 120 : 104,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: hasImages ? 6 : 0),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                OddItemView(
                  item: label,
                  imageSize: hasImages ? 92 : 84,
                  textStyle: TextStyle(
                    fontSize: q.isVisual ? 44 : 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                if (answer != null && isOdd)
                  const Positioned(top: 8, right: 4, child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)),
                if (answer != null && isChosen && !isOdd)
                  const Positioned(top: 8, right: 4, child: Icon(Icons.cancel_rounded, color: Colors.white, size: 20)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHintBar() {
    if (_answered) return const SizedBox.shrink();
    final busy = _hintBusy || _watchBusy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppColors.sunGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _hintUsed ? 'Wrong items removed' : 'Need help?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          if (!_hintUsed) ...[
            ValueListenableBuilder<bool>(
              valueListenable: AdCoordinator.rewardedReady,
              builder: (_, ready, __) => TextButton.icon(
                onPressed: busy ? null : _useWatchHint,
                icon: Icon(ready ? Icons.play_circle_fill_rounded : Icons.hourglass_top_rounded, size: 18),
                label: const Text('Watch: remove 1'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ),
            TextButton.icon(
              onPressed: busy ? null : _useHint,
              icon: const Icon(Icons.monetization_on_rounded, size: 16),
              label: const Text('$_hintCost: remove 2'),
              style: TextButton.styleFrom(foregroundColor: AppColors.sunGold),
            ),
          ],
        ],
      ),
    );
  }

  /// The "aha" moment: why this was the odd one out.
  Widget _buildReveal(OddOneOutAnswerResult a) {
    final timedOut = a.chosen == 'timeout';
    final title = a.isCorrect
        ? 'Correct!  +${a.score}'
        : timedOut
            ? "Time's up!"
            : 'Not quite';
    final color = a.isCorrect ? AppColors.savannaGreen : AppColors.earthRed;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(a.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color))),
            ],
          ),
          if (a.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(a.explanation, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.inkBrown)),
          ],
          if (a.isCorrect && a.combo >= 2) ...[
            const SizedBox(height: 8),
            Text(
              '🔥 Combo x${a.combo} • score x${oddOneOutComboMultiplier(a.combo).toStringAsFixed(1)}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- results --

  Widget _buildResults(OddOneOutResult r) {
    final accuracy = r.total == 0 ? 0 : (r.correct / r.total * 100).round();
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Text(r.isDaily ? '☀️' : '🔎', style: const TextStyle(fontSize: 58)),
              Text(
                oddOneOutVerdict(r.correct, r.total),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: Column(
                  children: [
                    Text(r.pattern, style: const TextStyle(fontSize: 24, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text('${r.score}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
                    const Text('FINAL SCORE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _stat('${r.correct}/${r.total}', 'CORRECT'),
                        _stat('$accuracy%', 'ACCURACY'),
                        _stat('x${r.maxCombo}', 'BEST COMBO'),
                      ],
                    ),
                    if (r.isDaily && r.dailyStreak > 0) ...[
                      const SizedBox(height: 14),
                      Text('🔥 ${r.dailyStreak}-day streak', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
                    ],
                    if (r.rewardsCapped) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Daily reward limit reached. Keep playing for the score!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_isLevel && _roundId != null)
                ModeLevelSummary(
                  mode: JourneyMode.oddOneOut,
                  roundId: _roundId!,
                  level: widget.levelNumber!,
                  onDark: true,
                  onRetry: () => _showAdThen(() => _start(OddOneOutMode.quick)),
                  onOpenLevel: (next) => _showAdThen(() {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(builder: (_) => OddOneOutScreen(levelNumber: next)),
                    );
                  }),
                )
              else if (r.isDaily) ...[
                JuaGlossyButton(
                  label: 'Copy Result',
                  icon: Icons.share_rounded,
                  onPressed: () => _copyShare(r.shareText),
                ),
                const SizedBox(height: 6),
                Text(
                  'Next set in ${formatOddOneOutCountdown(timeUntilNextNairobiDay())}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                JuaGlossyButton(
                  label: 'Play Quick Round',
                  icon: Icons.bolt_rounded,
                  variant: JuaButtonVariant.action,
                  onPressed: _playAgain,
                ),
              ] else
                JuaGlossyButton(label: 'Play Again', icon: Icons.replay_rounded, onPressed: _playAgain),
              if (!_isLevel) ...[
                const SizedBox(height: 10),
                JuaGlossyButton(
                  label: 'Back to Menu',
                  icon: Icons.grid_view_rounded,
                  variant: r.isDaily ? JuaButtonVariant.play : JuaButtonVariant.action,
                  onPressed: _backToLobby,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54)),
        ],
      );
}
