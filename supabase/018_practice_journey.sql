-- ============================================================================
-- 018_practice_journey.sql
-- Practice Journey: endless 10-level batches, 3-star mastery, cumulative gates.
-- Run AFTER 017_guess_it.sql.
-- ============================================================================

alter table public.practice_rounds
  add column if not exists practice_level integer not null default 1
    check (practice_level >= 1);

create index if not exists practice_rounds_user_level_idx
  on public.practice_rounds (user_id, practice_level, status);

create table if not exists public.practice_level_progress (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  level_number  integer not null check (level_number >= 1),
  best_stars    integer not null default 0 check (best_stars between 0 and 3),
  best_score    integer not null default 0,
  best_total    integer not null default 0,
  attempts      integer not null default 0,
  completed_at  timestamptz,
  updated_at    timestamptz not null default now(),
  primary key (user_id, level_number)
);

create table if not exists public.practice_batch_unlocks (
  user_id          uuid not null references public.profiles(id) on delete cascade,
  batch_number     integer not null check (batch_number >= 2),
  ad_watches       integer not null default 0 check (ad_watches >= 0),
  ad_unlock_granted boolean not null default false,
  premium_unlocked boolean not null default false,
  updated_at       timestamptz not null default now(),
  primary key (user_id, batch_number)
);

alter table public.practice_level_progress enable row level security;
alter table public.practice_batch_unlocks enable row level security;
revoke all on public.practice_level_progress from anon, authenticated;
revoke all on public.practice_batch_unlocks from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Shared server rules.
-- ---------------------------------------------------------------------------
create or replace function public.practice_batch_for_level(p_level integer)
returns integer
language sql immutable
as $$ select ((greatest(p_level, 1) - 1) / 10) + 1 $$;

create or replace function public.practice_question_count(p_level integer)
returns integer
language sql immutable
as $$ select 5 + least(((greatest(p_level, 1) - 1) / 10), 5) $$;

create or replace function public.practice_difficulty_for_batch(p_batch integer)
returns text
language sql immutable
as $$
  select case
    when p_batch <= 2 then 'easy'
    when p_batch <= 4 then 'medium'
    else 'hard'
  end
$$;

create or replace function public.practice_required_percent(p_batch integer)
returns integer
language sql immutable
as $$
  select case
    when p_batch = 2 then 50
    when p_batch = 3 then 75
    when p_batch = 4 then 80
    when p_batch = 5 then 85
    when p_batch = 6 then 88
    else 90
  end
$$;

create or replace function public.practice_batch_star_requirement(p_batch integer)
returns integer
language sql immutable
as $$
  select case
    when p_batch <= 1 then 0
    else ceil((((p_batch - 1) * 30)::numeric * public.practice_required_percent(p_batch)) / 100.0)::integer
  end
$$;

create or replace function public.practice_stars_for_score(p_score integer, p_total integer)
returns integer
language sql immutable
as $$
  select case
    when coalesce(p_total, 0) <= 0 or coalesce(p_score, 0) <= 0 then 0
    when p_score >= p_total then 3
    when (p_score * 100) / p_total >= 70 then 2
    else 1
  end
$$;

-- ---------------------------------------------------------------------------
-- Start a level. The server is authoritative about unlocks and difficulty.
-- ---------------------------------------------------------------------------
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
  v_count integer;
  v_required integer;
  v_cumulative integer;
  v_unlocked boolean := false;
  v_difficulty text := public.practice_difficulty_for_batch(v_batch);
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  perform pg_advisory_xact_lock(hashtext('practice:' || v_uid::text));

  select id into v_round
  from public.practice_rounds
  where user_id = v_uid and status = 'open'
  order by started_at desc
  limit 1;
  if v_round is not null then
    if (select practice_level from public.practice_rounds where id = v_round) = v_level then
      return v_round;
    end if;
    raise exception 'finish_current_practice_level';
  end if;

  if v_level = 1 then
    v_unlocked := true;
  else
    -- Every new level follows the previous one. Batch boundaries additionally
    -- require the cumulative mastery gate unless the batch was ad/premium unlocked.
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

  insert into public.practice_rounds (user_id, practice_level)
  values (v_uid, v_level)
  returning id into v_round;

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

-- Keep old callers working: the legacy Practice button starts Level 1.
create or replace function public.start_practice_round()
returns uuid
language sql
security definer
set search_path = public, pg_temp
as $$ select public.start_practice_level_round(1) $$;

-- ---------------------------------------------------------------------------
-- Server-authoritative journey snapshot.
-- ---------------------------------------------------------------------------
create or replace function public.get_practice_journey(p_through_level integer default 100)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_through_level, 100), 10), 1000);
  v_cumulative integer;
  v_highest_completed integer;
  v_next_batch integer;
  v_next_req integer;
  v_next_available integer;
  v_current integer;
  v_ad_used integer := 0;
  v_ad_limit constant integer := 3;
  v_max_unlocked_batch integer := 1;
  v_b integer;
  v_req integer;
  v_stars integer;
  v_unlocked boolean;
  v_levels jsonb := '[]'::jsonb;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select coalesce(sum(best_stars), 0),
         coalesce(max(level_number) filter (where best_stars >= 1), 0)
    into v_cumulative, v_highest_completed
  from public.practice_level_progress
  where user_id = v_uid;

  -- Work out how many 10-level batches are accessible, including ad/premium unlocks.
  for v_b in 2..ceil(v_limit / 10.0)::integer loop
    v_req := public.practice_batch_star_requirement(v_b);
    select coalesce(sum(best_stars), 0) into v_stars
    from public.practice_level_progress
    where user_id = v_uid and level_number < ((v_b - 1) * 10 + 1);
    select exists (
      select 1 from public.practice_batch_unlocks
      where user_id = v_uid and batch_number = v_b
        and (ad_unlock_granted or premium_unlocked)
    ) into v_unlocked;
    if v_stars >= v_req or v_unlocked then
      v_max_unlocked_batch := v_b;
    else
      exit;
    end if;
  end loop;

  v_next_batch := v_max_unlocked_batch + 1;
  v_next_req := public.practice_batch_star_requirement(v_next_batch);
  v_next_available := (v_next_batch - 1) * 30;
  if v_next_batch > 2 then
    select coalesce(ad_watches, 0) into v_ad_used
    from public.practice_batch_unlocks
    where user_id = v_uid and batch_number = v_next_batch;
  end if;

  v_current := greatest(v_highest_completed + 1, 1);
  if public.practice_batch_for_level(v_current) > v_max_unlocked_batch then
    v_current := v_max_unlocked_batch * 10;
  end if;

  for v_b in 1..v_limit loop
    select coalesce(plp.best_stars, 0) into v_stars
    from public.practice_level_progress plp
    where plp.user_id = v_uid and plp.level_number = v_b;

    v_unlocked := public.practice_batch_for_level(v_b) <= v_max_unlocked_batch
      and (v_b <= v_highest_completed + 1);
    if v_b = 1 then v_unlocked := true; end if;

    v_levels := v_levels || jsonb_build_object(
      'level', v_b,
      'batch', public.practice_batch_for_level(v_b),
      'question_count', public.practice_question_count(v_b),
      'difficulty', public.practice_difficulty_for_batch(public.practice_batch_for_level(v_b)),
      'stars', v_stars,
      'completed', exists (
        select 1 from public.practice_level_progress
        where user_id = v_uid and level_number = v_b
      ),
      'unlocked', v_unlocked
    );
  end loop;

  return jsonb_build_object(
    'current_level', v_current,
    'cumulative_stars', v_cumulative,
    'cumulative_available_stars', greatest(30, v_max_unlocked_batch * 30),
    'next_batch', v_next_batch,
    'next_batch_requirement', v_next_req,
    'next_batch_available_stars', v_next_available,
    'next_batch_requirement_percent', public.practice_required_percent(v_next_batch),
    'ad_unlocks_used', v_ad_used,
    'ad_unlocks_per_batch', v_ad_limit,
    'levels', v_levels
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Three rewarded videos can unlock a locked batch. The ad itself must be
-- earned by the client before this RPC is called. The existing AdMob flow is
-- deliberately used here; server-side verification can replace this later.
-- ---------------------------------------------------------------------------
create or replace function public.unlock_practice_batch_by_ad(p_batch_number integer)
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

  insert into public.practice_batch_unlocks(user_id, batch_number)
  values (v_uid, v_batch)
  on conflict (user_id, batch_number) do nothing;

  select ad_watches into v_watches
  from public.practice_batch_unlocks
  where user_id = v_uid and batch_number = v_batch
  for update;

  if v_watches >= 3 then raise exception 'ad_unlock_limit_reached'; end if;

  update public.practice_batch_unlocks
  set ad_watches = ad_watches + 1,
      ad_unlock_granted = ad_watches + 1 >= 3,
      updated_at = now()
  where user_id = v_uid and batch_number = v_batch;

  return public.get_practice_journey(100);
end;
$$;

-- ---------------------------------------------------------------------------
-- Replace the final practice submit with Journey star persistence while
-- preserving the existing XP cap and one-shot scoring behavior.
-- ---------------------------------------------------------------------------
create or replace function public.submit_practice_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := public.nairobi_today();
  v_daily_cap constant integer := 500;
  v_round public.practice_rounds%rowtype;
  v_profile public.profiles%rowtype;
  v_score integer;
  v_total integer;
  v_raw_xp integer;
  v_xp_earned integer;
  v_xp_today integer;
  v_old_level integer;
  v_new_xp integer;
  v_new_level integer;
  v_stars integer;
  v_cumulative integer;
  v_available integer;
  v_next_batch integer;
  v_next_req integer;
  v_answers jsonb;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select * into v_round
  from public.practice_rounds
  where id = p_round_id and user_id = v_uid
  for update;
  if not found then raise exception 'round not found'; end if;
  if v_round.status <> 'open' then raise exception 'round already submitted'; end if;

  select count(*)::integer,
         count(*) filter (where is_correct)::integer,
         coalesce(jsonb_object_agg(question_id::text, chosen) filter (where chosen is not null), '{}'::jsonb)
    into v_total, v_score, v_answers
  from public.practice_round_questions
  where round_id = p_round_id;
  if v_total = 0 then raise exception 'round has no questions'; end if;

  v_stars := public.practice_stars_for_score(v_score, v_total);
  v_raw_xp := v_score * 10;

  select coalesce(sum(xp_earned), 0) into v_xp_today
  from public.practice_rounds
  where user_id = v_uid and status = 'completed'
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

  -- A level that earns at least one star returns its reserved life immediately.
  -- A zero-star result bursts the life and starts its five-minute cooldown.
  perform public.finalize_practice_life(p_round_id, v_stars < 1);

  update public.practice_rounds set
    status = 'completed', score = v_score, total_questions = v_total,
    xp_earned = v_xp_earned, answers = v_answers, completed_at = now()
  where id = p_round_id;

  insert into public.practice_level_progress(user_id, level_number, best_stars, best_score, best_total, attempts, completed_at, updated_at)
  values (v_uid, v_round.practice_level, v_stars, v_score, v_total, 1, now(), now())
  on conflict (user_id, level_number) do update set
    best_stars = greatest(public.practice_level_progress.best_stars, excluded.best_stars),
    best_score = case when excluded.best_stars >= public.practice_level_progress.best_stars
                      then greatest(public.practice_level_progress.best_score, excluded.best_score)
                      else public.practice_level_progress.best_score end,
    best_total = case when excluded.best_stars >= public.practice_level_progress.best_stars
                      then excluded.best_total else public.practice_level_progress.best_total end,
    attempts = public.practice_level_progress.attempts + 1,
    completed_at = coalesce(public.practice_level_progress.completed_at, excluded.completed_at),
    updated_at = now();

  select coalesce(sum(best_stars), 0) into v_cumulative
  from public.practice_level_progress where user_id = v_uid;
  v_next_batch := public.practice_batch_for_level(v_round.practice_level) + 1;
  v_next_req := public.practice_batch_star_requirement(v_next_batch);
  v_available := (v_next_batch - 1) * 30;

  return jsonb_build_object(
    'score', v_score, 'total', v_total, 'xp_earned', v_xp_earned,
    'new_xp', v_new_xp, 'new_level', v_new_level,
    'leveled_up', v_new_level > v_old_level,
    'current_streak', v_profile.current_streak,
    'longest_streak', v_profile.longest_streak,
    'xp_capped', v_xp_earned < v_raw_xp,
    'practice_xp_today', v_xp_today + v_xp_earned,
    'practice_xp_cap', v_daily_cap,
    'practice_level', v_round.practice_level,
    'practice_stars', v_stars,
    'cumulative_practice_stars', v_cumulative,
    'cumulative_practice_available_stars', greatest(30, v_available),
    'next_practice_batch', v_next_batch,
    'next_practice_batch_requirement', v_next_req
  );
end;
$$;

revoke execute on function public.start_practice_level_round(integer) from public, anon;
revoke execute on function public.start_practice_round() from public, anon;
revoke execute on function public.get_practice_journey(integer) from public, anon;
revoke execute on function public.unlock_practice_batch_by_ad(integer) from public, anon;
revoke execute on function public.submit_practice_round(uuid) from public, anon;
grant execute on function public.start_practice_level_round(integer) to authenticated;
grant execute on function public.start_practice_round() to authenticated;
grant execute on function public.get_practice_journey(integer) to authenticated;
grant execute on function public.unlock_practice_batch_by_ad(integer) to authenticated;
grant execute on function public.submit_practice_round(uuid) to authenticated;
