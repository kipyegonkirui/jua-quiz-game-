import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/adapters/speed_quiz_game_adapter.dart';
import 'package:jua_quiz/game/models/game_answer.dart';
import 'package:jua_quiz/game/models/game_mode.dart';
import 'package:jua_quiz/game/models/speed_quiz_answer_result.dart';
import 'package:jua_quiz/game/models/speed_quiz_state.dart';
import 'package:jua_quiz/game/models/game_question.dart';

void main() {
  test('builds a speed quiz session from server state', () {
    final questions = List.generate(
      10,
      (i) => GameQuestion(
        id: 'q$i',
        text: 'Question $i',
        options: const {'a': 'A', 'b': 'B', 'c': 'C', 'd': 'D'},
        timeLimit: const Duration(seconds: 10),
      ),
    );
    final servedAt = DateTime.utc(2026, 1, 1, 12);
    final state = SpeedQuizState(
      status: 'playing',
      currentIndex: 3,
      score: 260,
      correctCount: 2,
      answeredCount: 2,
      totalQuestions: 10,
      secondsPerQuestion: 10,
      servedAt: servedAt,
    );
    final answers = [
      GameAnswer(
        questionId: 'q0',
        chosenOption: 'a',
        isCorrect: true,
        answeredAt: servedAt,
      ),
      GameAnswer(
        questionId: 'q1',
        chosenOption: '',
        isCorrect: false,
        answeredAt: servedAt,
        timedOut: true,
      ),
    ];

    final session = SpeedQuizGameAdapter.createSession(
      roundId: 'round-1',
      questions: questions,
      state: state,
      answers: answers,
    );

    expect(session.mode, GameMode.speedQuiz);
    expect(session.currentIndex, 2);
    expect(session.answeredCount, 2);
    expect(session.status.toString(), contains('inProgress'));
    expect(session.questionStartedAt, servedAt);
  });

  test('maps timeout answer without inventing a selected option', () {
    final result = SpeedQuizAnswerResult(
      isCorrect: false,
      timedOut: true,
      chosen: null,
      correctOption: 'c',
      points: 0,
      score: 120,
      correctCount: 1,
      answeredCount: 2,
      totalQuestions: 10,
      elapsedMs: 10042,
      finished: false,
    );
    final answer = SpeedQuizGameAdapter.toGameAnswer(
      questionId: 'q2',
      result: result,
      answeredAt: DateTime.utc(2026, 1, 1, 12),
    );

    expect(answer.timedOut, isTrue);
    expect(answer.chosenOption, isEmpty);
    expect(answer.isCorrect, isFalse);
    expect(answer.timeTaken, const Duration(milliseconds: 10042));
  });
}
