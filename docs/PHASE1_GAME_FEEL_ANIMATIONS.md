# Phase 1 — Game Feel Animations

Reusable game-feel effects are now part of the shared UI layer. Gameplay and
Supabase scoring rules are unchanged.

## Tactile buttons

- `JuaGlossyButton` now uses `ScaleTransition` for a press squish followed by a
  small release bounce.
- `JuaTactile` wraps standard Flutter buttons that also need the same physical
  response.
- Presses use Flutter's built-in `HapticFeedback.selectionClick()`.

## Answer feedback

`AnimatedGameAnswerTile` is shared by Practice, Daily Challenge, and Speed Quiz.

- Selected: gold highlight.
- Correct: bright green, slight scale/pop, medium haptic, coin burst.
- Wrong: crimson red, horizontal shake, heavy haptic.
- Correct Speed Quiz answers emit more coin particles when answered faster.

## Speed Quiz pressure

`SpeedPressureBar` uses a `TweenSequence<Color?>` across green → yellow →
orange/red. At 30% remaining or lower it pulses red.

The Speed Quiz timer also gives one medium haptic warning at each of the final
three seconds.
