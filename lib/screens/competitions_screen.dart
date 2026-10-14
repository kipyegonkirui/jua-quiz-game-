import '../widgets/jua_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/competition.dart';
import '../services/app_events.dart';
import '../services/quiz_assist.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'competition_play_screen.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Sat 3 Oct, 18:00" in the phone's local time.
String formatWhen(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}, $hh:$mm';
}

/// "2d 3h", "1h 20m", "12m" until [target].
String formatUntil(DateTime target) {
  final d = target.difference(DateTime.now());
  if (d.isNegative) return 'now';
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes.clamp(1, 59)}m';
}

String formatDuration(int ms) {
  final totalSeconds = (ms / 1000).round();
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return m > 0 ? '${m}m ${s}s' : '${s}s';
}

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> {
  List<Competition>? _items;
  int _coins = 0;
  bool _loading = true;
  String? _error;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _load();
    // Re-draw every so often so "starts in 5m" counts down and open/closed flip.
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    AppEvents.tabRequest.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    _clock?.cancel();
    AppEvents.tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  // Opening this tab always shows fresh data (and settles finished events).
  void _onTabRequest() {
    if (AppEvents.tabRequest.value == AppTabs.compete) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await SupabaseService.instance.listCompetitions();
      var coins = _coins;
      try {
        coins = (await SupabaseService.instance.getMyProfile()).coins;
      } catch (_) {
        // The coin chip is a nicety; the list is what matters.
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _coins = coins;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_items == null) _error = 'Couldn\'t load competitions. Check your connection.';
      });
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _play(Competition c) async {
    try {
      await SupabaseService.instance.startCompetitionEntry(c.id);
    } catch (e) {
      _snack(QuizAssist.competitionMessage(e));
      _load(silent: true);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CompetitionPlayScreen(competition: c)),
    );
    if (mounted) _load(silent: true);
  }

  void _openResults(Competition c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ResultsScreen(competition: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Compete', style: juaSceneTitleStyle),
                ),
                _CoinChip(coins: _coins),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _items;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (_error != null)
            JuaStateCard.error(message: _error!, onPressed: _load)
          else if (items == null || items.isEmpty)
            const JuaStateCard(
              title: 'No competitions right now',
              message: 'Pull down to refresh, or check back soon!',
              art: JuaDialogArt.chestOpen,
              tone: JuaDialogTone.orange,
            )
          else
            ...items.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CompetitionCard(
                    competition: c,
                    onPlay: () => _play(c),
                    onResults: () => _openResults(c),
                  ),
                )),
        ],
      ),
    );
  }
}

class _CoinChip extends StatelessWidget {
  final int coins;
  const _CoinChip({required this.coins});

  @override
  Widget build(BuildContext context) => JuaCoinPill(coins: coins);
}

class _CompetitionCard extends StatelessWidget {
  final Competition competition;
  final VoidCallback onPlay;
  final VoidCallback onResults;

  const _CompetitionCard({
    required this.competition,
    required this.onPlay,
    required this.onResults,
  });

  @override
  Widget build(BuildContext context) {
    final c = competition;
    final phase = c.phaseAt(DateTime.now());
    final mine = c.myEntry;

    final (label, color) = switch (phase) {
      'open' => ('OPEN NOW', AppColors.savannaGreen),
      'upcoming' => ('UPCOMING', AppColors.sunGold),
      'closed' => ('CLOSED', Colors.grey),
      _ => ('RESULTS', AppColors.inkBrown),
    };

    Widget action;
    String? note;
    if (phase == 'open') {
      if (mine == null) {
        action = ElevatedButton(onPressed: onPlay, child: const Text('Play now'));
        note = 'Closes in ${formatUntil(c.endsAt)}';
      } else if (!mine.isFinished) {
        action = ElevatedButton(onPressed: onPlay, child: const Text('Continue'));
        note = 'You\'re mid-run. The clock is running!';
      } else {
        action = const OutlinedButton(onPressed: null, child: Text('You\'ve played'));
        note = '${mine.correct}/${mine.totalQuestions} correct. Results when it closes.';
      }
    } else if (phase == 'upcoming') {
      action = OutlinedButton(onPressed: null, child: Text('Starts in ${formatUntil(c.startsAt)}'));
      note = formatWhen(c.startsAt);
    } else if (phase == 'closed') {
      action = const OutlinedButton(onPressed: null, child: Text('Results coming...'));
      note = 'Pull down in a moment to refresh.';
    } else {
      action = OutlinedButton(onPressed: onResults, child: const Text('View results'));
      if (mine != null && mine.rank != null) {
        note = 'You finished ${ordinal(mine.rank!)}'
            '${mine.coinsAwarded > 0 ? ' · +${mine.coinsAwarded} coins' : ''}';
      } else if (mine == null) {
        note = 'You didn\'t play this one.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _fact(Icons.help_outline_rounded, '${c.questionCount} questions'),
              _fact(Icons.favorite_rounded, '${c.lives} lives'),
              _fact(Icons.timer_outlined, '${c.secondsPerQuestion}s each'),
              _fact(Icons.groups_rounded, '${c.entrants} playing'),
            ],
          ),
          if (c.prizeSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Coins: ${c.prizeSummary}',
                style: const TextStyle(fontSize: 13, color: AppColors.inkBrown)),
          ],
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: action),
          if (note != null) ...[
            const SizedBox(height: 6),
            Center(child: Text(note, style: const TextStyle(fontSize: 12, color: Colors.black54))),
          ],
        ],
      ),
    );
  }

  Widget _fact(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.black45),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      );
}

/// Final standings for a settled competition.
class _ResultsScreen extends StatefulWidget {
  final Competition competition;
  const _ResultsScreen({required this.competition});

  @override
  State<_ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<_ResultsScreen> {
  late Future<CompetitionResults> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.instance.getCompetitionResults(widget.competition.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.competition.title)),
      body: FutureBuilder<CompetitionResults>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(QuizAssist.competitionMessage(snap.error!), textAlign: TextAlign.center),
              ),
            );
          }
          final r = snap.data!;
          if (r.top.isEmpty) {
            return const Center(child: Text('Nobody played this one.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('${r.players} players', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              ...r.top.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: s.isMe ? AppColors.savannaGreen.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: s.isMe ? AppColors.savannaGreen : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text('#${s.rank}',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.isMe ? '${s.username} (you)' : s.username,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                '${s.correct} correct · ${s.livesLeft} lives left · '
                                '${formatDuration(s.totalTimeMs)}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        if (s.coinsAwarded > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.monetization_on_rounded,
                                  size: 16, color: AppColors.sunGold),
                              const SizedBox(width: 3),
                              Text('+${s.coinsAwarded}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                      ],
                    ),
                  )),
              if (r.me != null && r.me!.rank != null && !r.top.any((s) => s.isMe))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'You finished ${ordinal(r.me!.rank!)}'
                    '${r.me!.coinsAwarded > 0 ? ' and earned ${r.me!.coinsAwarded} coins' : ''}.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
