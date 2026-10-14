# Phase 0 — Baseline Reconciliation

Jua Quiz v3 is the application baseline. The Supabase package supplied alongside
it is now incorporated into this project as the canonical database source.

## Cleanup performed

- Removed Flutter/Dart generated state: `.flutter-plugins*`, build/cache state,
  platform `ephemeral` directories, Android Gradle/Kotlin state, and machine-
  specific `android/local.properties`.
- Removed IDE-local project files (`.idea/` and `*.iml`).
- Replaced the incomplete `supabase/` folder with the supplied canonical SQL set.
- Moved superseded SQL snapshots into `supabase/archive/obsolete/`.
- Kept `008_guest_leaderboard.sql` as migration 008.
- Renumbered the Practice XP cap patch to `009_practice_xp_cap_500.sql`.
- Corrected stale `mobile_app/` and parent-directory Supabase references in docs.

## Canonical migration order

1. `schema.sql`
2. `002_optional_accounts.sql`
3. `003_phase1_practice_and_timezone.sql`
4. `004_more_questions.sql`
5. `005_answer_feedback.sql`
6. `006_rewarded_hints_second_chance.sql`
7. `007_competitions.sql`
8. `008_guest_leaderboard.sql`
9. `009_practice_xp_cap_500.sql`

Seed files are content loaders, not migrations. Superseded migrations remain only
for historical reference under `supabase/archive/obsolete/`.

## Validation status

The source tree has been structurally reconciled. Flutter `analyze`, `test`, and
release-build validation still need to be run in a local Flutter SDK environment.
