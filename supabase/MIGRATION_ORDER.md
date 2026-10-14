# Jua Quiz — Supabase SQL source of truth

The files in `supabase/` are the **active** database setup. They are intentionally
kept separate from obsolete snapshots in `supabase/archive/obsolete/` so an old
migration cannot accidentally be run after a newer replacement.

## Active order

1. `schema.sql` — baseline schema and original secure daily-challenge functions.
2. `002_optional_accounts.sql` — anonymous/guest accounts and leaderboard rules.
3. `003_phase1_practice_and_timezone.sql` — Nairobi day boundary, daily-submit
   hardening, and practice rounds. This supersedes the old standalone
   `003_nairobi_timezone.sql` and `004_practice_rounds.sql` files.
4. `004_more_questions.sql` — question-bank expansion. Safe to rerun because it
   skips questions whose exact text already exists.
5. `005_answer_feedback.sql` — server-side per-question answer locking and
   final scoring from recorded answers.
6. `006_rewarded_hints_second_chance.sql` — rewarded hints and second chances.
   This supersedes the earlier `006_hints_and_second_chances.sql` snapshot.
7. `007_competitions.sql` — coins, competitions, and the final integrations with
   the reward/help functions.
8. `008_guest_leaderboard.sql` — includes anonymous guest players on the global
   leaderboard; account creation remains optional for recovery after reinstall.
9. `009_practice_xp_cap_500.sql` — raises the daily Practice XP cap from 300 to 500.
10. `010_speed_quiz.sql` — server-authoritative Speed Quiz rounds, timing,
   scoring, progress, and XP award without changing the daily streak.

The seed files are content loaders and are not schema migrations:

- `seed_kenya_questions.sql`
- `seed_kenya_questions_batch2.sql`

## Important re-run rule

The production database may already have these changes applied. **Do not blindly
run every SQL file again.** For an existing project, apply only the next missing
migration, in order. If `007_competitions.sql` is rerun after changing the
reward system, rerun it last because it intentionally replaces two functions
from the reward migration.

## Obsolete files

`supabase/archive/obsolete/` preserves superseded SQL for historical reference;
it is not part of the active run order.


Active migration added in Phase 1 Step 13:

```text
011_coin_economy.sql
```

11. `011_coin_economy.sql` — explicit coin ledger/spending API and reward reasons.
12. `012_daily_missions.sql` — historical verification/smoke-check SQL for daily missions; it is not required as a schema migration if the mission schema is already present.
13. `013_achievements.sql` — server-authoritative achievement unlocks and claims.
14. `014_reward_chests.sql` — server-authoritative progression chest unlocks and reward claims.

15. `015_streak_rewards_shields.sql` — streak milestone rewards and one-day streak shields.

16. `016_streak_history.sql` — persistent Daily Challenge streak history, shield-use markers, and the streak dashboard RPC.

17. `017_guess_it.sql` — Guess It image-based game mode, server-authoritative hints, scoring and rewards.
18. `018_practice_journey.sql` — endless Practice Journey, 10-level batches, cumulative stars, and rewarded batch unlocks.
19. `019_practice_lives.sql` — five server-authoritative Practice Journey lives, five-minute independent recharge slots, and explicit abandoned-level sessions.

20. `020_odd_one_out.sql` — Odd One Out (daily set + quick play), server-authoritative scoring, hints and rewards.
21. `020_practice_difficulty_and_math.sql` — smooth easy/medium/hard curve per Practice level and generated Math levels at every 10th level. Run after 020_odd_one_out (both are numbered 020).
22. `021_mode_journeys.sql` — level journeys for Speed Quiz, Guess It and Odd One Out (stars, 5 lives per mode, batch gates, rewarded unlocks).
23. `022_level_difficulty_curve.sql` — the three mode journeys use the same difficulty curve as Practice. **Run after 020_practice_difficulty_and_math.** Do not run an older copy of 022: it overwrote Practice's Math-level function.
24. `024_content_quality.sql` — `questions.did_you_know`, `question_reports`, `report_question`, `get_question_fact`, `question_accuracy` view.
25. `seed_kenya_questions_batch3.sql` — 64 Kenyan questions with "Did you know?" lines (needs 024 first; safe to re-run).
26. `025_daily_login_calendar.sql` — 7-day daily reward calendar (`get_login_calendar`, `claim_login_reward`).
27. `026_daily_missions.sql` — daily missions backend (`daily_missions`, `get_daily_missions`, `claim_daily_mission`). Replaces the old note that no file defined it.
28. `seed_kenya_questions_batch4.sql` — 30 more questions (18 hard) and 20 Odd One Out puzzles. Needs 024 and 020_odd_one_out.
29. `027_guess_it_resume_and_png.sql` — Guess It pictures point at PNG files; resuming an unfinished round continues at the first unanswered question.
30. `028_odd_survival_run.sql` — Odd One Out Survival Run (strikes, streak multiplier, adaptive difficulty, Second Wind). Needs 020_odd_one_out and 026.
31. `seed_odd_one_out_pack1.sql` — 331 cleaned Odd One Out puzzles (179 easy, 134 medium, 18 hard). Needs 020_odd_one_out. Safe to re-run.
32. `029_odd_watch_hint.sql` — Odd One Out: watch a video to remove one wrong item (free, max 10 per day). Needs 020_odd_one_out.
33. `seed_odd_one_out_visual_pack.sql` — 58 harder picture puzzles (fruit vs vegetable, mammal vs bird...) and switches off the obvious visual ones (three identical pictures). Needs 020_odd_one_out.
34. `028_guess_it_reveal_and_facts.sql` — Guess It: 8-question rounds, 50/50 (first free) + sharper-picture hints, facts returned with answers. Needs 027 and the Guess It picture pack. Independent of the Odd One Out files above, so it can run before or after them. (Two files start with 028; their full names differ, so neither overwrites the other.)

> Note: `012_daily_missions.sql` is only a smoke check. The missions backend itself is `026_daily_missions.sql`.
