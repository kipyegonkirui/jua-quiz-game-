-- ============================================================================
-- Adding real pictures to Guess It (no app update needed).
-- Run the sections you need in the Supabase SQL editor.
-- ============================================================================

-- 1) ONE-TIME: a public bucket for the pictures.
--    (You can also create it in Dashboard > Storage > New bucket, tick "Public".)
insert into storage.buckets (id, name, public)
values ('guess-it', 'guess-it', true)
on conflict (id) do nothing;

-- Then upload your files in Dashboard > Storage > guess-it (JPG or WebP,
-- about 1080 px wide, 100-250 KB each). A file called  lion.jpg  is served at:
--   https://zlfhnxvvbbuhdsaynfju.supabase.co/storage/v1/object/public/guess-it/lion.jpg

-- 2) Add questions. Each prompt must be unique (there is a unique index on it).
--    correct_option is 'a', 'b', 'c' or 'd'. difficulty: easy | medium | hard.
--    Aim for a mix: the journeys use easy first and hard later.
insert into public.guess_it_questions
  (prompt, image_url, option_a, option_b, option_c, option_d, correct_option, difficulty, time_limit_seconds)
values
  ('Which Kenyan landmark is this?',
   'https://zlfhnxvvbbuhdsaynfju.supabase.co/storage/v1/object/public/guess-it/kicc.jpg',
   'KICC, Nairobi', 'Fort Jesus, Mombasa', 'Gedi Ruins', 'Nyayo Stadium', 'a', 'easy', 15),
  ('Which animal is this?',
   'https://zlfhnxvvbbuhdsaynfju.supabase.co/storage/v1/object/public/guess-it/lion.jpg',
   'Lion', 'Leopard', 'Cheetah', 'Hyena', 'a', 'easy', 15)
on conflict (prompt) do nothing;

-- 3) The six placeholder drawings are retired by guess_it_kenya_pack_1.sql.

-- 4) Check what players will see.
select difficulty, count(*) as active_questions
from public.guess_it_questions
where is_active
group by difficulty
order by case difficulty when 'easy' then 1 when 'medium' then 2 else 3 end;
