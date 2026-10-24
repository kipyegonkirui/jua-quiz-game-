import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../models/football_journey.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/jua_buttons.dart';
import 'football_play_screen.dart';

const String _fbStar = 'assets/football/fb_star.png';
const String _fbLock = 'assets/football/fb_lock.png';
const String _fbBall = 'assets/football/fb_ball.png';
const String _fbPlayer = 'assets/football/fb_player_blue.png';
const String _fbTrophy = 'assets/football/fb_trophy.png';
const String _fbStadium = 'assets/football/fb_stadium_a.png';
const String _fbStartFlag = 'assets/football/fb_flag_checkered.png';

Widget _sprite(String asset, {double? width, double? height}) {
  return Image.asset(
    asset,
    width: width,
    height: height,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
  );
}

/// Football Challenge: a winding road map of levels through six themed zones.
///
/// Tapping an open level starts a 5-kick penalty shootout of football trivia
/// ([FootballPlayScreen]). Stars come from the server. In debug builds,
/// long-press an open level to cycle its stars (0 → 3) and preview the
/// completed / current / locked looks (local only, never saved).
class FootballJourneyScreen extends StatefulWidget {
  const FootballJourneyScreen({super.key});

  @override
  State<FootballJourneyScreen> createState() => _FootballJourneyScreenState();
}

class _FootballJourneyScreenState extends State<FootballJourneyScreen> {
  FootballJourney _journey = const FootballJourney();

  @override
  void initState() {
    super.initState();
    _loadJourney();
  }

  Future<void> _loadJourney() async {
    try {
      final stars = await SupabaseService.instance.getFootballStars();
      if (!mounted) return;
      setState(() => _journey = FootballJourney(stars: stars));
    } catch (e) {
      // The road still shows (all locked but Level 1); progress reloads on return.
      debugPrint('Could not load the Football road: $e');
    }
  }

  Future<void> _play(int level) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FootballPlayScreen(level: level)),
    );
    if (mounted) await _loadJourney();
  }

  void _openLevel(int level) {
    final unlocked = _journey.isUnlocked(level);
    final zone = FootballJourneyRules.zoneForLevel(level);
    final stars = _journey.starsFor(level);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sprite(unlocked ? _fbBall : _fbLock, height: 58),
                const SizedBox(height: 10),
                Text(
                  unlocked ? 'Level $level' : 'Level $level is locked',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.inkBrown,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  zone.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.savannaGreen,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  unlocked
                      ? 'Penalty shootout: 5 football questions, 5 kicks. A right answer is a goal. 3 goals earn a star.'
                      : 'Win a star on Level ${level - 1} first, then this match opens.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, height: 1.4),
                ),
                if (unlocked) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < FootballJourneyRules.starsPerLevel; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _StarSprite(size: 26, earned: i < stars),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                JuaGlossyButton(
                  label: unlocked ? 'Kick off' : 'Back to the road',
                  icon: unlocked ? Icons.sports_soccer_rounded : Icons.route_rounded,
                  variant: JuaButtonVariant.action,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    if (unlocked) _play(level);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Debug-only helper so the completed / current / locked looks can be
  /// previewed before real content exists.
  void _debugCycleStars(int level) {
    if (!kDebugMode || !_journey.isUnlocked(level)) return;
    final next = (_journey.starsFor(level) + 1) % (FootballJourneyRules.starsPerLevel + 1);
    setState(() => _journey = _journey.withStars(level, next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.juaSkyBlue,
      appBar: AppBar(
        title: const Text('Football Challenge'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Reload from server',
              onPressed: _loadJourney,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          _StatBar(journey: _journey),
          Expanded(
            child: _RoadMap(
              journey: _journey,
              onOpenLevel: _openLevel,
              onDebugLevel: kDebugMode ? _debugCycleStars : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Top stat bar: stars, current level, current zone.
// ============================================================================

class _StatBar extends StatelessWidget {
  final FootballJourney journey;

  const _StatBar({required this.journey});

  @override
  Widget build(BuildContext context) {
    final zone = FootballJourneyRules.zoneForLevel(journey.currentLevel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _StatPill(
              icon: _sprite(_fbStar, height: 22),
              label: '${journey.totalStars}/${FootballJourneyRules.totalStars}',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _StatPill(
              icon: _sprite(_fbBall, height: 22),
              label: 'Lv ${journey.currentLevel}',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 8,
            child: _StatPill(
              icon: _sprite(zone.flag, height: 22),
              label: zone.name,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final Widget icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

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
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppColors.inkBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarSprite extends StatelessWidget {
  final double size;
  final bool earned;

  const _StarSprite({required this.size, required this.earned});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _fbStar,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      color: earned ? null : const Color(0x80203050),
      colorBlendMode: earned ? null : BlendMode.srcATop,
    );
  }
}

// ============================================================================
// Road geometry. Level 1 sits at the bottom; the road winds upward through
// six zones of ten levels each, one zone background per ten levels.
// ============================================================================

class _RoadGeometry {
  static const double nodeR = 29;
  static const double finalR = 34;
  static const double stepY = 122;
  static const double padBottom = 92;
  static const double padTop = 80;
  static const double topCap = 300;
  static const double bottomCap = 46;
  static const double zoneH =
      padBottom + (FootballJourneyRules.levelsPerZone - 1) * stepY + padTop;

  final double width;

  const _RoadGeometry(this.width);

  int get zones => FootballJourneyRules.zoneCount;
  int get count => FootballJourneyRules.totalLevels;

  double get height => topCap + zones * zoneH + bottomCap;

  /// Zone 0 is the bottom-most zone.
  double zoneTop(int zoneIndex) => topCap + (zones - 1 - zoneIndex) * zoneH;

  double zoneBottom(int zoneIndex) => zoneTop(zoneIndex) + zoneH;

  Offset center(int level) {
    final i = level - 1;
    final zone = i ~/ FootballJourneyRules.levelsPerZone;
    final local = i % FootballJourneyRules.levelsPerZone;
    final y = zoneBottom(zone) - padBottom - local * stepY;
    final x = width * (0.5 + 0.27 * math.sin(i * 0.95 + 0.4));
    return Offset(x, y);
  }

  Offset _point(int level) => center(level.clamp(1, count).toInt());

  /// Smooth road (Catmull-Rom through the level centres) from [fromLevel]
  /// to [toLevel], inclusive.
  Path trail(int fromLevel, int toLevel) {
    final start = _point(fromLevel);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var n = fromLevel; n < toLevel; n++) {
      final p0 = _point(n - 1);
      final p1 = _point(n);
      final p2 = _point(n + 1);
      final p3 = _point(n + 2);
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }
}

// ============================================================================
// The scrolling road map.
// ============================================================================

class _RoadMap extends StatefulWidget {
  final FootballJourney journey;
  final void Function(int level) onOpenLevel;
  final void Function(int level)? onDebugLevel;

  const _RoadMap({
    required this.journey,
    required this.onOpenLevel,
    required this.onDebugLevel,
  });

  @override
  State<_RoadMap> createState() => _RoadMapState();
}

class _RoadMapState extends State<_RoadMap> with SingleTickerProviderStateMixin {
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
    final currentLevel = journey.currentLevel;
    final unlockedThrough = journey.unlockedThrough;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapW = math.min(constraints.maxWidth, 440.0);
        final g = _RoadGeometry(mapW);
        _currentY = g.center(currentLevel).dy;

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

        // Night-sky cap above the last zone, fading into the Night City art.
        children.add(Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: _RoadGeometry.topCap + 70,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0E0838), Color(0xFF24108F)],
                ),
              ),
            ),
          ),
        ));

        // Zone backgrounds.
        for (var z = 0; z < FootballJourneyRules.zoneCount; z++) {
          final zone = FootballJourneyRules.zones[z];
          children.add(Positioned(
            left: 0,
            top: g.zoneTop(z),
            width: mapW,
            height: _RoadGeometry.zoneH,
            child: IgnorePointer(
              child: Image.asset(
                zone.background,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ));
        }

        // Soft blend from the night-sky cap into the top of the last zone.
        children.add(Positioned(
          left: 0,
          top: g.zoneTop(FootballJourneyRules.zoneCount - 1),
          width: mapW,
          height: 70,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF24108F), Color(0x0024108F)],
                ),
              ),
            ),
          ),
        ));

        // The road itself.
        children.add(Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RoadPainter(g: g, unlockedThrough: unlockedThrough),
            ),
          ),
        ));

        // Finish: stadium, trophy and the "more levels" sign.
        const stadiumW = 250.0;
        children.add(Positioned(
          left: (mapW - stadiumW) / 2,
          top: 118,
          width: stadiumW,
          child: IgnorePointer(child: _sprite(_fbStadium, width: stadiumW)),
        ));
        children.add(Positioned(
          left: mapW / 2 - 38,
          top: 78,
          width: 76,
          child: IgnorePointer(child: _sprite(_fbTrophy, width: 76)),
        ));
        children.add(Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xE62A2118),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'MORE LEVELS COMING SOON',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ));

        // Zone ribbons sit on the seam where each zone begins.
        final ribbonW = math.min(280.0, mapW * 0.66);
        for (var z = 0; z < FootballJourneyRules.zoneCount; z++) {
          final zone = FootballJourneyRules.zones[z];
          final y = g.zoneBottom(z);
          final unlocked = journey.isZoneUnlocked(zone);
          final flagX = (mapW - ribbonW) / 2;
          children.add(Positioned(
            left: flagX - 34,
            top: y - 32,
            width: 30,
            height: 52,
            child: IgnorePointer(child: _sprite(zone.flag, height: 52)),
          ));
          children.add(Positioned(
            left: flagX + ribbonW + 4,
            top: y - 32,
            width: 30,
            height: 52,
            child: IgnorePointer(child: _sprite(zone.flag, height: 52)),
          ));
          children.add(Positioned(
            left: flagX,
            top: y - 28,
            width: ribbonW,
            height: 56,
            child: IgnorePointer(
              child: _ZoneRibbon(
                zone: zone,
                locked: !unlocked,
                stars: journey.starsInZone(zone),
              ),
            ),
          ));
        }

        // Kick-off flag beside Level 1, on the outer side of the road.
        final first = g.center(1);
        final outward = first.dx > mapW / 2 ? 1.0 : -1.0;
        children.add(Positioned(
          left: outward > 0
              ? first.dx + _RoadGeometry.nodeR + 8
              : first.dx - _RoadGeometry.nodeR - 8 - 30,
          top: first.dy - 26,
          width: 30,
          child: IgnorePointer(child: _sprite(_fbStartFlag, width: 30)),
        ));

        // Level nodes.
        for (var level = 1; level <= FootballJourneyRules.totalLevels; level++) {
          final c = g.center(level);
          final isFinal = FootballJourneyRules.isZoneFinal(level);
          final r = isFinal ? _RoadGeometry.finalR : _RoadGeometry.nodeR;
          final unlocked = journey.isUnlocked(level);
          final onDebug = widget.onDebugLevel;
          children.add(Positioned(
            left: c.dx - 40,
            top: c.dy - r,
            width: 80,
            child: _MapNode(
              level: level,
              stars: journey.starsFor(level),
              locked: !unlocked,
              current: unlocked && level == currentLevel,
              isFinal: isFinal,
              pulse: _pulse,
              onTap: () => widget.onOpenLevel(level),
              onLongPress: onDebug == null ? null : () => onDebug(level),
            ),
          ));
        }

        // Player hopping beside the current level, toward the road centre.
        final cur = g.center(currentLevel);
        final curR = FootballJourneyRules.isZoneFinal(currentLevel)
            ? _RoadGeometry.finalR
            : _RoadGeometry.nodeR;
        final toLeft = cur.dx > mapW / 2;
        const playerW = 48.0;
        children.add(Positioned(
          left: toLeft ? cur.dx - curR - 4 - playerW : cur.dx + curR + 4,
          top: cur.dy - 46,
          width: playerW,
          height: 64,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) =>
                  Transform.translate(offset: Offset(0, -6 * _pulse.value), child: child),
              child: _sprite(_fbPlayer, height: 64),
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
                height: g.height,
                color: const Color(0xFF16324F),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: mapW,
                    height: g.height,
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
                  backgroundColor: const Color(0xFFF28C0F),
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

/// Paints the road: a white-cased lane with a dashed centre line. The part
/// leading to open levels is bright gold; the rest is faded.
class _RoadPainter extends CustomPainter {
  final _RoadGeometry g;
  final int unlockedThrough;

  const _RoadPainter({required this.g, required this.unlockedThrough});

  Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  void _drawRoad(Canvas canvas, Path path, {required bool bright}) {
    canvas.drawPath(path, _stroke(bright ? Colors.white : const Color(0x66FFFFFF), 28));
    canvas.drawPath(
      path,
      _stroke(bright ? const Color(0xFFFFC83D) : const Color(0x4DFFFFFF), 19),
    );

    final dashes = Path();
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + 9, metric.length);
        dashes.addPath(metric.extractPath(d, end), Offset.zero);
        d += 20;
      }
    }
    canvas.drawPath(
      dashes,
      _stroke(bright ? Colors.white : const Color(0x80FFFFFF), 3.5),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawRoad(canvas, g.trail(1, g.count), bright: false);
    if (unlockedThrough >= 2) {
      _drawRoad(canvas, g.trail(1, unlockedThrough), bright: true);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) =>
      old.g.width != g.width || old.unlockedThrough != unlockedThrough;
}

// ============================================================================
// Level node.
// ============================================================================

class _NodeColors {
  final Color top;
  final Color bottom;
  final Color shadow;

  const _NodeColors(this.top, this.bottom, this.shadow);

  static const completed = _NodeColors(Color(0xFF7BE495), Color(0xFF1FA34A), Color(0x661FA34A));
  static const current = _NodeColors(Color(0xFF6BB7FF), Color(0xFF1F5FD6), Color(0x801F5FD6));
  static const locked = _NodeColors(Color(0xFFB9A9E6), Color(0xFF6E5DB0), Color(0x556E5DB0));
}

class _MapNode extends StatelessWidget {
  final int level;
  final int stars;
  final bool locked;
  final bool current;
  final bool isFinal;
  final Animation<double> pulse;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _MapNode({
    required this.level,
    required this.stars,
    required this.locked,
    required this.current,
    required this.isFinal,
    required this.pulse,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = locked
        ? _NodeColors.locked
        : current
            ? _NodeColors.current
            : _NodeColors.completed;
    final r = isFinal ? _RoadGeometry.finalR : _RoadGeometry.nodeR;
    final d = r * 2;

    final circle = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.top, colors.bottom],
        ),
        border: Border.all(
          color: isFinal && !locked ? const Color(0xFFFFD36B) : Colors.white,
          width: isFinal ? 4 : 3.5,
        ),
        boxShadow: [BoxShadow(color: colors.shadow, blurRadius: 9, offset: const Offset(0, 5))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: d * 0.08,
            left: d * 0.2,
            right: d * 0.2,
            height: d * 0.3,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(40, 16)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$level',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: locked ? 0.9 : 1),
                  fontWeight: FontWeight.w900,
                  fontSize: isFinal ? 25 : 22,
                  shadows: const [
                    Shadow(color: Color(0x59000000), blurRadius: 3, offset: Offset(0, 1.5)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: locked
          ? 'Level $level, locked'
          : 'Level $level, $stars of 3 stars${current ? ', current level' : ''}'
              '${isFinal ? ', zone final' : ''}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: d,
            height: d,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (current)
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: pulse,
                      builder: (context, _) => Transform.scale(
                        scale: 1 + 0.24 * pulse.value,
                        child: Container(
                          width: d,
                          height: d,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.fromRGBO(107, 183, 255, 0.6 * (1 - pulse.value)),
                          ),
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: circle,
                ),
                if (locked)
                  Positioned(
                    right: -6,
                    top: -8,
                    child: IgnorePointer(child: _sprite(_fbLock, height: 24)),
                  )
                else if (isFinal)
                  Positioned(
                    top: -18,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(child: _sprite(_fbTrophy, height: 26)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 18,
            child: locked
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < FootballJourneyRules.starsPerLevel; i++)
                        _StarSprite(size: 17, earned: i < stars),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Zone ribbon.
// ============================================================================

class _ZoneRibbon extends StatelessWidget {
  final FootballZone zone;
  final bool locked;
  final int stars;

  const _ZoneRibbon({required this.zone, required this.locked, required this.stars});

  @override
  Widget build(BuildContext context) {
    final top = locked ? const Color(0xFFD9CFE8) : const Color(0xFFFFB04A);
    final bottom = locked ? const Color(0xFFA99BC8) : const Color(0xFFE8782A);
    final border = locked ? const Color(0xFF5E4F86) : const Color(0xFF8A4B12);
    const shadow = [Shadow(color: Color(0x80000000), blurRadius: 3, offset: Offset(0, 1.5))];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                zone.name.toUpperCase(),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.6,
                  shadows: shadow,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (locked) ...[
                    _sprite(_fbLock, height: 13),
                    const SizedBox(width: 4),
                    Text(
                      'Levels ${zone.firstLevel}–${zone.lastLevel} • Locked',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        shadows: shadow,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Levels ${zone.firstLevel}–${zone.lastLevel} • $stars/${FootballJourneyRules.starsPerZone}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        shadows: shadow,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _sprite(_fbStar, height: 13),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
