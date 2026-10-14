# Phase 1 — Speed Quiz Hotfix

Fixes the local integration issues reported after Step 8:

- Speed Quiz RPC wrapper methods are present in `SupabaseService`.
- Speed Quiz adapter tests no longer use `const GameAnswer` with a runtime `DateTime` variable.
- Removed the unused `_questions` field from `SpeedQuizScreen`.
- Removed the unnecessary non-null assertion on `GameScorer` usage.

No Supabase SQL migration changes are included in this hotfix.
