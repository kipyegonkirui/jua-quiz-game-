# Practice Journey — Polish & Stabilization

## Step 29

This pass keeps the Step 28 life rules and improves the player-facing loop.

### Life rules
- A level reserves a life but does not start a cooldown.
- ⭐1–3 returns the reserved life immediately.
- 0 ⭐ bursts the life and starts a five-minute cooldown.
- Exiting an unfinished level abandons the round and bursts the reserved life.
- Successful progression therefore does not consume lives.

### UX polish
- Practice Journey life card explains pass/refund versus fail/exit/burst.
- Active-level life badge shows the life pool as safe while the attempt is active.
- Results use a clear LIFE RETURNED / LIFE BUSTED outcome.
- Failed result countdown is based on the live recharge timestamp.
- Level nodes show star mastery plus question count/difficulty.
- Locked batch copy emphasizes the exact number of missing stars and replay path.

No new Supabase migration is required for Step 29.
