# Phase 1 — Game Controller

The shared game layer now contains `GameController`, an imperative orchestrator
around `GameSession`.

## Responsibilities

- select the current option
- calculate question elapsed time
- invoke a backend/local answer resolver
- keep retry-offer questions unsettled
- record settled answers in `GameSession`
- advance only after a settled answer
- replace a reconstructed session after app resume

The controller has no Flutter or Supabase dependency. Practice/Daily can pass a
resolver that calls their existing Supabase RPC and maps `AnswerResult` through
the existing game adapter. Future local modes can return `GameAnswerResolution`
directly.

## Retry lifecycle

```text
IN PROGRESS
    |
    | submit first pick
    v
RETRY PENDING  ----> second pick ----> ANSWER PENDING
    |                                  |
    +-- no second chance ------------> |
                                       v
                                   ADVANCE
```

A retry offer never increments `answeredCount` and never reveals the correct
answer until the server returns a settled response.
