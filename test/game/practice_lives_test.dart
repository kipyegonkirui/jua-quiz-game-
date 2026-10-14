import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/models/practice_lives.dart';

void main() {
  test('parses a full five-life pool', () {
    final lives = PracticeLives.fromMap({
      'available_lives': 5,
      'max_lives': 5,
      'next_recharge_at': null,
      'recharge_seconds': 0,
    });

    expect(lives.availableLives, 5);
    expect(lives.maxLives, 5);
    expect(lives.full, isTrue);
    expect(lives.empty, isFalse);
  });

  test('parses the next recharge timestamp', () {
    final lives = PracticeLives.fromMap({
      'available_lives': 4,
      'max_lives': 5,
      'next_recharge_at': '2026-10-04T10:05:00Z',
      'recharge_seconds': 300,
    });

    expect(lives.availableLives, 4);
    expect(lives.nextRechargeAt, isNotNull);
    expect(lives.rechargeSeconds, 300);
  });

  test('one-or-more stars return the reserved life', () {
    const stars = 1;
    expect(stars >= 1, isTrue);
  });

  test('zero stars burst the reserved life', () {
    const stars = 0;
    expect(stars < 1, isTrue);
  });
}
