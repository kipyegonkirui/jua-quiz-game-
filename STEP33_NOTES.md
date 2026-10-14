# Step 33: stability pass, content, game feel, share and daily calendar

## Not compiled
No Flutter SDK was available here. Dart was only syntax- and reference-checked. Please run
`flutter pub get` (new dependency: url_launcher), `flutter analyze`, `flutter run`.
SQL was run for real on Postgres 18 (Supabase stubs), whole chain plus the scenarios.

## SQL (run in this order after 022)
1. `024_content_quality.sql`  2. `seed_kenya_questions_batch3.sql`  3. `025_daily_login_calendar.sql`
If you ever ran the OLD 022, re-run `020_practice_difficulty_and_math.sql` first, then the new 022.

## What changed
- Did you know: `QuestionExtras` card under every settled answer (Daily and Practice; Speed Quiz shows its own feedback screen so not yet). The server only returns the fact after you answered.
- Report this question: reason sheet, 20 reports/day, one per reason per question. Review in `question_reports`; `question_accuracy` shows which questions players get wrong most.
- 64 new Kenyan questions in 9 categories, each with a fact. Please have a Kenyan skim the facts.
- Game feel: `ComboMeter` (Practice, Speed Quiz), `AnimatedStars` (Practice results, level summaries), sounds on taps, rewards and stars.
- Practice intro and results restyled (mascot, readable text over scenery).
- WhatsApp share (Practice results, mode level summaries). Set `AppConfig.shareUrl` when the app is on the Play Store.
- 7-day daily reward calendar card on the Streak screen (10,10,15,15,20,25,60 coins; a missed day restarts).

## Known gaps
- Missions backend SQL (`daily_missions`, `get_daily_missions`, `claim_daily_mission`) exists in no file.
- Only about 7 hard general questions; Guess It has 6 questions; Odd One Out has 4 hard puzzles.
- Speed Quiz does not show the "Did you know?" card.
