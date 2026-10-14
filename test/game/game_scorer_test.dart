import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/models/game_answer.dart';
import 'package:jua_quiz/game/models/game_mode.dart';
import 'package:jua_quiz/game/models/game_question.dart';
import 'package:jua_quiz/game/scoring/game_scorer.dart';

GameAnswer _answer({bool correct = true, Duration? timeTaken}) => GameAnswer(
      questionId: 'q1',
      chosenOption: 'a',
      isCorrect: correct,
      correctOption: correct ? 'a' : 'b',
      answeredAt: DateTime(2026, 1, 1),
      timeTaken: timeTaken,
    );

void main() {
  const scorer = GameScorer(
    basePoints: 100,
    maxSpeedBonus: 50,
    modeBonuses: {GameMode.speedQuiz: 25},
  );

  test('wrong answers score zero', () {
    final result = scorer.score(
      question: const GameQuestion(id: 'q1', text: 'Q'),
      answer: _answer(correct: false, timeTaken: const Duration(seconds: 1)),
      mode: GameMode.speedQuiz,
    );

    expect(result.total, 0);
  });

  test('correct answers include speed, difficulty and mode bonuses', () {
    final result = scorer.score(
      question: const GameQuestion(
        id: 'q1',
        text: 'Q',
        difficulty: 'hard',
        timeLimit: Duration(seconds: 10),
      ),
      answer: _answer(timeTaken: const Duration(seconds: 2)),
      mode: GameMode.speedQuiz,
    );

    expect(result.basePoints, 100);
    expect(result.speedBonus, 40);
    expect(result.difficultyBonus, 35);
    expect(result.modeBonus, 25);
    expect(result.total, 200);
  });

  test('no time limit means no speed bonus', () {
    final result = scorer.score(
      question: const GameQuestion(id: 'q1', text: 'Q', difficulty: 'expert'),
      answer: _answer(timeTaken: const Duration(seconds: 1)),
      mode: GameMode.practice,
    );

    expect(result.speedBonus, 0);
    expect(result.total, 160);
  });
}
