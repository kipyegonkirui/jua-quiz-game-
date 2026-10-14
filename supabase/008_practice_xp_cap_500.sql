-- Phase 1.3: Increase daily Practice XP cap from 300 to 500.
-- Run this migration in Supabase SQL Editor.

create or replace function public.submit_practice_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid         uuid := auth.uid();
  v_today       date := public.nairobi_today();
  v_daily_cap   constant integer := 500;   -- practice XP per day
  v_round       public.practice_rounds%rowtype;
  v_profile     public.profiles%rowtype;
  v_score       integer;
  v_total       integer;
  v_raw_xp      integer;
  v_xp_earned   integer;
  v_xp_today    integer;
  v_old_level   integer;
  v_new_xp      integer;
  v_new_level   integer;
  v_answers     jsonb;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_round
  from public.practice_rounds
  where id = p_round_id and user_id = v_uid
  for update;

  if not found then
    raise exception 'round not found';
  end if;
  if v_round.status <> 'open' then
    raise exception 'round already submitted';
  end if;

  select count(*)::integer,
         count(*) filter (where is_correct)::integer,
         coalesce(jsonb_object_agg(question_id::text, chosen) filter (where chosen is not null), '{}'::jsonb)
    into v_total, v_score, v_answers
  from public.practice_round_questions
  where round_id = p_round_id;

  if v_total = 0 then
    raise exception 'round has no questions';
  end if;

  v_raw_xp := v_score * 10;

  select coalesce(sum(xp_earned), 0) into v_xp_today
  from public.practice_rounds
  where user_id = v_uid
    and status = 'completed'
    and (completed_at at time zone 'Africa/Nairobi')::date = v_today;

  v_xp_earned := least(v_raw_xp, greatest(v_daily_cap - v_xp_today, 0));

  select * into v_profile from public.profiles where id = v_uid for update;
  v_old_level := v_profile.level;
  v_new_xp := v_profile.xp + v_xp_earned;
  v_new_level := (v_new_xp / 100) + 1;

  update public.profiles set
    xp = v_new_xp,
    level = v_new_level,
    practice_rounds = v_profile.practice_rounds + 1,
    total_correct = v_profile.total_correct + v_score,
    total_questions = v_profile.total_questions + v_total
  where id = v_uid;

  update public.practice_rounds set
    status = 'completed',
    score = v_score,
    total_questions = v_total,
    xp_earned = v_xp_earned,
    answers = v_answers,
    completed_at = now()
  where id = p_round_id;

  return jsonb_build_object(
    'score', v_score,
    'total', v_total,
    'xp_earned', v_xp_earned,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'leveled_up', v_new_level > v_old_level,
    'current_streak', v_profile.current_streak,
    'longest_streak', v_profile.longest_streak,
    'xp_capped', v_xp_earned < v_raw_xp,
    'practice_xp_today', v_xp_today + v_xp_earned,
    'practice_xp_cap', v_daily_cap
  );
end;
$$;
