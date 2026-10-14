import 'package:flutter_test/flutter_test.dart';

import 'package:jua_quiz/game/adapters/daily_game_adapter.dart';
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
  group('DailyGameAdapter', () {
    test('maps a Question into the shared game question', () {
      final question = DailyGameAdapter.toGameQuestion(_question('q1'));
      expect(question.id, 'q1');
      expect(question.type, 'multiple_choice');
      expect(question.options['d'], 'Option D');
    });

    test('does not record a pending second-chance answer', () {
      const pending = AnswerResult(
        chosen: 'a',
        isCorrect: false,
        status: 'retry_offered',
        firstChoice: 'a',
        retryGranted: true,
      );

      expect(
        DailyGameAdapter.toGameAnswer(
          questionId: 'q1',
          result: pending,
          answeredAt: DateTime(2026, 1, 1),
        ),
        isNull,
      );
    });

    test('reconstructs final daily answers into a session', () {
      final questions = [_question('q1'), _question('q2', position: 1)];
      final progress = {
        'q1': const AnswerResult(chosen: 'b', isCorrect: true, correctOption: 'b'),
        'q2': const AnswerResult(chosen: 'a', isCorrect: false, correctOption: 'd'),
      };
      final now = DateTime(2026, 1, 1, 12);

      final session = DailyGameAdapter.createSession(
        challengeId: 'daily-1',
        questions: questions,
        progress: progress,
        currentIndex: 1,
        now: now,
      );

      expect(session.id, 'daily-1');
      expect(session.mode, GameMode.dailyChallenge);
      expect(session.status, GameSessionStatus.inProgress);
      expect(session.answers, hasLength(2));
      expect(session.correctCount, 1);
      expect(session.currentIndex, 1);
    });

    test('maps a Daily Challenge result including streak data', () {
      final attempt = AttemptResult(
        score: 4,
        total: 5,
        xpEarned: 80,
        newXp: 180,
        newLevel: 2,
        leveledUp: true,
        currentStreak: 7,
        longestStreak: 12,
      );

      final result = DailyGameAdapter.toGameResult(attempt);

      expect(result.mode, GameMode.dailyChallenge);
      expect(result.currentStreak, 7);
      expect(result.longestStreak, 12);
      expect(result.leveledUp, isTrue);
    });
  });
}
