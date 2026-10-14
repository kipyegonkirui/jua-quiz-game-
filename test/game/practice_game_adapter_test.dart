import 'package:flutter_test/flutter_test.dart';

import 'package:jua_quiz/game/adapters/practice_game_adapter.dart';
import 'package:jua_quiz/game/engine/game_session.dart';
import 'package:jua_quiz/game/models/game_mode.dart';
import 'package:jua_quiz/models/answer_result.dart';
import 'package:jua_quiz/models/attempt_result.dart';
import 'package:jua_quiz/models/question.dart';

Question _question(String id, {int position = 0}) {
  return Question(
    id: id,
    text: 'Question $id',
    position: position,
    options: const {
      'a': 'Option A',
      'b': 'Option B',
      'c': 'Option C',
      'd': 'Option D',
    },
  );
}

void main() {
  group('PracticeGameAdapter', () {
    test('maps an existing Question into GameQuestion', () {
      final gameQuestion = PracticeGameAdapter.toGameQuestion(_question('q1'));

      expect(gameQuestion.id, 'q1');
      expect(gameQuestion.text, 'Question q1');
      expect(gameQuestion.options['a'], 'Option A');
      expect(gameQuestion.type, 'multiple_choice');
    });

    test('does not record a pending second-chance answer', () {
      const pending = AnswerResult(
        chosen: 'a',
        isCorrect: false,
        status: 'retry_offered',
        firstChoice: 'a',
        retryGranted: true,
      );

      final answer = PracticeGameAdapter.toGameAnswer(
        questionId: 'q1',
        result: pending,
        answeredAt: DateTime(2026, 1, 1),
      );

      expect(answer, isNull);
    });

    test('maps a settled answer including second-chance metadata', () {
      const settled = AnswerResult(
        chosen: 'c',
        isCorrect: true,
        correctOption: 'c',
        firstChoice: 'a',
        secondChanceUsed: true,
      );

      final answer = PracticeGameAdapter.toGameAnswer(
        questionId: 'q1',
        result: settled,
        answeredAt: DateTime(2026, 1, 1),
        timeTaken: const Duration(seconds: 4),
      );

      expect(answer, isNotNull);
      expect(answer!.questionId, 'q1');
      expect(answer.chosenOption, 'c');
      expect(answer.isCorrect, isTrue);
      expect(answer.correctOption, 'c');
      expect(answer.firstChoice, 'a');
      expect(answer.secondChanceUsed, isTrue);
      expect(answer.timeTaken, const Duration(seconds: 4));
    });

    test('reconstructs a Practice session from persisted final answers', () {
      final questions = [_question('q1'), _question('q2', position: 1)];
      final progress = {
        'q1': const AnswerResult(
          chosen: 'b',
          isCorrect: true,
          correctOption: 'b',
        ),
        'q2': const AnswerResult(
          chosen: 'a',
          isCorrect: false,
          correctOption: 'd',
        ),
      };
      final now = DateTime(2026, 1, 1, 12);

      final session = PracticeGameAdapter.createSession(
        roundId: 'round-1',
        questions: questions,
        progress: progress,
        currentIndex: 1,
        now: now,
      );

      expect(session.id, 'round-1');
      expect(session.mode, GameMode.practice);
      expect(session.status, GameSessionStatus.inProgress);
      expect(session.questions, hasLength(2));
      expect(session.answers, hasLength(2));
      expect(session.correctCount, 1);
      expect(session.currentIndex, 1);
      expect(session.currentQuestion!.id, 'q2');
    });

    test('maps Practice result into a generic GameResult', () {
      final attempt = AttemptResult(
        score: 4,
        total: 5,
        xpEarned: 80,
        newXp: 180,
        newLevel: 2,
        leveledUp: false,
        currentStreak: 0,
        longestStreak: 4,
      );

      final result = PracticeGameAdapter.toGameResult(attempt);

      expect(result.mode, GameMode.practice);
      expect(result.score, 4);
      expect(result.total, 5);
      expect(result.accuracy, 0.8);
      expect(result.xpEarned, 80);
      expect(result.newLevel, 2);
    });
  });
}
