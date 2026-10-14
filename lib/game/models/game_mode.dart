/// The gameplay modes supported by the shared game layer.
///
/// Mode-specific screens may have different rules and UI, but they all use
/// the same session lifecycle where possible.
enum GameMode {
  practice,
  dailyChallenge,
  competition,
  speedQuiz,
  guessIt,
  oddOneOut,
  findDifference,
  football,
  worldChallenge,
}
