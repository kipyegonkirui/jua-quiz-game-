# Phase 1 — Step 10: Shared Progression Handoff

## Goal

Give Practice, Daily Challenge, and Speed Quiz one consistent handoff after a server-confirmed result.

## Flow

```text
mode-specific Supabase RPC
        ↓
GameResultMapper
        ↓
GameResult
        ↓
GameProgressionService
        ↓
UserProfile projection
        ↓
AppEvents.publishProfile
        ↓
Stats / Leaderboard update immediately
```

## Rules

- Supabase remains authoritative for correctness, scores, XP, coins, and streaks.
- `GameProgressionService` is a pure client-side projection; it never grants server rewards.
- Practice increments `practiceRounds` but not `totalAttempts`.
- Daily Challenge increments `totalAttempts` and records `lastCompletedDate`.
- Speed Quiz increments `totalAttempts`.
- `coinsEarned` is supported by the shared contract; current mode payloads default to zero until a server reward is returned.
- `publishProfile()` already bumps the app data version, so the old duplicate `notifyProgressChanged()` calls were removed from the three completion screens.

No new Supabase SQL is required for Step 10.
