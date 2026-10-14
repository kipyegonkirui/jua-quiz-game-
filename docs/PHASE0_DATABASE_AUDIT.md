# Jua Quiz — Phase 0.3 Database Compatibility Audit

## Baseline

The canonical migration chain is:

1. `schema.sql`
2. `002_optional_accounts.sql`
3. `003_phase1_practice_and_timezone.sql`
4. `004_more_questions.sql`
5. `005_answer_feedback.sql`
6. `006_rewarded_hints_second_chance.sql`
7. `007_competitions.sql`
8. `008_guest_leaderboard.sql`
9. `009_practice_xp_cap_500.sql`

The older 003/004/006 snapshots remain historical under `supabase/archive/obsolete/`.

## Flutter RPC compatibility

The current Flutter `SupabaseService` calls these server functions, and each has a
matching final function signature in the active SQL chain:

- `get_or_create_today_challenge()`
- `get_challenge_questions(uuid)`
- `answer_daily_question(uuid, uuid, text)`
- `get_daily_progress(uuid)`
- `submit_daily_attempt(uuid)`
- `start_practice_round()`
- `get_practice_questions(uuid)`
- `answer_practice_question(uuid, uuid, text)`
- `get_practice_progress(uuid)`
- `submit_practice_round(uuid)`
- `get_help_state(text, uuid)`
- `claim_reward(text, uuid, uuid, text)`
- `use_hint(text, uuid, uuid)`
- `decline_second_chance(text, uuid, uuid)`
- `buy_hint(text, uuid, uuid)`
- `list_competitions()`
- `start_competition_entry(uuid)`
- `competition_next_question(uuid)`
- `competition_answer(uuid, uuid, text)`
- `get_competition_results(uuid)`

## Findings

### Fixed

`supabase/VERIFY_PHASE1.sql` previously checked for `public.practice_answers`.
That table is not part of the active schema. Practice answers are stored on
`public.practice_round_questions` in the `chosen` and `is_correct` columns.
The verification script now checks the real table and explicitly checks that the
obsolete two-argument submission functions are absent.

### Non-blocking observation

`public.questions_public` is present in `schema.sql`, but the application does
not currently use it. Because it uses `security_invoker = true` while the base
`questions` table has no general authenticated SELECT policy, direct use by a
normal player is intentionally unavailable. The app correctly gets questions
through server functions that omit `correct_option`.

### Security baseline

The active answer/scoring path is server-authoritative. The player-facing RPCs
are granted to `authenticated`, the answer-bearing tables are not directly
writable by clients, and the raw question table does not expose its answer key
through a normal client SELECT path.

## Remaining Phase 0 gate

This audit is static. A live Supabase project has not been modified or executed
by this cleanup. The final baseline gate still requires running the verifier in
Supabase SQL Editor and running:

- `flutter analyze`
- `flutter test`
- `flutter build appbundle --release`
