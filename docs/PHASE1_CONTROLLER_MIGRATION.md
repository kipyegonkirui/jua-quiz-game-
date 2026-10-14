# Phase 1 — Step 6: Practice & Daily Controller Migration

Both server-backed quiz screens now use `GameController` as the owner of client-side session state.

## Boundary

- `GameController` owns selection, timing, answer submission orchestration, retry-pending state, advancement, and completion state.
- Supabase remains authoritative for correctness, hints, second chance, XP, coins, streaks, and final round submission.
- `PracticeGameAdapter` and `DailyGameAdapter` continue translating existing server models into generic game-engine models.

## Practice

`PracticeScreen` resolves answers through `GameController.submitSelected()`, using the existing `answerPracticeQuestion` RPC.

## Daily Challenge

`DailyChallengeScreen` resolves answers through `GameController.submitSelected()`, using the existing `answerDailyQuestion` RPC.

## Special server path

Declining a second-chance offer is still a dedicated Supabase operation. The returned settled answer is injected into the controller with `recordSettledAnswer()`.

No Supabase SQL changes are required for this step.
