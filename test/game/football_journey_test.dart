import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/football_journey.dart';

void main() {
  group('FootballJourneyRules', () {
    test('has six zones of ten levels', () {
      expect(FootballJourneyRules.zoneCount, 6);
      expect(FootballJourneyRules.totalLevels, 60);
      expect(FootballJourneyRules.totalStars, 180);
    });

    test('maps levels to zones', () {
      expect(FootballJourneyRules.zoneForLevel(1).name, 'City Stadium');
      expect(FootballJourneyRules.zoneForLevel(10).name, 'City Stadium');
      expect(FootballJourneyRules.zoneForLevel(11).name, 'Forest Field');
      expect(FootballJourneyRules.zoneForLevel(60).name, 'Night City');
      expect(FootballJourneyRules.zones[1].firstLevel, 11);
      expect(FootballJourneyRules.zones[1].lastLevel, 20);
    });

    test('every tenth level is a zone final', () {
      expect(FootballJourneyRules.isZoneFinal(10), isTrue);
      expect(FootballJourneyRules.isZoneFinal(60), isTrue);
      expect(FootballJourneyRules.isZoneFinal(11), isFalse);
    });
  });

  group('FootballJourney', () {
    test('a new player has only level 1 open', () {
      const journey = FootballJourney();
      expect(journey.currentLevel, 1);
      expect(journey.isUnlocked(1), isTrue);
      expect(journey.isUnlocked(2), isFalse);
      expect(journey.unlockedThrough, 1);
      expect(journey.totalStars, 0);
    });

    test('completing a level opens the next one', () {
      final journey = const FootballJourney().withStars(1, 2);
      expect(journey.isCompleted(1), isTrue);
      expect(journey.isUnlocked(2), isTrue);
      expect(journey.isUnlocked(3), isFalse);
      expect(journey.currentLevel, 2);
      expect(journey.totalStars, 2);
    });

    test('stars are clamped and zero clears a level', () {
      var journey = const FootballJourney().withStars(1, 9);
      expect(journey.starsFor(1), 3);
      journey = journey.withStars(1, 0);
      expect(journey.isCompleted(1), isFalse);
    });

    test('counts stars per zone and unlocks zones by level', () {
      var journey = const FootballJourney();
      for (var level = 1; level <= 10; level++) {
        journey = journey.withStars(level, 3);
      }
      final city = FootballJourneyRules.zones[0];
      final forest = FootballJourneyRules.zones[1];
      final beach = FootballJourneyRules.zones[2];
      expect(journey.starsInZone(city), 30);
      expect(journey.isZoneUnlocked(forest), isTrue);
      expect(journey.isZoneUnlocked(beach), isFalse);
      expect(journey.currentLevel, 11);
    });

    test('finishing every level keeps the last level as current', () {
      var journey = const FootballJourney();
      for (var level = 1; level <= FootballJourneyRules.totalLevels; level++) {
        journey = journey.withStars(level, 1);
      }
      expect(journey.currentLevel, FootballJourneyRules.totalLevels);
    });
  });
}
