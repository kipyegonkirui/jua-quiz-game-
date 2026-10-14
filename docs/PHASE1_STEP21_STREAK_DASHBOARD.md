# Phase 1 — Step 21: Streak Dashboard & History

## Goal

Turn the Step 20 streak/shield system into a persistent player-facing dashboard.

## Added

- `lib/models/streak_dashboard.dart`
- `lib/screens/streak_dashboard_screen.dart`
- `supabase/016_streak_history.sql`
- `test/game/streak_dashboard_test.dart`

## Database

`streak_history` records each server-confirmed Daily Challenge completion:

- completion date
- resulting streak value
- whether a streak shield was consumed

Migration 016 also backfills historical Daily Challenge attempts. Historical
shield usage cannot be reconstructed from the old attempts table, so backfilled
rows have `shield_used = false`; all future shield usage is recorded by the
server-authoritative `submit_daily_attempt` function.

The new `get_streak_dashboard(p_days)` RPC returns:

- current streak
- longest streak
- shield inventory
- last completion date
- next milestone
- next milestone reward
- recent daily completion history

The RPC clamps the requested history window to 7–180 days.

## Flutter

The new Streak screen includes:

- current streak
- personal best
- shield inventory
- next milestone and progress bar
- milestone reward preview
- 90-day completion calendar
- shield-use markers
- milestone status
- return-to-Daily-Challenge messaging

The Progression Summary Card now exposes a **Streak** action.

## Authority

The client does not calculate or award streak rewards. Step 20 remains the
source of truth for streak transitions, milestone rewards, and shield use.
Step 21 only persists and displays the authoritative result.

## Apply

Run migration 016 only after migrations 001–015 have been applied in order.

```text
supabase/016_streak_history.sql
```

## Validation

From the Flutter project:

```text
flutter pub get
flutter test
flutter analyze
flutter run
```

This environment does not contain the Flutter/Dart SDK, so those commands must
be run on the development machine.
