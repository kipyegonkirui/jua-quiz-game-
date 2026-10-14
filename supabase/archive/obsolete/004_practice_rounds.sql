-- ============================================================================
-- Jua Quiz — Phase 1: practice rounds
-- Adds practice_rounds + practice_round_questions and three SECURITY DEFINER
-- functions. Practice awards XP and updates lifetime accuracy, but NEVER
-- touches current_streak / last_completed_date / total_attempts — those belong
-- to the daily challenge only.
-- ============================================================================

-- ---------------------------------------------------------------- rounds -----
create table if not exists public.practice_rounds (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  status          text not null default 'in_progress'
                  check (status in ('in_progress', 'completed')),
  score           integer,
  total_questions integer,
  xp_earned       integer,
  created_at      timestamptz not null default now(),
  completed_at    timestamptz
);

alter table public.practice_rounds enable row level security;

-- Players can read their own rounds (e.g. to see history later). All writes
-- happen through the SECURITY DEFINER functions below, so no insert/update
-- policy is granted to the client.
create policy "players read their own practice rounds"
  on public.practice_rounds for select
  to authenticated
  using (auth.uid() = user_id);

-- ------------------------------------------------------- round questions -----
create table if not exists public.practice_round_questions (
  practice_round_id uuid not null references public.practice_rounds(id) on delete cascade,
  question_id       uuid not null references public.questions(id) on delete cascade,
  position          integer not null,
  primary key (practice_round_id, question_id)
);

alter table public.practice_round_questions enable row level security;
-- No direct select policy: questions are read only through
-- get_practice_questions(), which omits the answer key (mirrors the daily
-- challenge_questions design).

-- ------------------------------------------------- start_practice_round -----
-- Creates a round, selects N random active questions SERVER-SIDE, records
-- them, and returns the round id. The client never chooses its own
-- questions.
create or replace function public.start_practice_round(p_question_count int default 5)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_round_id uuid;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;
  if p_question_count is null or p_question_count < 1 or p_question_count > 20 then
    raise exception 'invalid question count';
  end if;

  insert into public.practice_rounds (user_id) values (v_user_id) returning id into v_round_id;

  insert into public.practice_round_questions (practice_round_id, question_id, position)
  select v_round_id, q.id, row_number() over ()
  from (
    select id from public.questions where is_active = true order by random() limit p_question_count
  ) q;

  return v_round_id;
end;
$$;

grant execute on function public.start_practice_round(int) to authenticated;

-- --------------------------------------------------- get_practice_questions -
-- Returns only gameplay-safe columns for the caller's own round. Same shape
-- as get_challenge_questions() so the existing Question model works as-is.
create or replace function public.get_practice_questions(p_round_id uuid)
returns table (
  id uuid, question_text text, option_a text, option_b text,
  option_c text, option_d text, position integer
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select q.id, q.question_text, q.option_a, q.option_b, q.option_c, q.option_d, prq.position
  from public.practice_round_questions prq
  join public.questions q on q.id = prq.question_id
  join public.practice_rounds pr on pr.id = prq.practice_round_id
  where prq.practice_round_id = p_round_id
    and pr.user_id = auth.uid()
  order by prq.position;
$$;

grant execute on function public.get_practice_questions(uuid) to authenticated;

-- -------------------------------------------------- submit_practice_round ----
-- Validates answers, awards XP ONCE, updates lifetime accuracy stats, and
-- marks the round completed. The FOR UPDATE lock + status check is what
-- makes a round non-replayable: a second submit finds status='completed'
-- and is rejected.
create or replace function public.submit_practice_round(p_round_id uuid, p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id   uuid := auth.uid();
  v_round     public.practice_rounds%rowtype;
  v_score     integer := 0;
  v_total     integer := 0;
  v_xp        integer := 0;
  v_profile   public.profiles%rowtype;
  v_old_level integer;
  v_new_xp    integer;
  v_new_level integer;
  q           record;
  v_given     text;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select * into v_round from public.practice_rounds where id = p_round_id for update;
  if v_round is null then
    raise exception 'round not found';
  end if;
  if v_round.user_id <> v_user_id then
    raise exception 'not your round';
  end if;
  if v_round.status <> 'in_progress' then
    raise exception 'round already submitted';
  end if;

  for q in
    select qs.id, qs.correct_option
    from public.practice_round_questions prq
    join public.questions qs on qs.id = prq.question_id
    where prq.practice_round_id = p_round_id
  loop
    v_total := v_total + 1;
    v_given := p_answers ->> q.id::text;
    if v_given is not null and lower(v_given) = q.correct_option then
      v_score := v_score + 1;
    end if;
  end loop;

  if v_total = 0 then
    raise exception 'round has no questions';
  end if;

  v_xp := v_score * 10;
  if v_score = v_total then
    v_xp := v_xp + 20; -- perfect-round bonus, same as daily
  end if;

  select * into v_profile from public.profiles where id = v_user_id for update;
  v_old_level := v_profile.level;
  v_new_xp := v_profile.xp + v_xp;
  v_new_level := (v_new_xp / 100) + 1;

  -- Lifetime accuracy + progression only.
  update public.profiles set
    xp = v_new_xp,
    level = v_new_level,
    total_correct = v_profile.total_correct + v_score,
    total_questions = v_profile.total_questions + v_total
  where id = v_user_id;
  -- Deliberately NOT updated: current_streak, longest_streak,
  -- last_completed_date, total_attempts. Those are daily-challenge-only, so
  -- practice can never inflate a streak or the "challenges done" counter.

  update public.practice_rounds set
    status = 'completed',
    score = v_score,
    total_questions = v_total,
    xp_earned = v_xp,
    completed_at = now()
  where id = p_round_id;

  return jsonb_build_object(
    'score', v_score,
    'total', v_total,
    'xp_earned', v_xp,
    'new_xp', v_new_xp,
    'new_level', v_new_level,
    'leveled_up', v_new_level > v_old_level
  );
end;
$$;

grant execute on function public.submit_practice_round(uuid, jsonb) to authenticated;