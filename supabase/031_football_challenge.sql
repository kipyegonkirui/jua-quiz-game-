-- ============================================================================
-- 031_football_challenge.sql
-- Football Challenge: a penalty shootout of football trivia.
--   * 60 levels on the road map (6 zones x 10); every level is a 5-kick
--     shootout: a right answer is a GOAL, a wrong answer is a SAVE.
--   * 3+ goals = 1 star, 4 goals = 2 stars, 5 goals = 3 stars.
--   * a level opens once the previous level has at least 1 star.
--   * difficulty rises by zone (zones 1-2 easy, 3-4 medium, 5-6 hard), with
--     a fallback to the nearest difficulty when a pool runs short.
--   * questions come from the "Football" category only.
--   * XP: 10 per goal, capped at 300 football XP per Nairobi day.
-- Self-contained: it does not touch Practice or the other mode journeys.
-- Run AFTER 024_content_quality.sql. Safe to re-run.
-- ============================================================================

insert into public.categories (name, icon)
select 'Football', '⚽'
where not exists (select 1 from public.categories where name = 'Football');

create table if not exists public.football_level_progress (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  level_number  integer not null check (level_number >= 1),
  best_stars    integer not null default 0 check (best_stars between 0 and 3),
  best_goals    integer not null default 0,
  attempts      integer not null default 0,
  updated_at    timestamptz not null default now(),
  primary key (user_id, level_number)
);

create table if not exists public.football_rounds (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  level_number  integer not null check (level_number >= 1),
  status        text not null default 'open' check (status in ('open', 'completed')),
  score         integer not null default 0,
  total         integer not null default 0,
  stars         integer not null default 0,
  xp_earned     integer not null default 0,
  started_at    timestamptz not null default now(),
  completed_at  timestamptz
);
create index if not exists football_rounds_user_idx
  on public.football_rounds (user_id, status, started_at desc);

create table if not exists public.football_round_questions (
  round_id     uuid not null references public.football_rounds(id) on delete cascade,
  question_id  uuid not null references public.questions(id) on delete cascade,
  position     integer not null,
  chosen       text check (chosen in ('a', 'b', 'c', 'd')),
  is_correct   boolean,
  primary key (round_id, question_id)
);

alter table public.football_level_progress enable row level security;
alter table public.football_rounds enable row level security;
alter table public.football_round_questions enable row level security;
revoke all on public.football_level_progress from anon, authenticated;
revoke all on public.football_rounds from anon, authenticated;
revoke all on public.football_round_questions from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Rules
-- ---------------------------------------------------------------------------
create or replace function public.football_stars_for_goals(p_goals integer)
returns integer
language sql
immutable
as $$
  select case when p_goals >= 5 then 3 when p_goals = 4 then 2 when p_goals = 3 then 1 else 0 end
$$;

create or replace function public.football_difficulty_for_level(p_level integer)
returns text
language sql
immutable
as $$
  select case
    when p_level <= 20 then 'easy'
    when p_level <= 40 then 'medium'
    else 'hard'
  end
$$;

-- ---------------------------------------------------------------------------
-- Start (or resume) a level. The server decides what is unlocked.
-- ---------------------------------------------------------------------------
create or replace function public.start_football_level(p_level integer)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_level integer := greatest(coalesce(p_level, 1), 1);
  v_round uuid;
  v_count integer;
  v_difficulty text := public.football_difficulty_for_level(v_level);
  v_cat uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if v_level > 60 then raise exception 'level_not_available'; end if;

  perform pg_advisory_xact_lock(hashtext('football:' || v_uid::text));

  if v_level > 1 and not exists (
    select 1 from public.football_level_progress
    where user_id = v_uid and level_number = v_level - 1 and best_stars >= 1
  ) then
    raise exception 'previous_level_required';
  end if;

  -- Resume an unfinished shootout of the same level; drop any other.
  select id into v_round
  from public.football_rounds
  where user_id = v_uid and status = 'open' and level_number = v_level
  order by started_at desc limit 1;
  if v_round is not null then return v_round; end if;
  delete from public.football_rounds where user_id = v_uid and status = 'open';

  select id into v_cat from public.categories where name = 'Football';
  if v_cat is null then raise exception 'no questions available'; end if;

  insert into public.football_rounds (user_id, level_number)
  values (v_uid, v_level)
  returning id into v_round;

  with seen as (
    select frq.question_id, max(fr.started_at) as seen_at
    from public.football_round_questions frq
    join public.football_rounds fr on fr.id = frq.round_id
    where fr.user_id = v_uid
    group by frq.question_id
  ),
  picked as (
    select q.id
    from public.questions q
    left join seen s on s.question_id = q.id
    where q.is_active and q.category_id = v_cat
    order by
      (s.seen_at is not null),
      case when q.difficulty = v_difficulty then 0
           when v_difficulty = 'hard' and q.difficulty = 'medium' then 1
           when v_difficulty = 'medium' and q.difficulty in ('easy', 'hard') then 1
           when v_difficulty = 'easy' and q.difficulty = 'medium' then 1
           else 2 end,
      s.seen_at asc,
      random()
    limit 5
  )
  insert into public.football_round_questions (round_id, question_id, position)
  select v_round, id, (row_number() over ())::integer from picked;

  get diagnostics v_count = row_count;
  if v_count = 0 then raise exception 'no questions available'; end if;

  update public.football_rounds set total = v_count where id = v_round;
  return v_round;
end;
$$;

-- The questions of a round WITHOUT their answers.
create or replace function public.get_football_questions(p_round_id uuid)
returns table (
  id uuid, question_text text, option_a text, option_b text, option_c text,
  option_d text, difficulty text, "position" integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return query
    select q.id, q.question_text, q.option_a, q.option_b, q.option_c, q.option_d,
           q.difficulty, frq.position
    from public.football_round_questions frq
    join public.football_rounds fr on fr.id = frq.round_id
    join public.questions q on q.id = frq.question_id
    where frq.round_id = p_round_id and fr.user_id = auth.uid()
    order by frq.position;
end;
$$;

-- Answers already given in a round (so a half-played shootout can resume).
create or replace function public.get_football_progress(p_round_id uuid)
returns table (question_id uuid, chosen text, correct_option text, is_correct boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return query
    select frq.question_id, frq.chosen, q.correct_option, frq.is_correct
    from public.football_round_questions frq
    join public.football_rounds fr on fr.id = frq.round_id
    join public.questions q on q.id = frq.question_id
    where frq.round_id = p_round_id and fr.user_id = auth.uid() and frq.chosen is not null;
end;
$$;

-- One kick: lock the answer and say goal or save.
create or replace function public.answer_football_question(
  p_round_id uuid, p_question_id uuid, p_choice text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.football_round_questions%rowtype;
  v_status text;
  v_correct text;
  v_fact text;
  v_ok boolean;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if p_choice is null or p_choice not in ('a', 'b', 'c', 'd') then
    raise exception 'invalid choice';
  end if;

  select fr.status into v_status
  from public.football_rounds fr where fr.id = p_round_id and fr.user_id = v_uid;
  if not found then raise exception 'round not found'; end if;
  if v_status <> 'open' then raise exception 'round already submitted'; end if;

  select * into v_row from public.football_round_questions
  where round_id = p_round_id and question_id = p_question_id for update;
  if not found then raise exception 'question not in round'; end if;

  select correct_option, did_you_know into v_correct, v_fact
  from public.questions where id = p_question_id;

  if v_row.chosen is null then
    v_ok := (p_choice = v_correct);
    update public.football_round_questions
       set chosen = p_choice, is_correct = v_ok
     where round_id = p_round_id and question_id = p_question_id;
  else
    p_choice := v_row.chosen;   -- already locked: report the original verdict
    v_ok := v_row.is_correct;
  end if;

  return jsonb_build_object(
    'chosen', p_choice, 'correct_option', v_correct,
    'is_correct', v_ok, 'status', 'final', 'fact', v_fact
  );
end;
$$;

-- Finish the shootout: stars, XP, progress.
create or replace function public.submit_football_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_cap constant integer := 300;
  v_today date := public.nairobi_today();
  v_round public.football_rounds%rowtype;
  v_profile public.profiles%rowtype;
  v_score integer;
  v_total integer;
  v_stars integer;
  v_raw integer;
  v_xp_today integer;
  v_xp integer;
  v_old_level integer;
  v_new_xp integer;
  v_new_level integer;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select * into v_round from public.football_rounds
  where id = p_round_id and user_id = v_uid for update;
  if not found then raise exception 'round not found'; end if;
  if v_round.status <> 'open' then raise exception 'round already submitted'; end if;

  select count(*)::integer, count(*) filter (where is_correct)::integer
    into v_total, v_score
  from public.football_round_questions where round_id = p_round_id;
  if v_total = 0 then raise exception 'round has no questions'; end if;

  v_stars := public.football_stars_for_goals(v_score);
  v_raw := v_score * 10;

  select coalesce(sum(xp_earned), 0) into v_xp_today
  from public.football_rounds
  where user_id = v_uid and status = 'completed'
    and (completed_at at time zone 'Africa/Nairobi')::date = v_today;
  v_xp := least(v_raw, greatest(v_cap - v_xp_today, 0));

  select * into v_profile from public.profiles where id = v_uid for update;
  v_old_level := v_profile.level;
  v_new_xp := v_profile.xp + v_xp;
  v_new_level := (v_new_xp / 100) + 1;

  update public.profiles set
    xp = v_new_xp, level = v_new_level,
    total_correct = v_profile.total_correct + v_score,
    total_questions = v_profile.total_questions + v_total
  where id = v_uid;

  update public.football_rounds set
    status = 'completed', score = v_score, total = v_total,
    stars = v_stars, xp_earned = v_xp, completed_at = now()
  where id = p_round_id;

  insert into public.football_level_progress
    (user_id, level_number, best_stars, best_goals, attempts, updated_at)
  values (v_uid, v_round.level_number, v_stars, v_score, 1, now())
  on conflict (user_id, level_number) do update set
    best_stars = greatest(public.football_level_progress.best_stars, excluded.best_stars),
    best_goals = greatest(public.football_level_progress.best_goals, excluded.best_goals),
    attempts = public.football_level_progress.attempts + 1,
    updated_at = now();

  return jsonb_build_object(
    'level', v_round.level_number, 'score', v_score, 'total', v_total,
    'stars', v_stars, 'xp_earned', v_xp, 'xp_capped', v_xp < v_raw,
    'new_xp', v_new_xp, 'new_level', v_new_level,
    'leveled_up', v_new_level > v_old_level,
    'next_level_unlocked', v_stars >= 1 and v_round.level_number < 60
  );
end;
$$;

-- Star map for the road: {"stars": {"1": 3, "2": 1, ...}}
create or replace function public.get_football_journey()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return jsonb_build_object('stars', coalesce((
    select jsonb_object_agg(level_number::text, best_stars)
    from public.football_level_progress
    where user_id = auth.uid() and best_stars > 0
  ), '{}'::jsonb));
end;
$$;

revoke execute on function public.start_football_level(integer) from public, anon;
revoke execute on function public.get_football_questions(uuid) from public, anon;
revoke execute on function public.get_football_progress(uuid) from public, anon;
revoke execute on function public.answer_football_question(uuid, uuid, text) from public, anon;
revoke execute on function public.submit_football_round(uuid) from public, anon;
revoke execute on function public.get_football_journey() from public, anon;
grant execute on function public.start_football_level(integer) to authenticated;
grant execute on function public.get_football_questions(uuid) to authenticated;
grant execute on function public.get_football_progress(uuid) to authenticated;
grant execute on function public.answer_football_question(uuid, uuid, text) to authenticated;
grant execute on function public.submit_football_round(uuid) to authenticated;
grant execute on function public.get_football_journey() to authenticated;
