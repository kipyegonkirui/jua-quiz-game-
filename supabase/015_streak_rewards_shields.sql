-- 015_streak_rewards_shields.sql
-- Phase 1 Step 20: server-authoritative streak milestone rewards and shields.
-- Apply after 014_reward_chests.sql.

alter table public.profiles
  add column if not exists streak_shields integer not null default 0;

create table if not exists public.streak_reward_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  milestone integer not null,
  coins_awarded integer not null default 0,
  shields_awarded integer not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, milestone)
);

alter table public.streak_reward_claims enable row level security;
revoke all on public.streak_reward_claims from public, anon, authenticated;

-- Rebuild the daily completion RPC so a streak reward is granted exactly once
-- per milestone and a shield protects exactly one missed calendar day.
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
    -- Exactly one missed Daily Challenge day is protected.
    v_new_streak := v_profile.current_streak + 1;
    v_shield_used := true;
  else
    v_new_streak := 1;
  end if;

  -- Milestone rewards are intentionally modest and repeat-safe.
  -- Cosmetic badge/avatar rewards from the broader roadmap belong to the
  -- future cosmetics inventory system, not this migration.
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
        v_shields_awarded := v_shields_awarded;
      else
        -- A previously claimed milestone contributes no duplicate reward.
        v_streak_coins := 0;
        v_shields_awarded := 0;
      end if;

      exit; -- a normal completion can cross only one new milestone
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
