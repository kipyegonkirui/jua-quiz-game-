# Phase 1 — Guest Progress and Leaderboard

Guest players use an anonymous Supabase user while the app is installed.
Their progression is mirrored to device storage and their server-confirmed XP
is also stored in `profiles`.

Guest players are now included in the global leaderboard. Creating an account
is optional and is only needed if the player wants to restore progress after
uninstalling/reinstalling the app.

## Database migration

For an existing Supabase project, run:

`supabase/008_guest_leaderboard.sql`

Do not rerun all migrations blindly; apply only the next missing migration.

## Expected behavior

- Guest XP remains visible in Stats.
- Guest practice rounds remain visible in Stats.
- Guest scores appear on Leaderboard.
- The current guest row is highlighted like any other player's row.
- Account creation is not required to appear on the leaderboard.
- After reinstall, a guest-only device cache is gone; a linked account can
  restore the server-side progress.


## Instant refresh fix
The leaderboard now overlays the current in-memory guest profile and prevents older asynchronous refreshes from overwriting newer data.
