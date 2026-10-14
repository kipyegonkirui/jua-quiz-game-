import '../game/progression/xp_progression_service.dart';

/// Backwards-compatible facade for the app's existing XP display helpers.
/// The XP value itself remains server-authoritative; these methods only derive
/// level/progress presentation from the current XP.
class XpService {
  static const xpPerLevel = XpProgressionService.xpPerLevel;

  static int levelForXp(int xp) => XpProgressionService.fromXp(xp).level;

  static int xpIntoCurrentLevel(int xp) =>
      XpProgressionService.fromXp(xp).xpIntoLevel;

  static double progressToNextLevel(int xp) =>
      XpProgressionService.fromXp(xp).progress;

  static int xpToNextLevel(int xp) =>
      XpProgressionService.fromXp(xp).xpToNextLevel;
}
