/// Centralized XP/level math used by the client for presentation and
/// fallback calculations. Persistent XP remains server-authoritative.
class XpLevelState {
  final int xp;
  final int level;
  final int xpIntoLevel;
  final int xpToNextLevel;
  final double progress;

  const XpLevelState({
    required this.xp,
    required this.level,
    required this.xpIntoLevel,
    required this.xpToNextLevel,
    required this.progress,
  });

  bool get isAtLevelBoundary => xpIntoLevel == 0 && xp > 0;
}

class XpGainPreview {
  final XpLevelState before;
  final XpLevelState after;
  final int xpGained;
  final bool leveledUp;
  final int levelsGained;

  const XpGainPreview({
    required this.before,
    required this.after,
    required this.xpGained,
    required this.leveledUp,
    required this.levelsGained,
  });
}

class XpProgressionService {
  const XpProgressionService._();

  static const int xpPerLevel = 100;

  static XpLevelState fromXp(int xp) {
    final safeXp = xp < 0 ? 0 : xp;
    final into = safeXp % xpPerLevel;
    return XpLevelState(
      xp: safeXp,
      level: (safeXp ~/ xpPerLevel) + 1,
      xpIntoLevel: into,
      xpToNextLevel: xpPerLevel - into,
      progress: into / xpPerLevel,
    );
  }

  static XpGainPreview previewGain({
    required int currentXp,
    required int xpGained,
  }) {
    final before = fromXp(currentXp);
    final after = fromXp(currentXp + (xpGained < 0 ? 0 : xpGained));
    return XpGainPreview(
      before: before,
      after: after,
      xpGained: xpGained < 0 ? 0 : xpGained,
      leveledUp: after.level > before.level,
      levelsGained: after.level - before.level,
    );
  }
}
