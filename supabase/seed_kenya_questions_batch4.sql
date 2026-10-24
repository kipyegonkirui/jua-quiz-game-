-- ============================================================================
-- seed_kenya_questions_batch4.sql
-- 30 more questions (mostly hard and medium) with "Did you know?" lines, plus
-- 20 Odd One Out puzzles. Run AFTER 024_content_quality.sql and 020_odd_one_out.sql.
-- Safe to re-run. Please have a Kenyan reviewer skim the facts before release.
-- ============================================================================

insert into public.categories (name)
select c.name from (values ($q$Kenyan Food & Culture$q$), ($q$Kenyan Geography$q$), ($q$Kenyan History$q$), ($q$Kenyan Sports$q$), ($q$Kenyan Wildlife & Culture$q$), ($q$Swahili & Sheng$q$)) as c(name)
where not exists (select 1 from public.categories x where x.name = c.name);

insert into public.questions
  (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty, did_you_know)
select (select id from public.categories where name = v.cat limit 1),
       v.question_text, v.a, v.b, v.c, v.d, v.correct, v.difficulty, v.fact
from (values
  ($q$Kenyan History$q$, $q$In which year was the State of Emergency declared in Kenya during the Mau Mau uprising?$q$, $q$1957$q$, $q$1960$q$, $q$1948$q$, $q$1952$q$, 'd', 'hard', $q$The emergency was declared in October 1952 and lasted until 1960.$q$),
  ($q$Kenyan History$q$, $q$Which Mau Mau leader was captured in October 1956?$q$, $q$Bildad Kaggia$q$, $q$Jaramogi Oginga Odinga$q$, $q$Tom Mboya$q$, $q$Dedan Kimathi$q$, 'd', 'hard', $q$Dedan Kimathi was executed in February 1957. He is remembered as a national hero.$q$),
  ($q$Kenyan History$q$, $q$The Lancaster House conferences in London (1960 and 1962) were about Kenya's...$q$, $q$Currency$q$, $q$Border with Uganda$q$, $q$Independence constitution$q$, $q$Railway funding$q$, 'c', 'hard', $q$The talks set out how Kenya would move to self-rule and independence in 1963.$q$),
  ($q$Kenyan History$q$, $q$In which year did Kenya become a republic?$q$, $q$1966$q$, $q$1964$q$, $q$1969$q$, $q$1963$q$, 'b', 'hard', $q$Kenya got independence on 12 December 1963 and became a republic exactly one year later, with Jomo Kenyatta as President.$q$),
  ($q$Kenyan History$q$, $q$Who was Kenya's first Vice President?$q$, $q$Jaramogi Oginga Odinga$q$, $q$Joseph Murumbi$q$, $q$Tom Mboya$q$, $q$Daniel arap Moi$q$, 'a', 'hard', $q$Odinga served from 1963 to 1966, when he resigned and formed the Kenya People's Union.$q$),
  ($q$Kenyan History$q$, $q$In which year was Kenya's current constitution promulgated?$q$, $q$2007$q$, $q$2013$q$, $q$2010$q$, $q$2002$q$, 'c', 'hard', $q$It was signed into law on 27 August 2010 and created the 47 counties.$q$),
  ($q$Kenyan History$q$, $q$Wangari Maathai won the Nobel Peace Prize in which year?$q$, $q$2008$q$, $q$2004$q$, $q$2006$q$, $q$2002$q$, 'b', 'medium', $q$She was the first African woman to win it. She founded the Green Belt Movement in 1977.$q$),
  ($q$Kenyan History$q$, $q$Nairobi began in 1899 as what?$q$, $q$A railway depot$q$, $q$A Maasai fort$q$, $q$A mission station$q$, $q$A trading port$q$, 'a', 'hard', $q$It was a rest and supply depot on the Uganda Railway. The name comes from the Maasai "Enkare Nairobi", meaning cool water.$q$),
  ($q$Kenyan History$q$, $q$Which city was the capital of the East Africa Protectorate until 1907?$q$, $q$Mombasa$q$, $q$Nakuru$q$, $q$Kisumu$q$, $q$Naivasha$q$, 'a', 'hard', $q$The capital moved to Nairobi in 1907 because it was cooler and better placed on the railway.$q$),
  ($q$Kenyan Geography$q$, $q$What is the name of the highest peak of Mount Kenya?$q$, $q$Lenana$q$, $q$Nelion$q$, $q$Batian$q$, $q$Point Pigott$q$, 'c', 'hard', $q$Batian is 5,199 m high. Nelion is 5,188 m, and Lenana (4,985 m) is the one trekkers can climb without technical gear.$q$),
  ($q$Kenyan Geography$q$, $q$Which Kenyan lake is the world's largest permanent desert lake?$q$, $q$Lake Naivasha$q$, $q$Lake Magadi$q$, $q$Lake Turkana$q$, $q$Lake Baringo$q$, 'c', 'medium', $q$Lake Turkana is also called the Jade Sea because of its colour.$q$),
  ($q$Kenyan Geography$q$, $q$Which is Kenya's largest county by area?$q$, $q$Garissa$q$, $q$Wajir$q$, $q$Marsabit$q$, $q$Turkana$q$, 'c', 'hard', $q$Marsabit covers roughly 70,000 square kilometres. Turkana is a close second.$q$),
  ($q$Kenyan Geography$q$, $q$Which is Kenya's smallest county by area?$q$, $q$Mombasa$q$, $q$Vihiga$q$, $q$Kisii$q$, $q$Nairobi$q$, 'a', 'hard', $q$Mombasa County covers only about 220 square kilometres.$q$),
  ($q$Kenyan Geography$q$, $q$Which of these towns lies on the Equator?$q$, $q$Nyeri$q$, $q$Eldoret$q$, $q$Thika$q$, $q$Nanyuki$q$, 'd', 'medium', $q$The Equator crosses Kenya at Nanyuki, in the shadow of Mount Kenya, and at several other points.$q$),
  ($q$Kenyan Geography$q$, $q$Lake Magadi is best known for producing...$q$, $q$Soda ash$q$, $q$Geothermal tourism only$q$, $q$Fish$q$, $q$Salt for cooking only$q$, 'a', 'hard', $q$Magadi Soda mines a thick crust of soda ash from the lake in the Rift Valley.$q$),
  ($q$Kenyan Geography$q$, $q$Which is the longest river wholly within Kenya?$q$, $q$Tana River$q$, $q$Nzoia River$q$, $q$Ewaso Ng'iro$q$, $q$Athi River$q$, 'a', 'medium', $q$The Tana is about 1,000 km long and flows into the Indian Ocean.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the oldest continuously inhabited Swahili settlement in East Africa and a UNESCO site since 2001?$q$, $q$Lamu$q$, $q$Gedi$q$, $q$Kilifi$q$, $q$Malindi$q$, 'a', 'hard', $q$Lamu Old Town is known for its coral-stone buildings, carved doors and narrow streets with no cars.$q$),
  ($q$Kenyan Sports$q$, $q$In which year did Wilson Kiprugut win Kenya's first Olympic medal, a bronze in the 800 m?$q$, $q$1964$q$, $q$1968$q$, $q$1960$q$, $q$1972$q$, 'a', 'hard', $q$He won it at the 1964 Tokyo Olympics. Kenya had first competed at the Games in 1956.$q$),
  ($q$Kenyan Sports$q$, $q$David Rudisha's 800 m world record, set at the 2012 London Olympics, is...$q$, $q$1:40.91$q$, $q$1:42.10$q$, $q$1:39.50$q$, $q$1:41.73$q$, 'a', 'hard', $q$Rudisha led from the front all the way and set the record in the Olympic final.$q$),
  ($q$Kenyan Sports$q$, $q$In which city did Eliud Kipchoge run the first sub-two-hour marathon, in 2019?$q$, $q$Vienna$q$, $q$Berlin$q$, $q$London$q$, $q$Chicago$q$, 'a', 'medium', $q$He ran 1:59:40 in Vienna. It was not an official record because of pacemakers and other aids.$q$),
  ($q$Kenyan Sports$q$, $q$Kenya won the Cup at which 2016 World Rugby Sevens Series tournament, its first ever title?$q$, $q$Hong Kong$q$, $q$Singapore$q$, $q$Dubai$q$, $q$Cape Town$q$, 'b', 'hard', $q$Kenya's Shujaa beat Fiji in the final of the 2016 Singapore Sevens.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$The Turkana Boy skeleton, found near Lake Turkana in 1984, belongs to which early human species?$q$, $q$Australopithecus afarensis$q$, $q$Neanderthal$q$, $q$Homo erectus$q$, $q$Homo sapiens$q$, 'c', 'hard', $q$The skeleton is about 1.5 million years old and is one of the most complete early human fossils ever found.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Which Kenyan conservancy protects the last two northern white rhinos?$q$, $q$Ol Pejeta$q$, $q$Solio$q$, $q$Lewa$q$, $q$Nairobi National Park$q$, 'a', 'medium', $q$Najin and Fatu, both female, live under armed guard at Ol Pejeta Conservancy in Laikipia.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Which national park is famous for its red elephants?$q$, $q$Amboseli$q$, $q$Tsavo East$q$, $q$Meru$q$, $q$Aberdare$q$, 'b', 'medium', $q$The elephants look red because they dust-bathe in the park's red soil.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$The jumping dance performed by Maasai warriors is called...$q$, $q$Isicathamiya$q$, $q$Chakacha$q$, $q$Adumu$q$, $q$Kizomba$q$, 'c', 'medium', $q$Warriors take turns jumping as high as they can without bending their knees.$q$),
  ($q$Kenyan Food & Culture$q$, $q$Mursik, a fermented milk drink, is traditionally associated with which community?$q$, $q$Kikuyu$q$, $q$Luo$q$, $q$Kalenjin$q$, $q$Luhya$q$, 'c', 'medium', $q$Mursik is stored in a gourd that is cleaned with smoke from burnt cedar, which gives it a smoky taste.$q$),
  ($q$Swahili & Sheng$q$, $q$Which day of the week is "Jumanne" in Swahili?$q$, $q$Thursday$q$, $q$Tuesday$q$, $q$Monday$q$, $q$Friday$q$, 'b', 'medium', $q$Swahili days are counted from Saturday: Jumamosi, Jumapili, Jumatatu, Jumanne, Jumatano.$q$),
  ($q$Swahili & Sheng$q$, $q$What does the proverb "Fimbo ya mbali haiui nyoka" mean?$q$, $q$Help from far away comes too late$q$, $q$Walk with a stick$q$, $q$Snakes are dangerous$q$, $q$Keep your distance$q$, 'a', 'medium', $q$A stick that is far away cannot kill the snake in front of you. Use what is near you.$q$),
  ($q$Swahili & Sheng$q$, $q$In Sheng, what is a "mbogi"?$q$, $q$A police officer$q$, $q$A bus stop$q$, $q$A type of food$q$, $q$A group of friends$q$, 'd', 'medium', $q$"Mbogi" is also used in the phrase "mbogi genje", for a big group.$q$)
) as v(cat, question_text, a, b, c, d, correct, difficulty, fact)
where not exists (select 1 from public.questions q where q.question_text = v.question_text);

insert into public.odd_one_out_puzzles
  (puzzle_type, item_a, item_b, item_c, item_d, odd_option, explanation, difficulty, time_limit_seconds)
select * from (values
  ('local', $q$Lake Tanganyika$q$, $q$Lake Naivasha$q$, $q$Lake Turkana$q$, $q$Lake Victoria$q$, 'a', $q$Lake Tanganyika is not in Kenya. The other three are.$q$, 'hard', 12),
  ('local', $q$Kampala$q$, $q$Mombasa$q$, $q$Nakuru$q$, $q$Kisumu$q$, 'a', $q$Kampala is the capital of Uganda. The others are Kenyan cities.$q$, 'medium', 12),
  ('local', $q$Mount Kenya$q$, $q$Mount Longonot$q$, $q$Mount Elgon$q$, $q$Mount Kilimanjaro$q$, 'd', $q$Kilimanjaro is in Tanzania. The others are in Kenya.$q$, 'hard', 12),
  ('local', $q$Injera$q$, $q$Ugali$q$, $q$Mandazi$q$, $q$Githeri$q$, 'a', $q$Injera is an Ethiopian flatbread. The others are everyday Kenyan foods.$q$, 'medium', 12),
  ('local', $q$Zulu$q$, $q$Kikuyu$q$, $q$Kamba$q$, $q$Luo$q$, 'a', $q$The Zulu are from South Africa. The others are Kenyan communities.$q$, 'medium', 12),
  ('local', $q$Brigid Kosgei$q$, $q$Eliud Kipchoge$q$, $q$David Rudisha$q$, $q$Usain Bolt$q$, 'd', $q$Usain Bolt is Jamaican. The others are Kenyan runners.$q$, 'medium', 12),
  ('local', $q$Maasai Mara$q$, $q$Serengeti$q$, $q$Tsavo$q$, $q$Amboseli$q$, 'b', $q$The Serengeti is in Tanzania. The others are Kenyan parks and reserves.$q$, 'hard', 12),
  ('local', $q$Telkom$q$, $q$Airtel$q$, $q$MTN$q$, $q$Safaricom$q$, 'c', $q$MTN is not a mobile network in Kenya. The others are.$q$, 'hard', 12),
  ('wordplay', $q$Jumatatu$q$, $q$Jumapili$q$, $q$Jumanne$q$, $q$Januari$q$, 'd', $q$Januari means January. The others are days of the week in Swahili.$q$, 'medium', 12),
  ('local', $q$Kenyatta$q$, $q$Moi$q$, $q$Mandela$q$, $q$Kibaki$q$, 'c', $q$Nelson Mandela led South Africa. The others were presidents of Kenya.$q$, 'medium', 12),
  ('local', $q$Boxing Day$q$, $q$Madaraka Day$q$, $q$Jamhuri Day$q$, $q$Mashujaa Day$q$, 'a', $q$Madaraka, Jamhuri and Mashujaa are national days that celebrate Kenya's history. Boxing Day is not specific to Kenya.$q$, 'hard', 12),
  ('category', $q$Lion$q$, $q$Giraffe$q$, $q$Elephant$q$, $q$Rhino$q$, 'b', $q$The Big Five are elephant, lion, rhino, buffalo and leopard. The giraffe is not one of them.$q$, 'medium', 10),
  ('local', $q$Entebbe$q$, $q$Moi International$q$, $q$JKIA$q$, $q$Wilson$q$, 'a', $q$Entebbe airport is in Uganda. The others are Kenyan airports.$q$, 'hard', 12),
  ('local', $q$Rift Valley$q$, $q$Central$q$, $q$Ashanti$q$, $q$Coast$q$, 'c', $q$Ashanti is a region in Ghana. The others were Kenyan provinces.$q$, 'hard', 12),
  ('category', $q$Zebra$q$, $q$Wildebeest$q$, $q$Gazelle$q$, $q$Penguin$q$, 'd', $q$Penguins do not live on the African savanna. The others graze on it.$q$, 'easy', 10),
  ('tricky', $q$Mukimo$q$, $q$Terere$q$, $q$Sukuma wiki$q$, $q$Managu$q$, 'a', $q$Mukimo is a mashed dish. The others are leafy vegetables.$q$, 'hard', 14),
  ('local', $q$Wimbledon$q$, $q$Nairobi Marathon$q$, $q$Safari Rally$q$, $q$Kenya Open$q$, 'a', $q$Wimbledon is held in London. The others are held in Kenya.$q$, 'medium', 12),
  ('wordplay', $q$Mkate$q$, $q$Moja$q$, $q$Nne$q$, $q$Mbili$q$, 'a', $q$Mkate means bread. The others are the numbers 1, 2 and 4.$q$, 'easy', 10),
  ('local', $q$Naivasha$q$, $q$Tana$q$, $q$Nzoia$q$, $q$Athi$q$, 'a', $q$Naivasha is a lake. The others are rivers.$q$, 'medium', 12),
  ('local', $q$Nyayo$q$, $q$Sparrow$q$, $q$Uhuru$q$, $q$Harambee$q$, 'b', $q$Nyayo, Harambee and Uhuru are Kenyan national watchwords. A sparrow is a bird.$q$, 'hard', 12)
) as v(t, a, b, c, d, odd, expl, diff, secs)
where not exists (select 1 from public.odd_one_out_puzzles p
                   where p.item_a = v.a and p.item_b = v.b and p.item_c = v.c and p.item_d = v.d);
