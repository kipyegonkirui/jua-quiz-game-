// Football Challenge road map: zones, levels and local progress rules.
//
// Progress comes from the server (get_football_journey); see 031_football_challenge.sql.

class FootballZone {
  /// 1-based zone number.
  final int number;
  final String name;
  final String background;
  final String flag;

  const FootballZone({
    required this.number,
    required this.name,
    required this.background,
    required this.flag,
  });

  int get firstLevel => (number - 1) * FootballJourneyRules.levelsPerZone + 1;
  int get lastLevel => number * FootballJourneyRules.levelsPerZone;
}

class FootballJourneyRules {
  const FootballJourneyRules._();

  static const int levelsPerZone = 10;
  static const int starsPerLevel = 3;

  static const List<FootballZone> zones = [
    FootballZone(
      number: 1,
      name: 'City Stadium',
      background: 'assets/football/fb_zone_1_city.png',
      flag: 'assets/football/fb_flag_blue.png',
    ),
    FootballZone(
      number: 2,
      name: 'Forest Field',
      background: 'assets/football/fb_zone_2_forest.png',
      flag: 'assets/football/fb_flag_green.png',
    ),
    FootballZone(
      number: 3,
      name: 'Beach Arena',
      background: 'assets/football/fb_zone_3_beach.png',
      flag: 'assets/football/fb_flag_red.png',
    ),
    FootballZone(
      number: 4,
      name: 'Desert Dunes',
      background: 'assets/football/fb_zone_4_desert.png',
      flag: 'assets/football/fb_flag_yellow.png',
    ),
    FootballZone(
      number: 5,
      name: 'Snowy Mountains',
      background: 'assets/football/fb_zone_5_snow.png',
      flag: 'assets/football/fb_flag_blue.png',
    ),
    FootballZone(
      number: 6,
      name: 'Night City',
      background: 'assets/football/fb_zone_6_night.png',
      flag: 'assets/football/fb_flag_red.png',
    ),
  ];

  static int get zoneCount => zones.length;
  static int get totalLevels => zoneCount * levelsPerZone;
  static int get totalStars => totalLevels * starsPerLevel;
  static int get starsPerZone => levelsPerZone * starsPerLevel;

  /// 0-based index of the zone that contains [level].
  static int zoneIndexForLevel(int level) =>
      ((level - 1) ~/ levelsPerZone).clamp(0, zoneCount - 1).toInt();

  static FootballZone zoneForLevel(int level) => zones[zoneIndexForLevel(level)];

  /// Every tenth level is the "cup final" of its zone.
  static bool isZoneFinal(int level) => level % levelsPerZone == 0;
}

/// Immutable snapshot of the player's Football road progress.
class FootballJourney {
  final Map<int, int> _stars;

  const FootballJourney({Map<int, int> stars = const <int, int>{}}) : _stars = stars;

  int starsFor(int level) =>
      (_stars[level] ?? 0).clamp(0, FootballJourneyRules.starsPerLevel).toInt();

  bool isCompleted(int level) => starsFor(level) > 0;

  /// Levels open one at a time: Level 1 is always open, every other level
  /// opens once the previous one has been completed.
  bool isUnlocked(int level) {
    if (level < 1 || level > FootballJourneyRules.totalLevels) return false;
    return level == 1 || isCompleted(level - 1);
  }

  /// First level that has not been completed yet (or the last level once the
  /// whole road is finished).
  int get currentLevel {
    for (var level = 1; level <= FootballJourneyRules.totalLevels; level++) {
      if (!isCompleted(level)) return level;
    }
    return FootballJourneyRules.totalLevels;
  }

  /// Highest level the player can currently open.
  int get unlockedThrough {
    var through = 1;
    for (var level = 1; level <= FootballJourneyRules.totalLevels; level++) {
      if (isUnlocked(level)) through = level;
    }
    return through;
  }

  int get totalStars {
    var sum = 0;
    for (var level = 1; level <= FootballJourneyRules.totalLevels; level++) {
      sum += starsFor(level);
    }
    return sum;
  }

  int starsInZone(FootballZone zone) {
    var sum = 0;
    for (var level = zone.firstLevel; level <= zone.lastLevel; level++) {
      sum += starsFor(level);
    }
    return sum;
  }

  bool isZoneUnlocked(FootballZone zone) => isUnlocked(zone.firstLevel);

  FootballJourney withStars(int level, int stars) {
    final next = Map<int, int>.from(_stars);
    final clamped = stars.clamp(0, FootballJourneyRules.starsPerLevel).toInt();
    if (clamped == 0) {
      next.remove(level);
    } else {
      next[level] = clamped;
    }
    return FootballJourney(stars: next);
  }
}

/// The server's verdict on a finished 5-kick shootout.
class FootballRoundResult {
  final int level;
  final int goals;
  final int kicks;
  final int stars;
  final int xpEarned;
  final bool xpCapped;
  final int newLevel;
  final bool leveledUp;
  final bool nextLevelUnlocked;

  const FootballRoundResult({
    required this.level,
    required this.goals,
    required this.kicks,
    required this.stars,
    required this.xpEarned,
    required this.xpCapped,
    required this.newLevel,
    required this.leveledUp,
    required this.nextLevelUnlocked,
  });

  factory FootballRoundResult.fromMap(Map<String, dynamic> m) => FootballRoundResult(
        level: (m['level'] as num).toInt(),
        goals: (m['score'] as num).toInt(),
        kicks: (m['total'] as num).toInt(),
        stars: (m['stars'] as num).toInt(),
        xpEarned: (m['xp_earned'] as num?)?.toInt() ?? 0,
        xpCapped: m['xp_capped'] as bool? ?? false,
        newLevel: (m['new_level'] as num?)?.toInt() ?? 1,
        leveledUp: m['leveled_up'] as bool? ?? false,
        nextLevelUnlocked: m['next_level_unlocked'] as bool? ?? false,
      );
}
