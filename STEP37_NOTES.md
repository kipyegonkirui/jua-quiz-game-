# Step 37: tap-to-answer, auto-advance

Applies to the Daily Challenge and Practice (and Practice Journey levels), which share `QuizView`.

- Tap an option and it is checked at once: no "Check answer" button.
- Right answer: green, mascot, "Correct!", a thin gold bar fills for 1.1 s, then the next question slides in. Tap the "Correct!" area to skip the wait. The last question rolls straight into the results.
- Wrong answer: red + the right one green, the fun fact, and a "Next question" button (the player needs time to read).
- Second chance works as before, but picking the new answer also checks at once.
- Smooth progress bar, question slide transition, and a "🔥 N in a row" chip from 2 correct in a row (Practice only).
- `kAutoAdvanceDelay` in `quiz_widgets.dart` controls the 1.1 s. `QuizView(autoCheck: false)` restores the old two-step buttons.
- Not changed: Competition play (already tap-to-answer), Speed Quiz, Guess It, Odd One Out, Survival Run.
- No SQL.

Applied on top of v15. Note: Practice already has the `ComboMeter` (top right), so the extra "N in a row" chip is not passed from Practice (`QuizView(combo:)` still exists, unused).
