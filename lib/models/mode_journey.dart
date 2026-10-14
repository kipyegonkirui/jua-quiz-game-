/// The game modes that have a level journey like Practice.
///
/// Backed by the generic `*_mode_level*` RPCs in supabase/021_mode_journeys.sql.
enum JourneyMode {
  speedQuiz('speed_quiz', 'Speed Quiz', '⚡', 10),
  guessIt('guess_it', 'Guess It', '🖼️', 5),
  oddOneOut('odd_one_out', 'Odd One Out', '🔎', 8);

  /// Value stored in the database (`mode` column).
  final String key;
  final String title;
  final String emoji;

  /// Questions in one level (matches what the mode's round deals).
  final int questionCount;

  const JourneyMode(this.key, this.title, this.emoji, this.questionCount);
}

/// What the server returns when a journey level is settled.
class ModeLevelResult {
  final int level;
  final int stars;
  final int bestStars;
  final int correct;
  final int total;
  final int cumulativeStars;
  final bool lifeReturned;

  const ModeLevelResult({
    required this.level,
    required this.stars,
    required this.bestStars,
    required this.correct,
    required this.total,
    required this.cumulativeStars,
    required this.lifeReturned,
  });

  factory ModeLevelResult.fromMap(Map<String, dynamic> map) {
    int i(String k) => (map[k] as num?)?.toInt() ?? 0;
    return ModeLevelResult(
      level: i('level'),
      stars: i('stars'),
      bestStars: i('best_stars'),
      correct: i('correct'),
      total: i('total'),
      cumulativeStars: i('cumulative_stars'),
      lifeReturned: map['life_returned'] as bool? ?? false,
    );
  }
}

/// Share of easy / medium / hard questions at a level. Linear interpolation
/// between anchors, identical to `practice_difficulty_shares` in
/// supabase/020_practice_difficulty_and_math.sql (levels 1, 21, 41, 61, 81+).
({double easy, double medium, double hard}) journeyDifficultyShares(int level) {
  const lv = <double>[1, 21, 41, 61, 81];
  const e = <double>[1.00, 0.55, 0.20, 0.05, 0.00];
  const m = <double>[0.00, 0.45, 0.50, 0.40, 0.30];
  const h = <double>[0.00, 0.00, 0.30, 0.55, 0.70];
  final l = (level < 1 ? 1 : level).toDouble();
  if (l >= lv[4]) return (easy: e[4], medium: m[4], hard: h[4]);
  var i = 0;
  while (i < 3 && l >= lv[i + 1]) {
    i++;
  }
  final t = (l - lv[i]) / (lv[i + 1] - lv[i]);
  return (
    easy: e[i] + (e[i + 1] - e[i]) * t,
    medium: m[i] + (m[i + 1] - m[i]) * t,
    hard: h[i] + (h[i + 1] - h[i]) * t,
  );
}

/// How many easy / medium / hard questions a level of [count] questions deals.
/// Mirrors `practice_difficulty_mix` in the same migration.
({int easy, int medium, int hard}) journeyDifficultyMix(int level, int count) {
  final s = journeyDifficultyShares(level);
  final hard = (count * s.hard).round();
  final medium = (count * s.medium).round().clamp(0, count - hard).toInt();
  return (easy: count - hard - medium, medium: medium, hard: hard);
}

/// Dominant difficulty of a level: 'easy', 'medium' or 'hard'.
String journeyDifficultyLabel(int level) {
  final m = journeyDifficultyMix(level, 10);
  if (m.hard >= m.medium && m.hard >= m.easy) return 'hard';
  if (m.medium >= m.easy) return 'medium';
  return 'easy';
}
