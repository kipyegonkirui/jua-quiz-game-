# Step 35: Odd One Out "Survival Run"

Dart is uncompiled (no Flutter SDK here). SQL ran on real Postgres 18: a 6-answer run, three strikes, the Second Wind offer (refused with no coins, works with coins), a second collapse, payout, idempotent finish, personal-best tracking, timeout and wrong-puzzle checks.

Run `028_odd_survival_run.sql` after 026.

## How it plays
- Endless puzzles, 3 strikes (hearts). A miss or timeout costs a strike and breaks the streak.
- Streak multiplier: x1, x1.5 at 3, x2 HOT STREAK at 5 (screen turns orange), x3 at 10.
- Adaptive: the server picks every puzzle. Difficulty follows a heat score: it rises with puzzle count and streak and cools by one step per strike. Time per puzzle shrinks 2.5% each puzzle (floor 55%, minimum 4s).
- Time is server-checked (1.5s network grace). The clock starts when the puzzle is shown, so reading the explanation never costs time.
- Second Wind: out of strikes with 5+ correct, you can pay 40 coins for one strike back and your streak restored (max x5). Once per run.
- Rewards: XP up to 60, coins up to 40 per run, first 10 runs a day. Runs always count toward your best.
- Near-miss messaging ("Missed your best by 37") and a WhatsApp share.
- A run idle for 2+ minutes is closed and paid, so nobody parks a streak. Leaving ends the run and keeps what you earned.

## Not in this step (as agreed)
Mystery Crates, Eye Rank ladder, theme badges, shareable Daily grid changes, daily rank.

## Tuning knobs (all in 028)
`_odd_survival_target` (difficulty heat), `_odd_survival_multiplier`, base points in `answer_odd_survival`, Second Wind cost 40, reward caps in `finish_odd_survival_run`.
