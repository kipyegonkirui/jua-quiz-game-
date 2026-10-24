# Updates in v16.2

## 1. Animated loading screen (Flutter)
- `lib/widgets/jua_loading_screen.dart` - layered Jua Quiz emblem animation (entrance, idle loop, progress-driven book stack, completion burst).
- `lib/startup/jua_bootstrap.dart` - runs the old startup work (Supabase, deep links, guest sign-in, ads, push, sound) behind the loading screen, then fades into the app. Shows a "Try again" screen if Supabase init or sign-in fails.
- `lib/main.dart` - main() now calls runApp straight away with JuaBootstrap(app: JuaQuizApp()). JuaQuizApp and AuthGate are unchanged apart from a comment.
- `assets/logo/` (16 PNGs) and `pubspec.yaml` (`- assets/logo/` added).

## 2. Question content (Supabase)
- `supabase/seed_kenya_questions_batch5.sql` ... `batch12.sql` - 514 new questions, mostly medium and hard, each with a "Did you know?" line. Run after `024_content_quality.sql`. Safe to re-run.
- `supabase/batch5_fix_existing.sql` - run once. Switches off a wrong question from batch 4 (Kenya's first Olympic gold was Naftali Temu's, not Keino's). The row was also removed from `seed_kenya_questions_batch4.sql`.
- `supabase/content_reviews/` - review sheet per batch. A Kenyan reviewer should check every fact before release.

Not done yet: changes to how practice questions are picked (repeat avoidance).
