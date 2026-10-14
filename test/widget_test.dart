import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/services/xp_service.dart';

void main() {
  group('XpService', () {
    test('calculates levels from server XP', () {
      expect(XpService.levelForXp(0), 1);
      expect(XpService.levelForXp(99), 1);
      expect(XpService.levelForXp(100), 2);
      expect(XpService.levelForXp(250), 3);
    });

    test('calculates progress within the current level', () {
      expect(XpService.xpIntoCurrentLevel(0), 0);
      expect(XpService.xpIntoCurrentLevel(145), 45);
      expect(XpService.progressToNextLevel(50), 0.5);
      expect(XpService.progressToNextLevel(199), closeTo(0.99, 0.0001));
    });

    test('calculates XP needed for the next level', () {
      expect(XpService.xpToNextLevel(0), 100);
      expect(XpService.xpToNextLevel(45), 55);
      expect(XpService.xpToNextLevel(100), 100);
    });
  });
}
