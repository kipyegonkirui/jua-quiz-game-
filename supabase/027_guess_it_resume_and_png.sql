-- ============================================================================
-- 027_guess_it_resume_and_png.sql
-- 1. Guess It pictures are bundled PNGs now (Flutter cannot draw SVG files with
--    Image.asset), so point the existing rows at the .png files.
-- 2. Resuming an unfinished Guess It round no longer restarts at question 1:
--    get_guess_it_questions now says which questions are already answered and
--    which hints were already bought, so the app continues where it stopped
--    instead of hitting 'already_answered'.
-- Run after 026. Safe to re-run.
-- ============================================================================

update public.guess_it_questions
   set image_url = regexp_replace(image_url, '\.svg$', '.png', 'i')
 where image_url ~* '^asset:.*\.svg$';

-- The return type changes, so the old function has to be dropped first.
drop function if exists public.get_guess_it_questions(uuid);

create function public.get_guess_it_questions(p_round_id uuid)
returns table (
  id uuid,
  prompt text,
  image_url text,
  option_a text,
  option_b text,
  option_c text,
  option_d text,
  "position" integer,
  time_limit_seconds integer,
  difficulty text,
  answered boolean,
  hint_level integer,
  eliminated_options text[]
)
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select q.id, q.prompt, q.image_url, q.option_a, q.option_b, q.option_c, q.option_d,
         rq.position, q.time_limit_seconds, q.difficulty,
         (a.question_id is not null) as answered,
         coalesce((
           select max(h.hint_level) from public.guess_it_hints h
           where h.round_id = r.id and h.question_id = q.id
         ), 0) as hint_level,
         coalesce((
           select array_agg(distinct e)
           from public.guess_it_hints h, unnest(h.eliminated_options) e
           where h.round_id = r.id and h.question_id = q.id
         ), '{}'::text[]) as eliminated_options
  from public.guess_it_rounds r
  join public.guess_it_round_questions rq on rq.round_id = r.id
  join public.guess_it_questions q on q.id = rq.question_id
  left join public.guess_it_answers a on a.round_id = r.id and a.question_id = q.id
  where r.id = p_round_id and r.user_id = auth.uid() and r.status = 'open'
  order by rq.position;
$$;

revoke all on function public.get_guess_it_questions(uuid) from public, anon;
grant execute on function public.get_guess_it_questions(uuid) to authenticated;
