# Practice Choice Bubble Update

## UI changes

- Removed the Practice intro's "Try Speed Quiz" action. Speed Quiz is launched from the Play carousel.
- Practice answer choices now use the shared `AnimatedGameAnswerTile` with a glossy, rounded 2D bubble treatment.
- Idle choices use a light bubble gradient and raised shadow.
- Selected choices use a warm gold bubble state.
- Correct choices use a green bubble state with the existing pop/coin burst.
- Wrong choices use a red bubble state with the existing shake animation.
- `JuaTactile` still supplies press squish, bounce, and haptic feedback.

## Scope

No Supabase changes. No gameplay or answer-resolution changes.
