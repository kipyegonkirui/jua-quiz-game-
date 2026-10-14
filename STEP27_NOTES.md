# Step 27 — Candy-style Practice Journey map

`lib/screens/practice_journey_screen.dart` now shows the practice levels as a
winding level map instead of a vertical list of cards.

- Level 1 is at the bottom; the trail snakes upward in rows of 5 nodes.
- Candy-striped trail; bright up to the furthest unlocked level, faded after.
- Node colours: green = completed, orange (pulsing + 🦁 mascot) = current,
  blue = open, grey + padlock = locked. Stars (0-3) sit under each node.
- A banner at the start of every batch (10 levels): region name, difficulty,
  questions per level, stars earned. Locked batches show `have/need ⭐`; tapping
  the banner opens the existing unlock sheet (stars / rewarded ad).
- Opens scrolled to the current level; a "my level" button appears when away.
- Top bar: lives (with recharge timer), stars, current level.

Unchanged: Supabase calls, lives rules, locked-level sheet, ad unlock, level
launch via `PracticeScreen(levelNumber: ...)`. No schema/pubspec changes
(nodes are drawn in code; the empty assets/candy_map/*.png files are unused).
