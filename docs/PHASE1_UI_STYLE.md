# Phase 1 UI style — Jua Quiz sky blue + glossy primary buttons

The supplied UI reference is used as the visual direction for the app shell.

## Base background

- `AppColors.juaSkyBlue`: `#5291BE`
- Applied to the global `Scaffold` background.
- App bars and the bottom navigation use the same blue so screens feel like one game surface.
- Cards, forms, ads and other content surfaces remain white for readability.

## Primary glossy button

`JuaGlossyButton` in `lib/widgets/jua_buttons.dart` recreates the reference style as a real Flutter widget rather than shipping the reference image as a button asset.

- Pill-shaped translucent blue outer frame
- Gold/orange `play` variant
- Green `action` variant
- Highlight/gloss effect
- Soft shadow
- 110 ms press scale feedback
- Dynamic text and optional icon
- Accessible semantic button label

Primary calls-to-action currently using the style include Practice start, Daily follow-up, and Speed Quiz start/results.
