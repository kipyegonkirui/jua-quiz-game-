# Phase 1 Step 20 — Streak Rewards & Streak Shields

## Goal
Turn streak milestones into concrete rewards and protect one missed Daily Challenge with a server-authoritative streak shield.

## Milestones
- 3 days: 100 coins
- 7 days: 1 streak shield
- 14 days: 500 coins
- 30 days: 1 streak shield
- 60 days: 2 streak shields
- 100 days: 3 streak shields

The existing roadmap also mentions badges/avatars at later milestones. Those cosmetics are intentionally not added here because the current project has no cosmetic inventory system yet.

## Shield behavior
A shield protects exactly one missed Daily Challenge day. If the last completion was exactly two Nairobi calendar days ago and a shield is available, the next completion continues the existing streak and consumes one shield. A gap of more than one missed day still breaks the streak.

Rewards and shield consumption are performed inside the Supabase completion RPC, not trusted to the Flutter client.
