-- ============================================================================
-- 002_optional_accounts.sql
-- Optional accounts: people play as a guest (a Supabase "anonymous" user) and
-- can later attach an email to the SAME user id, so XP, streaks and attempts
-- carry over. Safe to run more than once.
-- ============================================================================

-- 1. Track guests on profiles (mirrors auth.users.is_anonymous).
alter table public.profiles
  add column if not exists is_guest boolean not null default false;

update public.profiles p
set is_guest = coalesce(u.is_anonymous, false)
from auth.users u
where u.id = p.id;

-- 2. New-user trigger: anonymous users have no email and no chosen username,
--    so give them a friendly default like "Player4F9A2".
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, username, is_guest)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data->>'username', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Player' || upper(substr(md5(new.id::text), 1, 5))
    ),
    coalesce(new.is_anonymous, false)
  );
  return new;
end;
$$;

-- 3. When a guest verifies an email (becomes a permanent user), flip the flag.
create or replace function public.sync_profile_guest_flag()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.profiles
  set is_guest = coalesce(new.is_anonymous, false)
  where id = new.id
    and is_guest is distinct from coalesce(new.is_anonymous, false);
  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update on auth.users
  for each row
  when (old.is_anonymous is distinct from new.is_anonymous)
  execute function public.sync_profile_guest_flag();

-- 4. Leaderboard: guests and registered players are both shown. Creating an
--    account is optional; it is only needed to restore guest progress after
--    reinstalling the app.
create or replace view public.leaderboard
with (security_invoker = true)
as
  select id, username, avatar_url, xp, level, current_streak
  from public.profiles
  order by xp desc, created_at asc
  limit 100;

-- 5. Tighten who can call what through the API. Trigger functions should never
--    be callable directly, and the game functions are for signed-in players
--    (guests count as signed in) only.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.sync_profile_guest_flag() from public, anon, authenticated;
revoke execute on function public.get_or_create_today_challenge() from public, anon;
revoke execute on function public.get_challenge_questions(uuid) from public, anon;
revoke execute on function public.submit_daily_attempt(uuid, jsonb) from public, anon;

-- ----------------------------------------------------------------------------
-- Optional housekeeping (NOT run automatically): guests who never come back pile
-- up in auth.users. Supabase has no automatic cleanup for them. This removes
-- guests that were created 60+ days ago AND haven't finished a challenge in
-- 60+ days (their profile/attempts are deleted with them via ON DELETE CASCADE).
--
-- delete from auth.users u
-- using public.profiles p
-- where p.id = u.id
--   and u.is_anonymous
--   and u.created_at < now() - interval '60 days'
--   and coalesce(p.last_completed_date, u.created_at::date) < current_date - 60;
-- ----------------------------------------------------------------------------
