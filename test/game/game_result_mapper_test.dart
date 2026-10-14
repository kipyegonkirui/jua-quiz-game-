import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/mappers/game_result_mapper.dart';
import 'package:jua_quiz/game/models/game_mode.dart';
import 'package:jua_quiz/game/models/speed_quiz_result.dart';
import 'package:jua_quiz/models/attempt_result.dart';

void main() {
  test('maps Practice AttemptResult into normalized GameResult', () {
    final result = GameResultMapper.fromAttemptResult(
      mode: GameMode.practice,
      result: AttemptResult(
        score: 4,
        total: 5,
        xpEarned: 30,
        newXp: 230,
        newLevel: 3,
        leveledUp: false,
        currentStreak: 0,
        longestStreak: 0,
        xpCapped: true,
        practiceXpToday: 500,
        practiceXpCap: 500,
      ),
    );

    expect(result.mode, GameMode.practice);
    expect(result.score, 4);
    expect(result.correct, 4);
    expect(result.accuracy, 0.8);
    expect(result.xpEarned, 30);
    expect(result.xpCapped, isTrue);
    expect(result.practiceXpToday, 500);
  });

  test('maps Speed Quiz result without confusing score for correct count', () {
    final result = GameResultMapper.fromSpeedQuizResult(
      const SpeedQuizResult(
        score: 742,
        total: 10,
        correct: 8,
        xpEarned: 60,
        newXp: 460,
        newLevel: 5,
        leveledUp: true,
        currentStreak: 2,
        longestStreak: 7,
      ),
    );

    expect(result.mode, GameMode.speedQuiz);
    expect(result.score, 742);
    expect(result.correct, 8);
    expect(result.accuracy, 0.8);
    expect(result.xpEarned, 60);
    expect(result.leveledUp, isTrue);
  });
}
