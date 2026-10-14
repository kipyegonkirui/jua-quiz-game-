import '../../models/answer_result.dart';
import '../mappers/game_answer_mapper.dart';
import '../../models/attempt_result.dart';
import '../../models/question.dart';
import '../engine/game_session.dart';
import '../models/game_answer.dart';
import '../models/game_mode.dart';
import '../models/game_question.dart';
import '../models/game_result.dart';
import '../mappers/game_result_mapper.dart';

/// Translates the existing server-backed Practice flow into the generic game
/// contracts. The Supabase service remains responsible for authoritative
/// scoring and answer validation; this adapter only maps data and state.
class PracticeGameAdapter {
  const PracticeGameAdapter._();

  static GameQuestion toGameQuestion(Question question) {
    return GameQuestion(
      id: question.id,
      text: question.text,
      options: Map<String, String>.unmodifiable(question.options),
      position: question.position,
      type: 'multiple_choice',
      difficulty: question.difficulty,
    );
  }

  static List<GameQuestion> toGameQuestions(List<Question> questions) {
    return questions.map(toGameQuestion).toList(growable: false);
  }

  /// Builds a session from a Practice round and any answers already persisted
  /// by Supabase. Pending second-chance offers are intentionally excluded from
  /// [answers] because they are not settled results yet.
  static GameSession createSession({
    required String roundId,
    required List<Question> questions,
    required Map<String, AnswerResult> progress,
    required int currentIndex,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final answers = <GameAnswer>[];

    for (final question in questions) {
      final result = progress[question.id];
      if (result == null || !result.isFinal) continue;

      final gameAnswer = toGameAnswer(
        questionId: question.id,
        result: result,
        answeredAt: timestamp,
      );
      if (gameAnswer != null) answers.add(gameAnswer);
    }

    final session = GameSession(
      id: roundId,
      mode: GameMode.practice,
      questions: toGameQuestions(questions),
      answers: answers,
      startedAt: timestamp,
      questionStartedAt: timestamp,
    ).start(now: timestamp);

    return session.copyWith(
      currentIndex: currentIndex,
      questionStartedAt: timestamp,
    );
  }

  /// Converts only a settled server answer into a generic game answer.
  /// `retry_offered` is deliberately ignored until the question is settled.
  static GameAnswer? toGameAnswer({
    required String questionId,
    required AnswerResult result,
    required DateTime answeredAt,
    Duration? timeTaken,
  }) {
    return GameAnswerMapper.fromAnswerResult(
      questionId: questionId,
      result: result,
      answeredAt: answeredAt,
      timeTaken: timeTaken,
    );
  }

  static GameResult toGameResult(AttemptResult result) => GameResultMapper.fromAttemptResult(
        mode: GameMode.practice,
        result: result,
      );
}
