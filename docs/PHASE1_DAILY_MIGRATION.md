# Phase 1 — Daily Challenge Migration

## Status

Daily Challenge now uses `GameSession` for client-side gameplay state while preserving the existing Supabase-backed behavior.

## Shared engine responsibilities

- current question index
- selected option
- settled answer history
- answer-pending state
- advancing between questions
- completion state
- question timing timestamps

## Server-authoritative responsibilities retained

- answer validation
- correct-answer disclosure
- second-chance state
- hints and hint purchases
- challenge submission
- score calculation
- XP and level updates
- streak updates

## Adapter

`lib/game/adapters/daily_game_adapter.dart` translates the existing `Question`, `AnswerResult`, and `AttemptResult` models into the shared game contracts.

## Intentionally unchanged

- Daily Challenge result UI
- streak/result presentation
- Ads behavior
- AppEvents behavior
- Supabase RPC names and payloads
- guest/account flows

## Validation target

Run:

```powershell
flutter analyze
flutter test
flutter run
```

Then verify Daily Challenge start/resume, normal answers, second chance, hint, completion, and the results screen.
