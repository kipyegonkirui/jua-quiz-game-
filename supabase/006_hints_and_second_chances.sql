-- ============================================================================
-- 006_hints_and_second_chances.sql
--
-- Rewarded-video features, enforced on the server:
--
--   HINT          Watch a video -> two WRONG options are hidden for that
--                 question. Max 2 hints per round/challenge, 1 per question.
--                 Not available on a question that has already been tried.
--
--   SECOND CHANCE After a FIRST WRONG pick the server does NOT reveal the right
--                 answer. The player may watch a video to try once more, or
--                 decline and see the answer. One second chance per
--                 round/challenge. A hinted question gets no second chance
--                 (with 2 options left a retry would be a free win).
--
-- Skipping the video buys nothing: if the player answers again without having
-- been granted the retry, the server just locks their FIRST pick.
--
-- HONEST LIMITATION: "the player watched a video" is reported by the app. A
-- modified app could claim it without watching. The damage is capped by the
-- limits above (2 hints + 1 retry per round). Real verification of ad
-- completion (AdMob server-side verification) is planned for when coins can
-- be earned, because that is when it starts to matter.
--
-- RUN ORDER: 003 -> 004 -> 005 -> this file. Run once (safe to re-run).
-- This REPLACES the four per-mode answer/progress functions from 005 with
-- single versions that take a 'daily' / 'practice' scope.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Per-question state that exists BEFORE an answer is final.
-- ----------------------------------------------------------------------------
create table if not exists public.question_assists (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  scope         text not null check (scope in ('daily', 'practice')),
  scope_id      uuid not null,               -- daily_challenges.id or practice_rounds.id
  question_id   uuid not null references public.questions(id) on delete cascade,
  hint_hidden   text[],                      -- the two wrong letters a hint removed
  first_wrong   text check (first_wrong in ('a','b','c','d')),
  retry_granted boolean not null default false,
  created_at    timestamptz not null default now(),
  primary key (user_id, scope, scope_id, question_id)
);

alter table public.question_assists enable row level security;
revoke all on public.question_assists from anon, authenticated;
-- No policies on purpose: only the functions below touch this table.

drop function if exists public.answer_practice_question(uuid, uuid, text);
drop function if exists public.answer_daily_question(uuid, uuid, text);
drop function if exists public.get_practice_progress(uuid);
drop function if exists public.get_daily_progress(uuid);


-- ============================================================================
-- Internal helpers (NOT callable from the app)
-- ============================================================================

-- Confirms the caller owns this round / it's today's challenge, and that the
-- question belongs to it.
create or replace function public._assist_validate(
  p_uid uuid, p_scope text, p_scope_id uuid, p_question_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_scope = 'practice' then
    perform 1 from public.practice_rounds
     where id = p_scope_id and user_id = p_uid and status = 'open'
     for update;
    if not found then
      raise exception 'round not found or already submitted';
    end if;
    if not exists (
      select 1 from public.practice_round_questions
      where round_id = p_scope_id and question_id = p_question_id
    ) then
      raise exception 'question is not part of this round';
    end if;

  elsif p_scope = 'daily' then
    if not exists (
      select 1 from public.daily_challenges
      where id = p_scope_id and challenge_date = public.nairobi_today()
    ) then
      raise exception 'this is not today''s challenge';
    end if;
    if not exists (
      select 1 from public.daily_challenge_questions
      where daily_challenge_id = p_scope_id and question_id = p_question_id
    ) then
      raise exception 'question is not part of this challenge';
    end if;

  else
    raise exception 'bad scope';
  end if;
end;
$$;

-- The locked answer for a question, or null if it isn't final yet.
create or replace function public._assist_final(
  p_uid uuid, p_scope text, p_scope_id uuid, p_question_id uuid
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v text;
begin
  if p_scope = 'practice' then
    select chosen into v from public.practice_round_questions
     where round_id = p_scope_id and question_id = p_question_id;
  else
    select chosen into v from public.daily_answers
     where user_id = p_uid and daily_challenge_id = p_scope_id and question_id = p_question_id;
  end if;
  return v;
end;
$$;

-- Writes the final answer (first write wins).
create or replace function public._assist_lock(
  p_uid uuid, p_scope text, p_scope_id uuid, p_question_id uuid, p_choice text, p_correct text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_scope = 'practice' then
    update public.practice_round_questions
       set chosen = p_choice, is_correct = (p_choice = p_correct), answered_at = now()
     where round_id = p_scope_id and question_id = p_question_id and chosen is null;
  else
    insert into public.daily_answers (user_id, daily_challenge_id, question_id, chosen, is_correct)
    values (p_uid, p_scope_id, p_question_id, p_choice, p_choice = p_correct)
    on conflict do nothing;
  end if;
end;
$$;

-- A finished daily challenge accepts no more changes.
create or replace function public._assist_ensure_open(p_uid uuid, p_scope text, p_scope_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_scope = 'daily' and exists (
    select 1 from public.attempts where user_id = p_uid and daily_challenge_id = p_scope_id
  ) then
    raise exception 'already completed today''s challenge';
  end if;
end;
$$;

create or replace function public._assist_final_result(p_chosen text, p_correct text)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'final', true,
    'chosen', p_chosen,
    'correct_option', p_correct,
    'is_correct', p_chosen = p_correct,
    'retry_available', false
  );
$$;

revoke execute on function public._assist_validate(uuid, text, uuid, uuid) from public, anon, authenticated;
revoke execute on function public._assist_final(uuid, text, uuid, uuid) from public, anon, authenticated;
revoke execute on function public._assist_lock(uuid, text, uuid, uuid, text, text) from public, anon, authenticated;
revoke execute on function public._assist_ensure_open(uuid, text, uuid) from public, anon, authenticated;
revoke execute on function public._assist_final_result(text, text) from public, anon, authenticated;


-- ============================================================================
-- Functions the app calls.  p_scope is 'daily' or 'practice'.
-- ============================================================================

-- Check an answer.
--   final = true   -> answer locked; correct_option revealed.
--   final = false  -> WRONG first try with a second chance on offer; the right
--                     answer is NOT revealed yet.
create or replace function public.answer_question(
  p_scope text, p_scope_id uuid, p_question_id uuid, p_choice text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_choice  text := lower(coalesce(p_choice, ''));
  v_final   text;
  v_correct text;
  a         public.question_assists%rowtype;
  v_has_row boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if v_choice not in ('a','b','c','d') then
    raise exception 'invalid choice';
  end if;

  perform public._assist_validate(v_uid, p_scope, p_scope_id, p_question_id);
  perform pg_advisory_xact_lock(hashtext(v_uid::text || p_scope_id::text || p_question_id::text));

  select correct_option into v_correct from public.questions where id = p_question_id;

  -- Already answered: return the locked result, whatever was sent this time.
  v_final := public._assist_final(v_uid, p_scope, p_scope_id, p_question_id);
  if v_final is not null then
    return public._assist_final_result(v_final, v_correct);
  end if;

  perform public._assist_ensure_open(v_uid, p_scope, p_scope_id);

  select * into a from public.question_assists
   where user_id = v_uid and scope = p_scope and scope_id = p_scope_id and question_id = p_question_id;
  v_has_row := found;

  -- Second attempt after a wrong first pick.
  if v_has_row and a.first_wrong is not null then
    if a.retry_granted then
      v_final := v_choice;        -- the granted retry: this pick is final
    else
      v_final := a.first_wrong;   -- no video, no retry: the FIRST pick stands
    end if;
    perform public._assist_lock(v_uid, p_scope, p_scope_id, p_question_id, v_final, v_correct);
    return public._assist_final_result(v_final, v_correct);
  end if;

  -- First attempt, correct.
  if v_choice = v_correct then
    perform public._assist_lock(v_uid, p_scope, p_scope_id, p_question_id, v_choice, v_correct);
    return public._assist_final_result(v_choice, v_correct);
  end if;

  -- First attempt, wrong. No retry if a hint was used or the one retry is spent.
  if (v_has_row and a.hint_hidden is not null)
     or exists (
       select 1 from public.question_assists
       where user_id = v_uid and scope = p_scope and scope_id = p_scope_id and retry_granted
     )
  then
    perform public._assist_lock(v_uid, p_scope, p_scope_id, p_question_id, v_choice, v_correct);
    return public._assist_final_result(v_choice, v_correct);
  end if;

  -- Offer the second chance: remember the wrong pick, reveal nothing.
  insert into public.question_assists (user_id, scope, scope_id, question_id, first_wrong)
  values (v_uid, p_scope, p_scope_id, p_question_id, v_choice)
  on conflict (user_id, scope, scope_id, question_id)
  do update set first_wrong = excluded.first_wrong;

  return jsonb_build_object(
    'final', false,
    'chosen', v_choice,
    'correct_option', null,
    'is_correct', false,
    'retry_available', true
  );
end;
$$;


-- Hint: hides two wrong options. Idempotent per question.
create or replace function public.use_hint(p_scope text, p_scope_id uuid, p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid       uuid := auth.uid();
  v_max_hints constant integer := 2;   -- keep in step with AppConfig.maxHintsPerRound
  v_correct   text;
  v_hidden    text[];
  a           public.question_assists%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public._assist_validate(v_uid, p_scope, p_scope_id, p_question_id);
  perform pg_advisory_xact_lock(hashtext(v_uid::text || p_scope_id::text || p_question_id::text));

  if public._assist_final(v_uid, p_scope, p_scope_id, p_question_id) is not null then
    raise exception 'question already answered';
  end if;
  perform public._assist_ensure_open(v_uid, p_scope, p_scope_id);

  select * into a from public.question_assists
   where user_id = v_uid and scope = p_scope and scope_id = p_scope_id and question_id = p_question_id;

  if found then
    if a.first_wrong is not null then
      raise exception 'no hint after a wrong try';
    end if;
    if a.hint_hidden is not null then
      return jsonb_build_object('hidden', to_jsonb(a.hint_hidden));   -- same hint again
    end if;
  end if;

  if (select count(*) from public.question_assists
       where user_id = v_uid and scope = p_scope and scope_id = p_scope_id
         and hint_hidden is not null) >= v_max_hints then
    raise exception 'no hints left';
  end if;

  select correct_option into v_correct from public.questions where id = p_question_id;

  select array_agg(l) into v_hidden
  from (
    select l from unnest(array['a','b','c','d']) as l
    where l <> v_correct
    order by random()
    limit 2
  ) s;

  insert into public.question_assists (user_id, scope, scope_id, question_id, hint_hidden)
  values (v_uid, p_scope, p_scope_id, p_question_id, v_hidden)
  on conflict (user_id, scope, scope_id, question_id)
  do update set hint_hidden = excluded.hint_hidden;

  return jsonb_build_object('hidden', to_jsonb(v_hidden));
end;
$$;


-- Called AFTER the player has watched the video: allows the retry.
create or replace function public.grant_second_chance(p_scope text, p_scope_id uuid, p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  a     public.question_assists%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public._assist_validate(v_uid, p_scope, p_scope_id, p_question_id);
  perform pg_advisory_xact_lock(hashtext(v_uid::text || p_scope_id::text || p_question_id::text));

  if public._assist_final(v_uid, p_scope, p_scope_id, p_question_id) is not null then
    raise exception 'question already answered';
  end if;
  perform public._assist_ensure_open(v_uid, p_scope, p_scope_id);

  select * into a from public.question_assists
   where user_id = v_uid and scope = p_scope and scope_id = p_scope_id and question_id = p_question_id;

  if not found or a.first_wrong is null then
    raise exception 'no second chance to grant';
  end if;

  if a.retry_granted then
    return jsonb_build_object('first_wrong', a.first_wrong);   -- already granted
  end if;

  if exists (
    select 1 from public.question_assists
    where user_id = v_uid and scope = p_scope and scope_id = p_scope_id and retry_granted
  ) then
    raise exception 'second chance already used';
  end if;

  update public.question_assists set retry_granted = true
   where user_id = v_uid and scope = p_scope and scope_id = p_scope_id and question_id = p_question_id;

  return jsonb_build_object('first_wrong', a.first_wrong);
end;
$$;


-- "No thanks": locks the first (wrong) pick and reveals the answer.
create or replace function public.decline_second_chance(p_scope text, p_scope_id uuid, p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_correct text;
  v_final   text;
  a         public.question_assists%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public._assist_validate(v_uid, p_scope, p_scope_id, p_question_id);
  perform pg_advisory_xact_lock(hashtext(v_uid::text || p_scope_id::text || p_question_id::text));

  select correct_option into v_correct from public.questions where id = p_question_id;

  v_final := public._assist_final(v_uid, p_scope, p_scope_id, p_question_id);
  if v_final is not null then
    return public._assist_final_result(v_final, v_correct);
  end if;
  perform public._assist_ensure_open(v_uid, p_scope, p_scope_id);

  select * into a from public.question_assists
   where user_id = v_uid and scope = p_scope and scope_id = p_scope_id and question_id = p_question_id;

  if not found or a.first_wrong is null or a.retry_granted then
    raise exception 'nothing to decline';
  end if;

  perform public._assist_lock(v_uid, p_scope, p_scope_id, p_question_id, a.first_wrong, v_correct);
  return public._assist_final_result(a.first_wrong, v_correct);
end;
$$;


-- Everything the player has done so far — for resuming after the app closes.
-- correct_option is only filled in for questions that are already FINAL.
create or replace function public.get_progress(p_scope text, p_scope_id uuid)
returns table (
  question_id   uuid,
  chosen        text,
  correct_option text,
  first_wrong   text,
  retry_granted boolean,
  hint_hidden   text[]
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
#variable_conflict use_column
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_scope = 'practice' then
    return query
    select prq.question_id,
           prq.chosen,
           case when prq.chosen is not null then q.correct_option end,
           a.first_wrong,
           coalesce(a.retry_granted, false),
           a.hint_hidden
    from public.practice_round_questions prq
    join public.practice_rounds pr
      on pr.id = prq.round_id and pr.user_id = auth.uid() and pr.status = 'open'
    join public.questions q on q.id = prq.question_id
    left join public.question_assists a
      on a.user_id = auth.uid() and a.scope = 'practice'
     and a.scope_id = prq.round_id and a.question_id = prq.question_id
    where prq.round_id = p_scope_id
      and (prq.chosen is not null or a.question_id is not null);

  elsif p_scope = 'daily' then
    return query
    select dcq.question_id,
           da.chosen,
           case when da.chosen is not null then q.correct_option end,
           a.first_wrong,
           coalesce(a.retry_granted, false),
           a.hint_hidden
    from public.daily_challenge_questions dcq
    join public.questions q on q.id = dcq.question_id
    left join public.daily_answers da
      on da.user_id = auth.uid() and da.daily_challenge_id = dcq.daily_challenge_id
     and da.question_id = dcq.question_id
    left join public.question_assists a
      on a.user_id = auth.uid() and a.scope = 'daily'
     and a.scope_id = dcq.daily_challenge_id and a.question_id = dcq.question_id
    where dcq.daily_challenge_id = p_scope_id
      and (da.question_id is not null or a.question_id is not null);

  else
    raise exception 'bad scope';
  end if;
end;
$$;


-- ----------------------------------------------------------------------------
-- Who may call what.
-- ----------------------------------------------------------------------------
revoke execute on function public.answer_question(text, uuid, uuid, text) from public, anon;
revoke execute on function public.use_hint(text, uuid, uuid) from public, anon;
revoke execute on function public.grant_second_chance(text, uuid, uuid) from public, anon;
revoke execute on function public.decline_second_chance(text, uuid, uuid) from public, anon;
revoke execute on function public.get_progress(text, uuid) from public, anon;

grant execute on function public.answer_question(text, uuid, uuid, text) to authenticated;
grant execute on function public.use_hint(text, uuid, uuid) to authenticated;
grant execute on function public.grant_second_chance(text, uuid, uuid) to authenticated;
grant execute on function public.decline_second_chance(text, uuid, uuid) to authenticated;
grant execute on function public.get_progress(text, uuid) to authenticated;
