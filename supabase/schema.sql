-- ============================================================================
-- Jua Quiz — core schema
-- Run this once in your Supabase project's SQL Editor (Dashboard > SQL Editor
-- > New query > paste > Run). Safe to re-run: uses IF NOT EXISTS / OR REPLACE
-- wherever possible, but on a second run the CREATE TABLE statements will
-- simply error harmlessly if the tables already exist.
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. PROFILES  (one row per auth user; XP/streak live here)
-- ----------------------------------------------------------------------------
create table public.profiles (
  id                 uuid primary key references auth.users(id) on delete cascade,
  username           text not null,
  avatar_url         text,
  xp                 integer not null default 0,
  level              integer not null default 1,
  current_streak     integer not null default 0,
  longest_streak     integer not null default 0,
  last_completed_date date,
  total_attempts     integer not null default 0,
  total_correct      integer not null default 0,
  total_questions    integer not null default 0,
  is_admin           boolean not null default false,
  created_at         timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles are readable by any signed-in user"
  on public.profiles for select
  to authenticated
  using (true);

create policy "users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "users can update their own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- Only username/avatar are editable directly by the client. xp, level,
-- streaks etc. are only ever changed by submit_daily_attempt() below, which
-- runs as SECURITY DEFINER and bypasses this grant — this is what stops a
-- user from just PATCHing their own xp to cheat the leaderboard.
revoke update on public.profiles from authenticated;
grant update (username, avatar_url) on public.profiles to authenticated;

-- Auto-create a profile row whenever someone signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 2. CATEGORIES
-- ----------------------------------------------------------------------------
create table public.categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  icon       text,
  is_active  boolean not null default true
);

alter table public.categories enable row level security;

create policy "categories are readable by any signed-in user"
  on public.categories for select
  to authenticated
  using (true);

-- ----------------------------------------------------------------------------
-- 3. QUESTIONS  (correct_option is never exposed directly to clients)
-- ----------------------------------------------------------------------------
create table public.questions (
  id              uuid primary key default gen_random_uuid(),
  category_id     uuid references public.categories(id) on delete set null,
  question_text   text not null,
  option_a        text not null,
  option_b        text not null,
  option_c        text not null,
  option_d        text not null,
  correct_option  text not null check (correct_option in ('a', 'b', 'c', 'd')),
  difficulty      text not null default 'medium' check (difficulty in ('easy', 'medium', 'hard')),
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

alter table public.questions enable row level security;
-- Intentionally NO select policy for plain clients — questions (with their
-- answer key) are only ever read through the SECURITY DEFINER functions
-- below, or directly by an admin (see admin policy).

create policy "admins can do anything with questions"
  on public.questions for all
  to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

create policy "admins can manage categories"
  on public.categories for insert
  to authenticated
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

create policy "admins can update categories"
  on public.categories for update
  to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin));

-- A safe, answer-key-free view the app itself is allowed to read.
create view public.questions_public
with (security_invoker = true)
as
  select id, category_id, question_text, option_a, option_b, option_c, option_d, difficulty
  from public.questions
  where is_active = true;

grant select on public.questions_public to authenticated;

-- ----------------------------------------------------------------------------
-- 4. DAILY CHALLENGES
-- ----------------------------------------------------------------------------
create table public.daily_challenges (
  id             uuid primary key default gen_random_uuid(),
  challenge_date date not null unique,
  created_at     timestamptz not null default now()
);

create table public.daily_challenge_questions (
  daily_challenge_id uuid not null references public.daily_challenges(id) on delete cascade,
  question_id        uuid not null references public.questions(id) on delete cascade,
  position           integer not null,
  primary key (daily_challenge_id, question_id)
);

alter table public.daily_challenges enable row level security;
alter table public.daily_challenge_questions enable row level security;

create policy "daily challenges are readable by any signed-in user"
  on public.daily_challenges for select
  to authenticated
  using (true);

-- Note: no direct select policy on daily_challenge_questions — it's read
-- through get_challenge_questions() below so the answer key stays hidden.

-- How many questions make up one day's challenge.
-- (change this constant in the function below if you want a different size)

create or replace function public.get_or_create_today_challenge()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_challenge_id uuid;
  v_today date := current_date;
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

grant execute on function public.get_or_create_today_challenge() to authenticated;

create or replace function public.get_challenge_questions(p_challenge_id uuid)
returns table (
  id uuid,
  question_text text,
  option_a text,
  option_b text,
  option_c text,
  option_d text,
  position integer
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

grant execute on function public.get_challenge_questions(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 5. ATTEMPTS  (one per user per daily challenge — this IS the streak record)
-- ----------------------------------------------------------------------------
create table public.attempts (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles(id) on delete cascade,
  daily_challenge_id uuid not null references public.daily_challenges(id) on delete cascade,
  score              integer not null,
  total_questions    integer not null,
  xp_earned          integer not null,
  answers            jsonb not null,
  completed_at       timestamptz not null default now(),
  unique (user_id, daily_challenge_id)
);

alter table public.attempts enable row level security;

create policy "users can read their own attempts"
  on public.attempts for select
  to authenticated
  using (auth.uid() = user_id);

-- No insert policy for attempts either — rows are only ever written by
-- submit_daily_attempt(), which validates answers server-side first.

-- ----------------------------------------------------------------------------
-- 6. THE SECURE SCORING FUNCTION
--    Client sends {"question-id": "a", "question-id-2": "c", ...}. This is
--    the *only* path that can change xp/level/streak, so a modified client
--    can't just write its own high score.
-- ----------------------------------------------------------------------------
create or replace function public.submit_daily_attempt(p_challenge_id uuid, p_answers jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id       uuid := auth.uid();
  v_score         integer := 0;
  v_total         integer := 0;
  v_xp_earned     integer := 0;
  v_old_level     integer;
  v_new_xp        integer;
  v_new_level     integer;
  v_profile       public.profiles%rowtype;
  v_yesterday     date := current_date - interval '1 day';
  v_new_streak    integer;
  q               record;
  v_given         text;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
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
  elsif v_profile.last_completed_date = current_date then
    v_new_streak := v_profile.current_streak; -- shouldn't happen, guarded above
  else
    v_new_streak := 1;
  end if;

  update public.profiles set
    xp = v_new_xp,
    level = v_new_level,
    current_streak = v_new_streak,
    longest_streak = greatest(v_profile.longest_streak, v_new_streak),
    last_completed_date = current_date,
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

grant execute on function public.submit_daily_attempt(uuid, jsonb) to authenticated;

-- ----------------------------------------------------------------------------
-- 7. LEADERBOARD  (top 100 by XP — trim/extend the limit as you like)
-- ----------------------------------------------------------------------------
create view public.leaderboard
with (security_invoker = true)
as
  select id, username, avatar_url, xp, level, current_streak
  from public.profiles
  order by xp desc, created_at asc
  limit 100;

grant select on public.leaderboard to authenticated;

-- ----------------------------------------------------------------------------
-- Done. Next: run seed_kenya_questions.sql, then make yourself an admin with:
--   update public.profiles set is_admin = true where id = '<your-auth-uid>';
-- ----------------------------------------------------------------------------
