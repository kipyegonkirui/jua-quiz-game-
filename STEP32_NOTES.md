# Step 32 — Question selection follows a difficulty curve

**Run `supabase/022_level_difficulty_curve.sql` (after 021).**

Before: Practice only preferred "this batch's" difficulty (batches 1-2 easy, 3-4 medium, 5+ hard) and the
other modes dealt fully random questions. Now every journey level gets an explicit mix:

| Level | 5-question level (easy/med/hard) |
|---|---|
| 1 | 5 / 0 / 0 |
| 10 (boss) | 2 / 3 / 0 |
| 20 (boss) | 1 / 3 / 1 |
| 30 (boss) | 0 / 3 / 2 |
| 45 | 0 / 2 / 3 |
| 60+ | 0 / 0 / 5 |

- Ramp: h = min((level-1)/59, 1); every 10th level is a boss (+0.15). hard share = clamp((h-0.4)/0.6),
  easy share = clamp(1-h/0.6), medium = rest. Questions in a level are ordered easy -> hard.
- If a difficulty runs short, the nearest one fills in, so small pools never break a level.
  Unseen / least-recently-seen questions are picked first; today's daily questions come last (Practice).
- Practice: `start_practice_level_round` replaced (copy of 019 with the new selection).
- Speed Quiz / Guess It / Odd One Out: `start_mode_level` re-deals a brand-new round with the curve
  (`_mode_deal_level`); resumed rounds are left alone. Speed Quiz keeps its random deal if fewer than 10 fit.
- Map ribbons show the real difficulty (Dart mirror: `journeyDifficultyLabel` in `mode_journey.dart`).
- The tuning knobs are the 0.4 / 0.6 / 59 / 0.15 constants in `mode_level_difficulty_mix` (and the Dart mirror).

## Content limits (important)
Seed data is skewed easy/medium, e.g. only ~18 hard general questions, 1 hard Guess It, 5 hard Odd One Out.
From about level 40 the "hard" share will be filled with medium questions and repeat often until more hard
questions are added.
