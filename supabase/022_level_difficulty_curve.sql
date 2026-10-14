-- ============================================================================
-- 022_level_difficulty_curve.sql
-- Speed Quiz / Guess It / Odd One Out levels follow the SAME easy -> medium ->
-- hard curve as the Practice journey (practice_difficulty_mix, defined in
-- 020_practice_difficulty_and_math.sql).
--
-- RUN ORDER: ... 019, 020_odd_one_out, 020_practice_difficulty_and_math, 021, 022.
--
-- This file deliberately does NOT replace start_practice_level_round: Practice
-- keeps the version from 020_practice_difficulty_and_math.sql (with its Math
-- levels). If an earlier copy of this file was already run, it overwrote that
-- function: re-run 020_practice_difficulty_and_math.sql afterwards to restore it.
--
-- Inside a level the questions are ordered easy first, hard last. When a
-- difficulty runs short the nearest one fills in, so small pools never break a
-- level; unseen / least-recently-seen questions come first.
-- ============================================================================

create or replace function public.mode_level_difficulty_mix(p_level integer, p_count integer)
returns table (easy integer, medium integer, hard integer)
language sql
stable
as $$
  select m.n_easy, m.n_medium, m.n_hard
  from public.practice_difficulty_mix(p_level, p_count) m
$$;

-- Dominant difficulty of a level, for the map labels.
create or replace function public.mode_level_difficulty_label(p_level integer)
returns text
language sql
immutable
as $$
  select case
    when m.hard >= m.medium and m.hard >= m.easy then 'hard'
    when m.medium >= m.easy then 'medium'
    else 'easy'
  end
  from public.mode_level_difficulty_mix(p_level, 10) m
$$;

-- Picks p_count ids following the level's difficulty mix. The arrays must be
-- sorted by priority already (best candidate first) and aligned with each
-- other. Returns the picked ids ordered easy -> hard.
create or replace function public._select_level_ids(
  p_ids uuid[], p_difficulties text[], p_level integer, p_count integer
)
returns uuid[]
language plpgsql
stable
as $$
declare
  v_mix record;
  v_center numeric;
  v_result uuid[];
begin
  if coalesce(array_length(p_ids, 1), 0) = 0 then return '{}'::uuid[]; end if;
  select * into v_mix from public.mode_level_difficulty_mix(p_level, p_count);
  v_center := (v_mix.easy * 1 + v_mix.medium * 2 + v_mix.hard * 3)::numeric / greatest(p_count, 1);

  with c as (
    select u.id,
           u.ord as pri,
           case d.diff when 'easy' then 1 when 'medium' then 2 else 3 end as tier
    from unnest(p_ids) with ordinality as u(id, ord)
    join unnest(p_difficulties) with ordinality as d(diff, ord2) on d.ord2 = u.ord
  ),
  ranked as (
    select c.*, row_number() over (partition by tier order by pri) as rn from c
  ),
  primary_pick as (
    select * from ranked
    where (tier = 1 and rn <= v_mix.easy)
       or (tier = 2 and rn <= v_mix.medium)
       or (tier = 3 and rn <= v_mix.hard)
  ),
  filler as (
    select r.* from ranked r
    where r.id not in (select id from primary_pick)
    order by abs(r.tier - v_center), r.pri
    limit greatest(p_count - (select count(*) from primary_pick), 0)
  ),
  final as (
    select * from primary_pick
    union all
    select * from filler
  )
  select array_agg(id order by tier, pri) into v_result from final;

  return coalesce(v_result, '{}'::uuid[]);
end;
$$;

-- Re-deals a freshly created level round so its questions follow the curve.
-- Only touches rounds with no answers yet; a resumed round is left alone.
create or replace function public._mode_deal_level(
  p_mode text, p_round_id uuid, p_uid uuid, p_level integer
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := public._mode_question_count(p_mode);
  v_ids uuid[];
  v_diffs text[];
  v_picked uuid[];
begin
  if p_mode = 'speed_quiz' then
    if exists (select 1 from public.speed_quiz_answers where round_id = p_round_id) then return; end if;

    with seen as (
      select a.question_id, max(a.answered_at) as seen_at
      from public.speed_quiz_answers a
      join public.speed_quiz_rounds r on r.id = a.round_id
      where r.user_id = p_uid
      group by a.question_id
    ),
    cand as (
      select q.id, q.difficulty,
             row_number() over (order by (s.seen_at is not null), s.seen_at asc, random()) as pri
      from public.questions q
      left join seen s on s.question_id = q.id
      where q.is_active
    )
    select array_agg(id order by pri), array_agg(difficulty order by pri) into v_ids, v_diffs from cand;

    v_picked := public._select_level_ids(v_ids, v_diffs, p_level, v_count);
    -- Speed Quiz needs a full round; keep the random deal if the pool is short.
    if coalesce(array_length(v_picked, 1), 0) < v_count then return; end if;
    update public.speed_quiz_rounds
       set question_order = v_picked
     where id = p_round_id and user_id = p_uid;

  elsif p_mode = 'guess_it' then
    if exists (select 1 from public.guess_it_answers where round_id = p_round_id) then return; end if;

    with seen as (
      select a.question_id, max(a.created_at) as seen_at
      from public.guess_it_answers a
      join public.guess_it_rounds r on r.id = a.round_id
      where r.user_id = p_uid
      group by a.question_id
    ),
    cand as (
      select q.id, q.difficulty,
             row_number() over (order by (s.seen_at is not null), s.seen_at asc, random()) as pri
      from public.guess_it_questions q
      left join seen s on s.question_id = q.id
      where q.is_active
    )
    select array_agg(id order by pri), array_agg(difficulty order by pri) into v_ids, v_diffs from cand;

    v_picked := public._select_level_ids(v_ids, v_diffs, p_level, v_count);
    if coalesce(array_length(v_picked, 1), 0) = 0 then return; end if;

    delete from public.guess_it_round_questions where round_id = p_round_id;
    insert into public.guess_it_round_questions (round_id, question_id, position)
    select p_round_id, x.id, x.ord::integer
    from unnest(v_picked) with ordinality as x(id, ord);
    update public.guess_it_rounds set total = array_length(v_picked, 1)
     where id = p_round_id and user_id = p_uid;

  elsif p_mode = 'odd_one_out' then
    if exists (select 1 from public.odd_one_out_answers where round_id = p_round_id) then return; end if;

    with seen as (
      select a.puzzle_id, max(a.created_at) as seen_at
      from public.odd_one_out_answers a
      join public.odd_one_out_rounds r on r.id = a.round_id
      where r.user_id = p_uid
      group by a.puzzle_id
    ),
    cand as (
      select p.id, p.difficulty,
             row_number() over (order by (s.seen_at is not null), s.seen_at asc, random()) as pri
      from public.odd_one_out_puzzles p
      left join seen s on s.puzzle_id = p.id
      where p.is_active
    )
    select array_agg(id order by pri), array_agg(difficulty order by pri) into v_ids, v_diffs from cand;

    v_picked := public._select_level_ids(v_ids, v_diffs, p_level, v_count);
    if coalesce(array_length(v_picked, 1), 0) = 0 then return; end if;

    delete from public.odd_one_out_round_puzzles where round_id = p_round_id;
    insert into public.odd_one_out_round_puzzles (round_id, puzzle_id, position)
    select p_round_id, x.id, x.ord::integer
    from unnest(v_picked) with ordinality as x(id, ord);
    update public.odd_one_out_rounds set total = array_length(v_picked, 1)
     where id = p_round_id and user_id = p_uid;
  end if;
end;
$$;

revoke all on function public._mode_deal_level(text, uuid, uuid, integer) from public, anon, authenticated;
revoke all on function public._select_level_ids(uuid[], text[], integer, integer) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Replaced functions (same as before except for the question selection /
-- difficulty label).
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
             'difficulty', public.mode_level_difficulty_label(g.lvl),
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
  perform public._mode_deal_level(p_mode, v_round, v_uid, v_level);

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

grant execute on function public.mode_level_difficulty_mix(integer, integer) to authenticated;
grant execute on function public.mode_level_difficulty_label(integer) to authenticated;
grant execute on function public.get_mode_journey(text, integer) to authenticated;
grant execute on function public.start_mode_level(text, integer) to authenticated;
