# Phase 1 — Practice Migration

## Status

Practice is the first existing mode migrated onto the shared game layer.

## What changed

- Added `PracticeGameAdapter` to translate the current backend models into the generic game models.
- `PracticeScreen` now stores its current question, selected option, answer history, and session lifecycle in `GameSession`.
- Existing Supabase RPCs remain unchanged and authoritative.
- Existing hints, second chances, ads, XP publication, results, and Play Again behavior remain in place.

## Important behavior

A server response with `status = retry_offered` is not a settled answer. The adapter therefore ignores it until the player either uses the second chance or declines it and receives a final answer.

## Validation on the developer machine

```bash
flutter analyze
flutter test
flutter run
```

The release AAB build remains subject to Android/Gradle network availability.
