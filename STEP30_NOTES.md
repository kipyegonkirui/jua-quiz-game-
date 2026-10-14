# Step 30 — Game modes finalised

- **Odd One Out is now live.** The screen, model and `020_odd_one_out.sql` already existed, but
  `SupabaseService` had none of the methods the screen called, so it could not have compiled/run.
  Added `getOddOneOutStatus`, `startOddOneOutRound`, `getOddOneOutPuzzles`, `answerOddOneOutPuzzle`,
  `useOddOneOutHint` (publishes the new coin balance) and `submitOddOneOutRound` (refreshes the profile
  and bumps `AppEvents.dataVersion`). Hub card enabled, routed, pill reads "🔎 New set daily".
  **Run `supabase/020_odd_one_out.sql` first** (see MIGRATION_ORDER.md).
- Odd One Out exit now uses the game-style `showJuaExitDialog` like the other modes.
- Timers (Odd One Out, Guess It): a failed answer call no longer restarts the countdown, so going
  offline can't buy extra time. A failed timeout is retried after 2s instead of every tick.
- Speed Quiz: a failed timeout is retried after 2s instead of every 100ms (was request/snackbar spam offline).
- Guess It: finishing a round now refreshes missions/achievements (`notifyProgressChanged`).
- Football Challenge stays "Coming soon": it's a road map with no questions, its `assets/football/`
  folder isn't listed in pubspec.yaml, and levels only open a placeholder sheet.
- Not done: the Practice intro/question/result restyle (paused earlier).
