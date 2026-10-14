import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/odd_survival.dart';
import '../services/app_events.dart';
import '../services/sound_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_effects.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/jua_dialog.dart';
import '../widgets/reward_feedback.dart';
import '../widgets/share_button.dart';

enum _Stage { loading, playing, offer, results, error }

/// Odd One Out: SURVIVAL RUN.
/// Endless puzzles, three strikes. Every correct answer builds a streak that
/// multiplies the score (Hot Streak at 5). Puzzles get harder and faster the
/// longer you last; a miss costs a strike and breaks the streak. When the last
/// strike lands on a good run you can buy a Second Wind to carry on.
class OddSurvivalScreen extends StatefulWidget {
  const OddSurvivalScreen({super.key});

  @override
  State<OddSurvivalScreen> createState() => _OddSurvivalScreenState();
}

class _OddSurvivalScreenState extends State<OddSurvivalScreen> {
  _Stage _stage = _Stage.loading;
  String? _error;

  SurvivalState? _state;
  SurvivalPuzzle? _puzzle;
  SurvivalAnswer? _answer; // reveal of the puzzle just answered
  String? _chosen;
  bool _answering = false;
  bool _windBusy = false;
  SurvivalResult? _result;

  Timer? _timer;
  Timer? _autoNext;
  DateTime? _startedAt;
  int _limitMs = 10000;
  int _remainingMs = 10000;
  int _lastTickSecond = -1;

  bool get _revealing => _answer != null;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoNext?.cancel();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  String _friendly(Object e) {
    final raw = e.toString();
    if (raw.contains('not_enough_coins')) return 'Not enough coins for a Second Wind.';
    if (raw.contains('no_puzzles_available')) return 'No puzzles are available yet.';
    return raw.replaceFirst('Exception: ', '');
  }

  // ---------------------------------------------------------------- flow --

  Future<void> _begin() async {
    setState(() {
      _stage = _Stage.loading;
      _error = null;
      _answer = null;
      _chosen = null;
      _result = null;
    });
    try {
      final state = await SupabaseService.instance.startOddSurvivalRun();
      if (!mounted) return;
      _applyState(state);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = _friendly(e);
      });
    }
  }

  /// Shows whatever the server says should happen next.
  void _applyState(SurvivalState state) {
    _state = state;
    if (state.status == 'offer') {
      setState(() => _stage = _Stage.offer);
      return;
    }
    if (state.status == 'over' || state.puzzle == null) {
      _finish();
      return;
    }
    _showPuzzle(state.puzzle!);
  }

  Future<void> _showPuzzle(SurvivalPuzzle puzzle) async {
    _autoNext?.cancel();
    setState(() {
      _puzzle = puzzle;
      _answer = null;
      _chosen = null;
      _answering = false;
      _stage = _Stage.playing;
      _limitMs = puzzle.timeLimitMs;
      _remainingMs = puzzle.remainingMs;
      _lastTickSecond = -1;
    });
    // The server starts this puzzle's clock now, not while the last reveal was on screen.
    var remaining = puzzle.remainingMs;
    try {
      final s = await SupabaseService.instance.beginOddSurvivalPuzzle(_state!.runId, puzzle.id);
      remaining = s.puzzle?.remainingMs ?? remaining;
    } catch (_) {/* the answer call still enforces the real time */}
    if (!mounted) return;
    _startTimer(remaining);
  }

  void _startTimer(int remainingMs) {
    _timer?.cancel();
    _remainingMs = remainingMs;
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _revealing || _answering) return;
      final left = remainingMs - DateTime.now().difference(_startedAt!).inMilliseconds;
      if (left <= 0) {
        _timer?.cancel();
        setState(() => _remainingMs = 0);
        _submit('timeout');
      } else {
        final sec = (left / 1000).ceil();
        if (sec <= 3 && sec != _lastTickSecond) {
          _lastTickSecond = sec;
          SoundService.instance.play(Sfx.tick);
        }
        setState(() => _remainingMs = left);
      }
    });
  }

  Future<void> _submit(String choice) async {
    final puzzle = _puzzle;
    final state = _state;
    if (puzzle == null || state == null || _answering || _revealing) return;
    _timer?.cancel();
    setState(() {
      _answering = true;
      _chosen = choice == 'timeout' ? null : choice;
    });
    try {
      final answer = await SupabaseService.instance.answerOddSurvival(state.runId, puzzle.id, choice);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (answer.hotStreak && answer.state.streak == 5) SoundService.instance.play(Sfx.levelUp);
      setState(() {
        _answer = answer;
        _state = answer.state;
        _answering = false;
      });
      final next = answer.state;
      if (next.status == 'playing' && answer.isCorrect) {
        // Fast loop: correct answers roll on by themselves.
        _autoNext = Timer(const Duration(milliseconds: 1500), _continue);
      } else if (next.status == 'over') {
        _autoNext = Timer(const Duration(milliseconds: 1800), _finish);
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      setState(() => _answering = false);
      if (raw.contains('run_not_playing') || raw.contains('wrong_puzzle') || raw.contains('run_not_found')) {
        _begin(); // out of sync with the server: resume or start fresh
        return;
      }
      _toast(_friendly(e));
      if (choice == 'timeout') {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted && !_revealing && !_answering) _submit('timeout');
        });
      } else {
        _startTimer(_remainingMs);
      }
    }
  }

  /// Leaves the reveal and moves to whatever comes next.
  void _continue() {
    _autoNext?.cancel();
    final state = _state;
    if (state == null || !_revealing) return;
    if (state.status == 'playing' && state.puzzle != null) {
      _showPuzzle(state.puzzle!);
    } else if (state.status == 'offer') {
      setState(() => _stage = _Stage.offer);
    } else {
      _finish();
    }
  }

  Future<void> _secondWind() async {
    final state = _state;
    if (state == null || _windBusy) return;
    setState(() => _windBusy = true);
    try {
      final next = await SupabaseService.instance.oddSurvivalSecondWind(state.runId);
      if (!mounted) return;
      SoundService.instance.play(Sfx.coin);
      setState(() => _windBusy = false);
      _applyState(next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _windBusy = false);
      _toast(_friendly(e));
    }
  }

  Future<void> _finish() async {
    final state = _state;
    if (state == null) return;
    _timer?.cancel();
    _autoNext?.cancel();
    setState(() => _stage = _Stage.loading);
    try {
      final result = await SupabaseService.instance.finishOddSurvivalRun(state.runId);
      if (!mounted) return;
      AppEvents.notifyProgressChanged();
      setState(() {
        _result = result;
        _stage = _Stage.results;
      });
      SoundService.instance.play(result.newBest ? Sfx.levelUp : Sfx.coin);
      final rewards = <RewardFeedbackItem>[
        if (result.xpEarned > 0) RewardFeedbackItem.xp(result.xpEarned),
        if (result.coinsEarned > 0) RewardFeedbackItem.coins(result.coinsEarned),
      ];
      if (rewards.isNotEmpty || result.leveledUp) {
        await RewardCelebration.show(
          context,
          rewards: rewards,
          title: result.newBest ? 'NEW PERSONAL BEST!' : 'RUN COMPLETE',
          subtitle: '${result.correct} correct • ${result.score} points',
          newLevel: result.newLevel,
          leveledUp: result.leveledUp,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = _friendly(e);
      });
    }
  }

  Future<bool> _confirmExit() async {
    if (_stage == _Stage.results || _stage == _Stage.loading || _stage == _Stage.error) return true;
    final leave = await showJuaConfirm(
      context,
      title: 'End this run?',
      message: 'Your run ends now and you keep what you have earned so far.',
      cancelLabel: 'Keep going',
      confirmLabel: 'End run',
      tone: JuaDialogTone.blue,
      art: JuaDialogArt.leaveMascot,
      artHeight: 118,
      artAlignment: Alignment.topLeft,
    );
    if (leave && _state != null) {
      try {
        await SupabaseService.instance.finishOddSurvivalRun(_state!.runId);
        AppEvents.notifyProgressChanged();
      } catch (_) {/* a stale run is closed automatically next time */}
    }
    return leave;
  }

  // ---------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final hot = (_state?.isHot ?? false) && _stage == _Stage.playing;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: hot ? const Color(0xFF8A3B12) : AppColors.juaSkyBlue,
        appBar: AppBar(
          title: const Text('SURVIVAL RUN'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: hot
              ? const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE8590C), Color(0xFF8A3B12)],
                  ),
                )
              : null,
          child: switch (_stage) {
            _Stage.loading => const Center(child: CircularProgressIndicator(color: Colors.white)),
            _Stage.playing => _buildGame(),
            _Stage.offer => _buildOffer(),
            _Stage.results => _buildResults(_result!),
            _Stage.error => _buildError(),
          },
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            JuaGlossyButton(label: 'Try Again', icon: Icons.refresh_rounded, onPressed: _begin),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ]),
        ),
      );

  Widget _hearts(SurvivalState s) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < s.maxStrikes; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(i < s.strikesLeft ? '❤️' : '🖤', style: const TextStyle(fontSize: 22)),
            ),
        ],
      );

  Widget _streakPill(SurvivalState s) {
    final streak = s.streak;
    final show = streak >= 2;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: !show
          ? const SizedBox(key: ValueKey('none'), height: 32)
          : Container(
              key: ValueKey(streak),
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: s.isHot ? const Color(0xFFFFD43B) : Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: Text(
                '${s.isHot ? '🔥 HOT STREAK ' : '⚡ '}x$streak  •  ${s.multiplier.toStringAsFixed(s.multiplier % 1 == 0 ? 0 : 1)}x points',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.inkBrown),
              ),
            ),
    );
  }

  Widget _buildGame() {
    final s = _state!;
    final p = _puzzle!;
    final ratio = (_remainingMs / _limitMs).clamp(0.0, 1.0).toDouble();
    final urgent = _remainingMs <= 3000 && !_revealing;
    final answer = _answer;

    AnswerVisualState tileState(String letter) {
      if (answer == null) return _chosen == letter && _answering ? AnswerVisualState.selected : AnswerVisualState.idle;
      if (letter == answer.oddOption) return AnswerVisualState.correct;
      if (letter == _chosen) return AnswerVisualState.wrong;
      return AnswerVisualState.dimmed;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              _hearts(s),
              const Spacer(),
              Text('${s.score}',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0x88000000), blurRadius: 4)])),
              const SizedBox(width: 4),
              const Text('pts', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Center(child: _streakPill(s)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Colors.white30,
                color: urgent ? AppColors.earthRed : AppColors.sunGold,
              ),
            ),
            const SizedBox(height: 4),
            Row(children: [
              Text('Puzzle ${p.seq}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              _difficultyChip(p.difficulty),
              const Spacer(),
              Text('${(_remainingMs / 1000).toStringAsFixed(1)}s',
                  style: TextStyle(color: urgent ? const Color(0xFFFFD43B) : Colors.white, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 14),
            const Text(
              'Which one does not belong?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0x88000000), blurRadius: 4)]),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [
                  for (final letter in const ['a', 'b', 'c', 'd'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AnimatedGameAnswerTile(
                        letter: letter,
                        text: p.items[letter]!,
                        state: tileState(letter),
                        rewardBurst: 8,
                        onTap: (_revealing || _answering) ? null : () => _submit(letter),
                      ),
                    ),
                  if (answer != null) _buildReveal(answer),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _difficultyChip(String d) {
    final (label, color) = switch (d) {
      'easy' => ('EASY', const Color(0xFF2E9E5B)),
      'hard' => ('HARD', const Color(0xFFD64545)),
      _ => ('MEDIUM', const Color(0xFFE08A00)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildReveal(SurvivalAnswer a) {
    final s = a.state;
    final String headline;
    final Color color;
    if (a.isCorrect) {
      headline = '+${a.points} points${a.hotStreak ? '  🔥 HOT STREAK' : ''}';
      color = const Color(0xFF2E9E5B);
    } else if (a.timedOut) {
      headline = "⏱ Time's up!${a.streakBroken ? '  Streak x${a.lostStreak} lost' : ''}";
      color = const Color(0xFFD64545);
    } else {
      headline = 'Not that one${a.streakBroken ? '  •  Streak x${a.lostStreak} lost' : ''}';
      color = const Color(0xFFD64545);
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(headline, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
        if (a.explanation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('💡 ${a.explanation}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkBrown, height: 1.3)),
        ],
        const SizedBox(height: 10),
        JuaGlossyButton(
          label: s.status == 'playing' ? 'NEXT' : (s.status == 'offer' ? 'CONTINUE' : 'SEE RESULTS'),
          icon: Icons.arrow_forward_rounded,
          variant: JuaButtonVariant.action,
          onPressed: _continue,
        ),
      ]),
    );
  }

  Widget _buildOffer() {
    final s = _state!;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 18, offset: Offset(0, 8))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('💔', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 6),
              const Text('Out of strikes!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
              const SizedBox(height: 6),
              Text('${s.score} points • ${s.correct} correct',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFF3CC), borderRadius: BorderRadius.circular(16)),
                child: Text(
                  'Second Wind: one strike back and your x${s.savedStreak} streak restored, so Hot Streak points are back on. Your score stays.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkBrown, height: 1.3),
                ),
              ),
              const SizedBox(height: 16),
              JuaGlossyButton(
                label: _windBusy ? 'ONE MOMENT…' : 'SECOND WIND • ${s.windCost} 🪙',
                icon: Icons.favorite_rounded,
                onPressed: _windBusy ? null : _secondWind,
              ),
              TextButton(
                onPressed: _windBusy ? null : _finish,
                child: const Text('End run and collect rewards'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(SurvivalResult r) {
    final String banner;
    if (r.newBest) {
      banner = '🏆 NEW PERSONAL BEST!';
    } else if (r.missedBestBy > 0 && r.missedBestBy <= 150) {
      banner = 'So close! You missed your best by ${r.missedBestBy}.';
    } else if (r.bestBefore > 0) {
      banner = 'Your best is ${r.bestBefore}. One more run?';
    } else {
      banner = 'Your first run! Beat it next time.';
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Center(child: Text('🔎', style: TextStyle(fontSize: 54))),
          Center(
            child: Text('${r.score}',
                style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0x88000000), blurRadius: 6)])),
          ),
          Center(
            child: Text(banner,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: r.newBest ? const Color(0xFFFFD43B) : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    shadows: const [Shadow(color: Color(0x88000000), blurRadius: 4)])),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _stat('✅', '${r.correct}', 'correct'),
              _stat('🔥', 'x${r.bestStreak}', 'best streak'),
              _stat('⚡', '+${r.xpEarned}', 'XP'),
              _stat('🪙', '+${r.coinsEarned}', 'coins'),
            ]),
          ),
          if (r.rewardsCapped)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text("You've used today's rewarded runs. Runs still count for your best score. Rewards reset at midnight.",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 20),
          JuaGlossyButton(label: 'RUN AGAIN', icon: Icons.replay_rounded, onPressed: _begin),
          WhatsAppShareButton(
            text: 'I scored ${r.score} (${r.correct} correct, x${r.bestStreak} streak) in Odd One Out Survival on Jua Quiz! Can you beat me? 🔎🇰🇪',
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Odd One Out'),
          ),
        ],
      ),
    );
  }

  Widget _stat(String icon, String value, String label) => Column(children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.inkBrown)),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
      ]);
}
