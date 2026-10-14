-- ============================================================================
-- 006_rewarded_hints_second_chance.sql   (Phase 4)
--
-- RUN ORDER: 003 -> 004 -> 005 -> this file.  Safe to run more than once.
--
-- What it adds
--   * HINT         use_hint() hides two WRONG options. It never returns, and
--                  the app never receives, the correct answer. Recorded.
--   * SECOND CHANCE  a wrong first answer is no longer revealed straight away.
--                  The player may watch a rewarded video and pick again — ONCE
--                  per question. Every attempt is recorded individually.
--   * REWARD GRANTS  one row = "this player earned a hint / second chance for
--                  this question". The server checks for the grant; the phone
--                  can't just say "I'm allowed".
--
-- What does NOT change: submit_daily_attempt() and submit_practice_round()
-- still score the final recorded answer per question, so XP and streak rules
-- are exactly as before. A question that is still waiting on a second-chance
-- decision when the round is submitted simply counts as wrong.
--
-- Tunable numbers: see reward_limit() just below.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- Tunables (edit and re-run this file)
-- ---------------------------------------------------------------------------
create or replace function public.reward_limit(p_kind text)
returns integer
language sql
immutable
as $$
  select case p_kind
           when 'hint'          then 2   -- hints per round / per daily challenge
           when 'second_chance' then 2   -- second chances per round / per daily challenge
         end;
$$;


-- ---------------------------------------------------------------------------
-- Tables. No policies on purpose: only the functions below touch them.
-- ---------------------------------------------------------------------------

-- Every individual answer attempt (1 = first pick, 2 = the second chance).
create table if not exists public.answer_attempts (
  user_id      uuid not null references public.profiles(id) on delete cascade,
  context_type text not null check (context_type in ('daily', 'practice')),
  context_id   uuid not null,          -- daily_challenges.id or practice_rounds.id
  question_id  uuid not null references public.questions(id) on delete cascade,
  attempt_no   smallint not null check (attempt_no in (1, 2)),
  chosen       text not null check (chosen in ('a', 'b', 'c', 'd')),
  is_correct   boolean not null,
  created_at   timestamptz not null default now(),
  primary key (user_id, context_type, context_id, question_id, attempt_no)
);

-- "The player earned a hint / second chance for this question."
-- The UNIQUE key is what enforces "one hint and one retry per question".
-- source = 'client' today (the app reports the finished video);
-- source = 'ssv' is reserved for AdMob server-side verification (Phase 7).
create table if not exists public.reward_grants (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  kind         text not null check (kind in ('hint', 'second_chance')),
  context_type text not null check (context_type in ('daily', 'practice')),
  context_id   uuid not null,
  question_id  uuid not null references public.questions(id) on delete cascade,
  source       text not null default 'client' check (source in ('client', 'ssv')),
  created_at   timestamptz not null default now(),
  consumed_at  timestamptz,
  unique (user_id, kind, context_type, context_id, question_id)
);

-- Every hint given: who, which question, which round, when, what was hidden.
create table if not exists public.hint_uses (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  context_type  text not null check (context_type in ('daily', 'practice')),
  context_id    uuid not null,
  question_id   uuid not null references public.questions(id) on delete cascade,
  wrong_options text[] not null,
  created_at    timestamptz not null default now(),
  primary key (user_id, context_type, context_id, question_id)
);

alter table public.answer_attempts enable row level security;
alter table public.reward_grants   enable row level security;
alter table public.hint_uses       enable row level security;
revoke all on public.answer_attempts from anon, authenticated;
revoke all on public.reward_grants   from anon, authenticated;
revoke all on public.hint_uses       from anon, authenticated;


-- ===========================================================================
-- Internal helpers (not callable from the app)
-- ===========================================================================

-- Is this a valid, still-playable round / today's challenge for this player,
-- and is the question part of it? Also takes a row lock so two quick taps on
-- the same player's round can't race each other.
create or replace function public._ctx_check(
  p_type text, p_ctx uuid, p_q uuid, p_uid uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_type = 'practice' then
    perform 1 from public.practice_rounds
     where id = p_ctx and user_id = p_uid and status = 'open'
     for update;
    if not found then
      raise exception 'round not found or already submitted';
    end if;
    perform 1 from public.practice_round_questions
     where round_id = p_ctx and question_id = p_q;
    if not found then
      raise exception 'question is not part of this round';
    end if;
  elsif p_type = 'daily' then
    perform 1 from public.profiles where id = p_uid for update;
    if not exists (
      select 1 from public.daily_challenges
       where id = p_ctx and challenge_date = public.nairobi_today()
    ) then
      raise exception 'this is not today''s challenge';
    end if;
    if not exists (
      select 1 from public.daily_challenge_questions
       where daily_challenge_id = p_ctx and question_id = p_q
    ) then
      raise exception 'question is not part of this challenge';
    end if;
  else
    raise exception 'unknown context type';
  end if;
end;
$$;

-- Has this player already submitted today's challenge? (Practice rounds check
-- "still open" inside _ctx_check instead.)
create or replace function public._ctx_completed(p_type text, p_ctx uuid, p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p_type = 'daily'
     and exists (select 1 from public.attempts
                  where user_id = p_uid and daily_challenge_id = p_ctx);
$$;

-- The FINAL locked answer for a question (null while unanswered / pending).
create or replace function public._ctx_final(p_type text, p_ctx uuid, p_q uuid, p_uid uuid)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case when p_type = 'practice' then
           (select prq.chosen from public.practice_round_questions prq
             where prq.round_id = p_ctx and prq.question_id = p_q)
         else
           (select da.chosen from public.daily_answers da
             where da.user_id = p_uid and da.daily_challenge_id = p_ctx and da.question_id = p_q)
         end;
$$;

-- Lock in the final answer. This is the row the submit functions score from.
create or replace function public._ctx_finalize(
  p_type text, p_ctx uuid, p_q uuid, p_uid uuid, p_chosen text, p_correct boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_type = 'practice' then
    update public.practice_round_questions
       set chosen = p_chosen, is_correct = p_correct, answered_at = now()
     where round_id = p_ctx and question_id = p_q and chosen is null;
  else
    insert into public.daily_answers (user_id, daily_challenge_id, question_id, chosen, is_correct)
    values (p_uid, p_ctx, p_q, p_chosen, p_correct)
    on conflict do nothing;
  end if;
end;
$$;

-- One JSON shape for every answer-related response.
--   status = 'final'         the answer is locked; correct_option is revealed
--   status = 'retry_offered' first pick was wrong; correct_option is NULL
create or replace function public._answer_json(
  p_type text, p_ctx uuid, p_q uuid, p_uid uuid, p_status text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_first     text;
  v_second    text;
  v_final     text;
  v_correct   text;
  v_granted   boolean;
begin
  select chosen into v_first  from public.answer_attempts
   where user_id = p_uid and context_type = p_type and context_id = p_ctx
     and question_id = p_q and attempt_no = 1;
  select chosen into v_second from public.answer_attempts
   where user_id = p_uid and context_type = p_type and context_id = p_ctx
     and question_id = p_q and attempt_no = 2;
  v_final := public._ctx_final(p_type, p_ctx, p_q, p_uid);
  select correct_option into v_correct from public.questions where id = p_q;
  select exists (select 1 from public.reward_grants
                  where user_id = p_uid and kind = 'second_chance' and context_type = p_type
                    and context_id = p_ctx and question_id = p_q and consumed_at is null)
    into v_granted;

  if p_status = 'final' then
    return jsonb_build_object(
      'status', 'final',
      'chosen', v_final,
      'correct_option', v_correct,
      'is_correct', v_final = v_correct,
      'first_choice', v_first,
      'second_chance_used', v_second is not null,
      'retry_granted', false
    );
  end if;

  return jsonb_build_object(
    'status', 'retry_offered',
    'chosen', v_first,
    'correct_option', null,
    'is_correct', false,
    'first_choice', v_first,
    'second_chance_used', false,
    'retry_granted', v_granted
  );
end;
$$;

revoke all on function public._ctx_check(text, uuid, uuid, uuid)              from public, anon, authenticated;
revoke all on function public._ctx_completed(text, uuid, uuid)                from public, anon, authenticated;
revoke all on function public._ctx_final(text, uuid, uuid, uuid)              from public, anon, authenticated;
revoke all on function public._ctx_finalize(text, uuid, uuid, uuid, text, boolean) from public, anon, authenticated;
revoke all on function public._answer_json(text, uuid, uuid, uuid, text)      from public, anon, authenticated;


-- ===========================================================================
-- Answering: attempt 1, and attempt 2 (the second chance)
-- ===========================================================================
create or replace function public._answer_question(
  p_type text, p_ctx uuid, p_q uuid, p_choice text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_choice  text := lower(coalesce(p_choice, ''));
  v_correct text;
  v_first   text;
  v_grant   uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if v_choice not in ('a', 'b', 'c', 'd') then
    raise exception 'invalid choice';
  end if;

  perform public._ctx_check(p_type, p_ctx, p_q, v_uid);

  -- Already locked? Return the locked result, whatever was sent this time.
  if public._ctx_final(p_type, p_ctx, p_q, v_uid) is not null then
    return public._answer_json(p_type, p_ctx, p_q, v_uid, 'final');
  end if;

  if public._ctx_completed(p_type, p_ctx, v_uid) then
    raise exception 'already completed today''s challenge';
  end if;

  select correct_option into v_correct from public.questions where id = p_q;

  select chosen into v_first from public.answer_attempts
   where user_id = v_uid and context_type = p_type and context_id = p_ctx
     and question_id = p_q and attempt_no = 1;

  -- ---- Attempt 1 ---------------------------------------------------------
  if v_first is null then
    insert into public.answer_attempts
      (user_id, context_type, context_id, question_id, attempt_no, chosen, is_correct)
    values (v_uid, p_type, p_ctx, p_q, 1, v_choice, v_choice = v_correct);

    if v_choice = v_correct then
      perform public._ctx_finalize(p_type, p_ctx, p_q, v_uid, v_choice, true);
      return public._answer_json(p_type, p_ctx, p_q, v_uid, 'final');
    end if;

    -- Wrong. Offer a second chance only while this round still has some left;
    -- otherwise it is final right now (the answer is revealed, as before).
    if (select count(*) from public.reward_grants
         where user_id = v_uid and kind = 'second_chance'
           and context_type = p_type and context_id = p_ctx) < public.reward_limit('second_chance') then
      return public._answer_json(p_type, p_ctx, p_q, v_uid, 'retry_offered');
    end if;

    perform public._ctx_finalize(p_type, p_ctx, p_q, v_uid, v_choice, false);
    return public._answer_json(p_type, p_ctx, p_q, v_uid, 'final');
  end if;

  -- ---- Attempt 2 (second chance) -----------------------------------------
  -- Needs a video reward that hasn't been used yet. Without one, nothing is
  -- recorded or revealed: the player is just told the offer is still open.
  select id into v_grant from public.reward_grants
   where user_id = v_uid and kind = 'second_chance' and context_type = p_type
     and context_id = p_ctx and question_id = p_q and consumed_at is null
   for update;
  if v_grant is null then
    return public._answer_json(p_type, p_ctx, p_q, v_uid, 'retry_offered');
  end if;

  if v_choice = v_first then
    raise exception 'pick a different option';
  end if;

  update public.reward_grants set consumed_at = now() where id = v_grant;

  insert into public.answer_attempts
    (user_id, context_type, context_id, question_id, attempt_no, chosen, is_correct)
  values (v_uid, p_type, p_ctx, p_q, 2, v_choice, v_choice = v_correct);

  perform public._ctx_finalize(p_type, p_ctx, p_q, v_uid, v_choice, v_choice = v_correct);
  return public._answer_json(p_type, p_ctx, p_q, v_uid, 'final');
end;
$$;
revoke all on function public._answer_question(text, uuid, uuid, text) from public, anon, authenticated;

-- Same names and arguments the app already calls.
create or replace function public.answer_practice_question(
  p_round_id uuid, p_question_id uuid, p_choice text
)
returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $$
  select public._answer_question('practice', p_round_id, p_question_id, p_choice);
$$;

create or replace function public.answer_daily_question(
  p_challenge_id uuid, p_question_id uuid, p_choice text
)
returns jsonb
language sql
security definer
set search_path = public, pg_temp
as $$
  select public._answer_question('daily', p_challenge_id, p_question_id, p_choice);
$$;


-- ===========================================================================
-- Rewards: claim_reward, use_hint, decline_second_chance, get_help_state
-- ===========================================================================

-- The app calls this after a rewarded video finishes. One grant per kind per
-- question (the table's UNIQUE key), capped per round by reward_limit().
-- Asking again for something already granted just says "granted".
--
-- HONEST LIMIT: today the server trusts the phone's "the video finished".
-- That is bounded (see the caps above, and nothing here ever reveals the
-- answer), and Phase 7 can make it airtight with AdMob server-side
-- verification: an Edge Function would insert these rows (source = 'ssv')
-- and this function would stop being callable by the app.
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
       where user_id = v_uid and kind = p_kind
         and context_type = p_context_type and context_id = p_context_id) >= public.reward_limit(p_kind) then
    raise exception 'limit_reached';
  end if;

  insert into public.reward_grants (user_id, kind, context_type, context_id, question_id)
  values (v_uid, p_kind, p_context_type, p_context_id, p_question_id);

  return jsonb_build_object('granted', true);
end;
$$;

-- Hides two WRONG options. Same answer if asked again (so it can't be re-rolled
-- to eliminate everything), and it never touches the correct option.
create or replace function public.use_hint(
  p_context_type text, p_context_id uuid, p_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_wrong   text[];
  v_grant   uuid;
  v_correct text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public._ctx_check(p_context_type, p_context_id, p_question_id, v_uid);
  if public._ctx_completed(p_context_type, p_context_id, v_uid) then
    raise exception 'already completed today''s challenge';
  end if;

  -- Already given for this question: same two options again.
  select wrong_options into v_wrong from public.hint_uses
   where user_id = v_uid and context_type = p_context_type
     and context_id = p_context_id and question_id = p_question_id;
  if v_wrong is not null then
    return jsonb_build_object('wrong_option_ids', to_jsonb(v_wrong));
  end if;

  if public._ctx_final(p_context_type, p_context_id, p_question_id, v_uid) is not null
     or exists (select 1 from public.answer_attempts
                 where user_id = v_uid and context_type = p_context_type
                   and context_id = p_context_id and question_id = p_question_id) then
    raise exception 'question_answered';
  end if;

  select id into v_grant from public.reward_grants
   where user_id = v_uid and kind = 'hint' and context_type = p_context_type
     and context_id = p_context_id and question_id = p_question_id and consumed_at is null
   for update;
  if v_grant is null then
    raise exception 'reward_required';
  end if;

  select correct_option into v_correct from public.questions where id = p_question_id;

  select array_agg(l) into v_wrong
  from (
    select l from unnest(array['a', 'b', 'c', 'd']) as l
     where l <> v_correct
     order by random()
     limit 2
  ) picked;

  update public.reward_grants set consumed_at = now() where id = v_grant;

  insert into public.hint_uses (user_id, context_type, context_id, question_id, wrong_options)
  values (v_uid, p_context_type, p_context_id, p_question_id, v_wrong);

  return jsonb_build_object('wrong_option_ids', to_jsonb(v_wrong));
end;
$$;

-- "No thanks" on the second-chance offer: lock the wrong answer and reveal
-- the right one, exactly like a wrong answer did before Phase 4.
create or replace function public.decline_second_chance(
  p_context_type text, p_context_id uuid, p_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid   uuid := auth.uid();
  v_first text;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public._ctx_check(p_context_type, p_context_id, p_question_id, v_uid);

  -- Already settled? Just return the settled result (idempotent).
  if public._ctx_final(p_context_type, p_context_id, p_question_id, v_uid) is not null then
    return public._answer_json(p_context_type, p_context_id, p_question_id, v_uid, 'final');
  end if;
  if public._ctx_completed(p_context_type, p_context_id, v_uid) then
    raise exception 'already completed today''s challenge';
  end if;

  select chosen into v_first from public.answer_attempts
   where user_id = v_uid and context_type = p_context_type and context_id = p_context_id
     and question_id = p_question_id and attempt_no = 1;
  if v_first is null then
    raise exception 'not_pending';
  end if;

  perform public._ctx_finalize(p_context_type, p_context_id, p_question_id, v_uid, v_first, false);
  return public._answer_json(p_context_type, p_context_id, p_question_id, v_uid, 'final');
end;
$$;

-- Everything the app needs to redraw hints / pending retries after a restart.
-- Never contains the correct answer.
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
        where user_id = v_uid and kind = 'hint' and context_type = p_context_type
          and context_id = p_context_id), 0),
    'retries_left',
      greatest(public.reward_limit('second_chance') - (select count(*) from public.reward_grants
        where user_id = v_uid and kind = 'second_chance' and context_type = p_context_type
          and context_id = p_context_id), 0),
    'questions', v_questions
  );
end;
$$;


-- ---------------------------------------------------------------------------
-- Who may call what.
-- ---------------------------------------------------------------------------
revoke execute on function public.answer_practice_question(uuid, uuid, text) from public, anon;
revoke execute on function public.answer_daily_question(uuid, uuid, text)    from public, anon;
revoke execute on function public.claim_reward(text, uuid, uuid, text)       from public, anon;
revoke execute on function public.use_hint(text, uuid, uuid)                 from public, anon;
revoke execute on function public.decline_second_chance(text, uuid, uuid)    from public, anon;
revoke execute on function public.get_help_state(text, uuid)                 from public, anon;
revoke execute on function public.reward_limit(text)                         from public, anon;

grant execute on function public.answer_practice_question(uuid, uuid, text) to authenticated;
grant execute on function public.answer_daily_question(uuid, uuid, text)    to authenticated;
grant execute on function public.claim_reward(text, uuid, uuid, text)       to authenticated;
grant execute on function public.use_hint(text, uuid, uuid)                 to authenticated;
grant execute on function public.decline_second_chance(text, uuid, uuid)    to authenticated;
grant execute on function public.get_help_state(text, uuid)                 to authenticated;
