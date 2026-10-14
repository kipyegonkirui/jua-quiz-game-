# Phase 1 — Swipeable Game Hub

## Purpose

The app now opens on a swipeable game-mode hub instead of opening directly on Daily Challenge.

## Entry experience

`HomeShell` uses `GameHubScreen` as its first tab. The existing `AppTabs.today` index remains `0` for compatibility, while the bottom-navigation label is now `Play`.

## Card behavior

The hub uses a horizontal `PageView` with a viewport fraction so adjacent cards remain partially visible. During a swipe, cards receive a 2D scale/opacity/vertical-offset transition. There is no 3D perspective transform.

## Included cards

- Daily Challenge — active
- Practice — active
- Speed Quiz — active
- Guess It — coming soon
- Odd One Out — coming soon
- Find the Difference — coming soon
- Football Challenge — coming soon
- World Challenge — coming soon
- Competitions — active

## Navigation

- Daily Challenge opens the existing Daily Challenge screen.
- Practice switches to the existing Practice tab.
- Speed Quiz opens the existing Speed Quiz screen.
- Competitions switches to the existing Competitions tab.
- Future modes show a coming-soon sheet until their implementations exist.

## Scope

This change is UI/navigation only. No Supabase schema or RPC changes are included.
