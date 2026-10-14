# Jua Quiz Practice Journey

## Product decision

Practice is now a Candy-Crush-style endless journey rather than an unstructured list of rounds.

- Levels are grouped into batches of 10.
- Each level can earn 0–3 stars.
- A completed level remains replayable forever.
- Replays only improve the stored best result; stars never decrease.
- The next batch is unlocked by cumulative mastery across all opened batches.
- Batch requirements become stricter as the journey advances.

## Star rules

- 0 stars: no correct answer.
- 1 star: completed with at least one correct answer.
- 2 stars: at least 70% correct.
- 3 stars: perfect score.

There are always 30 possible stars per 10-level batch, regardless of the number of questions in each level.

## Cumulative unlock gates

| Next batch | Cumulative levels considered | Requirement |
|---|---:|---:|
| 2 | 1–10 | 15 / 30 (50%) |
| 3 | 1–20 | 45 / 60 (75%) |
| 4 | 1–30 | 72 / 90 (80%) |
| 5 | 1–40 | 102 / 120 (85%) |
| 6 | 1–50 | 132 / 150 (88%) |
| 7+ | all previously opened batches | 90% |

The denominator increases by 30 each time a batch opens. A player can recover missing stars by replaying any previous level.

## Difficulty progression

- Batches 1–2: easy-focused question selection.
- Batches 3–4: medium-focused selection.
- Batch 5 onward: hard-focused selection, with a fallback to nearby difficulty so the server can still fill a level.
- Question count increases from 5 per level, up to 10 per level.

## Rewarded unlocks

A locked batch can optionally be opened through a fixed allowance of 3 rewarded videos for that batch. The server records each earned ad unlock and grants the batch after the third.

The ad unlock does **not** grant stars. Stars remain a record of gameplay mastery.

Premium/IAP is intentionally only represented in the data model at this stage. No insecure client-side "premium unlock" RPC is exposed. Store purchase verification should be added when the billing layer is introduced.

## Server authority

Migration `018_practice_journey.sql` adds:

- `practice_level` to `practice_rounds`.
- `practice_level_progress` for best stars/scores and attempts.
- `practice_batch_unlocks` for rewarded/premium access state.
- `start_practice_level_round()`.
- `get_practice_journey()`.
- `unlock_practice_batch_by_ad()`.
- an updated `submit_practice_round()` that calculates and persists stars.

The client never decides whether a locked level or batch is playable.
