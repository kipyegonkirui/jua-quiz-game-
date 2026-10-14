# Phase 1.3 — Compile Gate

## Current result
The Phase 1.2 baseline contained two obsolete, unused implementations:
- `lib/screens/practice_round_screen.dart`
- `lib/services/quiz_session.dart`

They referenced APIs that no longer exist in the active Supabase service and were responsible for most analyzer errors.

## Changes
- Removed the two obsolete implementations.
- Added `SupabaseService.signIn()` using Supabase password authentication.
- Added `SupabaseService.signUp()` with username metadata for the existing profile trigger.
- Switched Supabase initialization to `publishableKey`.
- Removed two lint-only unnecessary underscore warnings.

## Required local validation
Run from the project root:

```bash
flutter pub get
flutter analyze
flutter test
```

The live gameplay portion of Phase 1.3 starts only after the analyzer is clean and tests pass.
