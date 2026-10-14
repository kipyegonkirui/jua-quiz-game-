class PracticeJourneyData {
  final int cumulativeStars;
  final int nextBatchRequirement;
  final int nextBatchRequirementPercent;
  final int nextBatch;
  final int adUnlocksUsed;
  final int adUnlocksPerBatch;
  final List<PracticeLevelProgress> levels;

  PracticeJourneyData({
    required this.cumulativeStars,
    required this.nextBatchRequirement,
    required this.nextBatchRequirementPercent,
    required this.nextBatch,
    required this.adUnlocksUsed,
    required this.adUnlocksPerBatch,
    required this.levels,
  });
}

class PracticeLevelProgress {
  final int level;
  final int batch;
  final bool unlocked;
  final int stars;

  PracticeLevelProgress({
    required this.level,
    required this.batch,
    required this.unlocked,
    required this.stars,
  });
}
