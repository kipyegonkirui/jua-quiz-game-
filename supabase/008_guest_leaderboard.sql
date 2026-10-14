-- ============================================================================
-- 008_guest_leaderboard.sql
-- Guest players are real anonymous Supabase users, so their server-side XP
-- should be visible on the same leaderboard as registered players.
-- Creating an account remains optional; it is only needed to restore the
-- guest's progress after the app is uninstalled/reinstalled.
-- ============================================================================

create or replace view public.leaderboard
with (security_invoker = true)
as
  select id, username, avatar_url, xp, level, current_streak
  from public.profiles
  order by xp desc, created_at asc
  limit 100;

grant select on public.leaderboard to authenticated;
