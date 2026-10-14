-- Jua Quiz Phase 1 production smoke-check
-- READ ONLY. Run this in Supabase SQL Editor after applying migrations.

-- 1) Required tables/views
select object_name,
       case when to_regclass(object_name) is not null then 'OK' else 'MISSING' end as status
from (values
  ('public.profiles'),
  ('public.categories'),
  ('public.questions'),
  ('public.daily_challenges'),
  ('public.daily_challenge_questions'),
  ('public.attempts'),
  ('public.daily_answers'),
  ('public.practice_rounds'),
  ('public.practice_round_questions'),
  ('public.coin_ledger'),
  ('public.competitions'),
  ('public.competition_questions'),
  ('public.competition_entries'),
  ('public.competition_answers'),
  ('public.speed_quiz_rounds'),
  ('public.speed_quiz_answers'),
  ('public.leaderboard')
) as required(object_name);

-- 2) Required RPC signatures. This catches stale two-argument versions and
--    confirms the final client-facing functions are the one-argument versions.
select n.nspname as schema_name,
       p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_or_create_today_challenge',
    'get_challenge_questions',
    'answer_daily_question',
    'get_daily_progress',
    'submit_daily_attempt',
    'answer_practice_question',
    'get_practice_progress',
    'submit_practice_round',
    'hint_price',
    'buy_hint',
    'claim_reward',
    'list_competitions',
    'start_competition_entry',
    'competition_next_question',
    'competition_answer',
    'get_competition_results',
    'start_speed_quiz_round',
    'get_speed_quiz_questions',
    'get_speed_quiz_state',
    'get_speed_quiz_progress',
    'answer_speed_quiz_question',
    'submit_speed_quiz_round',
    'submit_practice_round'
  )
order by p.proname, arguments;

-- 3) Stale two-argument submission functions should not remain.
select case when not exists (
  select 1 from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname='public'
    and p.proname='submit_daily_attempt'
    and pg_get_function_identity_arguments(p.oid)='p_challenge_id uuid, p_answers jsonb'
) then 'OK' else 'STALE_FUNCTION_PRESENT' end as stale_daily_submission,
case when not exists (
  select 1 from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname='public'
    and p.proname='submit_practice_round'
    and pg_get_function_identity_arguments(p.oid)='p_round_id uuid, p_answers jsonb'
) then 'OK' else 'STALE_FUNCTION_PRESENT' end as stale_practice_submission;

-- 4) Content counts
select 'categories' as item, count(*)::bigint as count from public.categories
union all select 'questions', count(*) from public.questions
union all select 'daily challenges', count(*) from public.daily_challenges
union all select 'daily challenge questions', count(*) from public.daily_challenge_questions
union all select 'profiles', count(*) from public.profiles;

-- 5) Duplicate question text check
select lower(trim(question_text)) as normalized_question,
       count(*) as duplicates
from public.questions
where question_text is not null
  and trim(question_text) <> ''
group by lower(trim(question_text))
having count(*) > 1
order by duplicates desc, normalized_question;

-- 6) Nairobi-day sanity check
select now() as database_time_utc,
       now() at time zone 'Africa/Nairobi' as database_time_nairobi,
       (now() at time zone 'Africa/Nairobi')::date as nairobi_date;

-- 7) Final migration objects should expose one-argument submission functions.
select case when exists (
  select 1 from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname='public'
    and p.proname='submit_daily_attempt'
    and pg_get_function_identity_arguments(p.oid)='p_challenge_id uuid'
) then 'OK' else 'MISSING' end as daily_submission_signature,
case when exists (
  select 1 from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname='public'
    and p.proname='submit_practice_round'
    and pg_get_function_identity_arguments(p.oid)='p_round_id uuid'
) then 'OK' else 'MISSING' end as practice_submission_signature;
