import 'package:flutter_test/flutter_test.dart';

void main() {
  group('streak milestone reward policy', () {
    test('3 and 14 day milestones award coins', () {
      expect(_coinsFor(3), 100);
      expect(_coinsFor(14), 500);
    });

    test('7, 30, 60 and 100 day milestones award shields', () {
      expect(_shieldsFor(7), 1);
      expect(_shieldsFor(30), 1);
      expect(_shieldsFor(60), 2);
      expect(_shieldsFor(100), 3);
    });

    test('a shield protects exactly one missed day', () {
      expect(_protectedStreak(current: 14, daysSinceLastCompletion: 2, shields: 1), 15);
      expect(_protectedStreak(current: 14, daysSinceLastCompletion: 3, shields: 1), 1);
      expect(_protectedStreak(current: 14, daysSinceLastCompletion: 2, shields: 0), 1);
    });
  });
}

int _coinsFor(int milestone) => switch (milestone) {
      3 => 100,
      14 => 500,
      _ => 0,
    };

int _shieldsFor(int milestone) => switch (milestone) {
      7 => 1,
      30 => 1,
      60 => 2,
      100 => 3,
      _ => 0,
    };

int _protectedStreak({required int current, required int daysSinceLastCompletion, required int shields}) =>
    daysSinceLastCompletion == 2 && shields > 0 ? current + 1 : 1;
