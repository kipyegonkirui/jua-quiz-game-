# Step 42: Football Challenge is playable

- Hub: the Football Challenge card is now live and opens the road map.
- Road map (`football_journey_screen.dart`): stars come from the server (`get_football_journey`). Tapping an open level shows "Kick off".
- Play screen (`football_play_screen.dart`): a 5-kick penalty shootout. A right answer is a GOAL, a wrong one is a SAVE (ball, keeper and GOAL!/SAVED! banner). Right answers move on by themselves, wrong ones show the answer and the fun fact.
- Stars: 3 goals = 1, 4 goals = 2, 5 goals = 3. A level opens once the previous one has at least 1 star.
- Difficulty by level: 1-20 easy, 21-40 medium, 41-60 hard (falls back to medium while hard questions are few: 112 hard so far).
- Questions come only from the "Football" category and avoid repeats the player has already seen.
- XP: 10 per goal, up to 300 Football XP a day.
- SQL: 031_football_challenge.sql, then seed_football_questions.sql. `assets/football/` added to pubspec.

Not done: lives, rewarded-ad batch unlocks, zone-final bonus rounds, and sounds specific to football.
Uncompiled: only syntax and imports were checked. The SQL was run against a test Postgres.
