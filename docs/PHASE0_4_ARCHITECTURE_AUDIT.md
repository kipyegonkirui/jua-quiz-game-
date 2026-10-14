# Jua Quiz — Phase 0.4 Flutter Architecture Audit

## Purpose

This audit reviews the cleaned v3 Flutter source before the reusable game engine work begins. It identifies what should be preserved, what should be refactored, and what must not be mixed into the first architecture rewrite.

This is an **audit only**. No gameplay architecture has been rewritten in this phase.

## 1. Current source shape

```text
lib/
├── config/
├── models/
├── screens/
├── services/
├── theme/
└── widgets/
```

The current application is a feature-oriented Flutter app. Most screen state is managed locally with `StatefulWidget` + `setState` and backend access is centralized through `SupabaseService`.

## 2. What is already good and should be preserved

### Single backend access point

`SupabaseService` is currently the only application service that talks directly to Supabase for gameplay/account data. This is a useful seam and should remain during the transition.

### Reusable quiz presentation

`QuizView` and `OptionTile` in `quiz_widgets.dart` are already shared by Daily Challenge and Practice. This is the correct direction for the eventual game engine.

### Server-authoritative answers and rewards

Screens request answer verdicts and round results from the backend instead of calculating authoritative XP/results locally. That should remain the security boundary when new game modes are introduced.

### Local guest persistence

`GuestProgressStore` is isolated from the widgets and is a reasonable adapter for device-scoped guest progress.

### App-wide refresh signaling

`AppEvents` currently provides a small communication layer between the shell, stats, leaderboard, and quiz screens. It works for the current feature set and should not be ripped out until an explicit state-management replacement exists.

## 3. Main architectural debt

### A. `SupabaseService` is too broad

The service currently combines multiple responsibilities:

```text
Authentication
Profile loading / publishing
Guest reconciliation
Daily Challenge
Practice
Hints
Second Chance
Rewards
Coins
Competitions
Leaderboard
```

It is already about 669 lines. New modes added directly to this class would turn it into a large all-purpose backend service.

**Decision:** keep the public behavior for now, but split it later behind focused repositories/services.

Proposed target:

```text
core/backend/
├── auth_repository.dart
├── profile_repository.dart
├── quiz_repository.dart
├── competition_repository.dart
└── leaderboard_repository.dart
```

Do not perform this split until the shared game contracts are defined.

### B. Daily and Practice screens duplicate the quiz controller logic

Both screens independently implement most of the same lifecycle:

```text
start round
load questions
restore answers
select option
check answer
handle hint
handle second chance
move to next question
finish round
show results
play another round
```

`DailyChallengeScreen` and `PracticeScreen` are therefore the strongest evidence that the reusable game engine is needed.

**Decision:** extract the state machine/controller, not the entire screen UI.

Target shape:

```text
GameSession
GameQuestionState
GameSessionController
GameResult
```

with mode-specific adapters for Daily, Practice, Competition, etc.

### C. `QuizView` is reusable but still assumes the current two-step MCQ flow

The widget assumes:

```text
four options: a/b/c/d
pick → Check answer → server result → Next
```

That works for today's Daily/Practice modes, but it is not yet a generic game engine contract.

The future engine must support different interaction models without forcing every game into this widget.

Examples from the roadmap include Speed Quiz, Guess It, Odd One Out, Find the Difference, Football Challenge, and World Challenge.

**Decision:** keep `QuizView` as the existing MCQ presentation component; do not make it the universal game widget.

### D. `AppEvents` is a global event bus

`AppEvents` uses static `ValueNotifier`s for:

```text
tab requests
data refresh version
profile snapshot
active quiz tabs
```

This is adequate for the current small application but will become difficult to reason about as progression, missions, achievements, rewards, social features, and notifications are added.

**Decision:** retain it temporarily for compatibility; later replace individual responsibilities with explicit application state/controllers.

### E. Screen classes contain too much orchestration

The largest screens are:

```text
DailyChallengeScreen       ~532 lines
PracticeScreen             ~526 lines
CompetitionsScreen         ~443 lines
CompetitionPlayScreen      ~363 lines
```

They mix asynchronous orchestration, state transitions, business rules, snackbar/error handling, and widget composition.

**Decision:** future refactors should move state transitions and business decisions out first, then split the UI into smaller presentation widgets.

## 4. Model constraints that will matter for the game engine

### `Question`

The existing question model represents the current four-option multiple-choice format. This should remain supported, but the model should not become the sole representation for all game modes.

The game engine should eventually distinguish:

```text
Question content
Interaction type
Round state
Answer state
Scoring data
```

rather than putting every future mode-specific field into one huge `Question` class.

### Competition models

Competition already has a richer state model than Daily/Practice. This is useful evidence that the engine should treat a game session as stateful rather than just a list of questions.

## 5. Small cleanup candidates

These were found to have no current Dart imports/usages in the source tree:

```text
lib/models/practice_result.dart
lib/widgets/quiz_option_tile.dart
```

They should be removed only after the baseline test/build gate confirms there are no generated or external references.

They are not required by the first game-engine refactor.

## 6. Dependencies

The current runtime dependencies include:

```text
supabase_flutter
app_links
google_mobile_ads
onesignal_flutter
shared_preferences
```

There is currently no external state-management package. The application is therefore relying on Flutter's local state, `FutureBuilder`/`StreamBuilder`-style patterns, and `ValueNotifier` signals.

**Decision:** do not introduce a state-management framework merely for the sake of refactoring. First define the game contracts and isolate responsibilities. A framework can then be selected only if the resulting architecture actually benefits from it.

## 7. Target architecture for Phase 1

The master roadmap calls for a reusable game engine capable of running multiple modes without rebuilding scoring/progression logic for each mode.

The first target should therefore be:

```text
lib/
├── core/
│   ├── animations/
│   ├── audio/
│   ├── haptics/
│   ├── theme/
│   └── utils/
│
├── game/
│   ├── engine/
│   ├── models/
│   ├── scoring/
│   └── feedback/
│
├── modes/
│   ├── practice/
│   ├── daily/
│   ├── speed_quiz/
│   ├── guess_it/
│   ├── odd_one_out/
│   ├── find_difference/
│   └── football/
│
├── progression/
│   ├── xp/
│   ├── coins/
│   ├── streaks/
│   ├── missions/
│   ├── achievements/
│   └── rewards/
│
├── social/
│   ├── friends/
│   ├── challenges/
│   └── leaderboard/
│
└── ads/
```

This is a **target**, not a request to move every file immediately.

## 8. Refactor order

The safest order is:

```text
1. Freeze existing screen behavior.
2. Define game-domain models/contracts.
3. Extract shared game-session state from Daily/Practice.
4. Extract mode adapters around the existing Supabase RPCs.
5. Keep existing UI working against the new controller.
6. Add scoring as a separate deterministic service.
7. Add FeedbackService / SoundService later.
8. Only then introduce new game modes.
```

## 9. What we should NOT do yet

Do not:

```text
- rewrite all screens at once
- replace SupabaseService wholesale
- add a state-management framework just because the app is growing
- merge Competition into the Daily/Practice UI model
- make QuizView handle every future game type
- add animations/sound/haptics before the session architecture is stable
```

## Phase 0.4 conclusion

The existing app is suitable as the base for the master roadmap. The central architectural issue is not that the code is unusable; it is that **game behavior is currently embedded inside feature screens** and backend responsibilities are concentrated in one large service.

The next implementation phase should therefore introduce the reusable game contracts and session engine **without changing the existing Daily/Practice user experience first**.

## Phase 0.5 input

The architecture audit leaves the project with these known test/build expectations:

```text
flutter analyze
flutter test
flutter build appbundle --release
```

Those commands remain the release gate before Phase 1.
