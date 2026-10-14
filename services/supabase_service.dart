import '../models/practice_journey.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  Future<PracticeJourneyData> getPracticeJourney({required int throughLevel}) async {
    return PracticeJourneyData(
      cumulativeStars: 12,
      nextBatchRequirement: 30,
      nextBatchRequirementPercent: 40,
      nextBatch: 2,
      adUnlocksUsed: 0,
      adUnlocksPerBatch: 3,
      levels: List.generate(20, (index) {
        int lvl = index + 1;
        return PracticeLevelProgress(
          level: lvl,
          batch: (lvl <= 10) ? 1 : 2,
          unlocked: lvl <= 3,
          stars: lvl == 1 ? 3 : (lvl == 2 ? 2 : 0),
        );
      }),
    );
  }

  Future<PracticeJourneyData> unlockPracticeBatchByAd(int batch) async {
    return getPracticeJourney(throughLevel: 100);
  }
}
