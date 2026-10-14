# Odd One Out

New game mode, built on the same server-authoritative pattern as Guess It.

## How it plays
- 4 items, tap the one that does not belong. 8 puzzles per round, 10-15 s each.
- After every answer a one-line explanation is revealed (the "aha" moment).
- Correct answers build a combo: score = (100 + up to 100 speed bonus) x multiplier
  (1.0, 1.1 ... capped at 1.5 from the 6th correct answer in a row).
- Hint: 30 coins removes two wrong items (one per puzzle, -30 points on that puzzle).
- Puzzle types: category, local culture, wordplay, visual (emoji) and tricky.

## Modes
- **Daily Set**: same puzzles for every player each Nairobi day, one attempt per day.
  Finishing gives +25 XP and +15 coins, plus a streak bonus (3 coins per streak day, up to 7).
  Result can be copied as a Wordle-style emoji grid for WhatsApp.
- **Quick Play**: endless rounds. Puzzles the player has seen least come first.
  XP and coins are paid for the first 8 rounds per Nairobi day (about the same daily XP
  ceiling as Practice). Later rounds still play and score.

## Rewards (per round)
- Quick: XP = min(60, 6 per correct + score/120) (+10 if perfect); coins = 2 per correct (+10 if perfect).
- Daily: the same formula plus the daily bonus above.

## Files
- `supabase/020_odd_one_out.sql` — tables, seed puzzles, RPCs (start / get / hint / answer / submit / status).
- `lib/models/odd_one_out.dart`, `lib/services/odd_one_out_service.dart`
- `lib/services/supabase_service.dart` — new "Odd One Out" section.
- `lib/screens/odd_one_out_screen.dart` — lobby, gameplay, results.
- `lib/screens/game_hub_screen.dart` — the "Odd One Out" card is now live.
- `test/game/odd_one_out_test.dart`

## Adding puzzles
Insert rows into `odd_one_out_puzzles` (Supabase Table Editor). `odd_option` is the letter
(a-d) of the item that does not belong. Put the odd item in a random slot so the answer is
not always the same letter. Keep the explanation to one short sentence.
Daily sets are picked from all active puzzles by hashing the date, so more puzzles means
fewer repeats between days.

## Not wired yet
Daily missions, achievements and reward chests do not count Odd One Out rounds.
