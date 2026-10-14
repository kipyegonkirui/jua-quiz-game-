-- ============================================================================
-- 003_phase1_practice_and_timezone.sql
--
-- Phase 0 + Phase 1 of the roadmap:
--   A. Day boundaries switch from UTC to Kenya time (Africa/Nairobi), so the
--      daily challenge and streaks roll over at local midnight, not 3 AM.
--   B. Security fix: the daily challenge can only be submitted for TODAY's
--      challenge (before, any old challenge id could be submitted for XP).
--   C. Infinite practice rounds: server-picked, one-shot, no streak impact.
--
-- HOW TO RUN: Supabase Dashboard > SQL Editor > New query > paste this whole
-- file > Run. Run it AFTER schema.sql and 002_optional_accounts.sql.
-- Safe to run more than once.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- A. Kenya-time helper
-- ----------------------------------------------------------------------------
create or replace function public.nairobi_today()
returns date
language sql
stable
as $$
  select (now() at time zone 'Africa/Nairobi')::date;
$$;


-- ----------------------------------------------------------------------------
-- A. Daily challenge creation — identical to before except for the date.
-- ----------------------------------------------------------------------------
create or replace function public.get_or_create_today_challenge()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_challenge_id uuid;
  v_today date := public.nairobi_today();
begin
  select id into v_challenge_id from public.daily_challenges where challenge_date = v_today;

  if v_challenge_id is not null then
    return v_challenge_id;
  end if;

  insert into public.daily_challenges (challenge_date)
  values (v_today)
  on conflict (challenge_date) do nothing
  returning id into v_challenge_id;

  -- Someone else's request created it a moment ago — just fetch it.
  if v_challenge_id is null then
    select id into v_challenge_id from public.daily_challenges where challenge_date = v_today;
    return v_challenge_id;
  end if;

  insert into public.daily_challenge_questions (daily_challenge_id, question_id, position)
  select v_challenge_id, q.id, row_number() over ()
  from (
    select id from public.questions where is_active = true order by random() limit 5
  ) q;

  return v_challenge_id;
end;
$$;


-- ----------------------------------------------------------------------------
-- A + B. Daily scoring — same XP/streak rules as before. Two changes:
--   * "today" / "yesterday" are Kenya dates.
--   * Only today's challenge can be submitted.
-- ----------------------------------------------------------------------------
create or replace function public.submit_daily_attempt(p_challenge_id uuid, p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id       uuid := auth.uid();
  v_today         date := public.nairobi_today();
  v_yesterday     date := public.nairobi_today() - 1;
  v_score         integer := 0;
  v_total         integer := 0;
  v_xp_earned     integer := 0;
  v_old_level     integer;
  v_new_xp        integer;
  v_new_level     integer;
  v_profile       public.profiles%rowtype;
  v_new_streak    integer;
  q               record;
  v_given         text;
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

  for q in
    select qs.id, qs.correct_option
    from public.daily_challenge_questions dcq
    join public.questions qs on qs.id = dcq.question_id
    where dcq.daily_challenge_id = p_challenge_id
  loop
    v_total := v_total + 1;
    v_given := p_answers ->> q.id::text;
    if v_given is not null and lower(v_given) = q.correct_option then
      v_score := v_score + 1;
    end if;
  end loop;

  if v_total = 0 then
    raise exception 'challenge has no questions';
  end if;

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
  values (v_user_id, p_challenge_id, v_score, v_total, v_xp_earned, p_answers);

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
-- Repair: `position` is a reserved word in Postgres, so the original
-- get_challenge_questions() in schema.sql (unquoted `position integer` in its
-- RETURNS TABLE list) is a syntax error. If your database already has a
-- working version this simply re-creates it identically; if not, this fixes it.
-- ----------------------------------------------------------------------------
create or replace function public.get_challenge_questions(p_challenge_id uuid)
returns table (
  id uuid,
  question_text text,
  option_a text,
  option_b text,
  option_c text,
  option_d text,
  "position" integer
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select q.id, q.question_text, q.option_a, q.option_b, q.option_c, q.option_d, dcq.position
  from public.daily_challenge_questions dcq
  join public.questions q on q.id = dcq.question_id
  where dcq.daily_challenge_id = p_challenge_id
  order by dcq.position;
$$;

-- ----------------------------------------------------------------------------
-- C. Practice rounds
--   total_attempts keeps meaning "daily challenges completed".
--   total_correct / total_questions (accuracy) now include practice too.
--   practice_rounds counts finished practice rounds.
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists practice_rounds integer not null default 0;

create table if not exists public.practice_rounds (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  status          text not null default 'open' check (status in ('open', 'completed')),
  score           integer,
  total_questions integer not null default 0,
  xp_earned       integer not null default 0,
  answers         jsonb,
  started_at      timestamptz not null default now(),
  completed_at    timestamptz
);

create index if not exists practice_rounds_user_status_idx
  on public.practice_rounds (user_id, status);
create index if not exists practice_rounds_user_completed_idx
  on public.practice_rounds (user_id, completed_at);

create table if not exists public.practice_round_questions (
  round_id    uuid not null references public.practice_rounds(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  position    integer not null,
  primary key (round_id, question_id)
);

alter table public.practice_rounds enable row level security;
alter table public.practice_round_questions enable row level security;

-- Players may read their own round history. Nobody can write to either table
-- directly; rows only ever appear through the functions below.
drop policy if exists "users can read their own practice rounds" on public.practice_rounds;
create policy "users can read their own practice rounds"
  on public.practice_rounds for select
  to authenticated
  using (auth.uid() = user_id);

revoke all on public.practice_rounds from anon, authenticated;
revoke all on public.practice_round_questions from anon, authenticated;
grant select on public.practice_rounds to authenticated;


-- Start (or resume) a practice round. Returns the round id.
--   * If the player already has an unfinished round, that same round comes
--     back — they can't reroll to dodge hard questions.
--   * Questions they haven't seen yet (in practice OR in a daily challenge)
--     come first; once they've seen everything, the ones they saw longest
--     ago come back first.
--   * Questions that are in today's daily challenge are held back until last,
--     so practice never spoils a daily challenge that hasn't been played yet.
create or replace function public.start_practice_round()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_today   date := public.nairobi_today();
  v_size    constant integer := 5;   -- keep in step with AppConfig.practiceRoundSize
  v_round   uuid;
  v_count   integer;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Stops a double-tap from creating two rounds.
  perform pg_advisory_xact_lock(hashtext('practice:' || v_uid::text));

  select id into v_round
  from public.practice_rounds
  where user_id = v_uid and status = 'open'
  order by started_at desc
  limit 1;

  if v_round is not null then
    return v_round;
  end if;

  insert into public.practice_rounds (user_id) values (v_uid) returning id into v_round;

  with today_daily as (
    select dcq.question_id
    from public.daily_challenges dc
    join public.daily_challenge_questions dcq on dcq.daily_challenge_id = dc.id
    where dc.challenge_date = v_today
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
      (q.id in (select question_id from today_daily)),  -- false (not in today's daily) first
      (ls.seen_at is not null),                         -- never-seen first
      ls.seen_at asc,                                   -- then longest-ago first
      random()
    limit v_size
  )
  insert into public.practice_round_questions (round_id, question_id, position)
  select v_round, id, (row_number() over ())::integer from picked;

  get diagnostics v_count = row_count;

  if v_count = 0 then
    raise exception 'no questions available';
  end if;

  update public.practice_rounds set total_questions = v_count where id = v_round;

  return v_round;
end;
$$;


-- The questions for one of YOUR open rounds — never includes the answer key.
create or replace function public.get_practice_questions(p_round_id uuid)
returns table (
  id uuid,
  question_text text,
  option_a text,
  option_b text,
  option_c text,
  option_d text,
  "position" integer
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select q.id, q.question_text, q.option_a, q.option_b, q.option_c, q.option_d, prq.position
  from public.practice_round_questions prq
  join public.practice_rounds pr on pr.id = prq.round_id
  join public.questions q on q.id = prq.question_id
  where prq.round_id = p_round_id
    and pr.user_id = auth.uid()
    and pr.status = 'open'
  order by prq.position;
$$;


-- Score a practice round. One shot per round: a second submit is rejected, so
-- a round can never be replayed for repeat XP.
--   * 10 XP per correct answer, NO perfect-round bonus.
--   * XP from practice is capped per Kenya day (v_daily_cap). Past the cap the
--     round still counts toward accuracy and lifetime stats, just for 0 XP.
--   * Never touches current_streak / longest_streak / last_completed_date.
create or replace function public.submit_practice_round(p_round_id uuid, p_answers jsonb)
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
  v_score       integer := 0;
  v_total       integer := 0;
  v_raw_xp      integer;
  v_xp_earned   integer;
  v_xp_today    integer;
  v_old_level   integer;
  v_new_xp      integer;
  v_new_level   integer;
  q             record;
  v_given       text;
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

  for q in
    select qs.id, qs.correct_option
    from public.practice_round_questions prq
    join public.questions qs on qs.id = prq.question_id
    where prq.round_id = p_round_id
  loop
    v_total := v_total + 1;
    v_given := coalesce(p_answers, '{}'::jsonb) ->> q.id::text;
    if v_given is not null and lower(v_given) = q.correct_option then
      v_score := v_score + 1;
    end if;
  end loop;

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
    answers = coalesce(p_answers, '{}'::jsonb),
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


-- ----------------------------------------------------------------------------
-- Who may call what. Guests count as "authenticated".
-- ----------------------------------------------------------------------------
revoke execute on function public.start_practice_round() from public, anon;
revoke execute on function public.get_practice_questions(uuid) from public, anon;
revoke execute on function public.submit_practice_round(uuid, jsonb) from public, anon;
grant execute on function public.start_practice_round() to authenticated;
grant execute on function public.get_practice_questions(uuid) to authenticated;
grant execute on function public.submit_practice_round(uuid, jsonb) to authenticated;
