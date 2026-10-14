# Phase 1 — Step 12: XP & Level System

This step centralizes client-side XP/level presentation and fallback math.

## Rules

- Server-confirmed `new_xp` and `new_level` remain authoritative whenever present.
- When a result has `new_xp` but no `new_level`, the client derives the level from
  the centralized 100-XP-per-level policy.
- The client does not award, persist, or mutate XP by itself.
- `XpProgressionService` exposes snapshots and gain previews for future level-up
  animations and UI feedback.
- `XpService` remains as a backwards-compatible facade for existing screens.

## Current formula

```text
level = floor(xp / 100) + 1
xpIntoLevel = xp % 100
progress = xpIntoLevel / 100
xpToNextLevel = 100 - xpIntoLevel
```

## Future use

The gain preview can drive the level-up animation:

```text
GameResult
  -> XpGainPreview
  -> animate XP bar
  -> detect level-up
  -> overflow into next level
```

No Supabase migration is required for this step.
