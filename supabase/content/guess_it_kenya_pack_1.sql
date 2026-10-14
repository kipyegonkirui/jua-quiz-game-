-- ============================================================================
-- Guess It: Kenya picture pack 1 (19 questions, pictures bundled in the app).
-- Needs the images in assets/guess_it/ (gi_*.jpg) shipped with the app build.
-- Safe to re-run (prompts are unique, so duplicates are skipped).
-- ============================================================================

insert into public.guess_it_questions
  (prompt, image_url, option_a, option_b, option_c, option_d, correct_option, difficulty, time_limit_seconds)
values
  ('Which famous Nairobi building is this?',
   'asset:assets/guess_it/gi_kicc.jpg',
   'KICC', 'Times Tower', 'Anniversary Towers', 'Nyayo House', 'a', 'medium', 15),
  ('Which mountain is this?',
   'asset:assets/guess_it/gi_mount_kenya.jpg',
   'Mount Kilimanjaro', 'Mount Elgon', 'Mount Kenya', 'Mount Longonot', 'c', 'medium', 15),
  ('Which animal is this?',
   'asset:assets/guess_it/gi_elephant.jpg',
   'Rhino', 'African elephant', 'Hippo', 'Buffalo', 'b', 'easy', 15),
  ('Which big cat is this?',
   'asset:assets/guess_it/gi_lion.jpg',
   'Leopard', 'Cheetah', 'Serval', 'Lion', 'd', 'easy', 15),
  ('Which Kenyan community is known for the red shuka and beaded jewellery?',
   'asset:assets/guess_it/gi_maasai.jpg',
   'Maasai', 'Kikuyu', 'Luo', 'Luhya', 'a', 'medium', 15),
  ('Which tall animal is this?',
   'asset:assets/guess_it/gi_giraffe.jpg',
   'Antelope', 'Camel', 'Giraffe', 'Ostrich', 'c', 'easy', 15),
  ('Which striped animal is this?',
   'asset:assets/guess_it/gi_zebra.jpg',
   'Donkey', 'Zebra', 'Okapi', 'Horse', 'b', 'easy', 15),
  ('Which Kenyan meal is this?',
   'asset:assets/guess_it/gi_wali_nyama.jpg',
   'Ugali and fish', 'Githeri', 'Mukimo', 'Rice, beef stew and sukuma wiki', 'd', 'medium', 15),
  ('What popular Kenyan dish is this?',
   'asset:assets/guess_it/gi_nyama_choma.jpg',
   'Nyama choma', 'Mandazi', 'Mutura', 'Pilau', 'a', 'easy', 15),
  ('Which Kenyan favourite is this flat bread?',
   'asset:assets/guess_it/gi_chapati.jpg',
   'Mandazi', 'Injera', 'Chapati', 'Mkate mayai', 'c', 'easy', 15),
  ('Which animal from the Big Five is this?',
   'asset:assets/guess_it/gi_buffalo.jpg',
   'Rhino', 'Cape buffalo', 'Leopard', 'Lion', 'b', 'medium', 15),
  ('Which spotted cat is this?',
   'asset:assets/guess_it/gi_cheetah.jpg',
   'Leopard', 'Jaguar', 'Serval', 'Cheetah', 'd', 'hard', 15),
  ('Which pink bird, often seen at Lake Nakuru, is this?',
   'asset:assets/guess_it/gi_flamingo.jpg',
   'Flamingo', 'Crane', 'Ostrich', 'Pelican', 'a', 'easy', 15),
  ('Which country does this flag belong to?',
   'asset:assets/guess_it/gi_flag.jpg',
   'Tanzania', 'Uganda', 'Kenya', 'Zimbabwe', 'c', 'easy', 15),
  ('What kind of landform is this?',
   'asset:assets/guess_it/gi_crater.jpg',
   'Canyon', 'Volcanic crater', 'Glacier', 'Sand dune', 'b', 'hard', 15),
  ('Which sport is played in this stadium?',
   'asset:assets/guess_it/gi_football.jpg',
   'Rugby', 'Cricket', 'Tennis', 'Football', 'd', 'easy', 15),
  ('Which part of Kenya is famous for beaches like this?',
   'asset:assets/guess_it/gi_beach.jpg',
   'The Kenyan Coast', 'The Rift Valley', 'The Aberdare Ranges', 'Northern Kenya', 'a', 'medium', 15),
  ('Which spiced rice dish is this, a Kenyan favourite?',
   'asset:assets/guess_it/gi_pilau.jpg',
   'Githeri', 'Mukimo', 'Pilau', 'Ugali', 'c', 'medium', 15),
  ('Whose shield and spears appear on the Kenyan flag?',
   'asset:assets/guess_it/gi_shield.jpg',
   'The Kikuyu', 'The Maasai', 'The Luo', 'The Kalenjin', 'b', 'hard', 15)
on conflict (prompt) do nothing;

-- Retire the six simple placeholder drawings now that real pictures exist.
update public.guess_it_questions
   set is_active = false
 where image_url in (
   'asset:assets/guess_it/lion.png',    'asset:assets/guess_it/elephant.png',
   'asset:assets/guess_it/nairobi.png', 'asset:assets/guess_it/football.png',
   'asset:assets/guess_it/savanna.png', 'asset:assets/guess_it/camera.png',
   'asset:assets/guess_it/lion.svg',    'asset:assets/guess_it/elephant.svg',
   'asset:assets/guess_it/nairobi.svg', 'asset:assets/guess_it/football.svg',
   'asset:assets/guess_it/savanna.svg', 'asset:assets/guess_it/camera.svg'
 );

-- Check: how many active questions per difficulty?
select difficulty, count(*) as active_questions
from public.guess_it_questions
where is_active
group by difficulty
order by case difficulty when 'easy' then 1 when 'medium' then 2 else 3 end;
