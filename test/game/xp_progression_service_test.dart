import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/game/progression/xp_progression_service.dart';

void main() {
  test('builds a level snapshot from XP', () {
    final state = XpProgressionService.fromXp(245);

    expect(state.level, 3);
    expect(state.xpIntoLevel, 45);
    expect(state.xpToNextLevel, 55);
    expect(state.progress, closeTo(0.45, 0.0001));
  });

  test('previews a gain that crosses one level', () {
    final preview = XpProgressionService.previewGain(
      currentXp: 95,
      xpGained: 15,
    );

    expect(preview.before.level, 1);
    expect(preview.after.level, 2);
    expect(preview.after.xp, 110);
    expect(preview.leveledUp, isTrue);
    expect(preview.levelsGained, 1);
  });

  test('previews a gain that crosses multiple levels', () {
    final preview = XpProgressionService.previewGain(
      currentXp: 50,
      xpGained: 260,
    );

    expect(preview.before.level, 1);
    expect(preview.after.level, 4);
    expect(preview.levelsGained, 3);
  });

  test('clamps negative XP input to zero', () {
    final state = XpProgressionService.fromXp(-10);
    expect(state.xp, 0);
    expect(state.level, 1);
  });
}
