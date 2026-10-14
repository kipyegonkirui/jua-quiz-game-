-- ============================================================================
-- 007_competitions.sql   (Phase 5A — Competitions + coins)
--
-- RUN ORDER: 003 -> 004 -> 005 -> 006 -> this file.  Safe to run more than once.
-- (If you ever re-run 006, run this file again afterwards: it replaces two of
--  006's functions.)
--
-- What it adds
--   * COINS        virtual only. profiles.coins is the balance; coin_ledger is
--                  the permanent record of every change (nothing is ever
--                  edited or deleted, so any balance can be audited).
--   * COMPETITIONS a scheduled window (e.g. Sat 18:00-21:00). Everyone gets the
--                  SAME questions, in a different order each. You have a few
--                  lives; a wrong answer or a timeout costs one; zero = out.
--                  The server owns the clock.
--   * RESULTS      when the window closes, settle_competition() ranks everyone
--                  and pays coins. It runs by itself the next time anyone opens
--                  the Competitions tab, and can also be scheduled (see notes).
--   * BUY A HINT   buy_hint() spends coins instead of watching a video; the
--                  hint itself is still delivered by use_hint() from phase 4.
--
-- Competitions are separate from the daily streak, XP and practice stats.
-- Hints / second chances are NOT available inside competitions (fairness).
-- ============================================================================


-- ---------------------------------------------------------------------------
-- Tunables
-- ---------------------------------------------------------------------------
create or replace function public.hint_price()
returns integer language sql immutable as $$ select 20 $$;

-- Extra time allowed on top of a question's limit for network delay.
create or replace function public.competition_grace_ms()
returns integer language sql immutable as $$ select 2000 $$;


-- ---------------------------------------------------------------------------
-- Coins
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists coins integer not null default 0 check (coins >= 0);

create table if not exists public.coin_ledger (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  amount        integer not null check (amount <> 0),
  reason        text not null check (reason in ('competition_reward', 'hint_purchase', 'admin_grant')),
  ref_id        uuid,                                  -- entry id / reward-grant id
  balance_after integer not null check (balance_after >= 0),
  created_at    timestamptz not null default now(),
  unique (user_id, reason, ref_id)                     -- the same thing can't pay/charge twice
);
alter table public.coin_ledger enable row level security;
revoke all on public.coin_ledger from anon, authenticated;

-- The ONLY way coins move. Returns the new balance, or NULL if this exact
-- (user, reason, ref) was already applied (so retries are harmless).
create or replace function public._coin_apply(p_uid uuid, p_amount integer, p_reason text, p_ref uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_balance integer;
begin
  select coins into v_balance from public.profiles where id = p_uid for update;
  if v_balance is null then
    raise exception 'profile not found';
  end if;
  if v_balance + p_amount < 0 then
    raise exception 'not_enough_coins';
  end if;
  begin
    insert into public.coin_ledger (user_id, amount, reason, ref_id, balance_after)
    values (p_uid, p_amount, p_reason, p_ref, v_balance + p_amount);
  exception when unique_violation then
    return null;
  end;
  update public.profiles set coins = v_balance + p_amount where id = p_uid;
  return v_balance + p_amount;
end;
$$;
revoke all on function public._coin_apply(uuid, integer, text, uuid) from public, anon, authenticated;


-- ---------------------------------------------------------------------------
-- Competition tables. Players never touch these directly; they go through the
-- functions below. (Only the competition list itself is readable.)
-- ---------------------------------------------------------------------------
create table if not exists public.competitions (
  id                  uuid primary key default gen_random_uuid(),
  title               text not null,
  starts_at           timestamptz not null,
  ends_at             timestamptz not null,
  question_count      integer not null default 10 check (question_count between 3 and 30),
  lives               integer not null default 3  check (lives between 1 and 10),
  seconds_per_question integer not null default 20 check (seconds_per_question between 5 and 120),
  participation_coins integer not null default 10 check (participation_coins >= 0),
  -- e.g. [{"from":1,"to":1,"coins":100},{"from":2,"to":3,"coins":50}]
  prize_tiers         jsonb not null default '[]'::jsonb,
  status              text not null default 'scheduled' check (status in ('scheduled', 'settled')),
  settled_at          timestamptz,
  created_at          timestamptz not null default now(),
  check (ends_at > starts_at)
);

create table if not exists public.competition_questions (
  competition_id uuid not null references public.competitions(id) on delete cascade,
  question_id    uuid not null references public.questions(id) on delete cascade,
  position       integer not null,
  primary key (competition_id, question_id)
);

create table if not exists public.competition_entries (
  id             uuid primary key default gen_random_uuid(),
  competition_id uuid not null references public.competitions(id) on delete cascade,
  user_id        uuid not null references public.profiles(id) on delete cascade,
  status         text not null default 'playing' check (status in ('playing', 'finished')),
  finish_reason  text check (finish_reason in ('completed', 'out_of_lives', 'forfeited')),
  question_order uuid[] not null,            -- this player's own shuffled order
  next_index     integer not null default 1, -- 1-based: the question being served / next to serve
  served_at      timestamptz,                -- when the current question was served (server clock)
  lives_left     integer not null,
  answered       integer not null default 0,
  correct        integer not null default 0,
  total_time_ms  integer not null default 0,
  rank           integer,
  coins_awarded  integer not null default 0,
  started_at     timestamptz not null default now(),
  finished_at    timestamptz,
  unique (competition_id, user_id)
);

create table if not exists public.competition_answers (
  entry_id    uuid not null references public.competition_entries(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  position    integer not null,
  chosen      text check (chosen in ('a', 'b', 'c', 'd')),  -- null = skipped / timed out
  is_correct  boolean not null,
  timed_out   boolean not null default false,
  served_at   timestamptz not null,
  answered_at timestamptz not null default now(),
  elapsed_ms  integer not null,
  primary key (entry_id, question_id)
);

alter table public.competitions          enable row level security;
alter table public.competition_questions enable row level security;
alter table public.competition_entries   enable row level security;
alter table public.competition_answers   enable row level security;
revoke all on public.competitions          from anon, authenticated;
revoke all on public.competition_questions from anon, authenticated;
revoke all on public.competition_entries   from anon, authenticated;
revoke all on public.competition_answers   from anon, authenticated;

alter table public.reward_grants drop constraint if exists reward_grants_source_check;
alter table public.reward_grants
  add constraint reward_grants_source_check check (source in ('client', 'ssv', 'coins'));


-- ---------------------------------------------------------------------------
-- Admin helpers. From the SQL Editor (no signed-in user) these just work; from
-- the app they need profiles.is_admin = true.
-- ---------------------------------------------------------------------------
create or replace function public._require_admin()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is not null
     and not exists (select 1 from public.profiles where id = auth.uid() and is_admin) then
    raise exception 'admins only';
  end if;
end;
$$;
revoke all on function public._require_admin() from public, anon, authenticated;

create or replace function public.create_competition(
  p_title text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_question_count integer default 10,
  p_lives integer default 3,
  p_seconds integer default 20,
  p_participation_coins integer default 10,
  p_prize_tiers jsonb default '[{"from":1,"to":1,"coins":100},{"from":2,"to":3,"coins":50},{"from":4,"to":10,"coins":30}]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id uuid;
  v_n  integer;
begin
  perform public._require_admin();

  insert into public.competitions
    (title, starts_at, ends_at, question_count, lives, seconds_per_question, participation_coins, prize_tiers)
  values
    (p_title, p_starts_at, p_ends_at, p_question_count, p_lives, p_seconds, p_participation_coins, p_prize_tiers)
  returning id into v_id;

  insert into public.competition_questions (competition_id, question_id, position)
  select v_id, picked.id, row_number() over ()
  from (
    select id from public.questions where is_active = true order by random() limit p_question_count
  ) picked;

  get diagnostics v_n = row_count;
  if v_n < p_question_count then
    raise exception 'not enough active questions (have %, need %)', v_n, p_question_count;
  end if;
  return v_id;
end;
$$;

-- Handy for testing the hint shop. Coins appear in the ledger as 'admin_grant'.
create or replace function public.admin_grant_coins(p_user uuid, p_amount integer)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform public._require_admin();
  if p_amount <= 0 then
    raise exception 'amount must be positive';
  end if;
  return public._coin_apply(p_user, p_amount, 'admin_grant', null);
end;
$$;


-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------
create or replace function public._entry_summary(p_entry uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'status', e.status,
    'finish_reason', e.finish_reason,
    'lives_left', e.lives_left,
    'answered', e.answered,
    'correct', e.correct,
    'total_time_ms', e.total_time_ms,
    'total_questions', array_length(e.question_order, 1),
    'rank', e.rank,
    'coins_awarded', e.coins_awarded
  )
  from public.competition_entries e where e.id = p_entry;
$$;
revoke all on function public._entry_summary(uuid) from public, anon, authenticated;

-- Records the answer (or timeout) for the question currently being served and
-- moves the entry on. The caller must already hold the entry's row lock.
create or replace function public._comp_record(p_entry uuid, p_chosen text, p_force_timeout boolean)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  e            public.competition_entries%rowtype;
  c            public.competitions%rowtype;
  v_q          uuid;
  v_correct    text;
  v_elapsed    integer;
  v_limit      integer;
  v_timed_out  boolean;
  v_ok         boolean;
  v_chosen     text;
  v_lives      integer;
  v_right      integer;
  v_finished   boolean;
  v_reason     text;
begin
  select * into e from public.competition_entries where id = p_entry;
  select * into c from public.competitions where id = e.competition_id;

  v_q := e.question_order[e.next_index];
  select correct_option into v_correct from public.questions where id = v_q;

  v_elapsed := greatest(0, (extract(epoch from (now() - e.served_at)) * 1000)::integer);
  v_limit := c.seconds_per_question * 1000;
  v_timed_out := p_force_timeout or v_elapsed > v_limit + public.competition_grace_ms();

  if v_timed_out or p_chosen is null then
    v_chosen := null;
    v_ok := false;
  else
    v_chosen := p_chosen;
    v_ok := (p_chosen = v_correct);
  end if;

  insert into public.competition_answers
    (entry_id, question_id, position, chosen, is_correct, timed_out, served_at, elapsed_ms)
  values (p_entry, v_q, e.next_index, v_chosen, v_ok, v_timed_out, e.served_at, v_elapsed);

  v_lives := e.lives_left - (case when v_ok then 0 else 1 end);
  v_right := e.correct + (case when v_ok then 1 else 0 end);
  v_finished := v_lives <= 0 or e.next_index >= array_length(e.question_order, 1);
  v_reason := case when not v_finished then null
                   when v_lives <= 0 then 'out_of_lives'
                   else 'completed' end;

  update public.competition_entries set
    answered = answered + 1,
    correct = v_right,
    lives_left = v_lives,
    total_time_ms = total_time_ms + (case when v_timed_out then v_limit else least(v_elapsed, v_limit) end),
    next_index = next_index + 1,
    served_at = null,
    status = case when v_finished then 'finished' else 'playing' end,
    finish_reason = v_reason,
    finished_at = case when v_finished then now() end
  where id = p_entry;

  -- Deliberately NO correct_option here: everyone plays the same questions
  -- during the window, so the answer must not leak to people who haven't played.
  return jsonb_build_object(
    'is_correct', v_ok,
    'timed_out', v_timed_out,
    'lives_left', v_lives,
    'correct', v_right,
    'finished', v_finished,
    'finish_reason', v_reason,
    'elapsed_ms', v_elapsed
  );
end;
$$;
revoke all on function public._comp_record(uuid, text, boolean) from public, anon, authenticated;


-- ===========================================================================
-- Settlement (called by the app lazily, or by a schedule; never by players)
-- ===========================================================================
create or replace function public.settle_competition(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c        public.competitions%rowtype;
  v        record;
  v_coins  integer;
  v_tier   integer;
  v_total  integer := 0;
  v_paid   integer := 0;
begin
  select * into c from public.competitions where id = p_id for update;
  if not found then
    raise exception 'competition not found';
  end if;
  if c.status = 'settled' then
    return jsonb_build_object('already_settled', true);
  end if;
  -- Slack so a question served just before the buzzer can still be finished:
  -- its full time limit plus a few seconds. Settling earlier would cut it off.
  if now() < c.ends_at + make_interval(secs => c.seconds_per_question + 10) then
    raise exception 'not_yet';
  end if;

  -- Anyone still mid-run when the window closed is finalized with what they have.
  update public.competition_entries
     set status = 'finished', finish_reason = 'forfeited', finished_at = now(), served_at = null
   where competition_id = p_id and status = 'playing';

  -- Rank everyone who answered at least one question:
  -- more correct, then more lives left, then less total time, then who joined first.
  update public.competition_entries e
     set rank = r.rn
    from (
      select id, row_number() over (order by correct desc, lives_left desc, total_time_ms asc, started_at asc, id) as rn
        from public.competition_entries
       where competition_id = p_id and answered > 0
    ) r
   where e.id = r.id;

  for v in
    select id, user_id, rank, correct
      from public.competition_entries
     where competition_id = p_id and answered > 0
     order by rank
  loop
    v_coins := c.participation_coins;
    if v.correct > 0 then
      select coalesce(sum((t ->> 'coins')::integer), 0) into v_tier
        from jsonb_array_elements(c.prize_tiers) t
       where v.rank between (t ->> 'from')::integer and (t ->> 'to')::integer;
      v_coins := v_coins + v_tier;
    end if;

    if v_coins > 0 then
      perform public._coin_apply(v.user_id, v_coins, 'competition_reward', v.id);
    end if;
    update public.competition_entries set coins_awarded = v_coins where id = v.id;
    v_total := v_total + v_coins;
    v_paid := v_paid + 1;
  end loop;

  update public.competitions set status = 'settled', settled_at = now() where id = p_id;
  return jsonb_build_object('players_paid', v_paid, 'coins_paid', v_total);
end;
$$;

create or replace function public.settle_due_competitions()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select id from public.competitions
     where status = 'scheduled'
       and now() >= ends_at + make_interval(secs => seconds_per_question + 10)
     order by ends_at
  loop
    perform public.settle_competition(r.id);
    n := n + 1;
  end loop;
  return n;
end;
$$;
revoke all on function public.settle_competition(uuid)  from public, anon, authenticated;
revoke all on function public.settle_due_competitions() from public, anon, authenticated;


-- ===========================================================================
-- What the app calls
-- ===========================================================================

-- Upcoming, open and recently settled competitions, each with the caller's own
-- entry summary. Also settles anything that is due (so it never waits on a cron).
create or replace function public.list_competitions()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public.settle_due_competitions();

  return coalesce((
    select jsonb_agg(row_json order by sort_key)
    from (
      select
        jsonb_build_object(
          'id', c.id,
          'title', c.title,
          'starts_at', c.starts_at,
          'ends_at', c.ends_at,
          'question_count', c.question_count,
          'lives', c.lives,
          'seconds_per_question', c.seconds_per_question,
          'participation_coins', c.participation_coins,
          'prize_tiers', c.prize_tiers,
          'phase', case when c.status = 'settled' then 'settled'
                        when now() < c.starts_at then 'upcoming'
                        when now() < c.ends_at then 'open'
                        else 'closed' end,
          'entrants', (select count(*) from public.competition_entries x where x.competition_id = c.id),
          'my_entry', (select public._entry_summary(x.id) from public.competition_entries x
                        where x.competition_id = c.id and x.user_id = v_uid)
        ) as row_json,
        -- open first, then upcoming (soonest first), then closed/settled (newest first)
        case when now() >= c.starts_at and now() < c.ends_at then 0
             when now() < c.starts_at then 1 else 2 end * 1e12
          + case when now() < c.starts_at then extract(epoch from c.starts_at)
                 else 1e11 - extract(epoch from c.starts_at) end as sort_key
      from public.competitions c
      where c.ends_at > now() - interval '7 days'
    ) s
  ), '[]'::jsonb);
end;
$$;

-- Join (idempotent). Only possible while the window is open.
create or replace function public.start_competition_entry(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  c     public.competitions%rowtype;
  v_id  uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into c from public.competitions where id = p_id;
  if not found then
    raise exception 'competition not found';
  end if;

  select id into v_id from public.competition_entries where competition_id = p_id and user_id = v_uid;
  if v_id is not null then
    return public._entry_summary(v_id);
  end if;

  if now() < c.starts_at then
    raise exception 'not_started';
  end if;
  if now() >= c.ends_at then
    raise exception 'closed';
  end if;

  insert into public.competition_entries (competition_id, user_id, question_order, lives_left)
  select p_id, v_uid, array_agg(question_id order by random()), c.lives
    from public.competition_questions where competition_id = p_id
  on conflict (competition_id, user_id) do nothing;

  select id into v_id from public.competition_entries where competition_id = p_id and user_id = v_uid;
  return public._entry_summary(v_id);
end;
$$;

-- Serves the current question (one at a time). Asking again returns the SAME
-- question with the time that is genuinely left, so leaving and coming back
-- can never reset the clock. A question left past its time limit is recorded
-- as a timeout (costs a life) before the next one is served.
create or replace function public.competition_next_question(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  c         public.competitions%rowtype;
  e         public.competition_entries%rowtype;
  q         public.questions%rowtype;
  v_elapsed integer;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into c from public.competitions where id = p_id;
  if not found then
    raise exception 'competition not found';
  end if;

  select * into e from public.competition_entries
   where competition_id = p_id and user_id = v_uid for update;
  if not found then
    raise exception 'not_joined';
  end if;

  loop
    if e.status = 'finished' then
      return jsonb_build_object('status', 'finished', 'summary', public._entry_summary(e.id));
    end if;

    if e.served_at is not null then
      v_elapsed := greatest(0, (extract(epoch from (now() - e.served_at)) * 1000)::integer);
      exit when v_elapsed <= c.seconds_per_question * 1000 + public.competition_grace_ms();
      -- Left it too long: that's a timeout.
      perform public._comp_record(e.id, null, true);
      select * into e from public.competition_entries where id = e.id;
      continue;
    end if;

    -- Nothing being served. If the window has closed, the run ends here.
    if now() >= c.ends_at then
      update public.competition_entries
         set status = 'finished', finish_reason = 'forfeited', finished_at = now()
       where id = e.id;
      select * into e from public.competition_entries where id = e.id;
      continue;
    end if;

    update public.competition_entries set served_at = now() where id = e.id;
    select * into e from public.competition_entries where id = e.id;
    v_elapsed := 0;
    exit;
  end loop;

  select * into q from public.questions where id = e.question_order[e.next_index];

  return jsonb_build_object(
    'status', 'question',
    'question', jsonb_build_object(
      'id', q.id,
      'text', q.question_text,
      'options', jsonb_build_object('a', q.option_a, 'b', q.option_b, 'c', q.option_c, 'd', q.option_d)
    ),
    'position', e.next_index,
    'total', array_length(e.question_order, 1),
    'lives_left', e.lives_left,
    'correct', e.correct,
    'seconds_per_question', c.seconds_per_question,
    'seconds_left', greatest(0, ceil(c.seconds_per_question - v_elapsed / 1000.0))::integer
  );
end;
$$;

-- p_choice null/'' = skip (counts as wrong). Tells you right/wrong, NOT which
-- option was right (see _comp_record).
create or replace function public.competition_answer(p_id uuid, p_question_id uuid, p_choice text)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid    uuid := auth.uid();
  v_choice text := nullif(lower(coalesce(p_choice, '')), '');
  e        public.competition_entries%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if v_choice is not null and v_choice not in ('a', 'b', 'c', 'd') then
    raise exception 'invalid choice';
  end if;

  select * into e from public.competition_entries
   where competition_id = p_id and user_id = v_uid for update;
  if not found then
    raise exception 'not_joined';
  end if;

  -- Must be the question currently being served (blocks replays and double taps).
  if e.status <> 'playing' or e.served_at is null
     or e.question_order[e.next_index] is distinct from p_question_id then
    raise exception 'not_current_question';
  end if;

  return public._comp_record(e.id, v_choice, false);
end;
$$;

-- Final standings. Only once the competition is settled.
create or replace function public.get_competition_results(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  c     public.competitions%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  select * into c from public.competitions where id = p_id;
  if not found then
    raise exception 'competition not found';
  end if;
  if c.status <> 'settled' then
    raise exception 'not_settled';
  end if;

  return jsonb_build_object(
    'title', c.title,
    'top', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', e.rank, 'username', p.username, 'correct', e.correct,
               'lives_left', e.lives_left, 'total_time_ms', e.total_time_ms,
               'coins_awarded', e.coins_awarded, 'is_me', e.user_id = v_uid)
             order by e.rank)
        from (select * from public.competition_entries
               where competition_id = p_id and rank is not null order by rank limit 25) e
        join public.profiles p on p.id = e.user_id
    ), '[]'::jsonb),
    'me', (select public._entry_summary(x.id) from public.competition_entries x
            where x.competition_id = p_id and x.user_id = v_uid),
    'players', (select count(*) from public.competition_entries where competition_id = p_id and rank is not null)
  );
end;
$$;

-- Spend coins on a hint. Gives the same "hint entitlement" a video does, so
-- use_hint() (phase 4) then delivers the two wrong options. Idempotent: never
-- charges twice for the same question, never charges if a hint is already
-- available, and a failed charge leaves nothing behind.
create or replace function public.buy_hint(
  p_context_type text, p_context_id uuid, p_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_grant uuid;
  v_bal   integer;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public._ctx_check(p_context_type, p_context_id, p_question_id, v_uid);
  if public._ctx_completed(p_context_type, p_context_id, v_uid) then
    raise exception 'already completed today''s challenge';
  end if;

  select coins into v_bal from public.profiles where id = v_uid;

  -- Hint already delivered, or already paid/earned for: nothing to charge.
  if exists (select 1 from public.hint_uses
              where user_id = v_uid and context_type = p_context_type
                and context_id = p_context_id and question_id = p_question_id)
     or exists (select 1 from public.reward_grants
                 where user_id = v_uid and kind = 'hint' and context_type = p_context_type
                   and context_id = p_context_id and question_id = p_question_id) then
    return jsonb_build_object('granted', true, 'charged', false, 'coins', v_bal);
  end if;

  if public._ctx_final(p_context_type, p_context_id, p_question_id, v_uid) is not null
     or exists (select 1 from public.answer_attempts
                 where user_id = v_uid and context_type = p_context_type
                   and context_id = p_context_id and question_id = p_question_id) then
    raise exception 'question_answered';
  end if;

  insert into public.reward_grants (user_id, kind, context_type, context_id, question_id, source)
  values (v_uid, 'hint', p_context_type, p_context_id, p_question_id, 'coins')
  returning id into v_grant;

  -- Raises 'not_enough_coins' (undoing the grant above) if they can't afford it.
  v_bal := public._coin_apply(v_uid, -public.hint_price(), 'hint_purchase', v_grant);

  return jsonb_build_object('granted', true, 'charged', true, 'coins', v_bal);
end;
$$;


-- ---------------------------------------------------------------------------
-- Phase 4 functions, updated: coin-bought hints don't count against the
-- per-round video-hint cap, and the app also learns the coin balance + price.
-- ---------------------------------------------------------------------------
create or replace function public.claim_reward(
  p_context_type text, p_context_id uuid, p_question_id uuid, p_kind text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if p_kind not in ('hint', 'second_chance') then
    raise exception 'unknown reward kind';
  end if;

  perform public._ctx_check(p_context_type, p_context_id, p_question_id, v_uid);
  if public._ctx_completed(p_context_type, p_context_id, v_uid) then
    raise exception 'already completed today''s challenge';
  end if;
  if public._ctx_final(p_context_type, p_context_id, p_question_id, v_uid) is not null then
    raise exception 'question_answered';
  end if;

  if p_kind = 'hint' then
    -- A hint is for a question you haven't tried yet.
    if exists (select 1 from public.answer_attempts
                where user_id = v_uid and context_type = p_context_type
                  and context_id = p_context_id and question_id = p_question_id) then
      raise exception 'question_answered';
    end if;
  else
    -- A second chance is for a question you got wrong and haven't settled.
    if not exists (select 1 from public.answer_attempts
                    where user_id = v_uid and context_type = p_context_type
                      and context_id = p_context_id and question_id = p_question_id
                      and attempt_no = 1) then
      raise exception 'not_pending';
    end if;
  end if;

  -- Already have one for this question? Nothing more to do.
  if exists (select 1 from public.reward_grants
              where user_id = v_uid and kind = p_kind and context_type = p_context_type
                and context_id = p_context_id and question_id = p_question_id) then
    return jsonb_build_object('granted', true);
  end if;

  if (select count(*) from public.reward_grants
       where user_id = v_uid and kind = p_kind and source <> 'coins'
         and context_type = p_context_type and context_id = p_context_id) >= public.reward_limit(p_kind) then
    raise exception 'limit_reached';
  end if;

  insert into public.reward_grants (user_id, kind, context_type, context_id, question_id)
  values (v_uid, p_kind, p_context_type, p_context_id, p_question_id);

  return jsonb_build_object('granted', true);
end;
$$;

create or replace function public.get_help_state(
  p_context_type text, p_context_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_questions jsonb;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Only your own round / today's challenge.
  if p_context_type = 'practice' then
    if not exists (select 1 from public.practice_rounds
                    where id = p_context_id and user_id = v_uid) then
      raise exception 'round not found';
    end if;
  elsif p_context_type = 'daily' then
    if not exists (select 1 from public.daily_challenges where id = p_context_id) then
      raise exception 'challenge not found';
    end if;
  else
    raise exception 'unknown context type';
  end if;

  select coalesce(jsonb_object_agg(qid::text, info), '{}'::jsonb) into v_questions
  from (
    select q.qid,
           jsonb_build_object(
             'hint_wrong',    (select to_jsonb(h.wrong_options) from public.hint_uses h
                                where h.user_id = v_uid and h.context_type = p_context_type
                                  and h.context_id = p_context_id and h.question_id = q.qid),
             'hint_granted',  exists (select 1 from public.reward_grants g
                                where g.user_id = v_uid and g.kind = 'hint'
                                  and g.context_type = p_context_type and g.context_id = p_context_id
                                  and g.question_id = q.qid and g.consumed_at is null),
             'retry_granted', exists (select 1 from public.reward_grants g
                                where g.user_id = v_uid and g.kind = 'second_chance'
                                  and g.context_type = p_context_type and g.context_id = p_context_id
                                  and g.question_id = q.qid and g.consumed_at is null),
             -- first pick, only while the second-chance decision is still open
             'pending_first_choice',
               case when public._ctx_final(p_context_type, p_context_id, q.qid, v_uid) is null
                    then (select a.chosen from public.answer_attempts a
                           where a.user_id = v_uid and a.context_type = p_context_type
                             and a.context_id = p_context_id and a.question_id = q.qid
                             and a.attempt_no = 1)
               end
           ) as info
    from (
      select question_id as qid from public.practice_round_questions
       where p_context_type = 'practice' and round_id = p_context_id
      union all
      select question_id from public.daily_challenge_questions
       where p_context_type = 'daily' and daily_challenge_id = p_context_id
    ) q
  ) s;

  return jsonb_build_object(
    'hints_left',
      greatest(public.reward_limit('hint') - (select count(*) from public.reward_grants
        where user_id = v_uid and kind = 'hint' and source <> 'coins' and context_type = p_context_type
          and context_id = p_context_id), 0),
    'retries_left',
      greatest(public.reward_limit('second_chance') - (select count(*) from public.reward_grants
        where user_id = v_uid and kind = 'second_chance' and source <> 'coins' and context_type = p_context_type
          and context_id = p_context_id), 0),
    'questions', v_questions,
    'coins', (select coins from public.profiles where id = v_uid),
    'hint_price', public.hint_price()
  );
end;
$$;


-- ---------------------------------------------------------------------------
-- Who may call what.
-- ---------------------------------------------------------------------------
revoke execute on function public.create_competition(text, timestamptz, timestamptz, integer, integer, integer, integer, jsonb) from public, anon;
revoke execute on function public.admin_grant_coins(uuid, integer)        from public, anon;
revoke execute on function public.list_competitions()                     from public, anon;
revoke execute on function public.start_competition_entry(uuid)           from public, anon;
revoke execute on function public.competition_next_question(uuid)        from public, anon;
revoke execute on function public.competition_answer(uuid, uuid, text)   from public, anon;
revoke execute on function public.get_competition_results(uuid)          from public, anon;
revoke execute on function public.buy_hint(text, uuid, uuid)             from public, anon;
revoke execute on function public.hint_price()                           from public, anon;
revoke execute on function public.competition_grace_ms()                 from public, anon;

grant execute on function public.create_competition(text, timestamptz, timestamptz, integer, integer, integer, integer, jsonb) to authenticated;
grant execute on function public.admin_grant_coins(uuid, integer)        to authenticated;
grant execute on function public.list_competitions()                     to authenticated;
grant execute on function public.start_competition_entry(uuid)           to authenticated;
grant execute on function public.competition_next_question(uuid)        to authenticated;
grant execute on function public.competition_answer(uuid, uuid, text)   to authenticated;
grant execute on function public.get_competition_results(uuid)          to authenticated;
grant execute on function public.buy_hint(text, uuid, uuid)             to authenticated;
grant execute on function public.claim_reward(text, uuid, uuid, text)   to authenticated;
grant execute on function public.get_help_state(text, uuid)             to authenticated;

-- ---------------------------------------------------------------------------
-- OPTIONAL: settle on a timer too (results then appear even if nobody opens
-- the app). Needs the pg_cron extension (Dashboard -> Database -> Extensions):
--   select cron.schedule('settle-competitions', '*/5 * * * *',
--                        $$select public.settle_due_competitions()$$);
-- ---------------------------------------------------------------------------
