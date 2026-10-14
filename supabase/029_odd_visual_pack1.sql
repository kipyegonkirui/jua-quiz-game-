-- 029_odd_visual_pack1.sql
-- Odd One Out picture puzzles (16). Items are stored as  img:<file>|<label>
-- and drawn from assets/odd_one_out/<file>.png by the app (OddItemView).
-- Needs 020_odd_one_out. Safe to re-run: puzzles with the same four items are skipped.
--
-- The first 10 are live. The last 6 (sports, school, jobs, geography, sea animals,
-- appliances) have a debatable odd one out, so they are loaded with is_active = false.
-- Review them, then:  update public.odd_one_out_puzzles set is_active = true
--                     where puzzle_type = 'visual' and item_a like 'img:%';
insert into public.odd_one_out_puzzles
  (puzzle_type, item_a, item_b, item_c, item_d, odd_option, explanation, difficulty, time_limit_seconds, is_active)
select v.t, v.a, v.b, v.c, v.d,
       (case v.odd when v.a then 'a' when v.b then 'b' when v.c then 'c' else 'd' end),
       v.expl, v.diff, v.secs, v.act
from (values
($q$visual$q$,$q$img:fruits_broccoli|Broccoli$q$,$q$img:fruits_apple|Apple$q$,$q$img:fruits_banana|Banana$q$,$q$img:fruits_orange|Orange$q$,$q$img:fruits_broccoli|Broccoli$q$,$q$Apple, banana and orange are fruits. Broccoli is a vegetable.$q$,$q$easy$q$,10,true),
($q$visual$q$,$q$img:animals_lion|Lion$q$,$q$img:animals_fish|Fish$q$,$q$img:animals_elephant|Elephant$q$,$q$img:animals_zebra|Zebra$q$,$q$img:animals_fish|Fish$q$,$q$Lion, elephant and zebra live on land. A fish lives in water.$q$,$q$easy$q$,10,true),
($q$visual$q$,$q$img:countries_kenya|Kenya$q$,$q$img:countries_uganda|Uganda$q$,$q$img:countries_japan|Japan$q$,$q$img:countries_tanzania|Tanzania$q$,$q$img:countries_japan|Japan$q$,$q$Kenya, Uganda and Tanzania are East African countries. Japan is in Asia.$q$,$q$easy$q$,10,true),
($q$visual$q$,$q$img:vehicles_car|Car$q$,$q$img:vehicles_bus|Bus$q$,$q$img:vehicles_motorbike|Motorbike$q$,$q$img:vehicles_bicycle|Bicycle$q$,$q$img:vehicles_bicycle|Bicycle$q$,$q$Car, bus and motorbike have engines. A bicycle is pedal-powered.$q$,$q$easy$q$,10,true),
($q$visual$q$,$q$img:shapes_rectangle|Purple rectangle$q$,$q$img:shapes_circle|Red circle$q$,$q$img:shapes_square|Blue square$q$,$q$img:shapes_triangle|Yellow triangle$q$,$q$img:shapes_rectangle|Purple rectangle$q$,$q$Red, blue and yellow are the three primary colours. Purple is a mixed colour.$q$,$q$medium$q$,12,true),
($q$visual$q$,$q$img:food_pizza|Pizza$q$,$q$img:food_rice|Rice$q$,$q$img:food_burger|Burger$q$,$q$img:food_fries|Fries$q$,$q$img:food_rice|Rice$q$,$q$Pizza, burger and fries are fast food. Rice is a staple grain.$q$,$q$easy$q$,10,true),
($q$visual$q$,$q$img:tech_laptop|Laptop$q$,$q$img:tech_phone|Smartphone$q$,$q$img:tech_calculator|Calculator$q$,$q$img:tech_tablet|Tablet$q$,$q$img:tech_calculator|Calculator$q$,$q$Laptop, smartphone and tablet connect to the internet. A calculator only does sums.$q$,$q$medium$q$,12,true),
($q$visual$q$,$q$img:music_guitar|Guitar$q$,$q$img:music_violin|Violin$q$,$q$img:music_trumpet|Trumpet$q$,$q$img:music_drum|Drum$q$,$q$img:music_drum|Drum$q$,$q$Guitar, violin and trumpet play notes of different pitches. A drum is a percussion instrument you strike.$q$,$q$medium$q$,12,true),
($q$visual$q$,$q$img:planets_moon|Moon$q$,$q$img:planets_earth|Earth$q$,$q$img:planets_mars|Mars$q$,$q$img:planets_jupiter|Jupiter$q$,$q$img:planets_moon|Moon$q$,$q$Earth, Mars and Jupiter are planets. The Moon is a natural satellite.$q$,$q$medium$q$,12,true),
($q$visual$q$,$q$img:wild_lion|Lion$q$,$q$img:wild_cow|Cow$q$,$q$img:wild_giraffe|Giraffe$q$,$q$img:wild_zebra|Zebra$q$,$q$img:wild_cow|Cow$q$,$q$Lion, giraffe and zebra are wild animals. A cow is a farm animal.$q$,$q$easy$q$,10,true),
($q$visual$q$,$q$img:sports_football|Football$q$,$q$img:sports_basketball|Basketball$q$,$q$img:sports_tennis|Tennis ball$q$,$q$img:sports_cricket|Cricket ball$q$,$q$img:sports_tennis|Tennis ball$q$,$q$The football, basketball and cricket ball are larger or heavier balls. The tennis ball is the light, felt-covered one.$q$,$q$medium$q$,12,false),
($q$visual$q$,$q$img:school_pencil|Pencil$q$,$q$img:school_notebook|Notebook$q$,$q$img:school_ruler|Ruler$q$,$q$img:school_pen|Pen$q$,$q$img:school_pen|Pen$q$,$q$Pencil, notebook and ruler are all things you can write or draw with without ink. A pen uses ink.$q$,$q$medium$q$,12,false),
($q$visual$q$,$q$img:jobs_teacher|Teacher$q$,$q$img:jobs_doctor|Doctor$q$,$q$img:jobs_firefighter|Firefighter$q$,$q$img:jobs_farmer|Farmer$q$,$q$img:jobs_teacher|Teacher$q$,$q$Doctor, firefighter and farmer work away from a classroom. A teacher works in a classroom.$q$,$q$medium$q$,12,false),
($q$visual$q$,$q$img:geo_mountain|Mountain$q$,$q$img:geo_forest|Forest$q$,$q$img:geo_desert|Desert$q$,$q$img:geo_beach|Beach$q$,$q$img:geo_forest|Forest$q$,$q$Mountain, desert and beach are open landscapes. A forest is covered in trees.$q$,$q$medium$q$,12,false),
($q$visual$q$,$q$img:sea_shark|Shark$q$,$q$img:sea_dolphin|Dolphin$q$,$q$img:sea_starfish|Starfish$q$,$q$img:sea_octopus|Octopus$q$,$q$img:sea_starfish|Starfish$q$,$q$Shark, dolphin and octopus are fast swimmers. A starfish moves very slowly.$q$,$q$medium$q$,12,false),
($q$visual$q$,$q$img:appliances_fridge|Fridge$q$,$q$img:appliances_washer|Washing machine$q$,$q$img:appliances_microwave|Microwave$q$,$q$img:appliances_vacuum|Vacuum cleaner$q$,$q$img:appliances_vacuum|Vacuum cleaner$q$,$q$Fridge, washing machine and microwave stay in one place. A vacuum cleaner is carried around.$q$,$q$medium$q$,12,false)
) as v(t,a,b,c,d,odd,expl,diff,secs,act)
on conflict (item_a,item_b,item_c,item_d) do nothing;
