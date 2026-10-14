# Jua Quiz

Jua Quiz is a Kenya-focused trivia app built with Flutter and Supabase.

## Current product areas

- Daily challenge and streaks
- Guest accounts with optional email linking
- Practice rounds
- Per-question answer feedback
- XP, levels and accuracy stats
- Rewarded hints and second chances
- Coins and scheduled competitions
- Leaderboard
- AdMob banner, interstitial and rewarded-ad flows
- OneSignal notifications

## Development checks

From the project root:

```bash
flutter pub get
flutter analyze
flutter test
```

The test suite includes unit coverage for the XP/level calculations. The app's
network-backed flows should also be tested against the configured Supabase
project rather than mocked as a replacement for end-to-end verification.

## Supabase

See [`supabase/MIGRATION_ORDER.md`](supabase/MIGRATION_ORDER.md) for the
canonical SQL order. Do not execute obsolete files under
`supabase/archive/obsolete/`.

The Supabase anonymous key in `lib/config/app_config.dart` is a client-side
anon key, not a service-role secret. Keep service-role credentials out of the
Flutter app.

## Ads

The project currently uses Google's public test AdMob IDs. Replace them only
when the production AdMob app/ad units are ready for release. Production
release signing and Play Store configuration remain launch-preparation work.

## Baseline validation

Phase 0.5 repository-level validation is documented in `docs/PHASE0_5_VALIDATION.md`. Flutter/Dart command-line checks must be run in a local Flutter environment before release builds.

## Phase 1 Step 14
Daily Missions added via `supabase/012_daily_missions.sql`, plus Flutter mission models/service/screen.
