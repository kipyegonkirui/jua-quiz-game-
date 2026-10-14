-- ============================================================================
-- 028_odd_survival_run.sql
-- Odd One Out: SURVIVAL RUN. Endless puzzles, 3 strikes, rising speed and
-- difficulty (adaptive), combo multiplier with a Hot Streak, and a paid
-- "Second Wind" offer that rescues a long streak. Server-authoritative:
-- the server picks every puzzle, times every answer and scores it.
-- Run after 026. Safe to re-run.
-- ============================================================================

create table if not exists public.odd_survival_runs (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'playing' check (status in ('playing','offer','over')),
  strikes       integer not null default 0,
  max_strikes   integer not null default 3,
  streak        integer not null default 0,
  best_streak   integer not null default 0,
  saved_streak  integer not null default 0,   -- streak held while a Second Wind is on offer
  score         integer not null default 0,
  correct       integer not null default 0,
  answered      integer not null default 0,
  wind_used     integer not null default 0,
  seq           integer not null default 0,   -- puzzles served so far
  cur_puzzle_id uuid references public.odd_one_out_puzzles(id),
  cur_served_at timestamptz,
  cur_limit_ms  integer,
  cur_begun     boolean not null default false, -- the clock starts when the phone shows the puzzle
  best_before   integer not null default 0,   -- personal best when the run began
  xp_earned     integer not null default 0,
  coins_earned  integer not null default 0,
  rewards_capped boolean not null default false,
  started_at    timestamptz not null default now(),
  ended_at      timestamptz
);
alter table public.odd_survival_runs add column if not exists cur_begun boolean not null default false;
create unique index if not exists odd_survival_one_active
  on public.odd_survival_runs(user_id) where status in ('playing','offer');
create index if not exists odd_survival_runs_user on public.odd_survival_runs(user_id, ended_at desc);

create table if not exists public.odd_survival_seen (
  run_id    uuid not null references public.odd_survival_runs(id) on delete cascade,
  puzzle_id uuid not null references public.odd_one_out_puzzles(id) on delete cascade,
  seq       integer not null,
  primary key (run_id, seq)
);

create table if not exists public.odd_survival_stats (
  user_id     uuid primary key references public.profiles(id) on delete cascade,
  best_score  integer not null default 0,
  best_streak integer not null default 0,
  best_correct integer not null default 0,
  runs        integer not null default 0,
  updated_at  timestamptz not null default now()
);

alter table public.odd_survival_runs  enable row level security;
alter table public.odd_survival_seen  enable row level security;
alter table public.odd_survival_stats enable row level security;
revoke all on public.odd_survival_runs, public.odd_survival_seen, public.odd_survival_stats from anon, authenticated;

-- ---------------------------------------------------------------- tuning ---
-- Difficulty "heat": grows with progress and streak, cools with strikes.
create or replace function public._odd_survival_target(p_seq integer, p_streak integer, p_strikes integer)
returns text language sql immutable as $$
  select case
    when ((p_seq - 1) * 0.25 + p_streak * 0.35 - p_strikes * 1.0) < 1.5 then 'easy'
    when ((p_seq - 1) * 0.25 + p_streak * 0.35 - p_strikes * 1.0) < 4.5 then 'medium'
    else 'hard' end;
$$;

-- Streak multiplier: x1 / x1.5 (3+) / x2 HOT STREAK (5+) / x3 (10+).
create or replace function public._odd_survival_multiplier(p_streak integer)
returns numeric language sql immutable as $$
  select case when p_streak >= 10 then 3.0 when p_streak >= 5 then 2.0
              when p_streak >= 3 then 1.5 else 1.0 end;
$$;

-- Serve the next puzzle (adaptive difficulty, no repeats while unseen ones remain).
create or replace function public._odd_survival_serve(p_run_id uuid)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  r public.odd_survival_runs%rowtype;
  v_target text;
  p public.odd_one_out_puzzles%rowtype;
  v_seq integer;
  v_limit integer;
begin
  select * into r from odd_survival_runs where id = p_run_id for update;
  v_seq := r.seq + 1;
  v_target := public._odd_survival_target(v_seq, r.streak, r.strikes);

  select * into p from odd_one_out_puzzles x
   where x.is_active and x.difficulty = v_target
     and not exists (select 1 from odd_survival_seen s where s.run_id = p_run_id and s.puzzle_id = x.id)
   order by random() limit 1;
  if not found then
    select * into p from odd_one_out_puzzles x
     where x.is_active
       and not exists (select 1 from odd_survival_seen s where s.run_id = p_run_id and s.puzzle_id = x.id)
     order by random() limit 1;
  end if;
  if not found then
    select * into p from odd_one_out_puzzles x where x.is_active order by random() limit 1;
  end if;
  if not found then raise exception 'no_puzzles_available'; end if;

  -- Time shrinks as the run goes on, never below 4 seconds.
  v_limit := greatest(4000, round(p.time_limit_seconds * 1000 * greatest(0.55, 1 - 0.025 * (v_seq - 1)))::integer);

  insert into odd_survival_seen(run_id, puzzle_id, seq) values (p_run_id, p.id, v_seq);
  update odd_survival_runs
     set seq = v_seq, cur_puzzle_id = p.id, cur_served_at = now(), cur_limit_ms = v_limit, cur_begun = false
   where id = p_run_id;

  return jsonb_build_object(
    'id', p.id, 'puzzle_type', p.puzzle_type, 'difficulty', p.difficulty, 'seq', v_seq,
    'item_a', p.item_a, 'item_b', p.item_b, 'item_c', p.item_c, 'item_d', p.item_d,
    'time_limit_ms', v_limit, 'remaining_ms', v_limit);
end $$;

-- Common state block returned by every run function.
create or replace function public._odd_survival_state(p_run_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare r public.odd_survival_runs%rowtype; p public.odd_one_out_puzzles%rowtype; v_cur jsonb := null; v_rem integer;
begin
  select * into r from odd_survival_runs where id = p_run_id;
  if r.status = 'playing' and r.cur_puzzle_id is not null then
    select * into p from odd_one_out_puzzles where id = r.cur_puzzle_id;
    v_rem := case when r.cur_begun
      then greatest(0, r.cur_limit_ms - (extract(epoch from (now() - r.cur_served_at)) * 1000)::integer)
      else r.cur_limit_ms end;
    v_cur := jsonb_build_object(
      'id', p.id, 'puzzle_type', p.puzzle_type, 'difficulty', p.difficulty, 'seq', r.seq,
      'item_a', p.item_a, 'item_b', p.item_b, 'item_c', p.item_c, 'item_d', p.item_d,
      'time_limit_ms', r.cur_limit_ms, 'remaining_ms', v_rem);
  end if;
  return jsonb_build_object(
    'run_id', r.id, 'status', r.status, 'strikes', r.strikes, 'max_strikes', r.max_strikes,
    'streak', r.streak, 'best_streak', r.best_streak, 'saved_streak', r.saved_streak,
    'score', r.score, 'correct', r.correct, 'answered', r.answered,
    'multiplier', public._odd_survival_multiplier(r.streak),
    'best_before', r.best_before, 'wind_cost', 40, 'puzzle', v_cur);
end $$;

-- ------------------------------------------------------------------- start --
create or replace function public.start_odd_survival_run()
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  r public.odd_survival_runs%rowtype;
  v_id uuid;
  v_best integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into r from odd_survival_runs where user_id = v_uid and status in ('playing','offer') for update;
  if found then
    -- A run left untouched for 2+ minutes is closed (and paid) so nobody can park a streak.
    if coalesce(r.cur_served_at, r.started_at) < now() - interval '2 minutes' then
      perform public.finish_odd_survival_run(r.id);
    else
      return public._odd_survival_state(r.id);
    end if;
  end if;
  select coalesce(best_score, 0) into v_best from odd_survival_stats where user_id = v_uid;
  insert into odd_survival_runs(user_id, best_before) values (v_uid, coalesce(v_best, 0)) returning id into v_id;
  perform public._odd_survival_serve(v_id);
  return public._odd_survival_state(v_id);
end $$;

-- ------------------------------------------------------------------- begin --
-- The phone calls this the moment a puzzle appears (after the reveal pause), so
-- reading the last explanation never eats into the next puzzle's time.
create or replace function public.begin_odd_survival_puzzle(p_run_id uuid, p_puzzle_id uuid)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid(); r public.odd_survival_runs%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into r from odd_survival_runs where id = p_run_id and user_id = v_uid for update;
  if not found then raise exception 'run_not_found'; end if;
  if r.status <> 'playing' or r.cur_puzzle_id is distinct from p_puzzle_id then raise exception 'wrong_puzzle'; end if;
  if not r.cur_begun then
    update odd_survival_runs set cur_begun = true, cur_served_at = now() where id = p_run_id;
  end if;
  return public._odd_survival_state(p_run_id);
end $$;
revoke all on function public.begin_odd_survival_puzzle(uuid, uuid) from public, anon;
grant execute on function public.begin_odd_survival_puzzle(uuid, uuid) to authenticated;

-- ------------------------------------------------------------------ answer --
create or replace function public.answer_odd_survival(p_run_id uuid, p_puzzle_id uuid, p_choice text)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  r public.odd_survival_runs%rowtype;
  p public.odd_one_out_puzzles%rowtype;
  v_elapsed integer;
  v_ok boolean;
  v_timed_out boolean;
  v_base integer;
  v_points integer := 0;
  v_streak integer;
  v_mult numeric;
  v_state jsonb;
  v_next jsonb := null;
  v_prev_streak integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into r from odd_survival_runs where id = p_run_id and user_id = v_uid for update;
  if not found then raise exception 'run_not_found'; end if;
  if r.status <> 'playing' then raise exception 'run_not_playing'; end if;
  if r.cur_puzzle_id is distinct from p_puzzle_id then raise exception 'wrong_puzzle'; end if;
  if p_choice not in ('a','b','c','d','timeout') then raise exception 'bad_choice'; end if;

  select * into p from odd_one_out_puzzles where id = p_puzzle_id;
  v_elapsed := (extract(epoch from (now() - r.cur_served_at)) * 1000)::integer;
  v_timed_out := p_choice = 'timeout' or v_elapsed > r.cur_limit_ms + 1500;  -- 1.5s network grace
  v_ok := (not v_timed_out) and p_choice = p.odd_option;
  v_prev_streak := r.streak;

  if v_ok then
    v_streak := r.streak + 1;
    v_mult := public._odd_survival_multiplier(v_streak);
    v_base := case p.difficulty when 'easy' then 80 when 'medium' then 100 else 130 end;
    v_points := round((v_base + v_base * 0.6 * greatest(0, 1 - v_elapsed::numeric / r.cur_limit_ms)) * v_mult)::integer;
    update odd_survival_runs
       set streak = v_streak, best_streak = greatest(best_streak, v_streak),
           score = score + v_points, correct = correct + 1, answered = answered + 1
     where id = p_run_id;
    v_next := public._odd_survival_serve(p_run_id);
  else
    update odd_survival_runs
       set strikes = strikes + 1, streak = 0, answered = answered + 1
     where id = p_run_id returning * into r;
    if r.strikes >= r.max_strikes then
      -- Out of strikes. If the run is worth saving, offer a Second Wind: one strike
      -- back and the streak restored (capped at 5, so Hot Streak is back).
      if r.wind_used = 0 and r.correct >= 5 then
        update odd_survival_runs set status = 'offer', saved_streak = least(r.best_streak, 5) where id = p_run_id;
      else
        perform public.finish_odd_survival_run(p_run_id);
      end if;
    else
      v_next := public._odd_survival_serve(p_run_id);
    end if;
  end if;

  v_state := public._odd_survival_state(p_run_id);
  -- The state only carries the *current* puzzle while status = playing; after a
  -- serve it is the next one, so answer details are reported separately.
  return v_state || jsonb_build_object(
    'is_correct', v_ok, 'timed_out', v_timed_out, 'points', v_points,
    'odd_option', p.odd_option, 'explanation', p.explanation,
    'answered_puzzle_id', p_puzzle_id, 'elapsed_ms', v_elapsed,
    'hot_streak', v_ok and (v_state->>'streak')::integer >= 5,
    'streak_broken', (not v_ok) and v_prev_streak >= 3, 'lost_streak', case when v_ok then 0 else v_prev_streak end);
end $$;

-- -------------------------------------------------------------- second wind --
create or replace function public.odd_survival_second_wind(p_run_id uuid)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  r public.odd_survival_runs%rowtype;
  v_bal integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into r from odd_survival_runs where id = p_run_id and user_id = v_uid for update;
  if not found then raise exception 'run_not_found'; end if;
  if r.status <> 'offer' or r.wind_used > 0 then raise exception 'no_second_wind_offer'; end if;
  -- Raises not_enough_coins if the wallet is short (nothing changes).
  v_bal := public._coin_apply(v_uid, -40, 'second_chance_purchase', gen_random_uuid());
  update odd_survival_runs
     set status = 'playing', strikes = max_strikes - 1, streak = saved_streak, saved_streak = 0, wind_used = 1
   where id = p_run_id;
  perform public._odd_survival_serve(p_run_id);
  return public._odd_survival_state(p_run_id) || jsonb_build_object('coins_balance', v_bal);
end $$;

-- ------------------------------------------------------------------ finish --
-- Ends the run (declining a Second Wind, leaving, or the last strike) and pays out.
-- Safe to call twice: the second call returns the stored result.
create or replace function public.finish_odd_survival_run(p_run_id uuid)
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  r public.odd_survival_runs%rowtype;
  v_rewarded_today integer;
  v_cap constant integer := 10;
  v_capped boolean := false;
  v_xp integer := 0;
  v_coins integer := 0;
  v_old_level integer; v_new_level integer; v_new_xp integer;
  v_new_best boolean;
  v_best integer;
begin
  -- Called internally (start of a new run) with auth.uid() of the same user.
  select * into r from odd_survival_runs where id = p_run_id and user_id = v_uid for update;
  if not found then raise exception 'run_not_found'; end if;

  if r.status <> 'over' then
    update odd_survival_runs set status = 'over', ended_at = now(), saved_streak = 0 where id = p_run_id;

    select count(*) into v_rewarded_today from odd_survival_runs
     where user_id = v_uid and status = 'over' and id <> p_run_id and xp_earned > 0
       and (ended_at at time zone 'Africa/Nairobi')::date = public.nairobi_today();
    v_capped := v_rewarded_today >= v_cap;
    if not v_capped and r.correct > 0 then
      v_xp := least(60, r.correct * 3 + r.best_streak * 2);
      v_coins := least(40, r.correct + case when r.best_streak >= 10 then 15 when r.best_streak >= 5 then 6 else 0 end);
    end if;

    select xp, level into v_new_xp, v_old_level from profiles where id = v_uid for update;
    v_new_xp := coalesce(v_new_xp, 0) + v_xp;
    v_new_level := (v_new_xp / 100) + 1;
    update profiles
       set xp = v_new_xp, level = v_new_level,
           total_attempts = total_attempts + 1,
           total_correct = total_correct + r.correct,
           total_questions = total_questions + r.answered
     where id = v_uid;
    if v_coins > 0 then perform public._coin_apply(v_uid, v_coins, 'game_reward', p_run_id); end if;

    insert into odd_survival_stats(user_id, best_score, best_streak, best_correct, runs)
      values (v_uid, r.score, r.best_streak, r.correct, 1)
    on conflict (user_id) do update
       set best_score = greatest(odd_survival_stats.best_score, excluded.best_score),
           best_streak = greatest(odd_survival_stats.best_streak, excluded.best_streak),
           best_correct = greatest(odd_survival_stats.best_correct, excluded.best_correct),
           runs = odd_survival_stats.runs + 1, updated_at = now();

    update odd_survival_runs set xp_earned = v_xp, coins_earned = v_coins, rewards_capped = v_capped
     where id = p_run_id;
    select * into r from odd_survival_runs where id = p_run_id;
    return public._odd_survival_result(p_run_id, v_new_level > coalesce(v_old_level, 1));
  end if;
  return public._odd_survival_result(p_run_id, false);
end $$;

create or replace function public._odd_survival_result(p_run_id uuid, p_leveled boolean)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare r public.odd_survival_runs%rowtype; v_level integer; v_xp integer;
begin
  select * into r from odd_survival_runs where id = p_run_id;
  select level, xp into v_level, v_xp from profiles where id = r.user_id;
  return jsonb_build_object(
    'run_id', r.id, 'status', 'over', 'score', r.score, 'correct', r.correct, 'answered', r.answered,
    'best_streak', r.best_streak, 'best_before', r.best_before,
    'new_best', r.score > r.best_before and r.score > 0,
    'missed_best_by', case when r.score <= r.best_before then r.best_before - r.score else 0 end,
    'xp_earned', r.xp_earned, 'coins_earned', r.coins_earned, 'rewards_capped', r.rewards_capped,
    'new_level', v_level, 'new_xp', v_xp, 'leveled_up', p_leveled, 'wind_used', r.wind_used);
end $$;

-- --------------------------------------------------------------- lobby info --
create or replace function public.get_odd_survival_status()
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  s public.odd_survival_stats%rowtype;
  v_today integer;
  v_active uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into s from odd_survival_stats where user_id = v_uid;
  select count(*) into v_today from odd_survival_runs
   where user_id = v_uid and status = 'over' and xp_earned > 0
     and (ended_at at time zone 'Africa/Nairobi')::date = public.nairobi_today();
  select id into v_active from odd_survival_runs where user_id = v_uid and status in ('playing','offer');
  return jsonb_build_object(
    'best_score', coalesce(s.best_score, 0), 'best_streak', coalesce(s.best_streak, 0),
    'best_correct', coalesce(s.best_correct, 0), 'runs', coalesce(s.runs, 0),
    'rewarded_left', greatest(0, 10 - v_today), 'has_active_run', v_active is not null);
end $$;

revoke all on function public._odd_survival_target(integer, integer, integer) from public, anon, authenticated;
revoke all on function public._odd_survival_multiplier(integer) from public, anon, authenticated;
revoke all on function public._odd_survival_serve(uuid) from public, anon, authenticated;
revoke all on function public._odd_survival_state(uuid) from public, anon, authenticated;
revoke all on function public._odd_survival_result(uuid, boolean) from public, anon, authenticated;
revoke all on function public.start_odd_survival_run() from public, anon;
revoke all on function public.answer_odd_survival(uuid, uuid, text) from public, anon;
revoke all on function public.odd_survival_second_wind(uuid) from public, anon;
revoke all on function public.finish_odd_survival_run(uuid) from public, anon;
revoke all on function public.get_odd_survival_status() from public, anon;
grant execute on function public.start_odd_survival_run() to authenticated;
grant execute on function public.answer_odd_survival(uuid, uuid, text) to authenticated;
grant execute on function public.odd_survival_second_wind(uuid) to authenticated;
grant execute on function public.finish_odd_survival_run(uuid) to authenticated;
grant execute on function public.get_odd_survival_status() to authenticated;
