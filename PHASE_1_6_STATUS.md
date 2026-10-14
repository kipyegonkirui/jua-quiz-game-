# Phase 1.6 — Practice & Daily GameController Migration

## Status
Implemented.

## Changes
- `PracticeScreen` now owns a `GameController` instead of directly replacing `GameSession` state.
- `DailyChallengeScreen` now owns a `GameController` instead of directly replacing `GameSession` state.
- Practice answer submission uses the controller resolver and the existing `answerPracticeQuestion` RPC.
- Daily answer submission uses the controller resolver and the existing `answerDailyQuestion` RPC.
- Second-chance decline remains a dedicated Supabase operation; its settled result is injected through `recordSettledAnswer()`.
- Persisted second-chance offers are restored with `restoreRetryPending()`.
- Round completion is finalized through `GameController.complete()` after backend round submission.
- No Supabase SQL changes are required for this step.

## Validation to run locally
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Manual regression checks
- Practice: start, answer, wrong answer + second chance, decline second chance, hint, next, finish, play another.
- Practice: reopen an unfinished round and verify resume.
- Daily: answer, hints, second chance, decline, finish, streak/results.
- Daily: reopen an unfinished challenge and verify resume.
