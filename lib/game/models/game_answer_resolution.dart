import 'game_answer.dart';

/// The result of one answer submission at the game-engine boundary.
///
/// Existing server-backed modes may return a temporary retry offer instead of
/// a settled answer. New local modes can always return a settled answer.
enum GameAnswerResolutionStatus {
  settled,
  retryOffered,
}

class GameAnswerResolution {
  final GameAnswerResolutionStatus status;
  final GameAnswer? answer;
  final String? firstChoice;
  final bool retryGranted;

  const GameAnswerResolution._({
    required this.status,
    this.answer,
    this.firstChoice,
    this.retryGranted = false,
  });

  const GameAnswerResolution.settled(GameAnswer answer)
      : this._(
          status: GameAnswerResolutionStatus.settled,
          answer: answer,
        );

  const GameAnswerResolution.retryOffered({
    required String firstChoice,
    required bool retryGranted,
  }) : this._(
          status: GameAnswerResolutionStatus.retryOffered,
          firstChoice: firstChoice,
          retryGranted: retryGranted,
        );

  bool get isSettled => status == GameAnswerResolutionStatus.settled;
  bool get isRetryOffered => status == GameAnswerResolutionStatus.retryOffered;
}
