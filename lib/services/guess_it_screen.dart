import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/guess_it.dart';
import '../models/mode_journey.dart';
import '../services/app_events.dart';
import '../services/guess_it_service.dart';
import '../services/sound_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/jua_buttons.dart';
import '../widgets/jua_dialog.dart';
import '../widgets/mode_level_summary.dart';
import '../widgets/reward_feedback.dart';

class GuessItScreen extends StatefulWidget {
  /// When set, this is a journey level (stars, lives); otherwise a free round.
  final int? levelNumber;

  const GuessItScreen({super.key, this.levelNumber});

  @override
  State<GuessItScreen> createState() => _GuessItScreenState();
}

class _GuessItScreenState extends State<GuessItScreen> {
  String? _roundId;
  List<GuessItQuestion> _questions = const [];
  int _index = 0;
  int _hintLevel = 0;
  Set<String> _eliminated = <String>{};
  GuessItAnswerResult? _answer;
  bool _loading = true;
  bool _answering = false;
  bool _submitting = false;
  String? _error;
  Timer? _timer;
  int _remainingMs = 15000;
  DateTime? _questionStartedAt;
  GuessItGameResult? _result;

  // Game feel: combo streak, hearts (free rounds only) and the free 50/50.
  int _combo = 0;
  int _bestCombo = 0;
  int _hearts = 3;
  bool _freeHintUsed = false;
  int _lastTickSecond = -1;
  static const int _maxHints = 2;
  bool get _heartsMode => widget.levelNumber == null;
  bool get _roundEndsNow => _index + 1 >= _questions.length || (_heartsMode && _hearts <= 0);

  GuessItQuestion? get _question => _questions.isEmpty ? null : _questions[_index];
  bool get _answered => _answer != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roundId = widget.levelNumber == null
          ? await GuessItService.startRound()
          : await SupabaseService.instance.startModeLevel(JourneyMode.guessIt, widget.levelNumber!);
      final questions = await GuessItService.getQuestions(roundId);
      if (!mounted) return;
      if (questions.isEmpty) throw StateError('No Guess It questions are available yet.');
      // Resuming an unfinished round: continue at the first question that has
      // not been answered. Answering an answered one raises already_answered.
      final firstOpen = questions.indexWhere((q) => !q.answered);
      if (firstOpen == -1) {
        // Everything was answered but the round was never submitted.
        setState(() {
          _roundId = roundId;
          _questions = questions;
          _index = questions.length - 1;
          _loading = false;
        });
        await _finish();
        return;
      }
      final open = questions[firstOpen];
      setState(() {
        _roundId = roundId;
        _questions = questions;
        _index = firstOpen;
        _hintLevel = open.hintLevel;
        _eliminated = open.eliminated;
        _freeHintUsed = firstOpen > 0 || open.hintLevel > 0;
        _answer = null;
        _loading = false;
      });
      _startQuestionTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.levelNumber == null
            ? e.toString().replaceFirst('Exception: ', '')
            : modeLevelErrorText(e);
      });
    }
  }

  /// With [resume] the original start time is kept, so a failed network call
  /// can never buy the player extra time.
  void _startQuestionTimer({bool resume = false}) {
    _timer?.cancel();
    final limit = (_question?.timeLimitSeconds ?? 15) * 1000;
    if (!resume || _questionStartedAt == null) {
      _remainingMs = limit;
      _questionStartedAt = DateTime.now();
      _lastTickSecond = -1;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _answered || _answering) return;
      final started = _questionStartedAt;
      if (started == null) return;
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      final left = limit - elapsed;
      if (left <= 0) {
        _remainingMs = 0;
        _timer?.cancel();
        _answerChoice('timeout');
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

  Future<void> _answerChoice(String choice) async {
    final roundId = _roundId;
    final question = _question;
    if (roundId == null || question == null || _answering || _answered) return;
    _timer?.cancel();
    setState(() => _answering = true);
    final limitMs = question.timeLimitSeconds * 1000;
    final elapsed = _questionStartedAt == null
        ? limitMs
        : DateTime.now().difference(_questionStartedAt!).inMilliseconds.clamp(0, limitMs).toInt();
    try {
      final result = await GuessItService.answer(
        roundId: roundId,
        questionId: question.id,
        choice: choice,
        timeMs: elapsed,
      );
      if (!mounted) return;
      setState(() {
        _answer = result;
        _answering = false;
        if (result.isCorrect) {
          _combo++;
          _bestCombo = math.max(_bestCombo, _combo);
        } else {
          _combo = 0;
          if (_heartsMode) _hearts = math.max(0, _hearts - 1);
        }
      });
      if (result.isCorrect) {
        HapticFeedback.mediumImpact();
        SoundService.instance.play(Sfx.correct);
        if (_combo >= 3) {
          Future<void>.delayed(const Duration(milliseconds: 220), () => SoundService.instance.play(Sfx.starPop));
          HapticFeedback.lightImpact();
        }
      } else {
        HapticFeedback.heavyImpact();
        SoundService.instance.play(Sfx.wrong);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _answering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      if (choice == 'timeout') {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted && !_answered && !_answering) _answerChoice('timeout');
        });
      } else {
        _startQuestionTimer(resume: true);
      }
    }
  }

  Future<void> _useHint() async {
    final roundId = _roundId;
    final question = _question;
    if (roundId == null || question == null || _answered || _answering || _hintLevel >= _maxHints) return;
    try {
      final result = await GuessItService.useHint(roundId: roundId, questionId: question.id);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      SoundService.instance.play(Sfx.tap);
      setState(() {
        _hintLevel = result.hintLevel;
        if (result.eliminatedOptions.isNotEmpty) _eliminated = result.eliminatedOptions;
        if (result.hintLevel == 1) _freeHintUsed = true;
      });
      final name = result.hintLevel == 1 ? '50/50' : 'Sharper picture';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.free ? '$name used • free!' : '$name used • ${result.coinsSpent} coins')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _next() async {
    if (!_answered) return;
    if (!_roundEndsNow) {
      setState(() {
        _index++;
        _hintLevel = 0;
        _eliminated = <String>{};
        _answer = null;
      });
      _startQuestionTimer();
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
      final result = await GuessItService.submit(roundId);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _result = result;
        _submitting = false;
      });
      AppEvents.notifyProgressChanged(); // refresh missions / achievements
      final rewards = <RewardFeedbackItem>[
        if (result.xpEarned > 0) RewardFeedbackItem.xp(result.xpEarned),
        if (result.coinsEarned > 0) RewardFeedbackItem.coins(result.coinsEarned),
      ];
      await RewardCelebration.show(
        context,
        rewards: rewards,
        title: 'GUESS IT COMPLETE!',
        subtitle: '${result.correct}/${result.total} correct • ${result.score} points',
        newLevel: result.newLevel,
        leveledUp: result.leveledUp,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<bool> _confirmExit() async {
    if (_result != null || _loading) return true;
    final level = widget.levelNumber;
    final leave = await showJuaConfirm(
      context,
      title: level == null ? 'Leave Guess It?' : 'Exit level?',
      message: level == null
          ? 'Your current round will not be scored until it is completed.'
          : 'Leaving this level ends the attempt. It will burst one life and start its 5-minute recharge.',
      cancelLabel: 'Keep playing',
      confirmLabel: 'Leave',
      tone: JuaDialogTone.blue,
      art: JuaDialogArt.leaveMascot,
      artHeight: 118,
      artAlignment: Alignment.topLeft,
    );
    final roundId = _roundId;
    if (leave && level != null && roundId != null) {
      try {
        await SupabaseService.instance.abandonModeLevel(roundId);
      } catch (e) {
        debugPrint('Could not close abandoned Guess It level: $e');
      }
    }
    return leave;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) async {
        if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('GUESS IT'),
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
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmExit() && context.mounted) Navigator.of(context).pop();
            },
          ),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_search_rounded, size: 54, color: Colors.white),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              JuaGlossyButton(label: 'Try Again', icon: Icons.refresh_rounded, onPressed: _load),
            ],
          ),
        ),
      );
    }
    if (_result != null) return _buildResults(_result!);
    return _buildGame();
  }

  Widget _buildGame() {
    final q = _question!;
    final seconds = (_remainingMs / 1000).ceil();
    final timerFraction = (_remainingMs / (q.timeLimitSeconds * 1000)).clamp(0.0, 1.0);
    final last = _roundEndsNow;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('${_index + 1}/${_questions.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, shadows: juaSceneShadows)),
                    const SizedBox(width: 12),
                    if (_heartsMode) _HeartsRow(hearts: _hearts),
                    const Spacer(),
                    _ComboChip(count: _combo),
                    const SizedBox(width: 10),
                    const Icon(Icons.monetization_on_rounded, color: AppColors.sunGold, size: 18),
                    const SizedBox(width: 4),
                    ValueListenableBuilder(
                      valueListenable: AppEvents.profile,
                      builder: (_, profile, _) => Text('${profile?.coins ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, shadows: juaSceneShadows)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: timerFraction,
                          minHeight: 9,
                          backgroundColor: Colors.white30,
                          valueColor: AlwaysStoppedAnimation(timerFraction < 0.25 ? AppColors.earthRed : AppColors.sunGold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$seconds s', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, shadows: juaSceneShadows)),
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
                  _buildImageCard(q),
                  const SizedBox(height: 12),
                  Text(q.prompt, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, shadows: juaSceneShadows)),
                  const SizedBox(height: 10),
                  _buildHintBar(),
                  const SizedBox(height: 10),
                  ...q.options.entries.map((entry) => _buildOption(entry.key, entry.value)),
                  if (_answered) ...[
                    const SizedBox(height: 6),
                    _buildFeedback(),
                    const SizedBox(height: 14),
                    JuaDialogButton(
                      label: last ? 'See Results' : 'Next',
                      icon: last ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
                      style: last ? JuaDialogButtonStyle.green : JuaDialogButtonStyle.blue,
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

  /// Points you would earn if you answered right now (same formula as the server).
  int _potentialPoints(GuessItQuestion q) {
    final int limit = q.timeLimitSeconds * 1000;
    final int elapsed = (limit - _remainingMs).clamp(0, limit).toInt();
    final int pct = ((elapsed / limit) * 100).floor();
    final int timeBonus = math.max(0, 100 - pct);
    return math.max(25, 100 + timeBonus - _hintLevel * 10).toInt();
  }

  /// The picture sharpens by itself while the clock runs. Answering early is
  /// worth more points but means a blurrier picture.
  Widget _buildImageCard(GuessItQuestion q) {
    const broken = ColoredBox(
      color: Color(0xFFE7F0FA),
      child: Center(child: Icon(Icons.image_not_supported_rounded, size: 48, color: Color(0xFF7C8FB0))),
    );
    final source = q.displayImage;
    final image = source.startsWith('asset:')
        ? Image.asset(
            source.substring(6),
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.25), // keep heads in frame when cropping
            width: double.infinity,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => broken,
          )
        : Image.network(
            source,
            fit: BoxFit.cover,
            width: double.infinity,
            cacheWidth: 1080,
            filterQuality: FilterQuality.high,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const ColoredBox(
                    color: Color(0xFFE7F0FA),
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => broken,
          );

    final limitMs = q.timeLimitSeconds * 1000;
    final progress = (1 - _remainingMs / limitMs).clamp(0.0, 1.0);
    final boost = _hintLevel >= 2 ? 0.35 : 0.0;
    final points = _answered ? (_answer?.score ?? 0) : _potentialPoints(q);
    final pointsColor = _answered
        ? ((_answer?.isCorrect ?? false) ? const Color(0xFF1FA02E) : const Color(0xFFD81E2B))
        : (points >= 150 ? const Color(0xFFF59E0B) : (points >= 100 ? const Color(0xFFEF6C00) : const Color(0xFFD81E2B)));

    return Container(
      height: 258,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Keyed per question so a new picture starts blurred (no spoiler flash).
          TweenAnimationBuilder<double>(
            key: ValueKey('reveal-$_index'),
            tween: Tween<double>(end: _answered ? 0.0 : 1.0),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
            builder: (context, factor, _) {
              return TweenAnimationBuilder<double>(
                key: ValueKey('boost-$_index'),
                tween: Tween<double>(end: boost),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                child: image,
                builder: (context, b, child) {
                  final clarity = (progress + b).clamp(0.0, 1.0);
                  final sigma = 16.0 * math.pow(1 - clarity, 1.5).toDouble() * factor;
                  // clamp keeps the picture edges from fading out while blurred.
                  return ImageFiltered(
                    enabled: sigma > 0.05,
                    imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
                    child: child,
                  );
                },
              );
            },
          ),
          Positioned(
            top: 10,
            left: 10,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: pointsColor,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _answered ? ((_answer?.isCorrect ?? false) ? '+$points' : '0') : '$points',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const SizedBox(width: 4),
                  const Text('PTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: .8)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(99)),
              child: Text(
                _answered ? 'REVEALED' : 'GUESS FAST',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The two power-ups, in order: 50/50 (first one in a round is free), then
  /// a sharper picture.
  Widget _buildHintBar() {
    if (_answered || _hintLevel >= _maxHints) return const SizedBox.shrink();
    final isFifty = _hintLevel == 0;
    final free = isFifty && !_freeHintUsed;
    final cost = isFifty ? 25 : 40;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
      decoration: BoxDecoration(
        color: const Color(0xCC14235E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .7), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(isFifty ? Icons.call_split_rounded : Icons.visibility_rounded, color: AppColors.sunGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFifty ? '50/50: remove two wrong answers' : 'Sharper picture: clear the blur faster',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
            ),
          ),
          _HintPill(free: free, cost: cost, onTap: _useHint),
        ],
      ),
    );
  }

  /// After answering: the mascot reacts, then a one-line "Did you know?".
  Widget _buildFeedback() {
    final a = _answer!;
    final correct = a.isCorrect;
    final timedOut = a.chosen == 'timeout';
    final pose = correct ? (_combo >= 3 ? 'assets/mascot/pose6.png' : 'assets/mascot/pose4.png') : 'assets/mascot/pose3.png';
    final title = correct ? (_combo >= 3 ? 'ON FIRE!  ×$_combo' : 'Correct!') : (timedOut ? "Time's up!" : 'Not quite');
    final sub = correct
        ? '+${a.score} points'
        : (_heartsMode
            ? (_hearts <= 0 ? 'No hearts left' : '$_hearts heart${_hearts == 1 ? '' : 's'} left')
            : 'The right answer is highlighted');
    return JuaFramePanel(
      tone: correct ? JuaDialogTone.green : JuaDialogTone.red,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Image.asset(pose, height: 72, errorBuilder: (_, _, _) => const SizedBox(width: 72, height: 72)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Color(0xFF14235E), fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(color: Color(0xFF2B3A67), fontSize: 14.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          if (a.fact != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6D6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFC53D), width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Did you know? ', style: TextStyle(fontWeight: FontWeight.w900)),
                          TextSpan(text: a.fact!),
                        ],
                      ),
                      style: const TextStyle(color: Color(0xFF14235E), fontSize: 14, height: 1.35, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(String key, String label) {
    final answer = _answer;
    final disabledByHint = _eliminated.contains(key);
    final chosen = answer?.chosen == key;
    final correct = answer?.correctOption == key;
    Color? fill;
    if (answer != null && correct) fill = AppColors.savannaGreen.withValues(alpha: .92);
    if (answer != null && chosen && !answer.isCorrect) fill = AppColors.earthRed.withValues(alpha: .92);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: disabledByHint ? .30 : 1,
        child: IgnorePointer(
          ignoring: disabledByHint || _answered || _answering,
          child: GestureDetector(
            onTap: () => _answerChoice(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(color: fill ?? Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))]),
              child: Row(
                children: [
                  Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.juaSkyBlue.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)), child: Text(key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.inkBrown))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fill != null ? Colors.white : AppColors.inkBrown))),
                  if (answer != null && correct) const Icon(Icons.check_circle_rounded, color: Colors.white),
                  if (answer != null && chosen && !answer.isCorrect) const Icon(Icons.cancel_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(GuessItGameResult result) {
    final accuracy = result.total == 0 ? 0 : (result.correct / result.total * 100).round();
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Image.asset(
                accuracy >= 80 ? 'assets/mascot/pose6.png' : (accuracy >= 40 ? 'assets/mascot/pose2.png' : 'assets/mascot/pose3.png'),
                height: 110,
                errorBuilder: (_, _, _) => const Text('🖼️', style: TextStyle(fontSize: 58)),
              ),
              Text(
                _heartsMode && _hearts <= 0 ? 'OUT OF HEARTS!' : 'GUESS IT COMPLETE!',
                style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, shadows: juaSceneShadows),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
                child: Column(
                  children: [
                    Text('${result.score}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.inkBrown)),
                    const Text('FINAL SCORE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _stat('${result.correct}/${result.total}', 'CORRECT'),
                      _stat('$accuracy%', 'ACCURACY'),
                      _stat('${result.bestScore}', 'BEST'),
                      _stat('×$_bestCombo', 'COMBO'),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (widget.levelNumber != null && _roundId != null)
                ModeLevelSummary(
                  mode: JourneyMode.guessIt,
                  roundId: _roundId!,
                  level: widget.levelNumber!,
                  onDark: true,
                  onRetry: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => GuessItScreen(levelNumber: widget.levelNumber)),
                  ),
                  onOpenLevel: (next) => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => GuessItScreen(levelNumber: next)),
                  ),
                )
              else ...[
                JuaGlossyButton(label: 'Play Again', icon: Icons.replay_rounded, onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GuessItScreen()))),
                const SizedBox(height: 10),
                JuaGlossyButton(label: 'Back to Games', icon: Icons.grid_view_rounded, variant: JuaButtonVariant.action, onPressed: () => Navigator.of(context).pop()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(children: [Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.inkBrown)), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54))]);
}


class _HeartsRow extends StatelessWidget {
  final int hearts;
  const _HeartsRow({required this.hearts});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                i < hearts ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey('$i-${i < hearts}'),
                color: i < hearts ? const Color(0xFFFF4D5E) : Colors.white70,
                size: 22,
                shadows: juaSceneShadows,
              ),
            ),
          ),
      ],
    );
  }
}

/// "×3" streak chip that pops each time the combo grows. Hidden below ×2.
class _ComboChip extends StatelessWidget {
  final int count;
  const _ComboChip({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final hot = count >= 5;
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween<double>(begin: 1.45, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: hot ? const [Color(0xFFFF6A3D), Color(0xFFD81E2B)] : const [Color(0xFFFFD04D), Color(0xFFF08A10)]),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded, color: Colors.white, size: hot ? 20 : 17),
            const SizedBox(width: 3),
            Text('×$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  final bool free;
  final int cost;
  final VoidCallback onTap;
  const _HintPill({required this.free, required this.cost, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: free ? const [Color(0xFF5CDC4C), Color(0xFF1FA02E)] : const [Color(0xFFFFD04D), Color(0xFFF08A10)],
          ),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white, width: 1.8),
        ),
        child: free
            ? const Text('FREE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: .6))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$cost', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(width: 4),
                  Image.asset(JuaDialogArt.coin, height: 18, errorBuilder: (_, _, _) => const Icon(Icons.monetization_on_rounded, size: 16, color: Colors.white)),
                ],
              ),
      ),
    );
  }
}
