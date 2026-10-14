# Phase 1 — Step 14: Daily Missions

Adds five daily missions backed by Supabase. Progress is advanced only by authoritative completion RPCs for Daily Challenge, Practice, and Speed Quiz. Mission rewards are claimed server-side through `claim_daily_mission()`.

Active migration: `012_daily_missions.sql` (after `011_coin_economy.sql`).

Mission types: answer_questions, correct_answers, earn_xp, complete_rounds, perfect_round.
