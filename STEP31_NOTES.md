# Step 31 — Level journeys for Speed Quiz, Guess It and Odd One Out

Same rules as the Practice journey, on the same painted map.

**Run `supabase/021_mode_journeys.sql` (after 020).** Without it the new maps show an error.

## How it works
- Hub: the Speed Quiz, Guess It and Odd One Out cards now open that mode's level map
  (`PracticeJourneyScreen(mode: ...)`). The ⚡ icon in the map's top bar opens the old
  free play (Odd One Out's Daily Set lives there).
- Levels unlock in order (1+ star on the previous level); every 10 levels is a batch that needs
  cumulative stars or 3 rewarded ads (same formulas as Practice).
- Stars come from the round's server-recorded result: all correct = 3, >= 70% = 2, any = 1.
- 5 lives per mode, 5-minute recharge. Starting a level reserves a life. >= 1 star returns it;
  0 stars or leaving the level bursts it. Leaving deletes the half-played round.
- A level is a normal round of the mode, so XP / coins / daily caps / stats behave as before.
- Flow per screen: `startModeLevel` -> play -> mode's own submit -> `ModeLevelSummary`
  (calls `completeModeLevel`, shows stars, Next / Retry / Back).

## Files
- `supabase/021_mode_journeys.sql` (tables, `get_mode_journey`, `get_mode_lives`, `start_mode_level`,
  `complete_mode_level`, `abandon_mode_level`, `unlock_mode_batch_by_ad`)
- `lib/models/mode_journey.dart`, `lib/widgets/mode_level_summary.dart`
- `SupabaseService`: `getModeJourney`, `getModeLives`, `startModeLevel`, `completeModeLevel`,
  `abandonModeLevel`, `unlockModeBatchByAd`
- Screens take an optional `levelNumber`: `SpeedQuizScreen`, `GuessItScreen`, `OddOneOutScreen`
- Speed Quiz now also asks before leaving mid-round (it had no exit confirmation).

## Known limits
- Levels do not get harder: each mode's own start RPC deals the questions, so there is no
  per-level difficulty (the map says "N questions", not a difficulty).
- Football / Find the Difference / World have no questions yet, so no journey.
- Uncompiled and the SQL is only syntax-checked: run the migration on a test project first.
