-- ============================================================================
-- 005_answer_feedback.sql
--
-- Shows the right answer after each question (green / red in the app).
--
--   * Every answer is now checked ON THE SERVER, one question at a time, and
--     LOCKED the moment it's checked. A player can't see the green answer and
--     then change their pick — the first choice is the only one that counts.
--   * The final submit no longer takes answers from the phone at all: it
--     scores the answers the server already recorded. Unanswered = wrong.
--   * The answer key is still only ever revealed for a question the player has
--     ALREADY answered — never before.
--
-- RUN ORDER: 003, then 004, then this file. Run it once.
-- Do NOT re-run 003 after this file (003 recreates the older submit functions).
-- If you ever do, just run this file again afterwards.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Storage for recorded answers
-- ----------------------------------------------------------------------------
alter table public.practice_round_questions
  add column if not exists chosen      text check (chosen in ('a','b','c','d')),
  add column if not exists is_correct  boolean,
  add column if not exists answered_at timestamptz;

create table if not exists public.daily_answers (
  user_id            uuid not null references public.profiles(id) on delete cascade,
  daily_challenge_id uuid not null references public.daily_challenges(id) on delete cascade,
  question_id        uuid not null references public.questions(id) on delete cascade,
  chosen             text not null check (chosen in ('a','b','c','d')),
  is_correct         boolean not null,
  answered_at        timestamptz not null default now(),
  primary key (user_id, daily_challenge_id, question_id)
);

alter table public.daily_answers enable row level security;
revoke all on public.daily_answers from anon, authenticated;
-- No policies on purpose: rows are only written by answer_daily_question().


-- ----------------------------------------------------------------------------
-- Old function versions (they took the whole answer map from the phone)
-- ----------------------------------------------------------------------------
drop function if exists public.submit_daily_attempt(uuid, jsonb);
drop function if exists public.submit_practice_round(uuid, jsonb);


-- ============================================================================
-- PRACTICE
-- ============================================================================

-- Check one answer. Locks the first choice; asking again returns that same
-- locked result, whatever is passed the second time.
create or replace function public.answer_practice_question(
  p_round_id uuid, p_question_id uuid, p_choice text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_choice  text := lower(coalesce(p_choice, ''));
  v_chosen  text;
  v_correct text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if v_choice not in ('a','b','c','d') then
    raise exception 'invalid choice';
  end if;

  -- Lock the round so two quick taps can't race each other.
  perform 1 from public.practice_rounds
   where id = p_round_id and user_id = v_uid and status = 'open'
   for update;
  if not found then
    raise exception 'round not found or already submitted';
  end if;

  select prq.chosen into v_chosen
  from public.practice_round_questions prq
  where prq.round_id = p_round_id and prq.question_id = p_question_id
  for update;
  if not found then
    raise exception 'question is not part of this round';
  end if;

  select correct_option into v_correct from public.questions where id = p_question_id;

  if v_chosen is null then
    update public.practice_round_questions
       set chosen = v_choice,
           is_correct = (v_choice = v_correct),
           answered_at = now()
     where round_id = p_round_id and question_id = p_question_id;
    v_chosen := v_choice;
  end if;

  return jsonb_build_object(
    'chosen', v_chosen,
    'correct_option', v_correct,
    'is_correct', v_chosen = v_correct
  );
end;
$$;

-- Answers already given in one of YOUR open rounds — used to resume a round
-- after the app was closed. Only answered questions appear, so this never
-- reveals a question you haven't answered yet.
create or replace function public.get_practice_progress(p_round_id uuid)
returns table (question_id uuid, chosen text, correct_option text)
language sql
security definer
set search_path = public, pg_temp
as $$
  select prq.question_id, prq.chosen, q.correct_option
  from public.practice_round_questions prq
  join public.practice_rounds pr on pr.id = prq.round_id
  join public.questions q on q.id = prq.question_id
  where prq.round_id = p_round_id
    and pr.user_id = auth.uid()
    and pr.status = 'open'
    and prq.chosen is not null;
$$;

-- Score a round from the answers the server recorded. Same XP rules as before
-- (10 XP per correct, no bonus, daily practice cap, streak untouched).
create or replace function public.submit_practice_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid         uuid := auth.uid();
  v_today       date := public.nairobi_today();
  v_daily_cap   constant integer := 300;   -- practice XP per day; change here
  v_round       public.practice_rounds%rowtype;
  v_profile     public.profiles%rowtype;
  v_score       integer;
  v_total       integer;
  v_raw_xp      integer;
  v_xp_earned   integer;
  v_xp_today    integer;
  v_old_level   integer;
  v_new_xp      integer;
  v_new_level   integer;
  v_answers     jsonb;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_round
  from public.practice_rounds
  where id = p_round_id and user_id = v_uid
  for update;

  if not found then
    raise exception 'round not found';
  end if;
  if v_round.status <> 'open' then
    raise exception 'round already submitted';
  end if;

  select count(*)::integer,
         count(*) filter (where is_correct)::integer,
         coalesce(jsonb_object_agg(question_id::text, chosen) filter (where chosen is not null), '{}'::jsonb)
    into v_total, v_score, v_answers
  from public.practice_round_questions
  where round_id = p_round_id;

  if v_total = 0 then
    raise exception 'round has no questions';
  end if;

  v_raw_xp := v_score * 10;

  select coalesce(sum(xp_earned), 0) into v_xp_today
  from public.practice_rounds
  where user_id = v_uid
    and status = 'completed'
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

  update public.practice_rounds set
    status = 'completed',
    score = v_score,
    total_questions = v_total,
    xp_earned = v_xp_earned,
    answers = v_answers,
    completed_at = now()
  where id = p_round_id;

  return jsonb_build_object(
    'score', v_score,
    'total', v_total,
    'xp_earned', v_xp_earned,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'leveled_up', v_new_level > v_old_level,
    'current_streak', v_profile.current_streak,
    'longest_streak', v_profile.longest_streak,
    'xp_capped', v_xp_earned < v_raw_xp,
    'practice_xp_today', v_xp_today + v_xp_earned,
    'practice_xp_cap', v_daily_cap
  );
end;
$$;


-- ============================================================================
-- DAILY CHALLENGE
-- ============================================================================

-- Check one answer for TODAY's challenge. First choice is locked.
create or replace function public.answer_daily_question(
  p_challenge_id uuid, p_question_id uuid, p_choice text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_choice  text := lower(coalesce(p_choice, ''));
  v_chosen  text;
  v_correct text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if v_choice not in ('a','b','c','d') then
    raise exception 'invalid choice';
  end if;

  if not exists (
    select 1 from public.daily_challenges
    where id = p_challenge_id and challenge_date = public.nairobi_today()
  ) then
    raise exception 'this is not today''s challenge';
  end if;

  if not exists (
    select 1 from public.daily_challenge_questions
    where daily_challenge_id = p_challenge_id and question_id = p_question_id
  ) then
    raise exception 'question is not part of this challenge';
  end if;

  select correct_option into v_correct from public.questions where id = p_question_id;

  select chosen into v_chosen
  from public.daily_answers
  where user_id = v_uid and daily_challenge_id = p_challenge_id and question_id = p_question_id;

  if v_chosen is null then
    if exists (
      select 1 from public.attempts
      where user_id = v_uid and daily_challenge_id = p_challenge_id
    ) then
      raise exception 'already completed today''s challenge';
    end if;

    insert into public.daily_answers (user_id, daily_challenge_id, question_id, chosen, is_correct)
    values (v_uid, p_challenge_id, p_question_id, v_choice, v_choice = v_correct)
    on conflict do nothing;

    -- Re-read: if two taps raced, the first one wins for both.
    select chosen into v_chosen
    from public.daily_answers
    where user_id = v_uid and daily_challenge_id = p_challenge_id and question_id = p_question_id;
  end if;

  return jsonb_build_object(
    'chosen', v_chosen,
    'correct_option', v_correct,
    'is_correct', v_chosen = v_correct
  );
end;
$$;

-- Your own answers so far in a daily challenge — used to resume it.
create or replace function public.get_daily_progress(p_challenge_id uuid)
returns table (question_id uuid, chosen text, correct_option text)
language sql
security definer
set search_path = public, pg_temp
as $$
  select da.question_id, da.chosen, q.correct_option
  from public.daily_answers da
  join public.questions q on q.id = da.question_id
  where da.user_id = auth.uid()
    and da.daily_challenge_id = p_challenge_id;
$$;

-- Score today's challenge from the recorded answers. Same XP and streak rules
-- as always; nothing about the streak changed.
create or replace function public.submit_daily_attempt(p_challenge_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id       uuid := auth.uid();
  v_today         date := public.nairobi_today();
  v_yesterday     date := public.nairobi_today() - 1;
  v_score         integer;
  v_total         integer;
  v_xp_earned     integer;
  v_old_level     integer;
  v_new_xp        integer;
  v_new_level     integer;
  v_profile       public.profiles%rowtype;
  v_new_streak    integer;
  v_answers       jsonb;
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
    v_xp_earned := v_xp_earned + 20; -- perfect-round bonus
  end if;

  select * into v_profile from public.profiles where id = v_user_id for update;
  v_old_level := v_profile.level;
  v_new_xp := v_profile.xp + v_xp_earned;
  v_new_level := (v_new_xp / 100) + 1;

  if v_profile.last_completed_date = v_yesterday then
    v_new_streak := v_profile.current_streak + 1;
  elsif v_profile.last_completed_date = v_today then
    v_new_streak := v_profile.current_streak; -- shouldn't happen, guarded above
  else
    v_new_streak := 1;
  end if;

  update public.profiles set
    xp = v_new_xp,
    level = v_new_level,
    current_streak = v_new_streak,
    longest_streak = greatest(v_profile.longest_streak, v_new_streak),
    last_completed_date = v_today,
    total_attempts = v_profile.total_attempts + 1,
    total_correct = v_profile.total_correct + v_score,
    total_questions = v_profile.total_questions + v_total
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
    'longest_streak', greatest(v_profile.longest_streak, v_new_streak)
  );
end;
$$;


-- ----------------------------------------------------------------------------
-- Who may call what.
-- ----------------------------------------------------------------------------
revoke execute on function public.answer_practice_question(uuid, uuid, text) from public, anon;
revoke execute on function public.get_practice_progress(uuid) from public, anon;
revoke execute on function public.submit_practice_round(uuid) from public, anon;
revoke execute on function public.answer_daily_question(uuid, uuid, text) from public, anon;
revoke execute on function public.get_daily_progress(uuid) from public, anon;
revoke execute on function public.submit_daily_attempt(uuid) from public, anon;

grant execute on function public.answer_practice_question(uuid, uuid, text) to authenticated;
grant execute on function public.get_practice_progress(uuid) to authenticated;
grant execute on function public.submit_practice_round(uuid) to authenticated;
grant execute on function public.answer_daily_question(uuid, uuid, text) to authenticated;
grant execute on function public.get_daily_progress(uuid) to authenticated;
grant execute on function public.submit_daily_attempt(uuid) to authenticated;
