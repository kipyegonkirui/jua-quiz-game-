import 'package:flutter/material.dart';

import '../services/app_events.dart';
import '../services/supabase_service.dart';
import '../widgets/daily_countdown.dart';
import '../widgets/jua_dialog.dart';
import '../widgets/progression_summary_card.dart';
import 'daily_challenge_screen.dart';
import '../models/mode_journey.dart';
import 'practice_journey_screen.dart';

class GameHubScreen extends StatefulWidget {
  const GameHubScreen({super.key});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

enum _GameCardKind {
  daily,
  practice,
  speedQuiz,
  guessIt,
  oddOneOut,
  findDifference,
  football,
  world,
  compete,
}

class _GameCardData {
  final _GameCardKind kind;
  final String title;
  final String art; // assets/hub/cards/<art>.webp
  final bool available;
  final Rect pillRect; // where the live info pill sits (fractions of the card)
  final Color pillColor;
  final Color buttonTop;
  final Color buttonBottom;

  const _GameCardData({
    required this.kind,
    required this.title,
    required this.art,
    required this.pillRect,
    required this.pillColor,
    required this.buttonTop,
    required this.buttonBottom,
    this.available = true,
  });
}

// Play button area on every card art (fractions of the card).
const _buttonRect = Rect.fromLTRB(0.135, 0.832, 0.872, 0.974);

const _gameCards = <_GameCardData>[
  _GameCardData(
    kind: _GameCardKind.daily,
    title: 'Daily Challenge',
    art: 'daily',
    pillRect: Rect.fromLTRB(0.307, 0.206, 0.764, 0.286),
    pillColor: Color(0xFF7F1E00),
    buttonTop: Color(0xFFFDB50B),
    buttonBottom: Color(0xFFE77501),
  ),
  _GameCardData(
    kind: _GameCardKind.practice,
    title: 'Practice',
    art: 'practice',
    pillRect: Rect.fromLTRB(0.328, 0.152, 0.761, 0.238),
    pillColor: Color(0xFF013C27),
    buttonTop: Color(0xFF49E941),
    buttonBottom: Color(0xFF01A939),
  ),
  _GameCardData(
    kind: _GameCardKind.speedQuiz,
    title: 'Speed Quiz',
    art: 'speed',
    pillRect: Rect.fromLTRB(0.349, 0.147, 0.669, 0.242),
    pillColor: Color(0xFF01209E),
    buttonTop: Color(0xFF0BB2FC),
    buttonBottom: Color(0xFF006CFA),
  ),
  _GameCardData(
    kind: _GameCardKind.guessIt,
    title: 'Guess It',
    art: 'guess',
    pillRect: Rect.fromLTRB(0.316, 0.147, 0.728, 0.229),
    pillColor: Color(0xFF013B51),
    buttonTop: Color(0xFF01CFC9),
    buttonBottom: Color(0xFF019EA3),
  ),
  _GameCardData(
    kind: _GameCardKind.oddOneOut,
    title: 'Odd One Out',
    art: 'odd',
    pillRect: Rect.fromLTRB(0.328, 0.147, 0.728, 0.229),
    pillColor: Color(0xFF860235),
    buttonTop: Color(0xFFFC4D8F),
    buttonBottom: Color(0xFFF90570),
  ),
  _GameCardData(
    kind: _GameCardKind.findDifference,
    title: 'Find the Difference',
    art: 'difference',
    pillRect: Rect.fromLTRB(0.343, 0.195, 0.737, 0.277),
    pillColor: Color(0xFF013292),
    buttonTop: Color(0xFF04B4FD),
    buttonBottom: Color(0xFF007BFD),
    available: false,
  ),
  _GameCardData(
    kind: _GameCardKind.football,
    title: 'Football Challenge',
    art: 'football',
    pillRect: Rect.fromLTRB(0.337, 0.210, 0.764, 0.292),
    pillColor: Color(0xFF024A2C),
    buttonTop: Color(0xFF62E62A),
    buttonBottom: Color(0xFF05B416),
    available: false,
  ),
  _GameCardData(
    kind: _GameCardKind.world,
    title: 'World Challenge',
    art: 'world',
    pillRect: Rect.fromLTRB(0.343, 0.208, 0.743, 0.290),
    pillColor: Color(0xFF013793),
    buttonTop: Color(0xFF07B9FD),
    buttonBottom: Color(0xFF007AFD),
    available: false,
  ),
  _GameCardData(
    kind: _GameCardKind.compete,
    title: 'Competitions',
    art: 'compete',
    pillRect: Rect.fromLTRB(0.349, 0.152, 0.900, 0.247),
    pillColor: Color(0xFF2E0276),
    buttonTop: Color(0xFFB06CFF),
    buttonBottom: Color(0xFF7A2BE0),
  ),
];

class _GameHubScreenState extends State<GameHubScreen> {
  late final PageController _pageController;
  double _page = 0;
  int? _practiceLevel;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.64);
    _pageController.addListener(_handlePageChanged);
    AppEvents.profile.addListener(_onLiveDataChanged);
    AppEvents.dataVersion.addListener(_onProgressChanged);
    _loadPracticeLevel();
  }

  void _onLiveDataChanged() {
    if (mounted) setState(() {});
  }

  void _onProgressChanged() {
    _loadPracticeLevel();
  }

  Future<void> _loadPracticeLevel() async {
    try {
      final journey = await SupabaseService.instance.getPracticeJourney(throughLevel: 10);
      if (!mounted) return;
      setState(() => _practiceLevel = journey.currentLevel);
    } catch (_) {
      // Keep the generic label if the journey can't be read right now.
    }
  }

  String _pillText(_GameCardKind kind) {
    switch (kind) {
      case _GameCardKind.daily:
        final streak = AppEvents.profile.value?.currentStreak ?? 0;
        return streak > 0 ? '🔥 $streak Day Streak' : '🔥 Start your streak';
      case _GameCardKind.practice:
        final level = _practiceLevel;
        return level == null ? '⭐ Endless levels' : '⭐ Level $level';
      case _GameCardKind.speedQuiz:
        return '⏱ 10s each';
      case _GameCardKind.guessIt:
        return '🖼 5 pictures';
      case _GameCardKind.compete:
        return '🏆 Live now';
      case _GameCardKind.oddOneOut:
        return '🔎 New set daily';
      case _GameCardKind.findDifference:
      case _GameCardKind.football:
      case _GameCardKind.world:
        return '✨ Coming soon';
    }
  }

  void _handlePageChanged() {
    final value = _pageController.page;
    if (value == null || !mounted) return;
    setState(() => _page = value);
  }

  @override
  void dispose() {
    AppEvents.profile.removeListener(_onLiveDataChanged);
    AppEvents.dataVersion.removeListener(_onProgressChanged);
    _pageController
      ..removeListener(_handlePageChanged)
      ..dispose();
    super.dispose();
  }

  void _openCard(_GameCardData card) {
    if (!card.available) {
      _showComingSoon(card.title);
      return;
    }

    switch (card.kind) {
      case _GameCardKind.daily:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyChallengeScreen()));
        return;
      case _GameCardKind.practice:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PracticeJourneyScreen()));
        return;
      case _GameCardKind.speedQuiz:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PracticeJourneyScreen(mode: JourneyMode.speedQuiz)));
        return;
      case _GameCardKind.compete:
        AppEvents.goToTab(AppTabs.compete);
        return;
      case _GameCardKind.guessIt:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PracticeJourneyScreen(mode: JourneyMode.guessIt)));
        return;
      case _GameCardKind.oddOneOut:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PracticeJourneyScreen(mode: JourneyMode.oddOneOut)));
        return;
      case _GameCardKind.findDifference:
      case _GameCardKind.football:
      case _GameCardKind.world:
        _showComingSoon(card.title);
        return;
    }
  }

  void _showComingSoon(String title) {
    showJuaMessage(
      context,
      title: title,
      message: 'This game is coming soon. Swipe to choose another mode.',
      art: JuaDialogArt.bulb,
      tone: JuaDialogTone.green,
      buttonLabel: 'Back to games',
      buttonStyle: JuaDialogButtonStyle.green,
      buttonIcon: Icons.swipe_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('JUA QUIZ'),
        actions: [
          ValueListenableBuilder(
            valueListenable: AppEvents.profile,
            builder: (context, profile, _) {
              final xp = profile?.xp ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$xp XP',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const ProgressionSummaryCard(compact: true),
            const SizedBox(height: 2),
            const Text(
              'WHAT DO YOU WANT TO PLAY?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                shadows: juaSceneShadows,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                padEnds: true,
                physics: const BouncingScrollPhysics(),
                itemCount: _gameCards.length,
                itemBuilder: (context, index) {
                  final card = _gameCards[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    child: _GameCard(
                      data: card,
                      pillText: _pillText(card.kind),
                      onPlay: () => _openCard(card),
                      dailyDone: card.kind == _GameCardKind.daily &&
                          (AppEvents.profile.value?.completedToday ?? false),
                      onCountdownElapsed: () {
                        if (mounted) setState(() {});
                      },
                    ),
                    builder: (context, child) {
                      // The centred card is zoomed in; its neighbours shrink,
                      // dim and drop slightly so they read as "next" cards.
                      final distance = (_page - index).abs().clamp(0.0, 1.0);
                      final scale = 1.10 - (distance * 0.26);
                      final opacity = 1 - (distance * 0.30);
                      final offsetY = distance * 10;
                      return Transform.translate(
                        offset: Offset(0, offsetY),
                        child: Transform.scale(
                          scale: scale,
                          child: Opacity(opacity: opacity, child: child),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            _PageIndicator(count: _gameCards.length, page: _page),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  // Aspect ratio of the card artwork (assets/hub/cards/*.webp).
  static const double _aspect = 333 / 458;

  final _GameCardData data;
  final String pillText;
  final VoidCallback onPlay;

  /// Daily Challenge finished today: the pill becomes a live countdown to the
  /// next one and the button reads "Done today".
  final bool dailyDone;
  final VoidCallback? onCountdownElapsed;

  const _GameCard({
    required this.data,
    required this.pillText,
    required this.onPlay,
    this.dailyDone = false,
    this.onCountdownElapsed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !data.available;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Leave headroom so the centred card can zoom to 1.10x without clipping.
        final maxW = constraints.maxWidth - 4;
        final maxH = (constraints.maxHeight - 12) / 1.10;
        var w = maxW;
        var h = w / _aspect;
        if (h > maxH) {
          h = maxH;
          w = h * _aspect;
        }
        final k = w / 333; // scale for text, borders and radii
        final pill = data.pillRect;
        final btn = _buttonRect;

        return Center(
          child: Semantics(
            button: true,
            label: disabled
                ? '${data.title}, coming soon'
                : (dailyDone ? '${data.title}, done today, next one unlocks at midnight' : '${data.title}, play'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPlay,
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30 * k),
                          boxShadow: const [
                            BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 10)),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Image.asset(
                        'assets/hub/cards/${data.art}.webp',
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.high,
                        gaplessPlayback: true,
                      ),
                    ),
                    Positioned(
                      left: pill.left * w,
                      top: pill.top * h,
                      width: pill.width * w,
                      height: pill.height * h,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: data.pillColor.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.28), width: 1.2 * k),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10 * k),
                            child: dailyDone
                                ? DailyCountdownText(
                                    prefix: '⏳ ',
                                    onElapsed: onCountdownElapsed,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15 * k,
                                    ),
                                  )
                                : Text(
                                    pillText,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15 * k,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: btn.left * w,
                      top: btn.top * h,
                      width: btn.width * w,
                      height: btn.height * h,
                      child: _CardPlayButton(
                        top: disabled
                            ? const Color(0xFFAAB8CF)
                            : (dailyDone ? const Color(0xFF7FD68A) : data.buttonTop),
                        bottom: disabled
                            ? const Color(0xFF6B7FA0)
                            : (dailyDone ? const Color(0xFF2E9E4F) : data.buttonBottom),
                        label: disabled ? 'Coming soon' : (dailyDone ? 'Done today' : 'Play'),
                        icon: disabled
                            ? Icons.lock_rounded
                            : (dailyDone ? Icons.check_circle_rounded : Icons.arrow_forward_rounded),
                        scale: k,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardPlayButton extends StatelessWidget {
  final Color top;
  final Color bottom;
  final String label;
  final IconData icon;
  final double scale;

  const _CardPlayButton({
    required this.top,
    required this.bottom,
    required this.label,
    required this.icon,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 2 * k),
        boxShadow: [
          BoxShadow(color: bottom.withOpacity(0.55), blurRadius: 8 * k, offset: Offset(0, 4 * k)),
        ],
      ),
      child: Stack(
        children: [
          // Glossy highlight on the upper half.
          Positioned(
            left: 10 * k,
            right: 10 * k,
            top: 3 * k,
            height: 16 * k,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.42), Colors.white.withOpacity(0.0)],
                ),
              ),
            ),
          ),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28 * k,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: const Color(0x66000000), blurRadius: 3 * k, offset: Offset(0, 2 * k))],
                    ),
                  ),
                  SizedBox(width: 8 * k),
                  Icon(icon, color: Colors.white, size: 28 * k),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final int count;
  final double page;

  const _PageIndicator({required this.count, required this.page});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final distance = (page - index).abs();
        final active = distance < 0.45;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}
