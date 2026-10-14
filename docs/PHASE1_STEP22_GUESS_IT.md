# Phase 1 — Step 22: Guess It

## Goal

Introduce the first image-based entertainment mode without weakening the server-authoritative reward model.

## Gameplay

- 5 pictures per round.
- 12–15 second question timers.
- Picture starts heavily blurred.
- Hint 1 reveals more of the picture.
- Hint 2 reveals more again.
- Hint 3 removes two wrong options.
- Hints cost 25, 40 and 60 coins respectively.
- Correct answers score more when answered quickly.
- Wrong answers and timeouts score 0.
- The server reveals the correct option only after the answer is submitted.
- Results award server-authoritative XP and coins.
- Results show personal best and support Play Again.

## Database

Migration `017_guess_it.sql` adds:

- `guess_it_questions`
- `guess_it_rounds`
- `guess_it_round_questions`
- `guess_it_answers`
- `guess_it_hints`
- `start_guess_it_round()`
- `get_guess_it_questions()`
- `use_guess_it_hint()`
- `answer_guess_it_question()`
- `submit_guess_it_round()`

Direct client access to the Guess It tables is revoked. RPCs are the public game API.

## Flutter

Added:

- `lib/models/guess_it.dart`
- `lib/services/guess_it_service.dart`
- `lib/screens/guess_it_screen.dart`
- `test/game/guess_it_test.dart`
- bundled starter SVG artwork in `assets/guess_it/`

Updated:

- `SupabaseService` with Guess It RPC wrappers.
- `GameHubScreen` so Guess It is playable instead of Coming Soon.
- `pubspec.yaml` to package the starter artwork.

## Content contract

Starter records use `asset:assets/guess_it/...` so the mode works immediately without depending on third-party image hosting. The same database field accepts HTTPS media URLs later when an admin/content pipeline is added.

## Validation

Run locally from this checkpoint:

```bash
flutter pub get
flutter test
flutter analyze
flutter run
```

Then apply `supabase/017_guess_it.sql` after migrations `001–016`.
