import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/models/guess_it.dart';

void main() {
  test('Guess It question parses answer-free question payload', () {
    final question = GuessItQuestion.fromMap({
      'id': 'q1',
      'prompt': 'Which animal?',
      'image_url': 'asset:assets/guess_it/lion.svg',
      'option_a': 'Lion',
      'option_b': 'Elephant',
      'option_c': 'Zebra',
      'option_d': 'Rhino',
      'position': 1,
      'time_limit_seconds': 15,
      'difficulty': 'easy',
    });

    expect(question.id, 'q1');
    expect(question.options['a'], 'Lion');
    expect(question.imageUrl, startsWith('asset:'));
    expect(question.timeLimitSeconds, 15);
  });

  test('hint result tracks eliminated options and wallet balance', () {
    final hint = GuessItHintResult.fromMap({
      'hint_level': 3,
      'eliminated_options': ['b', 'd'],
      'coins_spent': 60,
      'coins_balance': 140,
    });

    expect(hint.hintLevel, 3);
    expect(hint.eliminatedOptions, {'b', 'd'});
    expect(hint.coinsSpent, 60);
    expect(hint.coinsBalance, 140);
  });

  test('Guess It result exposes authoritative rewards and best score', () {
    final result = GuessItGameResult.fromMap({
      'score': 820,
      'total': 5,
      'correct': 4,
      'xp_earned': 91,
      'coins_earned': 20,
      'new_xp': 491,
      'new_level': 5,
      'leveled_up': true,
      'best_score': 820,
    });

    expect(result.score, 820);
    expect(result.correct, 4);
    expect(result.xpEarned, 91);
    expect(result.coinsEarned, 20);
    expect(result.newLevel, 5);
    expect(result.leveledUp, isTrue);
    expect(result.bestScore, 820);
  });
}
