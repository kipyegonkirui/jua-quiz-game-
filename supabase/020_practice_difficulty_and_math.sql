-- ============================================================================
-- 020_practice_difficulty_and_math.sql
-- Practice Journey: a smooth easy -> medium -> hard curve inside and across
-- batches, plus a procedurally generated MATH level at every 10th level
-- (10, 20, 30, ...) whose difficulty keeps rising.
-- Run AFTER 019_practice_lives.sql.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Generated questions are stored like normal ones (so answering, hints and
--    second chances all keep working) but are inactive, so they never leak into
--    the daily challenge, competitions or the normal practice pool.
-- ---------------------------------------------------------------------------
alter table public.questions
  add column if not exists is_generated boolean not null default false;

insert into public.categories (name)
select 'Mathematics'
where not exists (select 1 from public.categories where name = 'Mathematics');

-- ---------------------------------------------------------------------------
-- 2. Level rules.
-- ---------------------------------------------------------------------------
-- Every 10th level is a Math level (the "boss" of each batch).
create or replace function public.practice_is_math_level(p_level integer)
returns boolean
language sql immutable
as $$ select greatest(coalesce(p_level, 1), 1) % 10 = 0 $$;

-- Math tier: level 10 -> 1, level 20 -> 2, ...
create or replace function public.practice_math_tier(p_level integer)
returns integer
language sql immutable
as $$ select greatest(coalesce(p_level, 1), 1) / 10 $$;

-- Share of easy / medium / hard questions by level. Linear interpolation
-- between anchors so difficulty creeps up level by level instead of jumping
-- at batch boundaries:
--   level  1: 100% easy
--   level 21:  55% easy, 45% medium
--   level 41:  20% easy, 50% medium, 30% hard
--   level 61:   5% easy, 40% medium, 55% hard
--   level 81+:  0% easy, 30% medium, 70% hard
create or replace function public.practice_difficulty_shares(p_level integer)
returns table(easy numeric, medium numeric, hard numeric)
language plpgsql immutable
as $$
declare
  lv numeric[] := array[1, 21, 41, 61, 81];
  e  numeric[] := array[1.00, 0.55, 0.20, 0.05, 0.00];
  m  numeric[] := array[0.00, 0.45, 0.50, 0.40, 0.30];
  h  numeric[] := array[0.00, 0.00, 0.30, 0.55, 0.70];
  l  numeric := greatest(coalesce(p_level, 1), 1);
  i  integer;
  t  numeric;
begin
  if l >= lv[5] then
    return query select e[5], m[5], h[5];
    return;
  end if;
  i := 1;
  while i < 4 and l >= lv[i + 1] loop i := i + 1; end loop;
  t := (l - lv[i]) / (lv[i + 1] - lv[i]);
  return query select
    e[i] + (e[i + 1] - e[i]) * t,
    m[i] + (m[i + 1] - m[i]) * t,
    h[i] + (h[i + 1] - h[i]) * t;
end;
$$;

-- Question counts per difficulty for a level.
create or replace function public.practice_difficulty_mix(p_level integer, p_count integer)
returns table(n_easy integer, n_medium integer, n_hard integer)
language plpgsql immutable
as $$
declare
  s record;
  v_hard integer;
  v_med integer;
begin
  select * into s from public.practice_difficulty_shares(p_level);
  v_hard := round(p_count * s.hard)::integer;
  v_med  := least(round(p_count * s.medium)::integer, p_count - v_hard);
  return query select p_count - v_hard - v_med, v_med, v_hard;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Math question generator. Higher tier = more operation types and bigger
--    numbers. p_ramp (0..1) makes the questions inside one level get a little
--    harder from first to last.
-- ---------------------------------------------------------------------------
create or replace function public.math_rand(p_lo integer, p_hi integer)
returns integer
language sql volatile
as $$ select p_lo + floor(random() * (greatest(p_hi, p_lo) - p_lo + 1))::integer $$;

create or replace function public.math_gcd(p_a integer, p_b integer)
returns integer
language plpgsql immutable
as $$
declare x integer := abs(p_a); y integer := abs(p_b); z integer;
begin
  while y <> 0 loop z := x % y; x := y; y := z; end loop;
  return greatest(x, 1);
end;
$$;

create or replace function public.generate_math_question(p_tier integer, p_ramp numeric default 0.5)
returns table(
  question_text text, option_a text, option_b text, option_c text, option_d text,
  correct_option text, difficulty text
)
language plpgsql volatile
set search_path = public, pg_temp
as $$
declare
  t      integer := greatest(coalesce(p_tier, 1), 1);
  r      numeric := least(greatest(coalesce(p_ramp, 0.5), 0), 1);
  maxn   integer := least(30 + 40 * t + round(r * 20)::integer, 9000);
  kinds  text[] := array['add', 'sub', 'table'];
  kind   text;
  idx    integer;
  a integer; b integer; c integer; d integer; x integer;
  den integer; den2 integer; num integer; num2 integer; g integer;
  pct integer; base integer;
  q text;
  ans bigint;
  ans_txt text;
  wrong text[];
  cand text[];
  cands bigint[];
  u bigint;
  opts text[];
  pos integer;
  k integer;
  j integer;
  v bigint;
begin
  if t >= 2 then kinds := kinds || array['mul', 'div']; end if;
  if t >= 3 then kinds := kinds || array['order', 'percent']; end if;
  if t >= 4 then kinds := kinds || array['brackets', 'negative', 'fracof']; end if;
  if t >= 5 then kinds := kinds || array['linear', 'square']; end if;
  if t >= 6 then kinds := kinds || array['fracadd', 'root', 'power']; end if;
  if t >= 7 then kinds := kinds || array['pctchange', 'average']; end if;
  if t >= 8 then kinds := kinds || array['linear2', 'mul2']; end if;

  -- Keep climbing: from tier 6 on, retire the easiest types in groups of three
  -- (add/sub/table first, then mul/div/order, ...) so later Math levels are
  -- never just bigger sums.
  if t >= 6 then
    k := least(((t - 3) / 3) * 3, array_length(kinds, 1) - 8);
    if k > 0 then kinds := kinds[(k + 1):array_length(kinds, 1)]; end if;
  end if;

  -- Favour the newest question types for the tier.
  idx := least(array_length(kinds, 1),
               array_length(kinds, 1) - floor(power(random(), 1.8) * array_length(kinds, 1))::integer);
  kind := kinds[greatest(idx, 1)];

  if kind = 'add' then
    a := public.math_rand(10, maxn); b := public.math_rand(10, maxn);
    ans := a + b; q := format('What is %s + %s?', a, b);
  elsif kind = 'sub' then
    a := public.math_rand(20, maxn); b := public.math_rand(5, a - 1);
    ans := a - b; q := format('What is %s - %s?', a, b);
  elsif kind = 'table' then
    a := public.math_rand(3, least(12, 6 + t)); b := public.math_rand(3, least(12, 6 + t));
    ans := a * b; q := format('What is %s × %s?', a, b);
  elsif kind = 'mul' then
    a := public.math_rand(12, least(99, 20 + 10 * t)); b := public.math_rand(3, 9);
    ans := a * b; q := format('What is %s × %s?', a, b);
  elsif kind = 'div' then
    b := public.math_rand(3, least(12, 5 + t)); x := public.math_rand(6, least(25, 10 + 3 * t));
    a := b * x; ans := x; q := format('What is %s ÷ %s?', a, b);
  elsif kind = 'order' then
    a := public.math_rand(5, 30 + 5 * t); b := public.math_rand(2, 9); c := public.math_rand(2, 9);
    ans := a + b * c; q := format('What is %s + %s × %s?', a, b, c);
  elsif kind = 'percent' then
    pct := (case when t >= 5 then array[5, 10, 15, 20, 25, 30, 40, 50, 75]
                 else array[10, 20, 25, 50] end)[public.math_rand(1, case when t >= 5 then 9 else 4 end)];
    base := 20 * public.math_rand(2, 5 + 2 * t);
    ans := base * pct / 100; q := format('What is %s%% of %s?', pct, base);
  elsif kind = 'brackets' then
    a := public.math_rand(2, 20 + 2 * t); b := public.math_rand(2, 20 + 2 * t); c := public.math_rand(2, 9);
    ans := (a + b) * c; q := format('What is (%s + %s) × %s?', a, b, c);
  elsif kind = 'negative' then
    a := public.math_rand(2, 20 + 2 * t); b := public.math_rand(a + 1, a + 30 + 5 * t);
    ans := a - b; q := format('What is %s - %s?', a, b);
  elsif kind = 'fracof' then
    den := (array[2, 3, 4, 5, 8, 10])[public.math_rand(1, 6)];
    num := public.math_rand(1, den - 1); x := public.math_rand(3, 12 + t);
    ans := num * x; q := format('What is %s/%s of %s?', num, den, den * x);
  elsif kind = 'linear' then
    x := public.math_rand(2, 12 + t); a := public.math_rand(2, 9); b := public.math_rand(1, 30);
    c := a * x + b; ans := x; q := format('Solve for x: %sx + %s = %s', a, b, c);
  elsif kind = 'square' then
    a := public.math_rand(11, least(30, 14 + t));
    ans := a * a; q := format('What is %s²?', a);
  elsif kind = 'root' then
    a := public.math_rand(6, 12 + 2 * t);
    ans := a; q := format('What is √%s?', a * a);
  elsif kind = 'power' then
    a := (array[2, 3, 5])[public.math_rand(1, 3)];
    b := case a when 2 then public.math_rand(4, 10) when 3 then public.math_rand(3, 6) else public.math_rand(2, 4) end;
    ans := (a::bigint) ^ b; q := format('What is %s^%s?', a, b);
  elsif kind = 'pctchange' then
    base := 100 * public.math_rand(2, 5 + t);
    pct := (array[10, 20, 25, 50])[public.math_rand(1, 4)];
    if random() < 0.5 then
      ans := base * (100 + pct) / 100;
      q := format('A phone costs %s shillings. After a %s%% price increase, what is the new price?', base, pct);
    else
      ans := base * (100 - pct) / 100;
      q := format('A phone costs %s shillings. After a %s%% discount, what is the new price?', base, pct);
    end if;
  elsif kind = 'average' then
    x := public.math_rand(10, 40 + 5 * t); d := public.math_rand(2, 8);
    ans := x;
    q := format('What is the average of %s, %s, %s, %s and %s?', x - 2 * d, x - d, x, x + d, x + 2 * d);
  elsif kind = 'linear2' then
    x := public.math_rand(2, 15); a := public.math_rand(4, 9); c := public.math_rand(1, a - 1);
    b := public.math_rand(1, 15); d := a * x + b - c * x;
    ans := x; q := format('Solve for x: %sx + %s = %sx + %s', a, b, c, d);
  elsif kind = 'mul2' then
    a := public.math_rand(12, least(99, 40 + 5 * t)); b := public.math_rand(11, least(99, 30 + 3 * t));
    ans := a * b; q := format('What is %s × %s?', a, b);
  elsif kind = 'fracadd' then
    den := (array[2, 3, 4, 5, 6])[public.math_rand(1, 5)];
    den2 := den;
    while den2 = den loop den2 := (array[2, 3, 4, 5, 6])[public.math_rand(1, 5)]; end loop;
    a := den + den2;            -- 1/den + 1/den2 = (den + den2) / (den * den2)
    b := den * den2;
    g := public.math_gcd(a, b);
    num := a / g;               -- reduced numerator
    d := b / g;                 -- reduced denominator
    q := format('What is 1/%s + 1/%s?', den, den2);
    ans := 0;
  end if;

  -- ---- build the options ---------------------------------------------------
  if kind = 'fracadd' then
    ans_txt := case when d = 1 then num::text else num || '/' || d end;
    wrong := array[]::text[];
    cand := array[
      '2/' || (den + den2),
      (num + 1) || '/' || d,
      num || '/' || (d + 1),
      (case when num > 1 then (num - 1) || '/' || d else (num + 2) || '/' || d end),
      (num + 2) || '/' || (d + 2),
      '1/' || (d + 1)
    ];
    for j in 1..array_length(cand, 1) loop
      if cand[j] <> ans_txt and not (cand[j] = any(wrong)) and coalesce(array_length(wrong, 1), 0) < 3 then
        wrong := wrong || cand[j];
      end if;
    end loop;
  else
    ans_txt := ans::text;
    u := greatest(1, round(abs(ans) * 0.1));
    cands := array[ans + 1, ans - 1, ans + 2, ans - 2, ans + u, ans - u, ans + 2 * u, ans - 2 * u, ans + 10, ans - 10, ans + 5, ans - 5];
    wrong := array[]::text[];
    -- Shuffle the candidate order, then take the first 3 distinct, sensible ones.
    for j in 1..array_length(cands, 1) loop
      k := public.math_rand(j, array_length(cands, 1));
      v := cands[j]; cands[j] := cands[k]; cands[k] := v;
    end loop;
    for j in 1..array_length(cands, 1) loop
      if cands[j] <> ans
         and (ans < 0 or cands[j] >= 0)
         and not (cands[j]::text = any(wrong))
         and coalesce(array_length(wrong, 1), 0) < 3 then
        wrong := wrong || cands[j]::text;
      end if;
    end loop;
    -- Tiny answers can run out of candidates; top up with larger offsets.
    k := 3;
    while coalesce(array_length(wrong, 1), 0) < 3 loop
      v := ans + k;
      if v <> ans and not (v::text = any(wrong)) then wrong := wrong || v::text; end if;
      k := k + 1;
    end loop;
  end if;

  while coalesce(array_length(wrong, 1), 0) < 3 loop
    wrong := wrong || ((public.math_rand(2, 40))::text || '/' || (public.math_rand(41, 90))::text);
  end loop;

  pos := public.math_rand(1, 4);
  opts := array[]::text[];
  j := 1;
  for k in 1..4 loop
    if k = pos then
      opts := opts || ans_txt;
    else
      opts := opts || wrong[j];
      j := j + 1;
    end if;
  end loop;

  return query select
    q, opts[1], opts[2], opts[3], opts[4],
    (array['a', 'b', 'c', 'd'])[pos],
    (case when t <= 1 then 'easy' when t <= 3 then 'medium' else 'hard' end)::text;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Question picking for a level (called by start_practice_level_round).
--    * Math level  -> generated questions.
--    * Other level -> the right easy/medium/hard mix, ordered easy -> hard,
--      unseen questions first, topped up from any difficulty if a pool is short.
-- ---------------------------------------------------------------------------
create or replace function public.practice_recent_questions(p_uid uuid)
returns table(question_id uuid, seen_at timestamptz)
language sql stable
security definer
set search_path = public, pg_temp
as $$
  select prq.question_id, pr.started_at
  from public.practice_round_questions prq
  join public.practice_rounds pr on pr.id = prq.round_id
  where pr.user_id = p_uid
  union all
  select dcq.question_id, a.completed_at
  from public.attempts a
  join public.daily_challenge_questions dcq on dcq.daily_challenge_id = a.daily_challenge_id
  where a.user_id = p_uid
$$;

create or replace function public.pick_practice_questions(
  p_round uuid, p_uid uuid, p_level integer, p_count integer
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cat uuid;
  g record;
  v_qid uuid;
  v_try integer;
  i integer;
  v_diff text;
  v_need integer;
  v_pos integer;
  v_got integer;
  v_n_easy integer; v_n_med integer; v_n_hard integer;
begin
  -- ---- Math level ----------------------------------------------------------
  if public.practice_is_math_level(p_level) then
    select id into v_cat from public.categories where name = 'Mathematics' limit 1;
    for i in 1..p_count loop
      v_try := 0;
      loop
        select * into g from public.generate_math_question(
          public.practice_math_tier(p_level),
          case when p_count > 1 then (i - 1)::numeric / (p_count - 1) else 0.5 end
        );
        exit when not exists (
          select 1
          from public.practice_round_questions prq
          join public.questions q on q.id = prq.question_id
          where prq.round_id = p_round and q.question_text = g.question_text
        );
        v_try := v_try + 1;
        exit when v_try >= 6;
      end loop;

      insert into public.questions (
        category_id, question_text, option_a, option_b, option_c, option_d,
        correct_option, difficulty, is_active, is_generated
      ) values (
        v_cat, g.question_text, g.option_a, g.option_b, g.option_c, g.option_d,
        g.correct_option, g.difficulty, false, true
      ) returning id into v_qid;

      insert into public.practice_round_questions (round_id, question_id, position)
      values (p_round, v_qid, i);
    end loop;
    return p_count;
  end if;

  -- ---- Normal level: easy -> medium -> hard --------------------------------
  select n_easy, n_medium, n_hard into v_n_easy, v_n_med, v_n_hard
  from public.practice_difficulty_mix(p_level, p_count);

  for v_diff, v_need in
    select t.d, t.n
    from (values ('easy', v_n_easy), ('medium', v_n_med), ('hard', v_n_hard)) as t(d, n)
    order by case t.d when 'easy' then 1 when 'medium' then 2 else 3 end
  loop
    continue when v_need <= 0;
    select coalesce(max(position), 0) into v_pos
    from public.practice_round_questions where round_id = p_round;

    insert into public.practice_round_questions (round_id, question_id, position)
    select p_round, s.id, v_pos + (row_number() over (order by s.ord))::integer
    from (
      select q.id,
             row_number() over (
               order by
                 (q.id in (
                   select dcq.question_id
                   from public.daily_challenges dc
                   join public.daily_challenge_questions dcq on dcq.daily_challenge_id = dc.id
                   where dc.challenge_date = public.nairobi_today()
                 )),
                 (ls.seen_at is not null),
                 ls.seen_at asc,
                 random()
             ) as ord
      from public.questions q
      left join (
        select question_id, max(seen_at) as seen_at
        from public.practice_recent_questions(p_uid) group by question_id
      ) ls on ls.question_id = q.id
      where q.is_active and not q.is_generated and q.difficulty = v_diff
        and q.id not in (select question_id from public.practice_round_questions where round_id = p_round)
      order by ord
      limit v_need
    ) s;
  end loop;

  -- Top up if a difficulty pool was too small.
  select count(*) into v_got from public.practice_round_questions where round_id = p_round;
  if v_got < p_count then
    select coalesce(max(position), 0) into v_pos
    from public.practice_round_questions where round_id = p_round;

    insert into public.practice_round_questions (round_id, question_id, position)
    select p_round, s.id, v_pos + (row_number() over (order by s.ord))::integer
    from (
      select q.id,
             row_number() over (order by (ls.seen_at is not null), ls.seen_at asc, random()) as ord
      from public.questions q
      left join (
        select question_id, max(seen_at) as seen_at
        from public.practice_recent_questions(p_uid) group by question_id
      ) ls on ls.question_id = q.id
      where q.is_active and not q.is_generated
        and q.id not in (select question_id from public.practice_round_questions where round_id = p_round)
      order by ord
      limit (p_count - v_got)
    ) s;
    select count(*) into v_got from public.practice_round_questions where round_id = p_round;
  end if;

  return v_got;
end;
$$;

revoke execute on function public.pick_practice_questions(uuid, uuid, integer, integer) from public, anon, authenticated;
revoke execute on function public.practice_recent_questions(uuid) from public, anon, authenticated;
revoke execute on function public.generate_math_question(integer, numeric) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. start_practice_level_round: identical to 019 (lives, unlock gates) except
--    that questions now come from pick_practice_questions().
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
  v_stale_round uuid;
  v_count integer;
  v_required integer;
  v_cumulative integer;
  v_unlocked boolean := false;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  perform pg_advisory_xact_lock(hashtext('practice:' || v_uid::text));

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

  insert into public.practice_rounds (user_id, practice_level)
  values (v_uid, v_level)
  returning id into v_round;

  perform public.reserve_practice_life(v_round);

  v_count := public.pick_practice_questions(
    v_round, v_uid, v_level, public.practice_question_count(v_level)
  );
  if v_count = 0 then raise exception 'no questions available'; end if;

  update public.practice_rounds set total_questions = v_count where id = v_round;
  return v_round;
end;
$$;

revoke execute on function public.start_practice_level_round(integer) from public, anon;
grant execute on function public.start_practice_level_round(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Quick health check: how deep is each question pool?
--    Run:  select * from public.practice_pool_report();
--    The journey needs roughly 250 easy / 250 medium / 200 hard questions to
--    avoid repeats through level 100.
-- ---------------------------------------------------------------------------
create or replace function public.practice_pool_report()
returns table(difficulty text, active_questions bigint)
language sql stable
set search_path = public, pg_temp
as $$
  select q.difficulty, count(*)
  from public.questions q
  where q.is_active and not q.is_generated
  group by q.difficulty
  order by case q.difficulty when 'easy' then 1 when 'medium' then 2 else 3 end
$$;
revoke execute on function public.practice_pool_report() from public, anon, authenticated;
