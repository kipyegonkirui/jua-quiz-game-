-- ============================================================================
-- 021_mode_journeys.sql
-- Level journeys for Speed Quiz, Guess It and Odd One Out.
-- Same rules as the Practice Journey (018/019):
--   * levels unlock in order; a level opens once the previous one has >= 1 star
--   * 10-level batches; the next batch needs cumulative stars OR 3 rewarded ads
--   * 1-3 stars per level, from the round's server-recorded correct / total
--   * 5 lives per mode, 5-minute recharge; a failed (0-star) or abandoned level
--     costs a life, a level with >= 1 star returns it
--
-- This is a thin layer ON TOP of the existing mode rounds. A level attempt is a
-- normal round of that mode (started through its own start_* RPC, answered and
-- submitted through its own RPCs, so XP/coins/caps/stats behave exactly as
-- before). Run AFTER 020_odd_one_out.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Tables (server-only; the app talks to the RPCs below).
-- ---------------------------------------------------------------------------
create table if not exists public.mode_level_progress (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  mode          text not null check (mode in ('speed_quiz', 'guess_it', 'odd_one_out')),
  level_number  integer not null check (level_number >= 1),
  best_stars    integer not null default 0 check (best_stars between 0 and 3),
  best_score    integer not null default 0,
  best_total    integer not null default 0,
  attempts      integer not null default 0,
  completed_at  timestamptz,
  updated_at    timestamptz not null default now(),
  primary key (user_id, mode, level_number)
);

-- One row per level attempt. round_id is the underlying mode round (no FK on
-- purpose: abandoned rounds are deleted, the attempt row stays as a record).
create table if not exists public.mode_level_attempts (
  round_id      uuid primary key,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  mode          text not null check (mode in ('speed_quiz', 'guess_it', 'odd_one_out')),
  level_number  integer not null check (level_number >= 1),
  life_slot     integer check (life_slot between 1 and 5),
  status        text not null default 'open' check (status in ('open', 'completed', 'abandoned')),
  stars         integer check (stars between 0 and 3),
  correct       integer,
  total         integer,
  created_at    timestamptz not null default now(),
  completed_at  timestamptz
);

create index if not exists mode_level_attempts_user_open_idx
  on public.mode_level_attempts (user_id, mode, status);

-- NULL available_at = life ready. 'infinity' = reserved by the level being
-- played right now. A timestamp in the future = recharging.
create table if not exists public.mode_lives (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  mode          text not null check (mode in ('speed_quiz', 'guess_it', 'odd_one_out')),
  slot_number   integer not null check (slot_number between 1 and 5),
  available_at  timestamptz,
  updated_at    timestamptz not null default now(),
  primary key (user_id, mode, slot_number)
);

create table if not exists public.mode_batch_unlocks (
  user_id            uuid not null references public.profiles(id) on delete cascade,
  mode               text not null check (mode in ('speed_quiz', 'guess_it', 'odd_one_out')),
  batch_number       integer not null check (batch_number >= 2),
  ad_watches         integer not null default 0 check (ad_watches >= 0),
  ad_unlock_granted  boolean not null default false,
  premium_unlocked   boolean not null default false,
  updated_at         timestamptz not null default now(),
  primary key (user_id, mode, batch_number)
);

alter table public.mode_level_progress enable row level security;
alter table public.mode_level_attempts enable row level security;
alter table public.mode_lives enable row level security;
alter table public.mode_batch_unlocks enable row level security;
revoke all on public.mode_level_progress from anon, authenticated;
revoke all on public.mode_level_attempts from anon, authenticated;
revoke all on public.mode_lives from anon, authenticated;
revoke all on public.mode_batch_unlocks from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public._mode_check(p_mode text)
returns void
language plpgsql
immutable
as $$
begin
  if p_mode is null or p_mode not in ('speed_quiz', 'guess_it', 'odd_one_out') then
    raise exception 'invalid_mode';
  end if;
end;
$$;

-- Questions per level (matches what each mode's start_* RPC deals).
create or replace function public._mode_question_count(p_mode text)
returns integer
language sql
immutable
as $$
  select case p_mode
    when 'speed_quiz'  then 10
    when 'guess_it'    then 5
    when 'odd_one_out' then 8
    else 5
  end
$$;

-- Server-authoritative result of the underlying round.
create or replace function public._mode_round_stats(p_mode text, p_round_id uuid, p_uid uuid)
returns table (done boolean, correct integer, total integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_mode = 'speed_quiz' then
    return query
      select r.status = 'completed', r.correct,
             coalesce(array_length(r.question_order, 1), 0)
      from public.speed_quiz_rounds r
      where r.id = p_round_id and r.user_id = p_uid;
  elsif p_mode = 'guess_it' then
    return query
      select r.status = 'completed', r.correct, r.total
      from public.guess_it_rounds r
      where r.id = p_round_id and r.user_id = p_uid;
  elsif p_mode = 'odd_one_out' then
    return query
      select r.status = 'completed', r.correct, r.total
      from public.odd_one_out_rounds r
      where r.id = p_round_id and r.user_id = p_uid;
  end if;
end;
$$;

create or replace function public._mode_start_round(p_mode text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_round uuid;
begin
  if p_mode = 'speed_quiz' then
    v_round := public.start_speed_quiz_round();
  elsif p_mode = 'guess_it' then
    v_round := public.start_guess_it_round();
  else
    v_round := public.start_odd_one_out_round('quick');
  end if;
  return v_round;
end;
$$;

-- Removes an unfinished round (answers, hints and questions cascade).
create or replace function public._mode_delete_round(p_mode text, p_round_id uuid, p_uid uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_mode = 'speed_quiz' then
    delete from public.speed_quiz_rounds
     where id = p_round_id and user_id = p_uid and status <> 'completed';
  elsif p_mode = 'guess_it' then
    delete from public.guess_it_rounds
     where id = p_round_id and user_id = p_uid and status <> 'completed';
  elsif p_mode = 'odd_one_out' then
    delete from public.odd_one_out_rounds
     where id = p_round_id and user_id = p_uid and status <> 'completed';
  end if;
end;
$$;

create or replace function public._mode_lives_ensure(p_uid uuid, p_mode text)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.mode_lives (user_id, mode, slot_number, available_at)
  select p_uid, p_mode, s, null::timestamptz
  from generate_series(1, 5) as s
  on conflict (user_id, mode, slot_number) do nothing;
$$;

-- ---------------------------------------------------------------------------
-- Lives
-- ---------------------------------------------------------------------------
create or replace function public.get_mode_lives(p_mode text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := now();
  v_available integer;
  v_next timestamptz;
  v_seconds integer := 0;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  perform public._mode_check(p_mode);
  perform public._mode_lives_ensure(v_uid, p_mode);

  select count(*) filter (where available_at is null or available_at <= v_now)::integer,
         min(available_at) filter (where available_at > v_now and available_at < 'infinity'::timestamptz)
    into v_available, v_next
  from public.mode_lives
  where user_id = v_uid and mode = p_mode;

  if v_next is not null then
    v_seconds := greatest(ceil(extract(epoch from (v_next - v_now)))::integer, 0);
  end if;

  return jsonb_build_object(
    'available_lives', v_available,
    'max_lives', 5,
    'next_recharge_at', v_next,
    'recharge_seconds', v_seconds
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Completing / abandoning an attempt
-- ---------------------------------------------------------------------------
create or replace function public.complete_mode_level(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  a public.mode_level_attempts%rowtype;
  v_done boolean;
  v_correct integer;
  v_total integer;
  v_stars integer;
  v_best integer;
  v_cumulative integer;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select * into a
  from public.mode_level_attempts
  where round_id = p_round_id and user_id = v_uid
  for update;
  if not found then raise exception 'attempt_not_found'; end if;

  -- Idempotent: a second call returns the stored result.
  if a.status = 'completed' then
    select best_stars into v_best from public.mode_level_progress
     where user_id = v_uid and mode = a.mode and level_number = a.level_number;
    select coalesce(sum(best_stars), 0) into v_cumulative from public.mode_level_progress
     where user_id = v_uid and mode = a.mode;
    return jsonb_build_object(
      'mode', a.mode, 'level', a.level_number, 'stars', coalesce(a.stars, 0),
      'correct', coalesce(a.correct, 0), 'total', coalesce(a.total, 0),
      'best_stars', coalesce(v_best, 0), 'cumulative_stars', v_cumulative,
      'life_returned', coalesce(a.stars, 0) >= 1
    );
  end if;
  if a.status <> 'open' then raise exception 'attempt_closed'; end if;

  select s.done, s.correct, s.total into v_done, v_correct, v_total
  from public._mode_round_stats(a.mode, p_round_id, v_uid) s;
  if not coalesce(v_done, false) then raise exception 'round_not_completed'; end if;

  v_stars := public.practice_stars_for_score(v_correct, v_total);

  insert into public.mode_level_progress
    (user_id, mode, level_number, best_stars, best_score, best_total, attempts, completed_at)
  values
    (v_uid, a.mode, a.level_number, v_stars, v_correct, v_total, 1,
     case when v_stars >= 1 then now() end)
  on conflict (user_id, mode, level_number) do update set
    best_stars   = greatest(public.mode_level_progress.best_stars, excluded.best_stars),
    best_score   = greatest(public.mode_level_progress.best_score, excluded.best_score),
    best_total   = excluded.best_total,
    attempts     = public.mode_level_progress.attempts + 1,
    completed_at = coalesce(public.mode_level_progress.completed_at,
                            case when excluded.best_stars >= 1 then now() end),
    updated_at   = now();

  -- >= 1 star returns the reserved life; 0 stars bursts it (5-minute recharge).
  if a.life_slot is not null then
    update public.mode_lives
       set available_at = case when v_stars >= 1 then null else now() + interval '5 minutes' end,
           updated_at = now()
     where user_id = v_uid and mode = a.mode and slot_number = a.life_slot;
  end if;

  update public.mode_level_attempts
     set status = 'completed', stars = v_stars, correct = v_correct, total = v_total,
         completed_at = now()
   where round_id = p_round_id;

  select best_stars into v_best from public.mode_level_progress
   where user_id = v_uid and mode = a.mode and level_number = a.level_number;
  select coalesce(sum(best_stars), 0) into v_cumulative from public.mode_level_progress
   where user_id = v_uid and mode = a.mode;

  return jsonb_build_object(
    'mode', a.mode, 'level', a.level_number, 'stars', v_stars,
    'correct', v_correct, 'total', v_total,
    'best_stars', v_best, 'cumulative_stars', v_cumulative,
    'life_returned', v_stars >= 1
  );
end;
$$;

-- Leaving an unfinished level: the life bursts and the half-played round is
-- removed so the next attempt starts fresh.
create or replace function public.abandon_mode_level(p_round_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  a public.mode_level_attempts%rowtype;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select * into a
  from public.mode_level_attempts
  where round_id = p_round_id and user_id = v_uid
  for update;
  if not found or a.status <> 'open' then return false; end if;

  if a.life_slot is not null then
    update public.mode_lives
       set available_at = now() + interval '5 minutes', updated_at = now()
     where user_id = v_uid and mode = a.mode and slot_number = a.life_slot;
  end if;

  perform public._mode_delete_round(a.mode, p_round_id, v_uid);

  update public.mode_level_attempts
     set status = 'abandoned', completed_at = now()
   where round_id = p_round_id;
  return true;
end;
$$;

-- ---------------------------------------------------------------------------
-- Start a level
-- ---------------------------------------------------------------------------
create or replace function public.start_mode_level(p_mode text, p_level integer)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_level integer := greatest(coalesce(p_level, 1), 1);
  v_batch integer := public.practice_batch_for_level(v_level);
  v_open public.mode_level_attempts%rowtype;
  v_round uuid;
  v_slot integer;
  v_cumulative integer;
  v_required integer;
  v_unlocked boolean := false;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  perform public._mode_check(p_mode);

  perform pg_advisory_xact_lock(hashtext('modelevel:' || p_mode || ':' || v_uid::text));

  -- An attempt that is still open?
  select * into v_open
  from public.mode_level_attempts
  where user_id = v_uid and mode = p_mode and status = 'open'
  order by created_at desc
  limit 1;

  if found then
    if exists (
      select 1 from public._mode_round_stats(p_mode, v_open.round_id, v_uid) s where s.done
    ) then
      -- Finished but never settled (app closed before completing): settle now.
      perform public.complete_mode_level(v_open.round_id);
    elsif v_open.level_number = v_level then
      return v_open.round_id; -- resume the same level, no extra life
    else
      perform public.abandon_mode_level(v_open.round_id); -- switching levels
    end if;
  end if;

  -- Unlock rules (server-authoritative).
  if v_level = 1 then
    v_unlocked := true;
  else
    if not exists (
      select 1 from public.mode_level_progress
      where user_id = v_uid and mode = p_mode
        and level_number = v_level - 1 and best_stars >= 1
    ) then
      raise exception 'previous_level_required';
    end if;

    if v_level % 10 = 1 then
      select coalesce(sum(best_stars), 0) into v_cumulative
      from public.mode_level_progress
      where user_id = v_uid and mode = p_mode and level_number < v_level;
      v_required := public.practice_batch_star_requirement(v_batch);
      select exists (
        select 1 from public.mode_batch_unlocks
        where user_id = v_uid and mode = p_mode and batch_number = v_batch
          and (ad_unlock_granted or premium_unlocked)
      ) into v_unlocked;
      v_unlocked := v_unlocked or v_cumulative >= v_required;
    else
      v_unlocked := true;
    end if;
  end if;
  if not v_unlocked then raise exception 'practice_batch_locked'; end if;

  -- Lives: reserve one slot for the duration of this attempt.
  perform public._mode_lives_ensure(v_uid, p_mode);
  select slot_number into v_slot
  from public.mode_lives
  where user_id = v_uid and mode = p_mode
    and (available_at is null or available_at <= now())
  order by slot_number
  limit 1
  for update;
  if v_slot is null then raise exception 'no_practice_lives'; end if;

  v_round := public._mode_start_round(p_mode);

  update public.mode_lives
     set available_at = 'infinity'::timestamptz, updated_at = now()
   where user_id = v_uid and mode = p_mode and slot_number = v_slot;

  insert into public.mode_level_attempts (round_id, user_id, mode, level_number, life_slot)
  values (v_round, v_uid, p_mode, v_level, v_slot)
  on conflict (round_id) do update
    set level_number = excluded.level_number, life_slot = excluded.life_slot,
        status = 'open', stars = null, completed_at = null;

  return v_round;
end;
$$;

-- ---------------------------------------------------------------------------
-- Journey snapshot (same JSON shape as get_practice_journey, so the app's
-- PracticeJourneyData parses it unchanged).
-- ---------------------------------------------------------------------------
create or replace function public.get_mode_journey(p_mode text, p_through_level integer default 100)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_through_level, 100), 10), 1000);
  v_cumulative integer;
  v_highest integer;
  v_max_batch integer := 1;
  v_next_batch integer;
  v_next_req integer;
  v_current integer;
  v_ad_used integer := 0;
  v_b integer;
  v_stars integer;
  v_unlocked boolean;
  v_levels jsonb;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  perform public._mode_check(p_mode);

  select coalesce(sum(best_stars), 0),
         coalesce(max(level_number) filter (where best_stars >= 1), 0)
    into v_cumulative, v_highest
  from public.mode_level_progress
  where user_id = v_uid and mode = p_mode;

  for v_b in 2..ceil(v_limit / 10.0)::integer loop
    select coalesce(sum(best_stars), 0) into v_stars
    from public.mode_level_progress
    where user_id = v_uid and mode = p_mode and level_number < ((v_b - 1) * 10 + 1);
    select exists (
      select 1 from public.mode_batch_unlocks
      where user_id = v_uid and mode = p_mode and batch_number = v_b
        and (ad_unlock_granted or premium_unlocked)
    ) into v_unlocked;
    if v_stars >= public.practice_batch_star_requirement(v_b) or v_unlocked then
      v_max_batch := v_b;
    else
      exit;
    end if;
  end loop;

  v_next_batch := v_max_batch + 1;
  v_next_req := public.practice_batch_star_requirement(v_next_batch);
  select coalesce(ad_watches, 0) into v_ad_used
  from public.mode_batch_unlocks
  where user_id = v_uid and mode = p_mode and batch_number = v_next_batch;
  v_ad_used := coalesce(v_ad_used, 0);

  v_current := greatest(v_highest + 1, 1);
  if public.practice_batch_for_level(v_current) > v_max_batch then
    v_current := v_max_batch * 10;
  end if;

  select jsonb_agg(
           jsonb_build_object(
             'level', g.lvl,
             'batch', public.practice_batch_for_level(g.lvl),
             'question_count', public._mode_question_count(p_mode),
             'difficulty', 'mixed',
             'stars', coalesce(p.best_stars, 0),
             'completed', coalesce(p.best_stars, 0) >= 1,
             'unlocked', g.lvl = 1 or (
               public.practice_batch_for_level(g.lvl) <= v_max_batch
               and g.lvl <= v_highest + 1)
           ) order by g.lvl)
    into v_levels
  from generate_series(1, v_limit) as g(lvl)
  left join public.mode_level_progress p
    on p.user_id = v_uid and p.mode = p_mode and p.level_number = g.lvl;

  return jsonb_build_object(
    'current_level', v_current,
    'cumulative_stars', v_cumulative,
    'cumulative_available_stars', greatest(30, v_max_batch * 30),
    'next_batch', v_next_batch,
    'next_batch_requirement', v_next_req,
    'next_batch_available_stars', (v_next_batch - 1) * 30,
    'next_batch_requirement_percent', public.practice_required_percent(v_next_batch),
    'ad_unlocks_used', v_ad_used,
    'ad_unlocks_per_batch', 3,
    'levels', coalesce(v_levels, '[]'::jsonb)
  );
end;
$$;

-- Three rewarded videos unlock a locked batch (same flow as Practice; the
-- client must have earned the ad before calling).
create or replace function public.unlock_mode_batch_by_ad(p_mode text, p_batch_number integer)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_batch integer := greatest(coalesce(p_batch_number, 2), 2);
  v_watches integer;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  perform public._mode_check(p_mode);

  insert into public.mode_batch_unlocks (user_id, mode, batch_number)
  values (v_uid, p_mode, v_batch)
  on conflict (user_id, mode, batch_number) do nothing;

  select ad_watches into v_watches
  from public.mode_batch_unlocks
  where user_id = v_uid and mode = p_mode and batch_number = v_batch
  for update;

  if v_watches >= 3 then raise exception 'ad_unlock_limit_reached'; end if;

  update public.mode_batch_unlocks
     set ad_watches = ad_watches + 1,
         ad_unlock_granted = ad_watches + 1 >= 3,
         updated_at = now()
   where user_id = v_uid and mode = p_mode and batch_number = v_batch;

  return public.get_mode_journey(p_mode, 100);
end;
$$;

grant execute on function public.get_mode_lives(text) to authenticated;
grant execute on function public.get_mode_journey(text, integer) to authenticated;
grant execute on function public.start_mode_level(text, integer) to authenticated;
grant execute on function public.complete_mode_level(uuid) to authenticated;
grant execute on function public.abandon_mode_level(uuid) to authenticated;
grant execute on function public.unlock_mode_batch_by_ad(text, integer) to authenticated;

-- Internal helpers are not callable from the app.
revoke all on function public._mode_round_stats(text, uuid, uuid) from public, anon, authenticated;
revoke all on function public._mode_start_round(text) from public, anon, authenticated;
revoke all on function public._mode_delete_round(text, uuid, uuid) from public, anon, authenticated;
revoke all on function public._mode_lives_ensure(uuid, text) from public, anon, authenticated;
