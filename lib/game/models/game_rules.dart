import 'game_mode.dart';

/// Immutable rules that describe how a game mode should behave.
///
/// The rules are intentionally separate from [GameSession] state and from
/// Supabase. A future mode can provide its own rules without creating another
/// gameplay engine.
class GameRules {
  final GameMode mode;
  final Duration? timeLimitPerQuestion;
  final bool localScoring;
  final bool allowsRetry;
  final bool allowsHints;
  final bool autoAdvance;

  const GameRules({
    required this.mode,
    this.timeLimitPerQuestion,
    this.localScoring = false,
    this.allowsRetry = false,
    this.allowsHints = false,
    this.autoAdvance = false,
  });

  GameRules copyWith({
    GameMode? mode,
    Duration? timeLimitPerQuestion,
    bool clearTimeLimit = false,
    bool? localScoring,
    bool? allowsRetry,
    bool? allowsHints,
    bool? autoAdvance,
  }) {
    return GameRules(
      mode: mode ?? this.mode,
      timeLimitPerQuestion: clearTimeLimit
          ? null
          : (timeLimitPerQuestion ?? this.timeLimitPerQuestion),
      localScoring: localScoring ?? this.localScoring,
      allowsRetry: allowsRetry ?? this.allowsRetry,
      allowsHints: allowsHints ?? this.allowsHints,
      autoAdvance: autoAdvance ?? this.autoAdvance,
    );
  }
}
