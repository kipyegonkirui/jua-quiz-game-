import 'package:flutter/material.dart';

import '../models/mode_journey.dart';
import '../models/practice_journey.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'game_feel.dart';
import 'share_button.dart';
import 'jua_buttons.dart';

/// Friendly text for the errors the level RPCs raise (021_mode_journeys.sql).
String modeLevelErrorText(Object error) {
  final value = error.toString().toLowerCase();
  if (value.contains('no_practice_lives')) {
    return 'No lives left. A new life is ready every 5 minutes.';
  }
  if (value.contains('previous_level_required')) {
    return 'Finish the previous level with at least 1 star first.';
  }
  if (value.contains('practice_batch_locked')) {
    return 'This batch is still locked. Earn more stars or unlock it from the map.';
  }
  if (value.contains('not authenticated')) {
    return 'Your session has expired. Please sign in again.';
  }
  return 'Could not start this level. Please try again.';
}

String _starText(int stars) =>
    '${List.filled(stars.clamp(0, 3), '⭐').join()}${List.filled(3 - stars.clamp(0, 3), '☆').join()}';

/// Stars, life outcome and next-step buttons shown at the end of a journey
/// level. It settles the round on the server (stars are computed there).
class ModeLevelSummary extends StatefulWidget {
  final JourneyMode mode;
  final String roundId;
  final int level;

  /// Starts this level again (costs a life if the last attempt failed).
  final VoidCallback onRetry;

  /// Opens another level of the same mode (replaces the current screen).
  final void Function(int level) onOpenLevel;

  /// True on dark / coloured backgrounds, so text buttons render in white.
  final bool onDark;

  const ModeLevelSummary({
    super.key,
    required this.mode,
    required this.roundId,
    required this.level,
    required this.onRetry,
    required this.onOpenLevel,
    this.onDark = false,
  });

  @override
  State<ModeLevelSummary> createState() => _ModeLevelSummaryState();
}

class _Settled {
  final ModeLevelResult result;
  final PracticeJourneyData? journey;
  const _Settled(this.result, this.journey);
}

class _ModeLevelSummaryState extends State<ModeLevelSummary> {
  late Future<_Settled> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Settled> _load() async {
    final service = SupabaseService.instance;
    final result = await service.completeModeLevel(widget.roundId);
    PracticeJourneyData? journey;
    if (result.stars >= 1) {
      try {
        journey = await service.getModeJourney(widget.mode, throughLevel: widget.level + 1);
      } catch (_) {
        // The next-level button simply falls back to "Back to journey".
      }
    }
    return _Settled(result, journey);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Settled>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Column(
            children: [
              const Text(
                'Could not save your stars. Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              JuaGlossyButton(
                onPressed: _reload,
                label: 'Try again',
                icon: Icons.refresh_rounded,
                variant: JuaButtonVariant.action,
              ),
            ],
          );
        }
        return _content(context, snapshot.data!);
      },
    );
  }

  Widget _content(BuildContext context, _Settled settled) {
    final r = settled.result;
    final passed = r.stars >= 1;
    final next = widget.level + 1;
    final linkStyle = widget.onDark ? TextButton.styleFrom(foregroundColor: Colors.white) : null;
    final matching = settled.journey?.levels.where((l) => l.level == next).toList() ?? const [];
    final nextUnlocked = matching.isNotEmpty && matching.first.unlocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AnimatedStars(stars: r.stars),
                const SizedBox(height: 4),
                Text(
                  passed ? 'Level ${widget.level} complete' : 'Level ${widget.level} failed',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  'Best: ${_starText(r.bestStars)}  •  ${r.cumulativeStars} total ⭐',
                  style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  passed
                      ? (r.stars < 3
                          ? '❤️ Life returned. Get every answer right for 3 ⭐.'
                          : '❤️ Life returned. Perfect level!')
                      : '💔 Life busted. It recharges in 5 minutes. Earn at least 1 ⭐ to progress.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: passed ? AppColors.savannaGreen : Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (passed && nextUnlocked) ...[
          JuaGlossyButton(
            onPressed: () => widget.onOpenLevel(next),
            label: 'NEXT LEVEL',
            icon: Icons.arrow_forward_rounded,
            variant: JuaButtonVariant.action,
          ),
          const SizedBox(height: 6),
          TextButton(style: linkStyle, onPressed: widget.onRetry, child: const Text('Replay this level')),
        ] else ...[
          if (passed)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'The next batch needs more stars. Replay levels to earn them, or unlock it from the map.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          JuaGlossyButton(
            onPressed: widget.onRetry,
            label: passed ? 'REPLAY LEVEL' : 'RETRY LEVEL',
            icon: Icons.refresh_rounded,
            variant: JuaButtonVariant.action,
          ),
        ],
        WhatsAppShareButton(
          onDark: widget.onDark,
          text: 'I just got ${r.stars}⭐ on ${widget.mode.title} level ${widget.level} in Jua Quiz! Can you beat me? 🇰🇪',
        ),
        TextButton(
          style: linkStyle,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to journey'),
        ),
      ],
    );
  }
}
