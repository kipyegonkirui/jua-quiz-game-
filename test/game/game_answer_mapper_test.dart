import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/mappers/game_answer_mapper.dart';
import 'package:jua_quiz/models/answer_result.dart';

void main() {
  test('pending retry is not mapped to a settled game answer', () {
    const result = AnswerResult(
      chosen: 'a',
      isCorrect: false,
      status: 'retry_offered',
      firstChoice: 'a',
      retryGranted: true,
    );

    expect(
      GameAnswerMapper.fromAnswerResult(
        questionId: 'q1',
        result: result,
        answeredAt: DateTime(2026, 1, 1),
      ),
      isNull,
    );
  });

  test('settled result maps consistently', () {
    const result = AnswerResult(
      chosen: 'c',
      isCorrect: true,
      correctOption: 'c',
      firstChoice: 'a',
      secondChanceUsed: true,
    );

    final answer = GameAnswerMapper.fromAnswerResult(
      questionId: 'q1',
      result: result,
      answeredAt: DateTime(2026, 1, 1),
      timeTaken: const Duration(seconds: 3),
    );

    expect(answer, isNotNull);
    expect(answer!.chosenOption, 'c');
    expect(answer.firstChoice, 'a');
    expect(answer.secondChanceUsed, isTrue);
    expect(answer.timeTaken, const Duration(seconds: 3));
  });
}
