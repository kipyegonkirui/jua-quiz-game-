# Phase 1 — Step 7: Shared Lifecycle & Scoring Boundary

This step hardens the boundary between generic game state and mode-specific rules.

## Added

- `GameRules`: immutable per-mode configuration for time limits, local scoring,
  retry/hint availability, and auto-advance behavior.
- `GameController` can optionally accept `GameRules` + `GameScorer`.
- Local/new modes can read `lastScore` and `localScore` immediately after a
  settled answer.
- Server-backed Practice and Daily remain unchanged because they do not opt
  into local scoring.
- `GameSession` exposes `remainingCount` and elapsed time for the current turn.

## Security boundary

Practice, Daily Challenge, and Competition still rely on Supabase for
correctness and authoritative scoring. The client scorer is for immediate
feedback in new modes and must be mirrored/validated server-side before any
competitive score is trusted.

## No Supabase SQL changes

No migration is required for this step.

## Verification

Run locally from the project root:

```powershell
flutter pub get
flutter test
flutter analyze
flutter run
```

Then re-check Practice and Daily to ensure their existing server-backed flows
remain unchanged.
