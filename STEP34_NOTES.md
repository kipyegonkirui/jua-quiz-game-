# Step 34: missions backend, Speed Quiz facts, more hard content

Dart is still uncompiled (no Flutter SDK here). SQL ran on real Postgres 18.

## Run after 025
1. `026_daily_missions.sql`  2. `seed_kenya_questions_batch4.sql`

## What changed
- Missions: 3 per Nairobi day (easy, medium, stretch) picked from a pool of 9. Progress is counted live from Daily, Practice and Speed Quiz answers and rounds, so no triggers. Claim pays coins (once, via the ledger) and XP. Matches the existing Missions screen and `Mission` model, no Dart change needed.
- Speed Quiz: answers advance too fast to read a fact, so the "Did you know?" facts show on the results screen (up to 3).
- Content: 30 questions (18 hard) and 20 Odd One Out puzzles (9 hard). Hard general questions went from about 7 to 34.
  Please have a Kenyan skim the facts, especially the sports records and dates.

## Still open
- Guess It has only 6 questions and 6 images; it needs image assets from you.
- Missions don't count Guess It or Odd One Out answers yet.
