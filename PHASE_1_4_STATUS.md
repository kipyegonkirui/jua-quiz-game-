# Phase 1.4 — Shared Game Controller

Added the backend-agnostic `GameController` orchestration layer.

## Added

- `lib/game/engine/game_controller.dart`
- `lib/game/models/game_answer_resolution.dart`
- `test/game/game_controller_test.dart`

## Session refinement

`GameSessionStatus.retryPending` now explicitly represents an unsettled
second-chance offer. A retry offer does not increment the settled answer count,
and the controller will not advance until the server/local resolver returns a
settled `GameAnswer`.

## Scope

The existing Practice and Daily screens are intentionally not replaced in this
step. Their Supabase RPCs remain authoritative. The controller is ready for the
next migration pass and for new game modes that use local or server-backed
answer resolvers.
