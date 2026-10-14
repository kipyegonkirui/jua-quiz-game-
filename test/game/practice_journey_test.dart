import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/practice_journey.dart';

void main() {
  group('PracticeJourneyRules', () {
    test('groups levels into batches of ten', () {
      expect(PracticeJourneyRules.batchForLevel(1), 1);
      expect(PracticeJourneyRules.batchForLevel(10), 1);
      expect(PracticeJourneyRules.batchForLevel(11), 2);
      expect(PracticeJourneyRules.batchForLevel(20), 2);
      expect(PracticeJourneyRules.batchForLevel(21), 3);
    });

    test('question count rises by batch and caps at ten', () {
      expect(PracticeJourneyRules.questionCountForLevel(1), 5);
      expect(PracticeJourneyRules.questionCountForLevel(11), 6);
      expect(PracticeJourneyRules.questionCountForLevel(21), 7);
      expect(PracticeJourneyRules.questionCountForLevel(51), 10);
      expect(PracticeJourneyRules.questionCountForLevel(101), 10);
    });

    test('cumulative batch requirements become harder', () {
      expect(PracticeJourneyRules.requirementForBatch(2), 15); // 50% of 30
      expect(PracticeJourneyRules.requirementForBatch(3), 45); // 75% of 60
      expect(PracticeJourneyRules.requirementForBatch(4), 72); // 80% of 90, rounded up
      expect(PracticeJourneyRules.requirementForBatch(5), 102); // 85% of 120
      expect(PracticeJourneyRules.requirementForBatch(6), 132); // 88% of 150
    });

    test('stars reward accuracy, with three stars reserved for perfect play', () {
      expect(PracticeJourneyRules.starsForScore(score: 0, total: 5), 0);
      expect(PracticeJourneyRules.starsForScore(score: 2, total: 5), 1);
      expect(PracticeJourneyRules.starsForScore(score: 3, total: 5), 1);
      expect(PracticeJourneyRules.starsForScore(score: 4, total: 5), 2);
      expect(PracticeJourneyRules.starsForScore(score: 5, total: 5), 3);
    });
  });
}
