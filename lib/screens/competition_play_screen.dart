import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/competition.dart';
import '../services/ads_service.dart';
import '../services/quiz_assist.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/jua_dialog.dart';
import '../widgets/quiz_widgets.dart';
import 'competitions_screen.dart' show formatDuration, formatWhen;

/// One player's run through a competition. The SERVER keeps the clock, the
/// lives and the score; this screen only shows them and sends taps. Closing
/// the app mid-question never resets the timer: coming back asks the server
/// for the same question with the time that is really left.
class CompetitionPlayScreen extends StatefulWidget {
  final Competition competition;
  const CompetitionPlayScreen({super.key, required this.competition});

  @override
  State<CompetitionPlayScreen> createState() => _CompetitionPlayScreenState();
}

class _CompetitionPlayScreenState extends State<CompetitionPlayScreen>
    with WidgetsBindingObserver {
  CompetitionQuestionState? _q;
  CompetitionEntry? _summary; // set once the run is over
  CompetitionAnswerResult? _feedback;
  String? _picked;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  Timer? _ticker;
  DateTime? _deadline;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNext();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  // Coming back from the background: re-sync with the server's clock.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _summary == null &&
        !_submitting &&
        _q != null) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    _ticker?.cancel();
    try {
      final s = await SupabaseService.instance.competitionNextQuestion(widget.competition.id);
      if (!mounted) return;
      if (s.finished) {
        _finish(s.summary!);
        return;
      }
      setState(() {
        _q = s;
        _picked = null;
        _feedback = null;
        _submitting = false;
        _loading = false;
        _error = null;
        _deadline = DateTime.now().add(Duration(seconds: s.secondsLeft));
        _secondsLeft = s.secondsLeft;
      });
      _startTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _submitting = false;
        _error = QuizAssist.competitionMessage(e);
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final deadline = _deadline;
      if (deadline == null || !mounted) return;
      final left = deadline.difference(DateTime.now());
      final secs = math.max(0, (left.inMilliseconds / 1000).ceil());
      if (secs != _secondsLeft) setState(() => _secondsLeft = secs);
      // Out of time: send a skip. The server has its own clock and decides.
      if (left <= Duration.zero && !_submitting) _answer(null);
    });
  }

  Future<void> _answer(String? choice) async {
    final q = _q;
    if (q == null || _submitting) return;
    _ticker?.cancel();
    setState(() {
      _submitting = true;
      _picked = choice;
    });
    try {
      final r = await SupabaseService.instance.competitionAnswer(
        competitionId: widget.competition.id,
        questionId: q.questionId,
        choice: choice,
      );
      if (!mounted) return;
      setState(() => _feedback = r);
      // Let the green/red sink in, then move on.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      await _loadNext(); // returns the finished summary when the run is over
    } catch (_) {
      // A double tap, a flaky network, a timeout the server already counted:
      // whatever it was, ask the server where things stand.
      if (!mounted) return;
      await _loadNext();
    }
  }

  bool _adQueued = false;

  void _finish(CompetitionEntry summary) {
    _ticker?.cancel();
    setState(() {
      _summary = summary;
      _loading = false;
      _submitting = false;
    });
    if (!_adQueued && summary.answered > 0) {
      _adQueued = true;
      AdCoordinator.roundFinished(); // shown when they leave, never mid-play
    }
  }

  Future<void> _leave() async {
    await AdCoordinator.showPendingIfAny();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmLeave() async {
    final leave = await showJuaConfirm(
      context,
      title: 'Leave the competition?',
      message: "The clock keeps running while you're away. You can come back and "
          'continue, but time that passes counts against you.',
      cancelLabel: 'Keep playing',
      confirmLabel: 'Leave',
      tone: JuaDialogTone.orange,
      art: JuaDialogArt.chestOpen,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _summary != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.competition.title)),
        body: SafeArea(child: _content()),
      ),
    );
  }

  Widget _content() {
    final summary = _summary;
    if (summary != null) return _finishedView(summary);
    if (_error != null && _q == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadNext();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final q = _q;
    if (_loading || q == null) return const Center(child: CircularProgressIndicator());
    return _questionView(q);
  }

  OptionState _stateFor(String letter) {
    final f = _feedback;
    if (f != null) {
      if (letter == _picked) return f.isCorrect ? OptionState.correct : OptionState.wrong;
      return OptionState.dimmed;
    }
    return _picked == letter ? OptionState.selected : OptionState.idle;
  }

  Widget _questionView(CompetitionQuestionState q) {
    final f = _feedback;
    final fraction = q.secondsPerQuestion == 0 ? 0.0 : _secondsLeft / q.secondsPerQuestion;
    final urgent = _secondsLeft <= 5;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Lives
              ...List.generate(
                widget.competition.lives,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    i < (f?.livesLeft ?? q.livesLeft)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: AppColors.earthRed,
                    size: 22,
                  ),
                ),
              ),
              const Spacer(),
              Text('Question ${q.position} of ${q.total}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 10,
                    color: urgent ? AppColors.earthRed : AppColors.savannaGreen,
                    backgroundColor: Colors.black12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 34,
                child: Text('${_secondsLeft}s',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: urgent ? AppColors.earthRed : AppColors.inkBrown)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(q.text, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          ...['a', 'b', 'c', 'd'].map((letter) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OptionTile(
                  letter: letter,
                  text: q.options[letter] ?? '',
                  state: _stateFor(letter),
                  // One tap answers. Speed matters here, so there's no "check" step.
                  onTap: _submitting ? null : () => _answer(letter),
                ),
              )),
          if (f != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                f.isCorrect
                    ? 'Correct! 🎉'
                    : (_picked == null
                        ? 'Time\'s up! You lost a life.'
                        : 'Not quite. You lost a life.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: f.isCorrect ? AppColors.savannaGreen : AppColors.earthRed,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.earthRed)),
            ),
          const SizedBox(height: 8),
          const Text(
            'Answers stay hidden until the competition closes, so nobody can pass them on.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _finishedView(CompetitionEntry s) {
    final (title, icon) = switch (s.finishReason) {
      'completed' => ('You finished!', Icons.emoji_events_rounded),
      'out_of_lives' => ('Out of lives', Icons.heart_broken_rounded),
      _ => ('Time ran out', Icons.hourglass_bottom_rounded),
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: AppColors.sunGold),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text('${s.correct} of ${s.totalQuestions} correct',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${s.livesLeft} lives left · ${formatDuration(s.totalTimeMs)} total',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Text(
            'Rankings and coin rewards arrive after the competition closes '
            '(${formatWhen(widget.competition.endsAt)}). Open the Compete tab then.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _leave, child: const Text('Back to competitions')),
        ],
      ),
    );
  }
}
