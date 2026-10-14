import '../../models/answer_result.dart';
import '../models/game_answer.dart';

/// Shared translation from the existing server answer contract into the
/// backend-agnostic game contract.
class GameAnswerMapper {
  const GameAnswerMapper._();

  /// Returns null while a second-chance offer is still pending because there
  /// is not yet a settled answer to record in the game session.
  static GameAnswer? fromAnswerResult({
    required String questionId,
    required AnswerResult result,
    required DateTime answeredAt,
    Duration? timeTaken,
  }) {
    if (!result.isFinal) return null;

    return GameAnswer(
      questionId: questionId,
      chosenOption: result.chosen,
      isCorrect: result.isCorrect,
      correctOption: result.correctOption,
      answeredAt: answeredAt,
      timeTaken: timeTaken,
      firstChoice: result.firstChoice,
      secondChanceUsed: result.secondChanceUsed,
    );
  }
}
