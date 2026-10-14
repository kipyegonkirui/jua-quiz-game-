# Step 29 — Illustrated game cards on the Play hub

`lib/screens/game_hub_screen.dart` now shows the swipeable game cards using the
supplied card artwork (`assets/hub/cards/*.webp`, 9 cards, same order as before).

- Art keeps the title, icon and scene. The baked-in info pill and Play button
  were cleaned out of the images and are drawn live instead, so they can be
  correct and dynamic:
  - Daily: 🔥 N Day Streak (from the profile) • Practice: ⭐ Level N (from the
    practice journey) • Speed Quiz: ⏱ 10s each • Guess It: 🖼 5 pictures •
    Competitions: 🏆 Live now • unreleased games: ✨ Coming soon.
- Unreleased games get a grey "Coming soon 🔒" button; tapping still opens the
  coming-soon sheet. Available cards open the same screens as before.
- To change a card's art, replace the .webp (keep 333:458 aspect). The pill and
  button positions are fractions of the card (see `_gameCards` / `_buttonRect`).
