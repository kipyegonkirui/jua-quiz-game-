# Jua Quiz — Phase 1 Step 18 Status

## Reward feedback / celebration layer

Implemented a shared `RewardCelebration` presentation layer in `lib/widgets/reward_feedback.dart`.

### Unified reward events
- XP earned
- coins earned
- mission reward claimed
- achievement reward claimed
- reward chest opened
- level-up celebration

### Integrated screens
- Daily Challenge results
- Practice results
- Speed Quiz results
- Daily Missions
- Achievements
- Reward Chests

The shared presentation uses one animated dialog, reward rows, haptic feedback, and lightweight confetti rather than each screen maintaining a separate reward dialog.

No database migration is required for Step 18.
