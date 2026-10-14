# Phase 1 — Shared Answer & Scoring Flow

## Step 4

The existing Practice and Daily adapters now use one shared `GameAnswerMapper`
for converting a settled `AnswerResult` into a `GameAnswer`.

A pending `retry_offered` response is deliberately not recorded as a settled
answer.

A pure `GameScorer` has also been added for new/local game modes. Its score is
composed from:

```text
correctness
+ speed bonus
+ difficulty bonus
+ mode bonus
```

Practice, Daily Challenge, and Competition **do not use this local calculation
for authoritative results**. Their current Supabase RPCs remain the source of
truth. The scorer is designed so a matching Supabase function can later
validate the same policy.

## New files

```text
lib/game/mappers/game_answer_mapper.dart
lib/game/scoring/game_score.dart
lib/game/scoring/game_scorer.dart
test/game/game_answer_mapper_test.dart
test/game/game_scorer_test.dart
```
