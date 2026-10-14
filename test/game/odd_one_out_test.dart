import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/models/odd_one_out.dart';

void main() {
  test('puzzle payload hides the answer until the puzzle is answered', () {
    final p = OddOneOutPuzzle.fromMap({
      'id': 'p1',
      'puzzle_type': 'local',
      'item_a': 'Tana',
      'item_b': 'Naivasha',
      'item_c': 'Nzoia',
      'item_d': 'Yala',
      'position': 1,
      'time_limit_seconds': 12,
      'difficulty': 'medium',
      'answered': false,
      'chosen': null,
      'is_correct': null,
      'odd_option': null,
      'explanation': null,
      'score': 0,
      'combo': 0,
      'hint_used': false,
      'eliminated_options': <String>[],
    });

    expect(p.items['b'], 'Naivasha');
    expect(p.answered, isFalse);
    expect(p.oddOption, isNull);
    expect(p.explanation, isNull);
    expect(p.isCorrect, isFalse); // a null is_correct must not crash
    expect(p.typeLabel, 'LOCAL CULTURE');
    expect(p.isVisual, isFalse);
  });

  test('answered puzzle rebuilds its result when resuming a round', () {
    final p = OddOneOutPuzzle.fromMap({
      'id': 'p2',
      'puzzle_type': 'visual',
      'item_a': '🔴',
      'item_b': '🔴',
      'item_c': '🔵',
      'item_d': '🔴',
      'position': 2,
      'answered': true,
      'chosen': 'c',
      'is_correct': true,
      'odd_option': 'c',
      'explanation': 'Three red circles and one blue circle.',
      'score': 145,
      'combo': 2,
      'hint_used': true,
      'eliminated_options': ['a', 'd'],
    });
    final r = OddOneOutAnswerResult.fromAnsweredPuzzle(p);

    expect(p.isVisual, isTrue);
    expect(p.eliminated, {'a', 'd'});
    expect(r.isCorrect, isTrue);
    expect(r.oddOption, 'c');
    expect(r.combo, 2);
    expect(r.score, 145);
    expect(r.hintUsed, isTrue);
  });

  test('answer result parses server payload including the explanation', () {
    final r = OddOneOutAnswerResult.fromMap({
      'puzzle_id': 'p1',
      'chosen': 'timeout',
      'odd_option': 'd',
      'is_correct': false,
      'score': 0,
      'combo': 0,
      'time_ms': 12000,
      'hint_used': false,
      'explanation': 'Tana, Nzoia and Yala are rivers. Naivasha is a lake.',
    });
    expect(r.isCorrect, isFalse);
    expect(r.chosen, 'timeout');
    expect(r.explanation, contains('Naivasha'));
  });

  test('hint result tracks removed items and wallet balance', () {
    final h = OddOneOutHintResult.fromMap({
      'eliminated_options': ['a', 'd'],
      'coins_spent': 30,
      'coins_balance': 70,
    });
    expect(h.eliminatedOptions, {'a', 'd'});
    expect(h.coinsSpent, 30);
    expect(h.coinsBalance, 70);
  });

  test('round result exposes rewards, streak, pattern and share text', () {
    final r = OddOneOutResult.fromMap({
      'mode': 'daily',
      'score': 1304,
      'total': 8,
      'correct': 6,
      'max_combo': 6,
      'xp_earned': 118,
      'coins_earned': 36,
      'rewards_capped': false,
      'new_xp': 302,
      'new_level': 4,
      'leveled_up': true,
      'best_score': 1304,
      'daily_streak': 3,
      'pattern': '🟩🟩🟩🟩🟩🟩🟥🟥',
    });

    expect(r.isDaily, isTrue);
    expect(r.xpEarned, 118);
    expect(r.coinsEarned, 36);
    expect(r.leveledUp, isTrue);
    expect(r.shareText, contains('🟩🟩🟩🟩🟩🟩🟥🟥  6/8'));
    expect(r.shareText, contains('Score 1304'));
    expect(r.shareText, contains('3-day streak'));
  });

  test('share text omits the streak line for a first day', () {
    final text = buildOddOneOutShareText(
      pattern: '🟩🟥',
      correct: 1,
      total: 2,
      score: 150,
      streak: 1,
    );
    expect(text, isNot(contains('streak')));
  });

  test('lobby status parses an unplayed day', () {
    final s = OddOneOutStatus.fromMap({
      'daily_done': false,
      'daily_in_progress': true,
      'daily_score': 0,
      'daily_correct': 0,
      'daily_total': 0,
      'daily_pattern': '',
      'daily_streak': 4,
      'best_quick_score': 1913,
      'rewarded_rounds_left': 8,
    });
    expect(s.dailyDone, isFalse);
    expect(s.dailyInProgress, isTrue);
    expect(s.dailyStreak, 4);
    expect(s.bestQuickScore, 1913);
    expect(s.rewardedRoundsLeft, 8);
  });

  test('combo multiplier mirrors the server formula', () {
    expect(oddOneOutComboMultiplier(0), 1.0);
    expect(oddOneOutComboMultiplier(1), 1.0);
    expect(oddOneOutComboMultiplier(2), closeTo(1.1, 1e-9));
    expect(oddOneOutComboMultiplier(6), closeTo(1.5, 1e-9));
    expect(oddOneOutComboMultiplier(20), closeTo(1.5, 1e-9)); // capped
  });

  test('verdict celebrates perfect rounds and frames near-misses', () {
    expect(oddOneOutVerdict(8, 8), contains('Perfect'));
    expect(oddOneOutVerdict(7, 8), contains('So close'));
    expect(oddOneOutVerdict(5, 8), contains('Sharp'));
    expect(oddOneOutVerdict(0, 0), 'Round complete');
  });

  test('countdown targets midnight in Kenya (UTC+3)', () {
    // 20:30 UTC is 23:30 in Nairobi, so 30 minutes remain.
    final d = timeUntilNextNairobiDay(DateTime.utc(2026, 10, 5, 20, 30));
    expect(d, const Duration(minutes: 30));
    // 21:00 UTC is exactly midnight in Nairobi, a full day remains.
    expect(timeUntilNextNairobiDay(DateTime.utc(2026, 10, 5, 21, 0)), const Duration(hours: 24));
    // Month rollover: 22:00 UTC on 31 Oct is 01:00 on 1 Nov in Nairobi.
    expect(timeUntilNextNairobiDay(DateTime.utc(2026, 10, 31, 22, 0)), const Duration(hours: 23));

    expect(formatOddOneOutCountdown(const Duration(hours: 5, minutes: 12)), '5h 12m');
    expect(formatOddOneOutCountdown(const Duration(minutes: 42)), '42m');
    expect(formatOddOneOutCountdown(Duration.zero), '1m');
  });
}
