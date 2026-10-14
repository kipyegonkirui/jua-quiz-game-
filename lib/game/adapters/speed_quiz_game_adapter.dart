import '../engine/game_session.dart';
import '../models/game_answer.dart';
import '../models/game_mode.dart';
import '../models/game_question.dart';
import '../models/speed_quiz_answer_result.dart';
import '../models/speed_quiz_state.dart';
import '../models/speed_quiz_result.dart';
import '../models/game_result.dart';
import '../mappers/game_result_mapper.dart';

class SpeedQuizGameAdapter {
  const SpeedQuizGameAdapter._();

  static const defaultSecondsPerQuestion = 10;
  static const totalQuestions = 10;

  static GameSession createSession({
    required String roundId,
    required List<GameQuestion> questions,
    required SpeedQuizState state,
    required List<GameAnswer> answers,
  }) {
    final currentIndex = state.isFinished
        ? (questions.isEmpty ? 0 : questions.length - 1)
        : (state.currentIndex.clamp(1, questions.length) as num).toInt() - 1;
    final startedAt = state.servedAt ?? DateTime.now();
    return GameSession(
      id: roundId,
      mode: GameMode.speedQuiz,
      questions: questions,
      answers: answers,
      currentIndex: currentIndex,
      status: state.isFinished
          ? GameSessionStatus.completed
          : GameSessionStatus.inProgress,
      startedAt: startedAt,
      questionStartedAt: startedAt,
    );
  }

  static GameResult toGameResult(SpeedQuizResult result) =>
      GameResultMapper.fromSpeedQuizResult(result);

  static GameAnswer toGameAnswer({
    required String questionId,
    required SpeedQuizAnswerResult result,
    required DateTime answeredAt,
  }) {
    return GameAnswer(
      questionId: questionId,
      chosenOption: result.chosen ?? '',
      isCorrect: result.isCorrect,
      correctOption: result.correctOption,
      answeredAt: answeredAt,
      timeTaken: Duration(milliseconds: result.elapsedMs),
      timedOut: result.timedOut,
    );
  }
}
