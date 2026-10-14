-- ---------------------------------------------------------------------------
-- Phase 1 Practice Lives
-- Five independent lives for Practice Journey levels.
-- A life is reserved when a level attempt starts, but is NOT consumed yet.
-- If the player earns at least one star, the reserved life is returned immediately
-- and no cooldown starts. If the player fails (0 stars) or exits an unfinished
-- level, the reserved life bursts and begins a five-minute cooldown.
-- This keeps successful progression free while making failed/abandoned attempts
-- cost one life.
-- ---------------------------------------------------------------------------

alter table public.practice_rounds
  drop constraint if exists practice_rounds_status_check;

alter table public.practice_rounds
  add constraint practice_rounds_status_check
  check (status in ('open', 'completed', 'abandoned'));

alter table public.practice_rounds
  add column if not exists practice_life_slot integer check (practice_life_slot between 1 and 5);

create index if not exists practice_rounds_open_life_idx
  on public.practice_rounds (user_id, status, practice_life_slot);

create table if not exists public.practice_lives (
  user_id uuid not null references public.profiles(id) on delete cascade,
  slot_number integer not null check (slot_number between 1 and 5),
  available_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, slot_number)
);

create index if not exists practice_lives_available_idx
  on public.practice_lives (user_id, available_at);

alter table public.practice_lives enable row level security;
revoke all on public.practice_lives from anon, authenticated;

-- Lazily create the five slots for a player. NULL means the life is available.
create or replace function public.ensure_practice_lives(p_uid uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.practice_lives(user_id, slot_number, available_at)
  select p_uid, s, null::timestamptz
  from generate_series(1, 5) as s
  on conflict (user_id, slot_number) do nothing;
$$;

create or replace function public.get_practice_lives()
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
  v_seconds integer;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  perform public.ensure_practice_lives(v_uid);

  select count(*)::integer into v_available
  from public.practice_lives
  where user_id = v_uid
    and (available_at is null or available_at <= v_now);

  select min(available_at) into v_next
  from public.practice_lives
  where user_id = v_uid and available_at > v_now;

  v_seconds := case when v_next is null then 0
                    else greatest(0, ceil(extract(epoch from (v_next - v_now)))::integer)
               end;

  return jsonb_build_object(
    'available_lives', v_available,
    'max_lives', 5,
    'next_recharge_at', v_next,
    'recharge_seconds', v_seconds
  );
end;
$$;

-- Reserve exactly one available life slot for the open level. No cooldown is
-- started here. The slot is either returned on a pass or burst on failure/exit.
create or replace function public.reserve_practice_life(p_round_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_slot integer;
  v_now timestamptz := now();
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  perform public.ensure_practice_lives(v_uid);

  select slot_number into v_slot
  from public.practice_lives
  where user_id = v_uid
    and (available_at is null or available_at <= v_now)
  order by slot_number
  for update skip locked
  limit 1;

  if v_slot is null then
    raise exception 'no_practice_lives';
  end if;

  update public.practice_rounds
  set practice_life_slot = v_slot
  where id = p_round_id and user_id = v_uid and status = 'open';

  if not found then raise exception 'round not found'; end if;
  return v_slot;
end;
$$;

-- Finalize the reserved life. A pass (1+ stars) returns it immediately; a
-- failure or abandoned level starts the five-minute recharge.
create or replace function public.finalize_practice_life(p_round_id uuid, p_burst boolean)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_slot integer;
  v_now timestamptz := now();
  v_next timestamptz;
  v_available integer;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select practice_life_slot into v_slot
  from public.practice_rounds
  where id = p_round_id and user_id = v_uid
  for update;

  if v_slot is null then
    return public.get_practice_lives();
  end if;

  if p_burst then
    v_next := v_now + interval '5 minutes';
    update public.practice_lives
    set available_at = v_next, updated_at = v_now
    where user_id = v_uid and slot_number = v_slot;
  else
    update public.practice_lives
    set available_at = null, updated_at = v_now
    where user_id = v_uid and slot_number = v_slot;
  end if;

  update public.practice_rounds
  set practice_life_slot = null
  where id = p_round_id and user_id = v_uid;

  select count(*)::integer into v_available
  from public.practice_lives
  where user_id = v_uid and (available_at is null or available_at <= v_now);

  select min(available_at) into v_next
  from public.practice_lives
  where user_id = v_uid and available_at > v_now;

  return jsonb_build_object(
    'available_lives', v_available,
    'max_lives', 5,
    'next_recharge_at', v_next,
    'recharge_seconds', case when v_next is null then 0 else greatest(0, ceil(extract(epoch from (v_next - v_now)))::integer) end,
    'life_burst', p_burst
  );
end;
$$;

-- Explicitly close a level that the player exits before submitting it. The
-- reserved life bursts here and starts its five-minute recharge.
create or replace function public.abandon_practice_level_round(p_round_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_open boolean;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select exists (
    select 1 from public.practice_rounds
    where id = p_round_id and user_id = v_uid and status = 'open'
  ) into v_open;

  if not v_open then return false; end if;

  perform public.finalize_practice_life(p_round_id, true);

  update public.practice_rounds
  set status = 'abandoned', completed_at = now()
  where id = p_round_id and user_id = v_uid and status = 'open';

  return found;
end;
$$;

-- Replace the level starter so every fresh attempt reserves one life without
-- starting its cooldown. An orphaned open round is treated as an abandonment.
create or replace function public.start_practice_level_round(p_level integer)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_level integer := greatest(coalesce(p_level, 1), 1);
  v_batch integer := public.practice_batch_for_level(v_level);
  v_round uuid;
  v_stale_round uuid;
  v_count integer;
  v_required integer;
  v_cumulative integer;
  v_unlocked boolean := false;
  v_difficulty text := public.practice_difficulty_for_batch(v_batch);
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  perform pg_advisory_xact_lock(hashtext('practice:' || v_uid::text));

  -- No level can be resumed after leaving. A stale open level is treated as
  -- abandoned, so its reserved life bursts and starts its five-minute cooldown.
  for v_stale_round in
    select id from public.practice_rounds
    where user_id = v_uid and status = 'open'
  loop
    perform public.finalize_practice_life(v_stale_round, true);
    update public.practice_rounds
    set status = 'abandoned', completed_at = now()
    where id = v_stale_round and user_id = v_uid and status = 'open';
  end loop;

  if v_level = 1 then
    v_unlocked := true;
  else
    if not exists (
      select 1 from public.practice_level_progress
      where user_id = v_uid and level_number = v_level - 1 and best_stars >= 1
    ) then
      raise exception 'previous_level_required';
    end if;

    if v_level % 10 = 1 then
      select coalesce(sum(best_stars), 0) into v_cumulative
      from public.practice_level_progress
      where user_id = v_uid and level_number < v_level;
      v_required := public.practice_batch_star_requirement(v_batch);

      select exists (
        select 1 from public.practice_batch_unlocks
        where user_id = v_uid and batch_number = v_batch
          and (ad_unlock_granted or premium_unlocked)
      ) into v_unlocked;
      v_unlocked := v_unlocked or v_cumulative >= v_required;
    else
      v_unlocked := true;
    end if;
  end if;

  if not v_unlocked then
    raise exception 'practice_batch_locked';
  end if;

  -- Reserve a life only after all unlock checks have passed. Reservation does
  -- not start a cooldown; finalization decides whether the life bursts or returns.
  insert into public.practice_rounds (user_id, practice_level)
  values (v_uid, v_level)
  returning id into v_round;

  perform public.reserve_practice_life(v_round);

  v_count := public.practice_question_count(v_level);

  with today_daily as (
    select dcq.question_id
    from public.daily_challenges dc
    join public.daily_challenge_questions dcq on dcq.daily_challenge_id = dc.id
    where dc.challenge_date = public.nairobi_today()
  ),
  seen as (
    select prq.question_id, pr.started_at as seen_at
    from public.practice_round_questions prq
    join public.practice_rounds pr on pr.id = prq.round_id
    where pr.user_id = v_uid
    union all
    select dcq.question_id, a.completed_at
    from public.attempts a
    join public.daily_challenge_questions dcq on dcq.daily_challenge_id = a.daily_challenge_id
    where a.user_id = v_uid
  ),
  last_seen as (
    select question_id, max(seen_at) as seen_at from seen group by question_id
  ),
  picked as (
    select q.id
    from public.questions q
    left join last_seen ls on ls.question_id = q.id
    where q.is_active
    order by
      (q.id in (select question_id from today_daily)),
      case when q.difficulty = v_difficulty then 0
           when v_difficulty = 'hard' and q.difficulty = 'medium' then 1
           when v_difficulty = 'medium' and q.difficulty = 'easy' then 1
           else 2 end,
      (ls.seen_at is not null),
      ls.seen_at asc,
      random()
    limit v_count
  )
  insert into public.practice_round_questions (round_id, question_id, position)
  select v_round, id, row_number() over ()::integer from picked;

  get diagnostics v_count = row_count;
  if v_count = 0 then raise exception 'no questions available'; end if;

  update public.practice_rounds set total_questions = v_count where id = v_round;
  return v_round;
end;
$$;

revoke execute on function public.ensure_practice_lives(uuid) from public, anon, authenticated;
revoke execute on function public.get_practice_lives() from public, anon;
revoke execute on function public.reserve_practice_life(uuid) from public, anon, authenticated;
revoke execute on function public.finalize_practice_life(uuid, boolean) from public, anon, authenticated;
-- consume_practice_life() was never created in this migration set; the old
-- unconditional REVOKE raised an error and stopped the grants below from running.
do $$
begin
  if to_regprocedure('public.consume_practice_life()') is not null then
    revoke execute on function public.consume_practice_life() from public, anon, authenticated;
  end if;
end $$;
revoke execute on function public.abandon_practice_level_round(uuid) from public, anon;
revoke execute on function public.start_practice_level_round(integer) from public, anon;

grant execute on function public.get_practice_lives() to authenticated;
grant execute on function public.abandon_practice_level_round(uuid) to authenticated;
grant execute on function public.start_practice_level_round(integer) to authenticated;
