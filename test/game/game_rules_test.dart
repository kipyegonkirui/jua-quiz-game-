import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/models/game_mode.dart';
import 'package:jua_quiz/game/models/game_rules.dart';

void main() {
  test('rules describe a mode independently of session state', () {
    const rules = GameRules(
      mode: GameMode.speedQuiz,
      timeLimitPerQuestion: Duration(seconds: 10),
      localScoring: true,
      allowsRetry: false,
      allowsHints: false,
      autoAdvance: true,
    );

    expect(rules.mode, GameMode.speedQuiz);
    expect(rules.timeLimitPerQuestion, const Duration(seconds: 10));
    expect(rules.localScoring, isTrue);
    expect(rules.autoAdvance, isTrue);
  });

  test('copyWith can clear a time limit', () {
    const rules = GameRules(
      mode: GameMode.practice,
      timeLimitPerQuestion: Duration(seconds: 15),
    );

    final cleared = rules.copyWith(clearTimeLimit: true);
    expect(cleared.timeLimitPerQuestion, isNull);
  });
}
