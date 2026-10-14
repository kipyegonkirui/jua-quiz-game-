# Phase 1 — Step 9: Shared Result Pipeline

## Goal
Normalize completion payloads from Practice, Daily Challenge, and Speed Quiz into one `GameResult` contract.

## Boundary
Mode-specific Supabase RPCs remain authoritative for correctness, scoring, XP, coins, streaks, and final settlement. `GameResult` is a client-side presentation/data contract; it does not grant persistent rewards.

## Mapping
- Practice/Daily: `AttemptResult` -> `GameResultMapper.fromAttemptResult`
- Speed Quiz: `SpeedQuizResult` -> `GameResultMapper.fromSpeedQuizResult`

`correct` is explicit so scored modes such as Speed Quiz do not accidentally treat a points total as an answer count.

No Supabase SQL changes are required for Step 9.
