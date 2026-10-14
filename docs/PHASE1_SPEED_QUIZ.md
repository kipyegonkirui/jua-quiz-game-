# Phase 1 — Step 8: Speed Quiz

Speed Quiz is the first new mode built on the shared game engine.

## Rules

- 10 questions per round.
- 10 seconds per question.
- Tapping an option submits immediately.
- A timeout is submitted automatically.
- The server measures authoritative elapsed time.
- Score = base 100 + difficulty bonus + speed bonus (0–50) + Speed Quiz mode bonus 25.
- Speed Quiz updates XP and lifetime question statistics but does not modify the daily streak.

## Backend

`supabase/010_speed_quiz.sql` creates the round/answer tables and server functions:

- `start_speed_quiz_round()`
- `get_speed_quiz_questions(uuid)`
- `get_speed_quiz_state(uuid)`
- `get_speed_quiz_progress(uuid)`
- `answer_speed_quiz_question(uuid, uuid, text, boolean)`
- `submit_speed_quiz_round(uuid)`

The correct answer is never returned by the question-loading function. It is only returned after that question has been settled.

## Flutter

`SpeedQuizScreen` uses `GameController` and the new timeout resolver. The countdown is a visual aid; the server remains authoritative when recording the answer.
