-- ============================================================================
-- Jua Quiz — Phase 0: Nairobi timezone fix
-- Run once in Supabase SQL Editor. Recreates the two daily-challenge functions
-- so "today" is the NAIROBI calendar date (Africa/Nairobi, UTC+3, no DST),
-- not the UTC date. Idempotent: uses CREATE OR REPLACE.
-- ============================================================================

-- Replace the challenge-creation function: use Nairobi date instead of
-- current_date (which is UTC on Supabase's default config).
create or replace function public.get_or_create_today_challenge()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_challenge_id uuid;
  v_today date := (now() at time zone 'Africa/Nairobi')::date;
begin
  select id into v_challenge_id
  from public.daily_challenges
  where challenge_date = v_today;

  if v_challenge_id is not null then
    return v_challenge_id;
  end if;

  insert into public.daily_challenges (challenge_date)
  values (v_today)
  on conflict (challenge_date) do nothing
  returning id into v_challenge_id;

  if v_challenge_id is null then
    select id into v_challenge_id
    from public.daily_challenges
    where challenge_date = v_today;
    return v_challenge_id;
  end if;

  insert into public.daily_challenge_questions (daily_challenge_id, question_id, position)
  select v_challenge_id, q.id, row_number() over ()
  from (
    select id from public.questions where is_active = true order by random() limit 5
  ) q;

  return v_challenge_id;
end;
$$;

-- Replace the scoring function: streak comparisons and last_completed_date
-- must use the Nairobi date too, otherwise a player finishing near midnight
-- Nairobi (21:00 UTC) could break or double-count their streak.
create or replace function public.submit_daily_attempt(p_challenge_id uuid, p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id       uuid := auth.uid();
  v_today         date := (now() at time zone 'Africa/Nairobi')::date;
  v_score         integer := 0;
  v_total         integer := 0;
  v_xp_earned     integer := 0;
  v_old_level     integer;
  v_new_xp        integer;
  v_new_level     integer;
  v_profile       public.profiles%rowtype;
  v_yesterday     date := v_today - 1;
  v_new_streak    integer;
  q               record;
  v_given         text;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if exists (
    select 1 from public.attempts
    where user_id = v_user_id and daily_challenge_id = p_challenge_id
  ) then
    raise exception 'already completed today''s challenge';
  end if;

  for q in
    select qs.id, qs.correct_option
    from public.daily_challenge_questions dcq
    join public.questions qs on qs.id = dcq.question_id
    where dcq.daily_challenge_id = p_challenge_id
  loop
    v_total := v_total + 1;
    v_given := p_answers ->> q.id::text;
    if v_given is not null and lower(v_given) = q.correct_option then
      v_score := v_score + 1;
    end if;
  end loop;

  if v_total = 0 then
    raise exception 'challenge has no questions';
  end if;

  v_xp_earned := v_score * 10;
  if v_score = v_total then
    v_xp_earned := v_xp_earned + 20; -- perfect-round bonus
  end if;

  select * into v_profile from public.profiles where id = v_user_id for update;
  v_old_level := v_profile.level;
  v_new_xp := v_profile.xp + v_xp_earned;
  v_new_level := (v_new_xp / 100) + 1;

  if v_profile.last_completed_date = v_yesterday then
    v_new_streak := v_profile.current_streak + 1;
  elsif v_profile.last_completed_date = v_today then
    v_new_streak := v_profile.current_streak; -- guarded by the unique attempt above
  else
    v_new_streak := 1;
  end if;

  update public.profiles set
    xp = v_new_xp,
    level = v_new_level,
    current_streak = v_new_streak,
    longest_streak = greatest(v_profile.longest_streak, v_new_streak),
    last_completed_date = v_today,
    total_attempts = v_profile.total_attempts + 1,
    total_correct = v_profile.total_correct + v_score,
    total_questions = v_profile.total_questions + v_total
  where id = v_user_id;

  insert into public.attempts (user_id, daily_challenge_id, score, total_questions, xp_earned, answers)
  values (v_user_id, p_challenge_id, v_score, v_total, v_xp_earned, p_answers);

  return jsonb_build_object(
    'score', v_score,
    'total', v_total,
    'xp_earned', v_xp_earned,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'leveled_up', v_new_level > v_old_level,
    'current_streak', v_new_streak,
    'longest_streak', greatest(v_profile.longest_streak, v_new_streak)
  );
end;
$$;

-- Re-grant execute (CREATE OR REPLACE drops grants).
grant execute on function public.get_or_create_today_challenge() to authenticated;
grant execute on function public.submit_daily_attempt(uuid, jsonb) to authenticated;

-- Sanity check (run manually to confirm):
-- select (now() at time zone 'Africa/Nairobi')::date as nairobi_today,
--        current_date as db_today;
