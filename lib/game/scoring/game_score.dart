/// The transparent components of one client-side score calculation.
///
/// This is a presentation/gameplay calculation for modes that need immediate
/// feedback. Practice, Daily Challenge, and Competition remain server-
/// authoritative until their RPCs are explicitly migrated to this policy.
class GameScoreBreakdown {
  final int basePoints;
  final int speedBonus;
  final int difficultyBonus;
  final int modeBonus;

  const GameScoreBreakdown({
    required this.basePoints,
    this.speedBonus = 0,
    this.difficultyBonus = 0,
    this.modeBonus = 0,
  });

  int get total => basePoints + speedBonus + difficultyBonus + modeBonus;

  @override
  String toString() =>
      'GameScoreBreakdown(base=$basePoints, speed=$speedBonus, '
      'difficulty=$difficultyBonus, mode=$modeBonus, total=$total)';
}
