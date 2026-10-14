-- ============================================================================
-- 024_content_quality.sql
-- "Did you know?" facts, "Report this question", and an accuracy view.
-- Run after 022_level_difficulty_curve.sql. Safe to re-run.
-- ============================================================================

alter table public.questions add column if not exists did_you_know text;

create table if not exists public.question_reports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  kind        text not null default 'question' check (kind in ('question')),
  reason      text not null check (reason in ('wrong_answer','typo','unclear','outdated','offensive','other')),
  note        text check (note is null or char_length(note) <= 500),
  status      text not null default 'open' check (status in ('open','fixed','dismissed')),
  created_at  timestamptz not null default now(),
  unique (user_id, question_id, reason)
);
create index if not exists question_reports_open_idx on public.question_reports (status, created_at desc);
alter table public.question_reports enable row level security;
revoke all on public.question_reports from anon, authenticated;
-- No policies on purpose: written only by report_question(); read by admins in the dashboard.

create or replace function public.report_question(
  p_question_id uuid, p_reason text, p_note text default null, p_kind text default 'question'
) returns boolean
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  if p_reason not in ('wrong_answer','typo','unclear','outdated','offensive','other') then
    raise exception 'bad reason';
  end if;
  if not exists (select 1 from questions where id = p_question_id) then
    raise exception 'unknown question';
  end if;
  if (select count(*) from question_reports
       where user_id = uid and created_at > now() - interval '1 day') >= 20 then
    raise exception 'report limit reached';
  end if;
  insert into question_reports (user_id, question_id, reason, note)
  values (uid, p_question_id, p_reason, nullif(left(btrim(coalesce(p_note,'')), 500), ''))
  on conflict (user_id, question_id, reason) do nothing;
  return true;
end $$;

-- The fact is returned only to someone who has already answered that question
-- (Daily, Practice or Speed Quiz), so it can never leak an answer.
create or replace function public.get_question_fact(p_question_id uuid)
returns text
language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); ok boolean;
begin
  if uid is null then return null; end if;
  select exists (select 1 from daily_answers where user_id = uid and question_id = p_question_id)
      or exists (select 1 from practice_round_questions prq join practice_rounds pr on pr.id = prq.round_id
                  where pr.user_id = uid and prq.question_id = p_question_id and prq.chosen is not null)
      or exists (select 1 from speed_quiz_answers sa join speed_quiz_rounds sr on sr.id = sa.round_id
                  where sr.user_id = uid and sa.question_id = p_question_id)
    into ok;
  if not ok then return null; end if;
  return (select did_you_know from questions where id = p_question_id);
end $$;

-- Admin-only view (not exposed to the app): how often each question is answered correctly.
create or replace view public.question_accuracy as
select q.id as question_id, q.question_text, q.difficulty,
       count(a.*) as answers,
       round(100.0 * avg((a.is_correct)::int), 1) as pct_correct,
       (select count(*) from question_reports r where r.question_id = q.id and r.status = 'open') as open_reports
from questions q
left join (
  select question_id, is_correct from daily_answers
  union all select question_id, is_correct from practice_round_questions where chosen is not null
  union all select question_id, is_correct from speed_quiz_answers
) a on a.question_id = q.id
group by q.id;
revoke all on public.question_accuracy from anon, authenticated;

revoke all on function public.report_question(uuid, text, text, text) from public, anon;
revoke all on function public.get_question_fact(uuid) from public, anon;
grant execute on function public.report_question(uuid, text, text, text) to authenticated;
grant execute on function public.get_question_fact(uuid) to authenticated;
