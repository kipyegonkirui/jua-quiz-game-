-- 016_streak_history.sql
-- Phase 1 Step 21: persistent streak history and dashboard RPC.
-- Apply after 015_streak_rewards_shields.sql.

create table if not exists public.streak_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  completion_date date not null,
  streak_value integer not null check (streak_value > 0),
  shield_used boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, completion_date)
);

create index if not exists streak_history_user_date_idx
  on public.streak_history(user_id, completion_date desc);

alter table public.streak_history enable row level security;
revoke all on public.streak_history from public, anon, authenticated;

-- Backfill completion history from already-settled Daily Challenge attempts.
-- Historical shield usage cannot be reconstructed from the old attempts table,
-- so existing rows are marked as normal completions. Future shield use is
-- recorded authoritatively by submit_daily_attempt below.
with ordered as (
  select
    a.user_id,
    dc.challenge_date as completion_date,
    lag(dc.challenge_date) over (
      partition by a.user_id order by dc.challenge_date
    ) as previous_date
  from public.attempts a
  join public.daily_challenges dc on dc.id = a.daily_challenge_id
  where a.daily_challenge_id is not null
), numbered as (
  select
    user_id,
    completion_date,
    case
      when previous_date = completion_date - 1 then 1
      else 0
    end as continues
  from ordered
), runs as (
  select
    user_id,
    completion_date,
    row_number() over (
      partition by user_id order by completion_date
    ) - sum(continues) over (
      partition by user_id order by completion_date
      rows between unbounded preceding and current row
    ) as run_group
  from numbered
), values_for_days as (
  select
    user_id,
    completion_date,
    row_number() over (
      partition by user_id, run_group order by completion_date
    )::integer as streak_value
  from runs
)
insert into public.streak_history(user_id, completion_date, streak_value, shield_used)
select user_id, completion_date, streak_value, false
from values_for_days
on conflict (user_id, completion_date) do nothing;

-- Server-authoritative dashboard payload. Dates are Nairobi calendar dates.
create or replace function public.get_streak_dashboard(p_days integer default 90)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_today date := public.nairobi_today();
  v_days integer := greatest(7, least(coalesce(p_days, 90), 180));
  v_profile public.profiles%rowtype;
  v_next_milestone integer;
  v_coins integer := 0;
  v_shields integer := 0;
  v_history jsonb;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_user_id;

  if not found then
    raise exception 'profile not found';
  end if;

  select min(m)
    into v_next_milestone
  from unnest(array[3,7,14,30,60,100]) as m
  where m > v_profile.current_streak;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'date', d.day,
      'completed', coalesce(sh.completion_date is not null, false),
      'streak_value', coalesce(sh.streak_value, 0),
      'shield_used', coalesce(sh.shield_used, false)
    ) order by d.day
  ), '[]'::jsonb)
  into v_history
  from generate_series(
    v_today - (v_days - 1),
    v_today,
    interval '1 day'
  ) as d(day)
  left join public.streak_history sh
    on sh.user_id = v_user_id
   and sh.completion_date = d.day::date;

  if v_next_milestone is not null then
    v_coins := case v_next_milestone
      when 3 then 100
      when 14 then 500
      else 0
    end;
    v_shields := case v_next_milestone
      when 7 then 1
      when 30 then 1
      when 60 then 2
      when 100 then 3
      else 0
    end;
  end if;

  return jsonb_build_object(
    'current_streak', v_profile.current_streak,
    'longest_streak', v_profile.longest_streak,
    'streak_shields', v_profile.streak_shields,
    'last_completed_date', v_profile.last_completed_date,
    'next_milestone', v_next_milestone,
    'next_milestone_coins', v_coins,
    'next_milestone_shields', v_shields,
    'days', v_history
  );
end;
$$;

revoke all on function public.get_streak_dashboard(integer) from public, anon;
grant execute on function public.get_streak_dashboard(integer) to authenticated;

-- Rebuild submit_daily_attempt from Step 20 with one additional authoritative
-- write to streak_history. Reward/shield semantics remain unchanged.
create or replace function public.submit_daily_attempt(p_challenge_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_today date := public.nairobi_today();
  v_yesterday date := public.nairobi_today() - 1;
  v_score integer;
  v_total integer;
  v_xp_earned integer;
  v_old_level integer;
  v_new_xp integer;
  v_new_level integer;
  v_profile public.profiles%rowtype;
  v_new_streak integer;
  v_answers jsonb;
  v_days_since integer;
  v_shield_used boolean := false;
  v_shields_awarded integer := 0;
  v_streak_coins integer := 0;
  v_milestone integer;
  v_claimed boolean;
  v_reward_ref uuid;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.daily_challenges
    where id = p_challenge_id and challenge_date = v_today
  ) then
    raise exception 'this is not today''s challenge';
  end if;

  if exists (
    select 1 from public.attempts
    where user_id = v_user_id and daily_challenge_id = p_challenge_id
  ) then
    raise exception 'already completed today''s challenge';
  end if;

  select count(*)::integer into v_total
  from public.daily_challenge_questions where daily_challenge_id = p_challenge_id;

  if v_total = 0 then
    raise exception 'challenge has no questions';
  end if;

  select count(*) filter (where is_correct)::integer,
         coalesce(jsonb_object_agg(question_id::text, chosen), '{}'::jsonb)
    into v_score, v_answers
  from public.daily_answers
  where user_id = v_user_id and daily_challenge_id = p_challenge_id;

  v_xp_earned := v_score * 10;
  if v_score = v_total then
    v_xp_earned := v_xp_earned + 20;
  end if;

  select * into v_profile from public.profiles where id = v_user_id for update;
  v_old_level := v_profile.level;
  v_new_xp := v_profile.xp + v_xp_earned;
  v_new_level := (v_new_xp / 100) + 1;

  v_days_since := case
    when v_profile.last_completed_date is null then null
    else v_today - v_profile.last_completed_date
  end;

  if v_profile.last_completed_date = v_yesterday then
    v_new_streak := v_profile.current_streak + 1;
  elsif v_profile.last_completed_date = v_today then
    v_new_streak := v_profile.current_streak;
  elsif v_days_since = 2 and v_profile.streak_shields > 0 then
    v_new_streak := v_profile.current_streak + 1;
    v_shield_used := true;
  else
    v_new_streak := 1;
  end if;

  for v_milestone in select x from unnest(array[3,7,14,30,60,100]) as x loop
    if v_new_streak >= v_milestone
       and v_profile.current_streak < v_milestone then
      v_streak_coins := case v_milestone
        when 3 then 100
        when 14 then 500
        else 0
      end;
      v_shields_awarded := case v_milestone
        when 7 then 1
        when 30 then 1
        when 60 then 2
        when 100 then 3
        else 0
      end;

      insert into public.streak_reward_claims(
        user_id, milestone, coins_awarded, shields_awarded
      ) values (
        v_user_id, v_milestone, v_streak_coins, v_shields_awarded
      ) on conflict (user_id, milestone) do nothing
      returning true into v_claimed;

      if coalesce(v_claimed, false) then
        if v_streak_coins > 0 then
          v_reward_ref := gen_random_uuid();
          perform public._coin_apply(v_user_id, v_streak_coins, 'daily_reward', v_reward_ref);
        end if;
      else
        v_streak_coins := 0;
        v_shields_awarded := 0;
      end if;

      exit;
    end if;
  end loop;

  update public.profiles set
    xp = v_new_xp,
    level = v_new_level,
    current_streak = v_new_streak,
    longest_streak = greatest(v_profile.longest_streak, v_new_streak),
    last_completed_date = v_today,
    total_attempts = v_profile.total_attempts + 1,
    total_correct = v_profile.total_correct + v_score,
    total_questions = v_profile.total_questions + v_total,
    streak_shields = greatest(0, v_profile.streak_shields
      - case when v_shield_used then 1 else 0 end
      + v_shields_awarded)
  where id = v_user_id;

  insert into public.streak_history(user_id, completion_date, streak_value, shield_used)
  values (v_user_id, v_today, v_new_streak, v_shield_used)
  on conflict (user_id, completion_date) do update set
    streak_value = excluded.streak_value,
    shield_used = excluded.shield_used;

  insert into public.attempts (user_id, daily_challenge_id, score, total_questions, xp_earned, answers)
  values (v_user_id, p_challenge_id, v_score, v_total, v_xp_earned, v_answers);

  return jsonb_build_object(
    'score', v_score,
    'total', v_total,
    'xp_earned', v_xp_earned,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'leveled_up', v_new_level > v_old_level,
    'current_streak', v_new_streak,
    'longest_streak', greatest(v_profile.longest_streak, v_new_streak),
    'coins_earned', v_streak_coins,
    'streak_shields', greatest(0, v_profile.streak_shields
      - case when v_shield_used then 1 else 0 end
      + v_shields_awarded),
    'streak_shields_awarded', v_shields_awarded,
    'streak_shield_used', v_shield_used
  );
end;
$$;

revoke all on function public.submit_daily_attempt(uuid) from public, anon;
grant execute on function public.submit_daily_attempt(uuid) to authenticated;
