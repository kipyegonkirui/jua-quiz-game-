-- Jua Quiz — Phase 1: Speed Quiz
-- 10 questions, 10 seconds per question, server-authoritative timing/scoring.
-- Run after 009_practice_xp_cap_500.sql.

create table if not exists public.speed_quiz_rounds (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles(id) on delete cascade,
  status                text not null default 'playing' check (status in ('playing', 'completed')),
  question_order        uuid[] not null,
  current_index         integer not null default 1,
  served_at             timestamptz,
  score                 integer not null default 0,
  correct               integer not null default 0,
  answered              integer not null default 0,
  total_time_ms         integer not null default 0,
  seconds_per_question  integer not null default 10 check (seconds_per_question > 0),
  xp_earned             integer not null default 0,
  submitted_at          timestamptz,
  started_at            timestamptz not null default now(),
  completed_at          timestamptz
);

create table if not exists public.speed_quiz_answers (
  round_id       uuid not null references public.speed_quiz_rounds(id) on delete cascade,
  question_id    uuid not null references public.questions(id) on delete cascade,
  position       integer not null,
  chosen         text check (chosen in ('a', 'b', 'c', 'd')),
  is_correct     boolean not null,
  timed_out      boolean not null default false,
  served_at      timestamptz not null,
  answered_at    timestamptz not null default now(),
  elapsed_ms     integer not null,
  points         integer not null default 0,
  primary key (round_id, question_id)
);

alter table public.speed_quiz_rounds enable row level security;
alter table public.speed_quiz_answers enable row level security;
revoke all on public.speed_quiz_rounds from anon, authenticated;
revoke all on public.speed_quiz_answers from anon, authenticated;

create or replace function public._speed_quiz_score(
  p_difficulty text,
  p_elapsed_ms integer,
  p_limit_ms integer,
  p_is_correct boolean
)
returns integer
language plpgsql
immutable
security definer
set search_path = public, pg_temp
as $$
declare
  v_difficulty_bonus integer := case lower(coalesce(p_difficulty, 'medium'))
    when 'hard' then 35
    when 'medium' then 15
    else 0
  end;
  v_speed_bonus integer := 0;
begin
  if not p_is_correct then
    return 0;
  end if;
  if p_elapsed_ms < p_limit_ms then
    v_speed_bonus := greatest(0, least(50, round(50.0 * (p_limit_ms - p_elapsed_ms) / p_limit_ms)::integer));
  end if;
  return 100 + v_difficulty_bonus + v_speed_bonus + 25;
end;
$$;
revoke all on function public._speed_quiz_score(text, integer, integer, boolean) from public, anon, authenticated;

create or replace function public.start_speed_quiz_round()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_questions uuid[];
begin
  if v_uid is null then raise exception 'not authenticated'; end if;

  select id into v_id
  from public.speed_quiz_rounds
  where user_id = v_uid and status = 'playing'
  order by started_at desc
  limit 1
  for update;

  if v_id is not null then
    return v_id;
  end if;

  select array_agg(id order by random()) into v_questions
  from (
    select id from public.questions where is_active = true order by random() limit 10
  ) q;

  if coalesce(array_length(v_questions, 1), 0) < 10 then
    raise exception 'not enough active questions (need 10)';
  end if;

  insert into public.speed_quiz_rounds (user_id, question_order, current_index, served_at)
  values (v_uid, v_questions, 1, now())
  returning id into v_id;

  return v_id;
end;
$$;
grant execute on function public.start_speed_quiz_round() to authenticated;

create or replace function public.get_speed_quiz_questions(p_round_id uuid)
returns table (
  id uuid,
  question_text text,
  option_a text,
  option_b text,
  option_c text,
  option_d text,
  difficulty text,
  "position" integer
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select q.id, q.question_text, q.option_a, q.option_b, q.option_c, q.option_d,
         q.difficulty, u.pos as "position"
  from public.speed_quiz_rounds r
  cross join lateral unnest(r.question_order) with ordinality as u(question_id, pos)
  join public.questions q on q.id = u.question_id
  where r.id = p_round_id and r.user_id = auth.uid()
  order by u.pos;
$$;
grant execute on function public.get_speed_quiz_questions(uuid) to authenticated;

create or replace function public.get_speed_quiz_state(p_round_id uuid)
returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'status', r.status,
    'current_index', r.current_index,
    'score', r.score,
    'correct_count', r.correct,
    'answered', r.answered,
    'total_questions', array_length(r.question_order, 1),
    'seconds_per_question', r.seconds_per_question,
    'served_at', r.served_at
  )
  from public.speed_quiz_rounds r
  where r.id = p_round_id and r.user_id = auth.uid();
$$;
grant execute on function public.get_speed_quiz_state(uuid) to authenticated;

create or replace function public.get_speed_quiz_progress(p_round_id uuid)
returns table (
  question_id uuid,
  chosen text,
  is_correct boolean,
  timed_out boolean,
  elapsed_ms integer,
  points integer,
  correct_option text
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select a.question_id, a.chosen, a.is_correct, a.timed_out, a.elapsed_ms, a.points, q.correct_option
  from public.speed_quiz_answers a
  join public.questions q on q.id = a.question_id
  join public.speed_quiz_rounds r on r.id = a.round_id
  where a.round_id = p_round_id and r.user_id = auth.uid()
  order by a.position;
$$;
grant execute on function public.get_speed_quiz_progress(uuid) to authenticated;

create or replace function public.answer_speed_quiz_question(
  p_round_id uuid,
  p_question_id uuid,
  p_choice text default null,
  p_force_timeout boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r public.speed_quiz_rounds%rowtype;
  v_question_id uuid;
  v_correct_option text;
  v_difficulty text;
  v_elapsed integer;
  v_limit integer;
  v_timed_out boolean;
  v_correct boolean;
  v_points integer;
  v_next_index integer;
  v_finished boolean;
  v_score integer;
  v_correct_count integer;
  v_answered integer;
  v_chosen text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select * into r
  from public.speed_quiz_rounds
  where id = p_round_id and user_id = auth.uid()
  for update;
  if not found then raise exception 'speed quiz round not found'; end if;
  if r.status <> 'playing' then raise exception 'speed quiz round already finished'; end if;
  if r.current_index < 1 or r.current_index > array_length(r.question_order, 1) then
    raise exception 'speed quiz round is in an invalid state';
  end if;

  v_question_id := r.question_order[r.current_index];
  if p_question_id <> v_question_id then raise exception 'question is not the current speed quiz question'; end if;
  if r.served_at is null then raise exception 'current question has not been served'; end if;

  v_elapsed := greatest(0, (extract(epoch from (now() - r.served_at)) * 1000)::integer);
  v_limit := r.seconds_per_question * 1000;
  v_timed_out := p_force_timeout or v_elapsed > v_limit + 1000;

  if not v_timed_out and p_choice is not null and lower(p_choice) not in ('a','b','c','d') then
    raise exception 'invalid option';
  end if;

  select q.correct_option, q.difficulty into v_correct_option, v_difficulty
  from public.questions q where q.id = v_question_id;

  v_chosen := case when v_timed_out then null else lower(p_choice) end;
  v_correct := not v_timed_out and v_chosen is not null and v_chosen = v_correct_option;
  v_points := public._speed_quiz_score(v_difficulty, least(v_elapsed, v_limit), v_limit, v_correct);
  v_next_index := r.current_index + 1;
  v_finished := v_next_index > array_length(r.question_order, 1);
  v_score := r.score + v_points;
  v_correct_count := r.correct + case when v_correct then 1 else 0 end;
  v_answered := r.answered + 1;

  insert into public.speed_quiz_answers
    (round_id, question_id, position, chosen, is_correct, timed_out, served_at, elapsed_ms, points)
  values
    (r.id, v_question_id, r.current_index, v_chosen, v_correct, v_timed_out,
     r.served_at, v_elapsed, v_points);

  update public.speed_quiz_rounds set
    current_index = v_next_index,
    served_at = case when v_finished then null else now() end,
    score = v_score,
    correct = v_correct_count,
    answered = v_answered,
    total_time_ms = total_time_ms + least(v_elapsed, v_limit),
    status = case when v_finished then 'completed' else 'playing' end,
    completed_at = case when v_finished then now() else null end
  where id = r.id;

  return jsonb_build_object(
    'is_correct', v_correct,
    'timed_out', v_timed_out,
    'chosen', v_chosen,
    'correct_option', v_correct_option,
    'points', v_points,
    'score', v_score,
    'correct_count', v_correct_count,
    'answered', v_answered,
    'total_questions', array_length(r.question_order, 1),
    'elapsed_ms', v_elapsed,
    'finished', v_finished
  );
end;
$$;
grant execute on function public.answer_speed_quiz_question(uuid, uuid, text, boolean) to authenticated;

create or replace function public.submit_speed_quiz_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r public.speed_quiz_rounds%rowtype;
  p public.profiles%rowtype;
  v_old_level integer;
  v_new_xp integer;
  v_new_level integer;
  v_xp integer;
  v_total integer;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into r from public.speed_quiz_rounds where id = p_round_id and user_id = auth.uid() for update;
  if not found then raise exception 'speed quiz round not found'; end if;
  if r.status <> 'completed' then raise exception 'speed quiz round is not finished'; end if;
  if r.submitted_at is not null then
    raise exception 'speed quiz round already submitted';
  end if;

  v_total := array_length(r.question_order, 1);
  -- Speed Quiz awards XP without affecting the streak. The cap keeps a single
  -- round from overwhelming the existing level economy.
  v_xp := least(100, r.correct * 8 + least(20, r.score / 200));

  select * into p from public.profiles where id = auth.uid() for update;
  v_old_level := p.level;
  v_new_xp := p.xp + v_xp;
  v_new_level := (v_new_xp / 100) + 1;

  update public.profiles set
    xp = v_new_xp,
    level = v_new_level,
    total_attempts = p.total_attempts + 1,
    total_correct = p.total_correct + r.correct,
    total_questions = p.total_questions + v_total
  where id = auth.uid();

  update public.speed_quiz_rounds set xp_earned = v_xp, submitted_at = now() where id = r.id;

  return jsonb_build_object(
    'score', r.score,
    'total', v_total,
    'correct', r.correct,
    'xp_earned', v_xp,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'leveled_up', v_new_level > v_old_level,
    'current_streak', p.current_streak,
    'longest_streak', p.longest_streak
  );
end;
$$;
grant execute on function public.submit_speed_quiz_round(uuid) to authenticated;
