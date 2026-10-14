import '../../models/mission.dart';

class MissionService {
  const MissionService._();

  static int completedCount(Iterable<Mission> missions) => missions.where((m) => m.completed).length;

  static bool canClaim(Mission mission) => mission.completed && !mission.claimed;
}
