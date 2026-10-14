# Leaderboard instant XP update

## What changed

The leaderboard now mirrors the latest `AppEvents.profile` snapshot immediately after a confirmed round, just like Stats.

- The current user's XP, level, streak and username are overlaid on the existing leaderboard snapshot.
- The overlay is re-ranked immediately using XP.
- A completed round triggers an immediate local rebuild instead of replacing the visible list with a loading Future.
- The remote leaderboard query then runs quietly in the background and replaces the snapshot when it completes.
- The leaderboard service also overlays the current profile when it queries the server view, protecting against the short delay between the profile update and the view reflecting it.

## Supabase

No SQL migration is required. The existing `leaderboard` view remains server-authoritative; this is a client-side freshness improvement for the current player's row.

## Verification

After replacing the project, run:

```powershell
flutter pub get
flutter test
flutter analyze
flutter run
```

Complete a Practice, Daily Challenge, or Speed Quiz round and open/observe Leaderboard immediately. The player's new XP should appear without waiting for the remote leaderboard refresh.
