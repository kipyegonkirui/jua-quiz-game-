# Phase 1 — Step 11: Streak System

## Status
Implemented on the latest UI/Step 10-compatible checkpoint.

A pure `StreakService` models daily streak transitions for client-side presentation and fallback projection. The Daily Challenge Supabase RPC remains authoritative for persisted streak values.

### Rules
- First daily completion starts a streak at 1.
- Completing the same daily challenge again does not increment the streak.
- Completing on the following day increments the streak by 1.
- Missing at least one day resets the current streak to 1.
- The best streak is preserved.
- Milestones are 3, 7, 14, 30, 60, and 100 days.

### Architecture
`GameProgressionService` consumes `StreakService` only when a Daily Challenge result does not contain authoritative streak values. When the server provides `current_streak` and `longest_streak`, those values are used unchanged.

No Supabase SQL migration was added in Step 11.
