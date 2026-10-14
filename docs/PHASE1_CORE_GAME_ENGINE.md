# Phase 1 — Core Game Engine

## Step 1: Core contracts

This step introduces backend-agnostic game contracts without changing the existing Daily Challenge, Practice, or Competition screens.

### Added

```text
lib/game/
├── engine/
│   └── game_session.dart
└── models/
    ├── game_answer.dart
    ├── game_mode.dart
    ├── game_question.dart
    └── game_result.dart
```

### Session lifecycle

```text
READY → IN PROGRESS → ANSWER PENDING → IN PROGRESS → ... → COMPLETED
```

`GameSession` owns in-memory gameplay state only. It has no Flutter or Supabase dependencies.

### Intentional boundary

The existing `Question`, `AnswerResult`, and `AttemptResult` models remain unchanged for now. Existing screens therefore continue to use the already-tested Supabase flow.

The next Phase 1 step is to add adapters/services that translate the existing Supabase question/answer structures into these generic game contracts, then migrate **Practice** first.


## Step 2: Practice adapter and migration

Practice now owns its playable session state through `GameSession` while keeping
Supabase authoritative for answer validation and round scoring.

### Added

```text
lib/game/
└── adapters/
    └── practice_game_adapter.dart

 test/game/
└── practice_game_adapter_test.dart
```

### Practice boundary

```text
Supabase Practice RPCs
        ↓
Existing Question / AnswerResult / AttemptResult
        ↓
PracticeGameAdapter
        ↓
GameSession
        ↓
Existing Practice UI
```

The migration preserves existing behavior for:
- five-question Practice rounds
- resumed unfinished rounds
- hints and second chances
- server-side answer checking
- server-side XP/scoring
- Practice results and Play Again

A second-chance `retry_offered` response is not recorded as a settled `GameAnswer`.
It is recorded only after the question reaches a final server verdict.

## Step 4: Shared answer mapping and scoring

Practice and Daily Challenge share one `GameAnswerMapper` for converting
settled server answer verdicts. A pure `GameScorer` defines the reusable
correctness/speed/difficulty/mode scoring policy for future local game modes;
existing server-backed modes remain authoritative on Supabase.
