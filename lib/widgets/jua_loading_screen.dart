import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Layered, animated Jua Quiz loading screen.
///
/// Every piece of the emblem (lion, crown, flag, cards, chalkboard, books,
/// football, car badges, JUA, QUIZ, ring, star) is its own image, positioned on
/// the original 1024x1024 emblem canvas. The flattened emblem sits underneath
/// as a base so small movements never reveal holes.
///
///  1. Entrance   - pieces build the logo in sequence (~1.6s).
///  2. Loop       - lion bob, crown float, flag wave, card sway, football
///                  rock, badge pops, shimmer, sparkles.
///                  The book stack hops one book at a time as [progress] fills
///                  (HISTORY -> SCIENCE -> SPORTS -> KENYA).
///  3. Completion - set [done] to true: lion pump, confetti burst from the
///                  star, white flash, zoom-through, then [onFinished].
class JuaLoadingScreen extends StatefulWidget {
  const JuaLoadingScreen({
    super.key,
    this.progress,
    this.done = false,
    this.onFinished,
    this.message = 'Loading...',
  });

  /// 0..1 for a determinate bar, or null for an indeterminate loop.
  final double? progress;

  /// Flip to true when loading is finished to play the completion burst.
  final bool done;

  /// Called once the completion burst has finished playing.
  final VoidCallback? onFinished;

  final String message;

  static const background = Color(0xFF037AF5);

  @override
  State<JuaLoadingScreen> createState() => _JuaLoadingScreenState();
}

// ---------------------------------------------------------------------------
// Layer geometry (x, y, w, h on the 1024 x 1024 emblem canvas)
// ---------------------------------------------------------------------------

class _Box {
  const _Box(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
}

const _kCanvas = 1024.0;
const _ring = _Box(45, 558, 911, 400);
const _books = _Box(771, 504, 213, 217);
const _board = _Box(683, 324, 236, 242);
const _cards = _Box(37, 216, 293, 276);
const _flag = _Box(658, 103, 298, 282);
const _ball = _Box(40, 492, 206, 225);
const _lion = _Box(285, 133, 418, 341);
const _crown = _Box(339, 27, 269, 165);
const _toyota = _Box(106, 737, 94, 88);
const _merc = _Box(170, 816, 91, 114);
const _bmw = _Box(795, 726, 99, 106);
const _vw = _Box(762, 809, 84, 108);
const _jua = _Box(182, 463, 616, 267);
const _quiz = _Box(233, 684, 560, 190);
const _star = _Box(423, 850, 178, 109);

double _seg(double t, double a, double b, [Curve c = Curves.linear]) =>
    c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// Clips a layer to a polygon given in canvas coordinates.
class _PolyClipper extends CustomClipper<Path> {
  _PolyClipper(this.box, this.pts);
  final _Box box;
  final List<Offset> pts;

  @override
  Path getClip(Size size) {
    final p = Path();
    for (var i = 0; i < pts.length; i++) {
      final o = Offset((pts[i].dx - box.x) / box.w * size.width,
          (pts[i].dy - box.y) / box.h * size.height);
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldReclip(covariant _PolyClipper oldClipper) => false;
}

List<Offset> _rectPoly(_Box b, double x0, double x1) =>
    [Offset(x0, b.y), Offset(x1, b.y), Offset(x1, b.y + b.h), Offset(x0, b.y + b.h)];

// Flag: a static pole strip + 10 vertical strips that wave.
const _flagStart = 702.0;
const _flagStrips = 10;
final List<_PolyClipper> _flagClips = () {
  final end = _flag.x + _flag.w;
  final step = (end - _flagStart) / _flagStrips;
  return <_PolyClipper>[
    _PolyClipper(_flag, _rectPoly(_flag, _flag.x, _flagStart + 1.5)),
    for (var k = 0; k < _flagStrips; k++)
      _PolyClipper(_flag, _rectPoly(_flag, _flagStart + k * step, _flagStart + (k + 1) * step + 1.5)),
  ];
}();

// Books: four tilted bands (HISTORY, SCIENCE, SPORTS, KENYA).
final List<_PolyClipper> _bookClips = () {
  const slope = -0.14;
  double line(double c, double x) => c + slope * (x - 780);
  const cs = [538.0, 600.0, 651.0, 698.0, 760.0];
  final xl = _books.x;
  final xr = _books.x + _books.w;
  return List<_PolyClipper>.generate(4, (i) {
    final top = cs[i];
    final bot = cs[i + 1] + (i < 3 ? 2 : 0);
    return _PolyClipper(_books, [
      Offset(xl, line(top, xl)),
      Offset(xr, line(top, xr)),
      Offset(xr, line(bot, xr)),
      Offset(xl, line(bot, xl)),
    ]);
  });
}();

// JUA: three letter slices.
final List<_PolyClipper> _juaClips = [
  _PolyClipper(_jua, _rectPoly(_jua, _jua.x, 392)),
  _PolyClipper(_jua, _rectPoly(_jua, 390, 587)),
  _PolyClipper(_jua, _rectPoly(_jua, 585, _jua.x + _jua.w)),
];

// ---------------------------------------------------------------------------

class _JuaLoadingScreenState extends State<JuaLoadingScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _prog =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  late final List<_Particle> _particles = _makeParticles();
  bool _loopStarted = false;
  double _progFrom = 0;
  double _progTo = 0;

  double get _p =>
      _progFrom + (_progTo - _progFrom) * Curves.easeOut.transform(_prog.value);

  @override
  void initState() {
    super.initState();
    _progFrom = _progTo = widget.done ? 1.0 : (widget.progress ?? 0.0);
    _intro.forward().whenComplete(_startLoop);
    _burst.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished?.call();
    });
    if (widget.done) _playBurst();
  }

  void _startLoop() {
    if (!mounted || _loopStarted || widget.done) return;
    // Respect the OS "reduce motion" setting: keep the logo still.
    if (MediaQuery.of(context).disableAnimations) return;
    _loopStarted = true;
    _loop.repeat();
  }

  void _playBurst() {
    if (_burst.isAnimating || _burst.isCompleted) return;
    _loop.stop();
    _burst.forward();
  }

  @override
  void didUpdateWidget(JuaLoadingScreen old) {
    super.didUpdateWidget(old);
    final target = widget.done ? 1.0 : widget.progress;
    if (target != null && target != _progTo) {
      _progFrom = _p;
      _progTo = target;
      _prog.forward(from: 0);
    }
    if (widget.done && !old.done) _playBurst();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _burst.dispose();
    _prog.dispose();
    super.dispose();
  }

  static List<_Particle> _makeParticles() {
    final rnd = math.Random(7);
    const colors = [
      Color(0xFFFFD54A),
      Colors.white,
      Color(0xFFE53935),
      Color(0xFF43A047),
      Color(0xFFFF9800),
    ];
    return List.generate(48, (i) {
      return _Particle(
        angle: -math.pi * (0.05 + 0.9 * rnd.nextDouble()),
        distance: 0.35 + 0.75 * rnd.nextDouble(),
        size: 4 + 6 * rnd.nextDouble(),
        color: colors[i % colors.length],
        round: i.isEven,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final logo = math.min(w * 0.82, 340.0);
    final all = Listenable.merge([_intro, _loop, _burst, _prog]);

    return Scaffold(
      backgroundColor: JuaLoadingScreen.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: logo,
                  height: logo,
                  child: AnimatedBuilder(animation: all, builder: (context, _) => _buildLogo(logo)),
                ),
                const SizedBox(height: 28),
                AnimatedBuilder(animation: all, builder: (context, _) => _buildProgress(logo)),
              ],
            ),
          ),
          // White flash during the completion burst.
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _burst,
              builder: (context, _) {
                final t = _burst.value;
                final a = t < 0.3 ? 0.0 : math.sin(((t - 0.3) / 0.7) * math.pi) * 0.85;
                return ColoredBox(color: Colors.white.withValues(alpha: a.clamp(0.0, 1.0)));
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- layer helper --------------------------------------------------------

  Widget _layer(
    String name,
    _Box box,
    double s, {
    double dx = 0,
    double dy = 0,
    double rot = 0,
    double sx = 1,
    double sy = 1,
    Offset pivot = const Offset(0.5, 0.5),
    double opacity = 1,
    CustomClipper<Path>? clipper,
  }) {
    if (opacity <= 0.001) return const SizedBox.shrink();
    Widget img = Image.asset(
      'assets/logo/jua_$name.png',
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
    if (clipper != null) img = ClipPath(clipper: clipper, child: img);
    final m = Matrix4.translationValues(dx * s, dy * s, 0) *
        Matrix4.rotationZ(rot) *
        Matrix4.diagonal3Values(sx, sy, 1);
    return Positioned(
      left: box.x * s,
      top: box.y * s,
      width: box.w * s,
      height: box.h * s,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment(pivot.dx * 2 - 1, pivot.dy * 2 - 1),
          transform: m,
          child: img,
        ),
      ),
    );
  }

  List<Widget> _layers(double s, double intro, double loop, double b, double bp) {
    final lr = loop * 2 * math.pi;
    double e(double a, double z, [Curve c = Curves.easeOutBack]) => _seg(intro, a, z, c);
    double f(double a, double z) => _seg(intro, a, a + (z - a) * 0.5, Curves.easeOut);
    final pump = (b > 0 && b < 0.35) ? math.sin(b / 0.35 * math.pi) : 0.0;
    final shake = (b > 0 && b < 0.35) ? math.sin(b * 60) * 0.02 : 0.0;

    final out = <Widget>[];

    // Flattened base: fades in at the end of the entrance, hides all seams.
    out.add(Positioned.fill(
      child: Opacity(
        opacity: _seg(intro, 0.78, 1.0, Curves.easeIn),
        child: Image.asset('assets/logo/jua_emblem_base.png', fit: BoxFit.fill, gaplessPlayback: true),
      ),
    ));

    // Gold ring pops from the centre.
    final er = e(0.0, 0.35);
    out.add(_layer('ring', _ring, s,
        sx: 0.3 + 0.7 * er, sy: 0.3 + 0.7 * er, pivot: const Offset(0.51, -0.12), opacity: f(0.0, 0.35)));

    // Books: each band hops as progress passes its quarter.
    final eb = e(0.5, 0.76);
    for (var i = 0; i < 4; i++) {
      final lit = (bp * 4 - i).clamp(0.0, 1.0);
      final hop = (lit > 0 && lit < 1) ? math.sin(lit * math.pi) : 0.0;
      out.add(_layer('books', _books, s,
          dx: (1 - eb) * 90 + 5 * hop,
          dy: -9 * hop,
          opacity: f(0.5, 0.76),
          clipper: _bookClips[i]));
    }

    // Chalkboard slides in from the right, then breathes.
    final ec = e(0.45, 0.72);
    out.add(_layer('chalkboard', _board, s,
        dx: (1 - ec) * 90,
        rot: math.sin(lr + 0.8) * 0.006,
        sx: 1 + math.sin(lr) * 0.01,
        sy: 1 + math.sin(lr) * 0.01,
        opacity: f(0.45, 0.72)));

    // Question cards swing in from the left, then sway.
    final ek = e(0.40, 0.68);
    out.add(_layer('cards', _cards, s,
        dx: -(1 - ek) * 90,
        rot: -(1 - ek) * 0.25 + math.sin(lr + 1.2) * 0.02,
        pivot: const Offset(0.4, 0.95),
        opacity: f(0.40, 0.68)));

    // Flag: strips fade in left-to-right, then wave.
    final stripW = (_flag.x + _flag.w - _flagStart) / _flagStrips;
    for (var i = 0; i < _flagClips.length; i++) {
      final u = i == 0 ? 0.0 : ((_flagStart + (i - 0.5) * stripW) - _flagStart) / (_flag.x + _flag.w - _flagStart);
      final wave = math.sin(lr * 2 - u * 5.0) * 5.0 * u;
      out.add(_layer('flag', _flag, s,
          dy: wave, opacity: f(0.45 + u * 0.14, 0.62 + u * 0.14), clipper: _flagClips[i]));
    }

    // Football rolls in from the left, then rocks.
    final ef = e(0.35, 0.62);
    out.add(_layer('football', _ball, s,
        dx: -(1 - ef) * 100,
        rot: -(1 - ef) * 2.0 + math.sin(lr) * 0.10,
        opacity: f(0.35, 0.62)));

    // Lion pops up, bobs, and pumps/shakes on completion.
    final el = e(0.35, 0.65);
    out.add(_layer('lion', _lion, s,
        dy: (1 - el) * 110 + math.sin(lr) * 4.0 - pump * 6,
        rot: math.sin(lr + 0.5) * 0.012 + shake,
        sx: (0.85 + 0.15 * el) * (1 + 0.05 * pump),
        sy: (0.85 + 0.15 * el) * (1 + 0.05 * pump),
        pivot: const Offset(0.5, 1.0),
        opacity: f(0.35, 0.65)));

    // Crown drops on with a bounce, then floats.
    final ecr = _seg(intro, 0.60, 0.88, Curves.bounceOut);
    out.add(_layer('crown', _crown, s,
        dy: -(1 - ecr) * 90 + math.sin(lr + 2.2) * 3.0,
        rot: math.sin(lr + 1.0) * 0.02,
        pivot: const Offset(0.5, 0.9),
        opacity: f(0.60, 0.88)));

    // Car badges pop in one after another, then take turns pulsing.
    final badges = [(_toyota, 'badge_toyota'), (_merc, 'badge_mercedes'), (_vw, 'badge_vw'), (_bmw, 'badge_bmw')];
    for (var i = 0; i < badges.length; i++) {
      final a = 0.52 + i * 0.07;
      final pop = e(a, a + 0.25);
      final v = (loop - i * 0.25) % 1.0;
      final bump = v < 0.2 ? math.sin(v / 0.2 * math.pi) : 0.0;
      final sc = (0.2 + 0.8 * pop) * (1 + 0.14 * bump);
      out.add(_layer(badges[i].$2, badges[i].$1, s, sx: sc, sy: sc, opacity: f(a, a + 0.25)));
    }

    // JUA drops in letter by letter.
    for (var i = 0; i < 3; i++) {
      final a = 0.12 + i * 0.09;
      final drop = _seg(intro, a, a + 0.28, Curves.bounceOut);
      out.add(_layer('jua', _jua, s, dy: -(1 - drop) * 110, opacity: f(a, a + 0.28), clipper: _juaClips[i]));
    }

    // QUIZ slides up into place.
    final eq = e(0.10, 0.45);
    out.add(_layer('quiz', _quiz, s, dy: (1 - eq) * 60, opacity: f(0.10, 0.45)));

    // Bottom star pops, pulses, and flares on completion.
    final es = e(0.72, 0.92);
    final starPulse = 1 + math.sin(lr) * 0.06 + (b > 0 ? 0.5 * math.sin(math.min(b / 0.3, 1.0) * math.pi) : 0);
    out.add(_layer('star', _star, s,
        sx: (0.2 + 0.8 * es) * starPulse, sy: (0.2 + 0.8 * es) * starPulse, opacity: f(0.72, 0.92)));

    return out;
  }

  // ---- logo ---------------------------------------------------------------

  Widget _buildLogo(double size) {
    final s = size / _kCanvas;
    final intro = _intro.value;
    final loop = _loop.value;
    final b = _burst.value;
    final loopRad = loop * 2 * math.pi;
    final bp = (widget.progress == null && !widget.done) ? loop : _p;

    // Whole-logo idle motion.
    final bob = math.sin(loopRad) * 4.0;
    var scale = 1 + math.sin(loopRad + 0.6) * 0.012;
    final tilt = math.sin(loopRad) * 0.008;
    var opacity = 1.0;

    // Completion: pump up, then zoom through the camera.
    if (b > 0) {
      if (b < 0.35) {
        scale *= 1 + 0.12 * Curves.easeOut.transform(b / 0.35);
      } else {
        final z = Curves.easeInCubic.transform((b - 0.35) / 0.65);
        scale *= 1.12 + 1.6 * z;
        opacity = 1 - Curves.easeIn.transform(((b - 0.6) / 0.4).clamp(0.0, 1.0));
      }
    }

    // Shimmer band sweeps across during the first 60% of each loop.
    final sh = (loop / 0.6).clamp(0.0, 1.0);
    final center = -0.3 + 1.6 * sh;
    double st(double v) => v.clamp(0.0, 1.0);

    final crownFlash = (intro > 0.82 && intro < 1.0) ? math.sin((intro - 0.82) / 0.18 * math.pi) : 0.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _RingPainter(intro: intro, spin: loop, fade: 1 - b.clamp(0.0, 1.0))),
        ),
        Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (rect) => LinearGradient(
                    begin: const Alignment(-1, -0.5),
                    end: const Alignment(1, 0.5),
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: loop == 0 ? 0.0 : 0.36),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: [st(center - 0.14), st(center), st(center + 0.14)],
                  ).createShader(rect),
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: _layers(s, intro, loop, b, bp),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SparklePainter(
                loop: loop,
                visible: intro >= 1 ? 1 - b : 0,
                crownFlash: crownFlash,
              ),
            ),
          ),
        ),
        if (b > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _BurstPainter(t: b, particles: _particles)),
            ),
          ),
      ],
    );
  }

  Widget _buildProgress(double logoSize) {
    final barWidth = logoSize * 0.72;
    final fade = Curves.easeOut.transform(((_intro.value - 0.5) * 2).clamp(0.0, 1.0)) *
        (1 - _burst.value.clamp(0.0, 1.0));
    final determinate = widget.done || widget.progress != null;

    return Opacity(
      opacity: fade,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: barWidth,
            height: 16,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2E7A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD54A), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: determinate
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _p.clamp(0.0, 1.0),
                        heightFactor: 1,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFB300)]),
                          ),
                        ),
                      ),
                    )
                  : CustomPaint(size: Size.infinite, painter: _IndeterminatePainter(_loop.value)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _RingPainter extends CustomPainter {
  _RingPainter({required this.intro, required this.spin, required this.fade});
  final double intro;
  final double spin;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.width;

    // Rotating soft gold rays.
    final rayAlpha = 0.16 * Curves.easeOut.transform(intro.clamp(0.0, 1.0)) * fade;
    if (rayAlpha > 0) {
      final rayPaint = Paint()..color = const Color(0xFFFFD54A).withValues(alpha: rayAlpha);
      const rays = 14;
      final r = base * 0.82;
      for (var i = 0; i < rays; i++) {
        final a0 = spin * 2 * math.pi * 0.25 + i * 2 * math.pi / rays;
        final a1 = a0 + math.pi / rays * 0.9;
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + r * math.cos(a0), c.dy + r * math.sin(a0))
          ..lineTo(c.dx + r * math.cos(a1), c.dy + r * math.sin(a1))
          ..close();
        canvas.drawPath(path, rayPaint);
      }
    }

    // One-shot ripple ring during the entrance.
    if (intro < 0.5) {
      final k = intro / 0.5;
      final t = Curves.easeOutBack.transform(k);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * (1 - k) + 1
        ..color = const Color(0xFFFFD54A).withValues(alpha: (1 - k) * 0.9);
      canvas.drawCircle(c, base * (0.15 + 0.4 * t), ring);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.intro != intro || o.spin != spin || o.fade != fade;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.loop, required this.visible, required this.crownFlash});
  final double loop;
  final double visible;
  final double crownFlash;

  // (x, y, phase, size) as fractions of the logo box.
  static const _spots = [
    [0.10, 0.20, 0.00, 1.0],
    [0.90, 0.14, 0.18, 0.8],
    [0.04, 0.58, 0.36, 0.7],
    [0.96, 0.62, 0.54, 0.9],
    [0.30, 0.04, 0.72, 0.7],
    [0.72, 0.03, 0.90, 0.8],
    [0.50, 0.93, 0.45, 1.1],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Sparkle where the crown lands.
    if (crownFlash > 0.02) {
      _star(canvas, Offset(size.width * 0.527, size.height * 0.112), 26 * crownFlash, crownFlash);
    }
    if (visible <= 0) return;
    for (final s in _spots) {
      final v = math.sin((loop + s[2]) * 2 * math.pi);
      final k = v <= 0 ? 0.0 : v * v * v;
      if (k < 0.02) continue;
      _star(canvas, Offset(size.width * s[0], size.height * s[1]), 16 * s[3] * k,
          (k * visible).clamp(0.0, 1.0));
    }
  }

  void _star(Canvas canvas, Offset c, double r, double alpha) {
    final path = Path();
    const pts = 8;
    for (var i = 0; i < pts; i++) {
      final rad = i.isEven ? r : r * 0.22;
      final a = -math.pi / 2 + i * math.pi / 4;
      final p = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawCircle(c, r * 1.1, Paint()..color = Colors.white.withValues(alpha: alpha * 0.25));
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(_SparklePainter o) =>
      o.loop != loop || o.visible != visible || o.crownFlash != crownFlash;
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.round,
  });
  final double angle;
  final double distance;
  final double size;
  final Color color;
  final bool round;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.t, required this.particles});
  final double t;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    // Origin: the star at the bottom centre of the emblem.
    final origin = Offset(size.width * 0.5, size.height * 0.885);
    final e = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final alpha = (1 - t * t).clamp(0.0, 1.0);
    for (final p in particles) {
      final d = p.distance * size.width * e;
      final pos = Offset(
        origin.dx + math.cos(p.angle) * d,
        origin.dy + math.sin(p.angle) * d + 90 * t * t, // gravity
      );
      final paint = Paint()..color = p.color.withValues(alpha: alpha);
      if (p.round) {
        canvas.drawCircle(pos, p.size / 2, paint);
      } else {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(p.angle * 3 + t * 8);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), paint);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter o) => o.t != t;
}

class _IndeterminatePainter extends CustomPainter {
  _IndeterminatePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final segW = size.width * 0.35;
    final x = -segW + (size.width + segW) * Curves.easeInOut.transform(t);
    final rect = Rect.fromLTWH(x, 0, segW, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_IndeterminatePainter o) => o.t != t;
}
