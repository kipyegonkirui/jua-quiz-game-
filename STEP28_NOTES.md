# Step 28 — Illustrated Practice Journey map

The journey now uses painted scenery instead of code-drawn shapes.

- `assets/journey/strips/`  one painted region per batch of 10 levels
  (meadow, savanna, coast, snow, candy). Regions cycle every 5 batches (mirrored
  on the second lap) and cross-fade into each other. Sky was cropped off; the
  top of the world uses `assets/journey/caps/`.
- `lib/screens/journey_map_data.dart` (generated) holds, per region, the image
  aspect ratios and the 10 normalised node positions that sit on the painted road.
- `assets/journey/ui/`  level bubbles (number/stars/lock removed so the app draws
  them), star, lock, level-up badge (badge not wired yet).
- `assets/journey/props/`  small props shown beside each batch banner.

To replace the art: keep the same file names. If a new strip has a different
road, re-trace it and regenerate `journey_map_data.dart` (node positions).
Source strips are low-res (~140x440 px); higher-res originals will look sharper.
