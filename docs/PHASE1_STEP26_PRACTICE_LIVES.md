# Phase 1 — Practice Lives

## Rules

- Practice Journey has **5 lives**.
- Starting a level consumes exactly **1 life** after the server confirms the level is unlocked.
- Each consumed life slot starts its own **5-minute recharge** immediately.
- A successful level still uses the life; the UI does not call this a burst.
- A failed level (0 stars) visually **bursts/breaks** the used life.
- Leaving an open level explicitly abandons the session. The consumed life is **not refunded**.
- The next attempt starts a fresh session and consumes another available life.
- If the app is killed while a level is open, the next server start safely marks the orphaned session abandoned before creating a new attempt.
- The server is authoritative for life availability; the client countdown is display-only.

## Recharge

Each of the five slots is independent. If four lives are available and one is cooling down, the earliest recharge time is displayed. When that slot reaches five minutes, it becomes available again.

## Level failure

A level earns 0 stars when the server score is 0. The existing star rules remain unchanged:

- 0 correct → 0 stars
- 1–69% → 1 star
- 70–99% → 2 stars
- 100% → 3 stars

A 0-star result requires **RETRY LEVEL**. A 1–3-star result can continue when the next level is unlocked.

## SQL

Apply `019_practice_lives.sql` after `018_practice_journey.sql`.


## Step 28 lifecycle correction
A life is reserved when a Practice level starts, but no cooldown begins. If the player earns 1–3 stars, the reserved life is returned immediately and the next level can begin with the full life pool. If the player earns 0 stars or exits an unfinished level, the reserved life bursts and starts a five-minute recharge. A stale open level is treated as abandoned and bursts its reserved life before another level can start.
