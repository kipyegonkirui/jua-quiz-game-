# Football Challenge road map

The Football Challenge card on the game hub now opens a road map of levels.
There is no question content yet: tapping an open level shows a "coming soon"
sheet.

## Structure

- 6 zones x 10 levels = 60 levels, 3 stars per level (180 total).
- Zones, bottom to top: City Stadium, Forest Field, Beach Arena, Desert Dunes,
  Snowy Mountains, Night City.
- Every 10th level is the zone "cup final" (larger node with a trophy).
- Levels open one at a time: Level 1 is open, each next level opens once the
  previous one has at least 1 star.

## Files

- `lib/models/football_journey.dart` - zones, rules, `FootballJourney` progress.
- `lib/screens/football_journey_screen.dart` - the scrolling road map.
- `assets/football/` - art cut from the football sprite sheet.
- `test/game/football_journey_test.dart` - rules tests.

## Previewing states (debug builds only)

Long-press an open level to cycle its stars 0 -> 1 -> 2 -> 3 -> 0 and see the
completed / current / locked looks. The reset icon in the app bar clears it.
Progress is in memory only until real content exists.

## Plugging in content later

Replace the in-memory star map in `_FootballJourneyScreenState` with data loaded
from Supabase (same pattern as `PracticeJourneyData`) and route unlocked level
taps to a play screen instead of the "coming soon" sheet.

## Art notes

The zone backgrounds in the source sheet are small (about 140x380 px), so they
are upscaled 2x and stretched across the map width. For a crisper final look,
export larger zone backgrounds and replace the six `fb_zone_*.png` files.
