import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/engine/game_session.dart';
import 'package:jua_quiz/game/models/game_answer.dart';
import 'package:jua_quiz/game/models/game_mode.dart';
import 'package:jua_quiz/game/models/game_question.dart';
import 'package:jua_quiz/game/models/game_result.dart';

void main() {
  final questions = [
    const GameQuestion(id: 'q1', text: 'One?', options: {'a': 'A', 'b': 'B'}),
    const GameQuestion(id: 'q2', text: 'Two?', options: {'a': 'A', 'b': 'B'}),
  ];

  test('starts on the first question', () {
    final now = DateTime(2026, 1, 1, 12);
    final session = GameSession(
      id: 'practice-1',
      mode: GameMode.practice,
      questions: questions,
      startedAt: now,
      questionStartedAt: now,
    ).start(now: now);

    expect(session.status, GameSessionStatus.inProgress);
    expect(session.currentIndex, 0);
    expect(session.currentQuestion?.id, 'q1');
  });

  test('records an answer and advances to the next question', () {
    final now = DateTime(2026, 1, 1, 12);
    final answerTime = now.add(const Duration(seconds: 3));
    final answer = GameAnswer(
      questionId: 'q1',
      chosenOption: 'a',
      isCorrect: true,
      correctOption: 'a',
      answeredAt: answerTime,
      timeTaken: answerTime.difference(now),
    );

    final session = GameSession(
      id: 'practice-1',
      mode: GameMode.practice,
      questions: questions,
      startedAt: now,
      questionStartedAt: now,
    ).start(now: now).selectOption('a').recordAnswer(answer);

    expect(session.status, GameSessionStatus.answerPending);
    expect(session.answeredCount, 1);
    expect(session.correctCount, 1);
    expect(session.selectedOption, isNull);

    final next = session.advance(now: answerTime);
    expect(next.status, GameSessionStatus.inProgress);
    expect(next.currentIndex, 1);
    expect(next.currentQuestion?.id, 'q2');
  });

  test('finishes after the final answer', () {
    final now = DateTime(2026, 1, 1, 12);
    final session = GameSession(
      id: 'daily-1',
      mode: GameMode.dailyChallenge,
      questions: questions,
      startedAt: now,
      questionStartedAt: now,
    ).start(now: now);

    final first = session.recordAnswer(
      GameAnswer(
        questionId: 'q1',
        chosenOption: 'b',
        isCorrect: false,
        correctOption: 'a',
        answeredAt: now,
      ),
    );
    final second = first.advance(now: now).recordAnswer(
          GameAnswer(
            questionId: 'q2',
            chosenOption: 'a',
            isCorrect: true,
            correctOption: 'a',
            answeredAt: now,
          ),
        );
    final completed = second.advance(now: now);

    expect(completed.isComplete, isTrue);
    expect(completed.answeredCount, 2);
    expect(completed.correctCount, 1);
  });

  test('calculates accuracy safely', () {
    const result = GameResult(
      mode: GameMode.practice,
      score: 3,
      total: 5,
    );

    expect(result.accuracy, closeTo(0.6, 0.0001));

    const empty = GameResult(mode: GameMode.practice, score: 0, total: 0);
    expect(empty.accuracy, 0);
  });
}
