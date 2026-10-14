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

/// Translates the existing server-backed Daily Challenge flow into the shared
/// game contracts. Supabase remains authoritative for answer validation,
/// scoring, streaks, hints, second chances, and submission.
class DailyGameAdapter {
  const DailyGameAdapter._();

  static GameQuestion toGameQuestion(Question question) {
    return GameQuestion(
      id: question.id,
      text: question.text,
      options: Map<String, String>.unmodifiable(question.options),
      position: question.position,
      type: 'multiple_choice',
    );
  }

  static List<GameQuestion> toGameQuestions(List<Question> questions) {
    return questions.map(toGameQuestion).toList(growable: false);
  }

  /// Reconstructs a Daily Challenge session from server-side final answers.
  /// Pending second-chance offers are intentionally left outside the generic
  /// answer history until the server settles the question.
  static GameSession createSession({
    required String challengeId,
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
      id: challengeId,
      mode: GameMode.dailyChallenge,
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
        mode: GameMode.dailyChallenge,
        result: result,
      );
}
