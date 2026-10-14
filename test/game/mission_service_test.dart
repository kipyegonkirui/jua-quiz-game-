import 'package:flutter_test/flutter_test.dart';
import 'package:jua_quiz/models/mission.dart';
import 'package:jua_quiz/game/progression/mission_service.dart';

void main() {
  final date = DateTime.utc(2026, 10, 3);

  Mission mission({int progress = 0, int target = 10, DateTime? claimedAt}) => Mission(
        id: 'm1', missionDate: date, kind: MissionKind.answerQuestions,
        title: 'Question Crusher', description: 'Answer 10 questions.', target: target,
        progress: progress, rewardXp: 25, rewardCoins: 25, claimedAt: claimedAt,
      );

  test('mission reports progress fraction safely', () {
    expect(mission(progress: 5).progressFraction, 0.5);
    expect(mission(progress: 12).progressFraction, 1.0);
  });

  test('only complete unclaimed missions can be claimed', () {
    expect(MissionService.canClaim(mission(progress: 9)), isFalse);
    expect(MissionService.canClaim(mission(progress: 10)), isTrue);
    expect(MissionService.canClaim(mission(progress: 10, claimedAt: date)), isFalse);
  });

  test('completedCount counts only completed missions', () {
    expect(MissionService.completedCount([mission(progress: 10), mission(progress: 3), mission(progress: 10)]), 2);
  });
}
