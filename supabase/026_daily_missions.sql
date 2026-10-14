-- ============================================================================
-- 026_daily_missions.sql
-- Daily missions backend: 3 missions per Nairobi day, progress counted live from
-- the answer/round tables, rewards claimed once. Matches lib/models/mission.dart.
-- Run after 025. Safe to re-run.
-- ============================================================================

create table if not exists public.daily_missions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  mission_date date not null,
  slot         integer not null check (slot between 1 and 3),
  kind         text not null check (kind in ('answer_questions','correct_answers','earn_xp','complete_rounds','perfect_round')),
  title        text not null,
  description  text not null,
  target       integer not null check (target > 0),
  reward_xp    integer not null default 0,
  reward_coins integer not null default 0,
  claimed_at   timestamptz,
  created_at   timestamptz not null default now(),
  unique (user_id, mission_date, slot)
);
alter table public.daily_missions enable row level security;
revoke all on public.daily_missions from anon, authenticated;

-- Mission pool: slot 1 = easy, 2 = medium, 3 = stretch.
create or replace function public._mission_pool()
returns table (slot int, kind text, title text, description text, target int, reward_xp int, reward_coins int)
language sql immutable as $$
  values
   (1,'answer_questions','Warm up','Answer 10 questions today',10,10,5),
   (1,'answer_questions','Quick fire','Answer 15 questions today',15,15,8),
   (1,'complete_rounds','Finish a round','Complete 1 round of any mode',1,10,5),
   (2,'correct_answers','Sharp mind','Get 10 answers right today',10,20,10),
   (2,'complete_rounds','Hat trick','Complete 3 rounds today',3,25,12),
   (2,'earn_xp','XP hunter','Earn 40 XP from rounds today',40,20,10),
   (3,'correct_answers','Know-it-all','Get 25 answers right today',25,40,20),
   (3,'perfect_round','Flawless','Finish a round with every answer correct',1,40,25),
   (3,'earn_xp','XP machine','Earn 100 XP from rounds today',100,40,20);
$$;

create or replace function public._mission_progress(p_uid uuid, p_date date, p_kind text)
returns integer
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare n integer := 0;
begin
  if p_kind in ('answer_questions','correct_answers') then
    select count(*) into n from (
      select is_correct from daily_answers
        where user_id = p_uid and (answered_at at time zone 'Africa/Nairobi')::date = p_date
      union all
      select prq.is_correct from practice_round_questions prq join practice_rounds pr on pr.id = prq.round_id
        where pr.user_id = p_uid and prq.chosen is not null
          and (prq.answered_at at time zone 'Africa/Nairobi')::date = p_date
      union all
      select sa.is_correct from speed_quiz_answers sa join speed_quiz_rounds sr on sr.id = sa.round_id
        where sr.user_id = p_uid and (sa.answered_at at time zone 'Africa/Nairobi')::date = p_date
    ) a where p_kind = 'answer_questions' or a.is_correct;
  elsif p_kind = 'earn_xp' then
    select coalesce(sum(x), 0) into n from (
      select xp_earned x from attempts where user_id = p_uid and (completed_at at time zone 'Africa/Nairobi')::date = p_date
      union all select coalesce(xp_earned,0) from practice_rounds where user_id = p_uid and status = 'completed' and (completed_at at time zone 'Africa/Nairobi')::date = p_date
      union all select xp_earned from speed_quiz_rounds where user_id = p_uid and status = 'completed' and (completed_at at time zone 'Africa/Nairobi')::date = p_date
    ) t;
  elsif p_kind = 'complete_rounds' then
    select (select count(*) from attempts where user_id = p_uid and (completed_at at time zone 'Africa/Nairobi')::date = p_date)
         + (select count(*) from practice_rounds where user_id = p_uid and status = 'completed' and (completed_at at time zone 'Africa/Nairobi')::date = p_date)
         + (select count(*) from speed_quiz_rounds where user_id = p_uid and status = 'completed' and (completed_at at time zone 'Africa/Nairobi')::date = p_date)
      into n;
  elsif p_kind = 'perfect_round' then
    select (select count(*) from attempts where user_id = p_uid and score = total_questions and total_questions > 0 and (completed_at at time zone 'Africa/Nairobi')::date = p_date)
         + (select count(*) from practice_rounds where user_id = p_uid and status = 'completed' and score = total_questions and total_questions > 0 and (completed_at at time zone 'Africa/Nairobi')::date = p_date)
      into n;
  end if;
  return coalesce(n, 0);
end $$;

create or replace function public.get_daily_missions()
returns table (id uuid, mission_date date, kind text, title text, description text,
               target integer, progress integer, reward_xp integer, reward_coins integer, claimed_at timestamptz)
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'Africa/Nairobi')::date;
  s int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from daily_missions m where m.user_id = v_uid and m.mission_date = v_today) then
    for s in 1..3 loop
      insert into daily_missions (user_id, mission_date, slot, kind, title, description, target, reward_xp, reward_coins)
      select v_uid, v_today, p.slot, p.kind, p.title, p.description, p.target, p.reward_xp, p.reward_coins
        from _mission_pool() p where p.slot = s order by random() limit 1
      on conflict on constraint daily_missions_user_id_mission_date_slot_key do nothing;
    end loop;
  end if;
  return query
    select m.id, m.mission_date, m.kind, m.title, m.description, m.target,
           least(public._mission_progress(v_uid, v_today, m.kind), m.target)::integer,
           m.reward_xp, m.reward_coins, m.claimed_at
      from daily_missions m
     where m.user_id = v_uid and m.mission_date = v_today
     order by m.slot;
end $$;

create or replace function public.claim_daily_mission(p_mission_id uuid)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  m record; v_balance integer; v_old_level integer; v_new_xp integer; v_new_level integer; v_coins integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform 1 from profiles where id = v_uid for update;
  select * into m from daily_missions where id = p_mission_id and user_id = v_uid;
  if not found then raise exception 'mission_not_found'; end if;
  if m.claimed_at is not null then
    select coins, xp, level into v_balance, v_new_xp, v_new_level from profiles where id = v_uid;
    return jsonb_build_object('claimed', false, 'balance', v_balance, 'xp_awarded', 0, 'coins_awarded', 0,
                              'new_xp', v_new_xp, 'new_level', v_new_level, 'leveled_up', false);
  end if;
  if public._mission_progress(v_uid, m.mission_date, m.kind) < m.target then
    raise exception 'mission_not_complete';
  end if;
  update daily_missions set claimed_at = now() where id = m.id;
  select level into v_old_level from profiles where id = v_uid;
  v_balance := public._coin_apply(v_uid, m.reward_coins, 'mission_reward', m.id);
  update profiles set xp = xp + m.reward_xp, level = ((xp + m.reward_xp) / 100) + 1
    where id = v_uid returning xp, level, coins into v_new_xp, v_new_level, v_coins;
  return jsonb_build_object('claimed', true, 'balance', v_coins, 'xp_awarded', m.reward_xp,
    'coins_awarded', m.reward_coins, 'new_xp', v_new_xp, 'new_level', v_new_level,
    'leveled_up', v_new_level > v_old_level);
end $$;

revoke all on function public._mission_pool() from public, anon, authenticated;
revoke all on function public._mission_progress(uuid, date, text) from public, anon, authenticated;
revoke all on function public.get_daily_missions() from public, anon;
revoke all on function public.claim_daily_mission(uuid) from public, anon;
grant execute on function public.get_daily_missions() to authenticated;
grant execute on function public.claim_daily_mission(uuid) to authenticated;
