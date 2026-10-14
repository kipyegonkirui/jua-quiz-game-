import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mode_journey.dart';
import '../models/practice_journey.dart';
import '../models/practice_lives.dart';
import '../services/ads_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/jua_dialog.dart';
import 'journey_map_data.dart';
import 'guess_it_screen.dart';
import 'odd_one_out_screen.dart';
import 'practice_screen.dart';
import 'speed_quiz_screen.dart';

/// The level map. With [mode] == null it is the Practice journey; otherwise it
/// is the journey of Speed Quiz / Guess It / Odd One Out (same rules, own
/// progress and lives, see supabase/021_mode_journeys.sql).
class PracticeJourneyScreen extends StatefulWidget {
  final JourneyMode? mode;

  const PracticeJourneyScreen({super.key, this.mode});

  @override
  State<PracticeJourneyScreen> createState() => _PracticeJourneyScreenState();
}

class _PracticeJourneyScreenState extends State<PracticeJourneyScreen> {
  JourneyMode? get _mode => widget.mode;

  Future<PracticeJourneyData> _fetchJourney() => _mode == null
      ? SupabaseService.instance.getPracticeJourney(throughLevel: 100)
      : SupabaseService.instance.getModeJourney(_mode!, throughLevel: 100);

  Future<PracticeLives> _fetchLives() => _mode == null
      ? SupabaseService.instance.getPracticeLives()
      : SupabaseService.instance.getModeLives(_mode!);

  PracticeJourneyData? _journey;
  bool _loading = true;
  bool _unlocking = false;
  String? _error;
  PracticeLives? _lives;
  Timer? _lifeTimer;
  DateTime _lifeClock = DateTime.now();

  @override
  void initState() {
    super.initState();
    AdCoordinator.preloadRewarded();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final journey = await _fetchJourney();
      final lives = await _fetchLives();
      if (!mounted) return;
      setState(() {
        _journey = journey;
        _lives = lives;
        _lifeClock = DateTime.now();
        _loading = false;
      });
      _startLifeTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startLifeTicker() {
    _lifeTimer?.cancel();
    _lifeTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() => _lifeClock = now);
      if (_lives?.nextRechargeAt != null && !now.isBefore(_lives!.nextRechargeAt!)) {
        try {
          final lives = await _fetchLives();
          if (!mounted) return;
          setState(() {
            _lives = lives;
            _lifeClock = DateTime.now();
          });
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _lifeTimer?.cancel();
    super.dispose();
  }

  Future<void> _openLevel(PracticeLevelProgress level) async {
    if (!level.unlocked) {
      await _showLocked(level);
      return;
    }
    if (_lives?.empty == true) {
      await _showNoLives();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => switch (_mode) {
          null => PracticeScreen(levelNumber: level.level),
          JourneyMode.speedQuiz => SpeedQuizScreen(levelNumber: level.level),
          JourneyMode.guessIt => GuessItScreen(levelNumber: level.level),
          JourneyMode.oddOneOut => OddOneOutScreen(levelNumber: level.level),
        },
      ),
    );
    if (mounted) _load();
  }

  /// The original, level-free version of the mode (Odd One Out keeps its
  /// Daily Set here).
  Future<void> _openFreePlay() async {
    final mode = _mode;
    if (mode == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => switch (mode) {
          JourneyMode.speedQuiz => const SpeedQuizScreen(),
          JourneyMode.guessIt => const GuessItScreen(),
          JourneyMode.oddOneOut => const OddOneOutScreen(),
        },
      ),
    );
    if (mounted) _load();
  }

  Future<void> _watchUnlockAd() async {
    final journey = _journey;
    if (journey == null || journey.nextBatch <= 1 || _unlocking) return;
    if (journey.adUnlocksUsed >= journey.adUnlocksPerBatch) {
      _snack('You have used all rewarded unlocks for this batch.');
      return;
    }

    setState(() => _unlocking = true);
    try {
      final result = await AdCoordinator.showRewarded();
      if (result == RewardedResult.unavailable) {
        _snack('No rewarded video is available right now. Try again shortly.');
        return;
      }
      if (result == RewardedResult.notEarned) {
        _snack('Watch the whole video to earn the unlock progress.');
        return;
      }
      final updated = _mode == null
          ? await SupabaseService.instance.unlockPracticeBatchByAd(journey.nextBatch)
          : await SupabaseService.instance.unlockModeBatchByAd(_mode!, journey.nextBatch);
      if (!mounted) return;
      setState(() => _journey = updated);
      if (updated.adUnlocksUsed >= updated.adUnlocksPerBatch) {
        _snack('Batch ${journey.nextBatch} unlocked!');
      } else {
        _snack('${updated.adUnlocksPerBatch - updated.adUnlocksUsed} rewarded unlock video(s) left.');
      }
    } catch (e) {
      if (mounted) _snack('Could not record the rewarded unlock. Please try again.');
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _showNoLives() async {
    final lives = _lives;
    if (!mounted || lives == null) return;
    await showJuaMessage(
      context,
      title: 'No lives left',
      message: lives.nextRechargeAt == null
          ? 'Your lives are currently recharging. Come back shortly.'
          : 'Your next life will be ready in ${lives.remainingLabel}.',
      art: JuaDialogArt.clock,
      tone: JuaDialogTone.red,
      buttonLabel: 'OK',
      buttonStyle: JuaDialogButtonStyle.blue,
    );
  }

  Future<void> _showLocked(PracticeLevelProgress level) async {
    final journey = _journey;
    if (journey == null) return;
    final isBatchStart = level.level > 1 && level.level % 10 == 1;
    await showJuaDialogRoute<void>(
      context,
      label: 'Level locked',
      builder: (dialogContext) => JuaDialogCard(
        title: 'Level ${level.level} is locked',
        message: isBatchStart
            ? 'Reach ${journey.nextBatchRequirement} cumulative stars from the opened journey levels to unlock Batch ${journey.nextBatch}.'
            : 'Complete Level ${level.level - 1} first, then this level opens.',
        fallbackIcon: Icons.lock_rounded,
        tone: JuaDialogTone.orange,
        onClose: () => Navigator.of(dialogContext).pop(),
        content: isBatchStart
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${journey.cumulativeStars} / ${journey.nextBatchRequirement} ⭐',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF14235E)),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: journey.nextBatchRequirement == 0
                          ? 1
                          : (journey.cumulativeStars / journey.nextBatchRequirement).clamp(0, 1).toDouble(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mastery requirement: ${journey.nextBatchRequirementPercent}%',
                    style: const TextStyle(color: Color(0xFF2B3A67), fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You can always replay earlier levels and earn the missing stars. Premium batch unlocks will be added through the app-store billing layer; stars are never sold.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              )
            : null,
        buttons: [
          if (isBatchStart && journey.adUnlocksUsed < journey.adUnlocksPerBatch)
            JuaDialogButton(
              label: _unlocking
                  ? 'Loading reward…'
                  : 'Watch Ad • ${journey.adUnlocksUsed}/${journey.adUnlocksPerBatch}',
              icon: Icons.ondemand_video_rounded,
              style: JuaDialogButtonStyle.gold,
              onPressed: _unlocking
                  ? null
                  : () async {
                      Navigator.of(dialogContext).pop();
                      await _watchUnlockAd();
                    },
            ),
          JuaDialogButton(
            label: 'Keep playing',
            style: JuaDialogButtonStyle.light,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_mode == null ? 'Quiz Journey' : '${_mode!.emoji} ${_mode!.title}'),
        actions: [
          if (_mode != null)
            IconButton(
              tooltip: _mode == JourneyMode.oddOneOut ? 'Daily set & quick play' : 'Free play',
              onPressed: _openFreePlay,
              icon: const Icon(Icons.bolt_rounded),
            ),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _journey == null
                  ? _ErrorView(message: 'Journey unavailable.', onRetry: _load)
                  : Column(
                      children: [
                        _JourneyStatBar(journey: _journey!, lives: _lives, now: _lifeClock),
                        Expanded(
                          child: _JourneyMap(journey: _journey!, onOpenLevel: _openLevel, mode: _mode),
                        ),
                      ],
                    ),
    );
  }
}

// ============================================================================
// Top stat bar: lives, stars, current level.
// ============================================================================

class _JourneyStatBar extends StatelessWidget {
  final PracticeJourneyData journey;
  final PracticeLives? lives;
  final DateTime now;

  const _JourneyStatBar({required this.journey, required this.lives, required this.now});

  @override
  Widget build(BuildContext context) {
    final l = lives;
    String livesLabel = '';
    if (l != null) {
      livesLabel = '${l.availableLives}/${l.maxLives}';
      if (!l.full && l.nextRechargeAt != null) {
        final remaining = l.nextRechargeAt!.difference(now).inSeconds.clamp(0, 3599).toInt();
        final mm = (remaining ~/ 60).toString().padLeft(2, '0');
        final ss = (remaining % 60).toString().padLeft(2, '0');
        livesLabel = '$livesLabel  $mm:$ss';
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          if (l != null) Expanded(flex: 5, child: _StatPill(emoji: '❤️', label: livesLabel)),
          if (l != null) const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _StatPill(emoji: '⭐', label: '${journey.cumulativeStars}/${journey.cumulativeAvailableStars}'),
          ),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _StatPill(emoji: '🚩', label: 'Lv ${journey.currentLevel}')),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String emoji;
  final String label;

  const _StatPill({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.inkBrown)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// The illustrated level map.
// Each batch of 10 levels is one painted region (assets/journey/strips). The
// regions are stacked upward and cross-faded; level nodes sit on the painted
// road using positions stored in journey_map_data.dart.
// ============================================================================

const String _uiDir = 'assets/journey/ui';

class _MapLayout {
  static const double bottomPad = 12;

  final double mapW;
  final int batches;
  final List<double> tops;
  final List<double> heights;
  final double capH;
  final double total;

  const _MapLayout._(this.mapW, this.batches, this.tops, this.heights, this.capH, this.total);

  factory _MapLayout.build(double mapW, int batches) {
    final n = kJourneyRegions.length;
    final heights = <double>[
      for (var b = 0; b < batches; b++) kJourneyRegions[b % n].aspect * mapW,
    ];
    final capH = kJourneyRegions[(batches - 1) % n].capAspect * mapW;
    var total = capH + bottomPad;
    for (final h in heights) {
      total += h;
    }
    for (var b = 1; b < batches; b++) {
      total -= kJourneyRegions[b % n].feather * mapW;
    }
    final tops = List<double>.filled(batches, 0);
    var bottom = total - bottomPad;
    for (var b = 0; b < batches; b++) {
      tops[b] = bottom - heights[b];
      if (b < batches - 1) {
        bottom = tops[b] + kJourneyRegions[(b + 1) % n].feather * mapW;
      }
    }
    return _MapLayout._(mapW, batches, tops, heights, capH, total);
  }

  static JourneyRegion regionOf(int batchIndex) => kJourneyRegions[batchIndex % kJourneyRegions.length];

  static bool flipped(int batchIndex) => (batchIndex ~/ kJourneyRegions.length).isOdd;

  /// Centre of the node for a 1-based level number.
  Offset nodeCenter(int level) {
    final b = (level - 1) ~/ 10;
    final i = (level - 1) % 10;
    final p = regionOf(b).nodes[i];
    final nx = flipped(b) ? 1 - p.dx : p.dx;
    return Offset(nx * mapW, tops[b] + p.dy * heights[b]);
  }

  /// Vertical centre of the region banner for a batch (just above the strip's bottom edge).
  double ribbonY(int batchIndex) => tops[batchIndex] + heights[batchIndex] - 52;
}

Widget _mapImage(String asset, {required double width, required double height, bool flip = false}) {
  Widget img = Image.asset(
    asset,
    width: width,
    height: height,
    fit: BoxFit.fill,
    filterQuality: FilterQuality.high,
    gaplessPlayback: true,
  );
  if (flip) img = Transform.flip(flipX: true, child: img);
  return img;
}

class _JourneyMap extends StatefulWidget {
  final PracticeJourneyData journey;
  final Future<void> Function(PracticeLevelProgress level) onOpenLevel;
  final JourneyMode? mode;

  const _JourneyMap({required this.journey, required this.onOpenLevel, this.mode});

  @override
  State<_JourneyMap> createState() => _JourneyMapState();
}

class _JourneyMapState extends State<_JourneyMap> with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final AnimationController _pulse;
  bool _centered = false;
  bool _showJump = false;
  double _currentY = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _pulse.dispose();
    super.dispose();
  }

  double _targetOffset(double viewport, double maxExtent) {
    return (_currentY - viewport * 0.62).clamp(0.0, maxExtent).toDouble();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final target = _targetOffset(pos.viewportDimension, pos.maxScrollExtent);
    final far = (pos.pixels - target).abs() > pos.viewportDimension * 0.7;
    if (far != _showJump && mounted) setState(() => _showJump = far);
  }

  void _jumpToCurrent() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _scroll.animateTo(
      _targetOffset(pos.viewportDimension, pos.maxScrollExtent),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;
    final levels = [...journey.levels]..sort((a, b) => a.level.compareTo(b.level));
    if (levels.isEmpty) {
      return const Center(child: Text('No levels yet.', style: TextStyle(color: Colors.white)));
    }
    final maxLevel = levels.last.level;
    final batches = (maxLevel + 9) ~/ 10;
    final currentLevel = journey.currentLevel.clamp(1, maxLevel).toInt();

    final byBatch = <int, List<PracticeLevelProgress>>{};
    for (final l in levels) {
      byBatch.putIfAbsent((l.level - 1) ~/ 10 + 1, () => <PracticeLevelProgress>[]).add(l);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapW = math.min(constraints.maxWidth, 460.0);
        final layout = _MapLayout.build(mapW, batches);
        _currentY = layout.nodeCenter(currentLevel).dy;

        if (!_centered) {
          _centered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) return;
            final pos = _scroll.position;
            _scroll.jumpTo(_targetOffset(pos.viewportDimension, pos.maxScrollExtent));
            _onScroll();
          });
        }

        final children = <Widget>[];

        // Sky / horizon cap above the highest region.
        final topRegion = _MapLayout.regionOf(batches - 1);
        children.add(Positioned(
          top: 0,
          left: 0,
          width: mapW,
          height: layout.capH,
          child: _mapImage(topRegion.capAsset, width: mapW, height: layout.capH, flip: _MapLayout.flipped(batches - 1)),
        ));

        // Region strips; higher batches are painted last so their feathered
        // bottom edge cross-fades over the top of the region below.
        for (var b = 0; b < batches; b++) {
          final region = _MapLayout.regionOf(b);
          children.add(Positioned(
            top: layout.tops[b],
            left: 0,
            width: mapW,
            height: layout.heights[b],
            child: _mapImage(
              b == 0 ? region.startAsset : region.stripAsset,
              width: mapW,
              height: layout.heights[b],
              flip: _MapLayout.flipped(b),
            ),
          ));
        }

        // Signpost for "more to come".
        children.add(Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE62A2118),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'More levels beyond Level $maxLevel  ♾️',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ));

        // Region banners with a prop on each side.
        for (var b = 0; b < batches; b++) {
          final batchLevels = byBatch[b + 1] ?? const <PracticeLevelProgress>[];
          if (batchLevels.isEmpty) continue;
          final region = _MapLayout.regionOf(b);
          final unlocked = batchLevels.any((l) => l.unlocked);
          final stars = batchLevels.fold<int>(0, (sum, l) => sum + l.stars);
          final first = b * 10 + 1;
          final qs = widget.mode?.questionCount ?? PracticeJourneyRules.questionCountForLevel(first);
          // Difficulty ramps level by level (see journeyDifficultyShares);
          // label the batch by its middle level.
          final diff = journeyDifficultyLabel(first + 4);
          final diffLabel = '${diff[0].toUpperCase()}${diff.substring(1)}';
          String subtitle;
          if (unlocked) {
            subtitle = '$diffLabel • $qs questions • $stars/${batchLevels.length * 3} ⭐';
          } else if (b + 1 == journey.nextBatch && journey.nextBatchRequirement > 0) {
            subtitle = '🔒 ${journey.cumulativeStars}/${journey.nextBatchRequirement} ⭐ to open';
          } else {
            subtitle = '🔒 Locked';
          }
          final ribbonW = math.min(236.0, mapW * 0.66);
          final side = (mapW - ribbonW) / 2;
          final y = layout.ribbonY(b);
          children.add(Positioned(
            left: 0,
            top: y - 46,
            width: side,
            height: 60,
            child: IgnorePointer(child: Image.asset(region.props[0], fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
          ));
          children.add(Positioned(
            left: mapW - side,
            top: y - 46,
            width: side,
            height: 60,
            child: IgnorePointer(child: Image.asset(region.props[1], fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
          ));
          children.add(Positioned(
            left: side,
            top: y - 28,
            width: ribbonW,
            height: 56,
            child: _BatchRibbon(
              title: 'BATCH ${b + 1} • ${region.title}',
              subtitle: subtitle,
              locked: !unlocked,
              onTap: unlocked ? null : () => widget.onOpenLevel(batchLevels.first),
            ),
          ));
        }

        // Level nodes.
        for (final level in levels) {
          final c = layout.nodeCenter(level.level);
          final isCurrent = level.unlocked && level.level == currentLevel;
          children.add(Positioned(
            left: c.dx - _MapNode.boxW / 2,
            top: c.dy - _MapNode.d / 2,
            width: _MapNode.boxW,
            height: _MapNode.d + 16,
            child: _MapNode(
              level: level,
              current: isCurrent,
              pulse: _pulse,
              onTap: () => widget.onOpenLevel(level),
            ),
          ));
        }

        // Mascot hopping above the current level.
        final cur = layout.nodeCenter(currentLevel);
        children.add(Positioned(
          left: cur.dx - 22,
          top: cur.dy - _MapNode.d / 2 - 62,
          width: 44,
          height: 44,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) => Transform.translate(offset: Offset(0, -6 * _pulse.value), child: child),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF4F9A), width: 3.5),
                  boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 3))],
                ),
                child: const Text('🦁', style: TextStyle(fontSize: 22)),
              ),
            ),
          ),
        ));

        return Stack(
          children: [
            SingleChildScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              child: Container(
                width: constraints.maxWidth,
                height: layout.total,
                color: const Color(0xFF8FD3F4),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: mapW,
                    height: layout.total,
                    child: Stack(clipBehavior: Clip.none, children: children),
                  ),
                ),
              ),
            ),
            if (_showJump)
              Positioned(
                right: 14,
                bottom: 14,
                child: FloatingActionButton.small(
                  heroTag: null,
                  backgroundColor: const Color(0xFFFF4F9A),
                  foregroundColor: Colors.white,
                  tooltip: 'Go to my level',
                  onPressed: _jumpToCurrent,
                  child: const Icon(Icons.my_location_rounded),
                ),
              ),
          ],
        );
      },
    );
  }
}

const ColorFilter _greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

class _MapNode extends StatelessWidget {
  static const double d = 48; // bubble diameter
  static const double boxW = 76;

  final PracticeLevelProgress level;
  final bool current;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _MapNode({required this.level, required this.current, required this.pulse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locked = !level.unlocked;
    final String kind;
    final Color stroke;
    if (locked) {
      kind = 'locked';
      stroke = const Color(0xFF4B546B);
    } else if (current) {
      kind = 'current';
      stroke = const Color(0xFF5A1AA0);
    } else if (level.completed) {
      kind = 'completed';
      stroke = const Color(0xFF9C0F4A);
    } else {
      kind = 'open';
      stroke = const Color(0xFF123F9E);
    }
    final stars = level.stars.clamp(0, 3).toInt();
    final label = '${level.level}';

    Widget number = FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5
                ..strokeJoin = StrokeJoin.round
                ..color = stroke,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(locked ? 0.9 : 1),
            ),
          ),
        ],
      ),
    );

    Widget star(int i) {
      final earned = i < stars;
      Widget img = Image.asset('$_uiDir/star.png', width: 21, height: 21, filterQuality: FilterQuality.high);
      if (!earned) {
        img = Opacity(opacity: 0.85, child: ColorFiltered(colorFilter: _greyscale, child: img));
      }
      return Positioned(
        left: (boxW - 54) / 2 + i * 16.5,
        top: d - (i == 1 ? 9 : 13),
        child: img,
      );
    }

    final bubble = SizedBox(
      width: boxW,
      height: d + 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (current)
            Positioned(
              left: (boxW - d) / 2,
              top: 0,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => Transform.scale(
                    scale: 1 + 0.30 * pulse.value,
                    child: Container(
                      width: d,
                      height: d,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.fromRGBO(255, 255, 255, 0.55 * (1 - pulse.value)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: (boxW - d) / 2,
            top: 0,
            child: Image.asset('$_uiDir/bubble_$kind.png', width: d, height: d, filterQuality: FilterQuality.high),
          ),
          Positioned(
            left: (boxW - d) / 2 + 6,
            top: 0,
            width: d - 12,
            height: d - 8,
            child: Center(child: number),
          ),
          if (locked)
            Positioned(
              left: (boxW - 26) / 2,
              top: d - 16,
              child: Image.asset('$_uiDir/lock.png', width: 26, height: 26, filterQuality: FilterQuality.high),
            )
          else ...[star(0), star(2), star(1)],
          if (level.isMath)
            Positioned(
              left: (boxW - d) / 2 + d - 16,
              top: -7,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFD04D), Color(0xFFF08A10)],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: const Text('∑', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, height: 1.1)),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: locked
          ? 'Level ${level.level}${level.isMath ? ', math level' : ''}, locked'
          : 'Level ${level.level}${level.isMath ? ', math level' : ''}, $stars of 3 stars${current ? ', current level' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Transform.scale(scale: current ? 1.12 : 1.0, alignment: const Alignment(0, -0.45), child: bubble),
      ),
    );
  }
}

class _BatchRibbon extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback? onTap;

  const _BatchRibbon({required this.title, required this.subtitle, required this.locked, this.onTap});

  @override
  Widget build(BuildContext context) {
    final top = locked ? const Color(0xFFD9CFE0) : const Color(0xFFFF7BB5);
    final bottom = locked ? const Color(0xFFB3A6BF) : const Color(0xFFE5337F);
    const ink = Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1.5))],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  maxLines: 1,
                  style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 11.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final friendly = message.contains('Exception') || message.contains('SocketException')
        ? 'Please check your internet connection and try again.'
        : message;
    return JuaStateCard.error(
      title: "Couldn't load the Quiz Journey",
      message: friendly,
      onPressed: onRetry,
    );
  }
}
