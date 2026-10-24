-- ============================================================================
-- seed_kenya_questions_batch7.sql
-- 70 more questions (mostly hard and medium), each with a "Did you know?" line.
-- Run AFTER 024_content_quality.sql. Safe to re-run (skips existing question text).
-- IMPORTANT: have a Kenyan reviewer check every fact (see batch7_review.md) before release.
-- ============================================================================

insert into public.categories (name)
select c.name from (values ($q$General Knowledge$q$), ($q$Kenyan Geography$q$), ($q$Kenyan History$q$), ($q$Kenyan Sports$q$)) as c(name)
where not exists (select 1 from public.categories x where x.name = c.name);

insert into public.questions
  (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty, did_you_know)
select (select id from public.categories where name = v.cat limit 1),
       v.question_text, v.a, v.b, v.c, v.d, v.correct, v.difficulty, v.fact
from (values
  ($q$Kenyan History$q$, $q$Mashujaa Day, held on 20 October, used to be called what?$q$, $q$Madaraka Day$q$, $q$Jamhuri Day$q$, $q$Moi Day$q$, $q$Kenyatta Day$q$, 'd', 'medium', $q$It was renamed under the 2010 Constitution.$q$),
  ($q$Kenyan History$q$, $q$What happened on 20 October 1952 to give Kenyatta Day its date?$q$, $q$A State of Emergency was declared and Kenyatta was arrested$q$, $q$Kenya won independence$q$, $q$The Lancaster House talks began$q$, $q$Kenya became a republic$q$, 'a', 'medium', $q$The Emergency lasted until 1960.$q$),
  ($q$Kenyan History$q$, $q$Which of these men was one of the "Kapenguria Six" tried alongside Jomo Kenyatta?$q$, $q$Tom Mboya$q$, $q$Bildad Kaggia$q$, $q$Mwai Kibaki$q$, $q$Daniel arap Moi$q$, 'b', 'hard', $q$The trial took place in Kapenguria in 1952 and 1953.$q$),
  ($q$Kenyan History$q$, $q$The 1959 Hola detention camp massacre took place in which part of Kenya?$q$, $q$Lake Turkana$q$, $q$Mount Elgon$q$, $q$The Tana River area$q$, $q$Kisumu$q$, 'c', 'hard', $q$Eleven detainees died after beatings, and the news shocked Britain.$q$),
  ($q$Kenyan History$q$, $q$Operation Anvil in 1954 targeted which city?$q$, $q$Nairobi$q$, $q$Mombasa$q$, $q$Nakuru$q$, $q$Kisumu$q$, 'a', 'hard', $q$Tens of thousands of people were screened and many were detained.$q$),
  ($q$Kenyan History$q$, $q$Who was the British governor of Kenya when the State of Emergency was declared in 1952?$q$, $q$Sir Philip Mitchell$q$, $q$Sir Evelyn Baring$q$, $q$Sir Richard Turnbull$q$, $q$Lord Delamere$q$, 'b', 'hard', $q$Baring served as governor until 1959.$q$),
  ($q$Kenyan History$q$, $q$The "White Highlands" of colonial Kenya were fertile farmland reserved for whom?$q$, $q$Indian traders$q$, $q$Maasai herders$q$, $q$European settlers$q$, $q$Arab merchants$q$, 'c', 'medium', $q$Many Kenyans lost land under this policy.$q$),
  ($q$Kenyan History$q$, $q$In which year did the East Africa Protectorate become the Colony of Kenya?$q$, $q$1895$q$, $q$1905$q$, $q$1930$q$, $q$1920$q$, 'd', 'hard', $q$The coastal strip stayed a protectorate.$q$),
  ($q$Kenyan History$q$, $q$Which early Kenyan nationalist founded the East African Association in 1921?$q$, $q$Jomo Kenyatta$q$, $q$Harry Thuku$q$, $q$Jaramogi Oginga Odinga$q$, $q$Mbiyu Koinange$q$, 'b', 'hard', $q$He was arrested in 1922, and protests followed in Nairobi.$q$),
  ($q$Kenyan History$q$, $q$Who became president of the Kenya African Union in 1947?$q$, $q$Tom Mboya$q$, $q$Dedan Kimathi$q$, $q$Jomo Kenyatta$q$, $q$Achieng Oneko$q$, 'c', 'hard', $q$Kenyatta had returned from Britain in 1946.$q$),
  ($q$Kenyan History$q$, $q$Who became the first African member of Kenya's Legislative Council in 1944?$q$, $q$Jomo Kenyatta$q$, $q$Ronald Ngala$q$, $q$Tom Mboya$q$, $q$Eliud Mathu$q$, 'd', 'hard', $q$Mathu was an early voice for African representation.$q$),
  ($q$Kenyan History$q$, $q$Which party, led by Ronald Ngala, opposed KANU at independence?$q$, $q$KADU$q$, $q$KAU$q$, $q$KPU$q$, $q$FORD$q$, 'a', 'hard', $q$KADU backed a federal "majimbo" system.$q$),
  ($q$Kenyan History$q$, $q$In which year was Tom Mboya assassinated in Nairobi?$q$, $q$1965$q$, $q$1971$q$, $q$1969$q$, $q$1975$q$, 'c', 'hard', $q$He was a leading trade unionist and government minister.$q$),
  ($q$Kenyan History$q$, $q$Kenya joined the United Nations in which year?$q$, $q$1960$q$, $q$1965$q$, $q$1970$q$, $q$1963$q$, 'd', 'hard', $q$Kenya joined days after independence.$q$),
  ($q$Kenyan History$q$, $q$Nairobi became the capital of British East Africa in which year?$q$, $q$1907$q$, $q$1899$q$, $q$1920$q$, $q$1930$q$, 'a', 'hard', $q$The capital moved from Mombasa.$q$),
  ($q$Kenyan History$q$, $q$The Gedi Ruins, near Watamu, are the remains of a medieval town of which culture?$q$, $q$Maasai$q$, $q$Swahili$q$, $q$Kikuyu$q$, $q$Luo$q$, 'b', 'medium', $q$The town was abandoned in the 17th century.$q$),
  ($q$Kenyan History$q$, $q$Olorgesailie, south of Nairobi, is famous for ancient what?$q$, $q$Dinosaur bones$q$, $q$Cave paintings$q$, $q$Gold coins$q$, $q$Stone hand axes$q$, 'd', 'hard', $q$Some of the tools there are around a million years old.$q$),
  ($q$Kenyan History$q$, $q$Koobi Fora, famous for human fossils, lies on the shores of which lake?$q$, $q$Lake Turkana$q$, $q$Lake Victoria$q$, $q$Lake Baringo$q$, $q$Lake Naivasha$q$, 'a', 'hard', $q$Richard Leakey led digs there.$q$),
  ($q$Kenyan History$q$, $q$Jamhuri Day marks which event in 1964?$q$, $q$Kenyatta's release from prison$q$, $q$Kenya becoming a republic$q$, $q$Kenya joining the UN$q$, $q$The Lancaster House talks$q$, 'b', 'medium', $q$Jomo Kenyatta became the first President.$q$),
  ($q$Kenyan History$q$, $q$Who found the Turkana Boy skeleton at Nariokotome in 1984?$q$, $q$Richard Leakey$q$, $q$Louis Leakey$q$, $q$Kamoya Kimeu$q$, $q$Meave Leakey$q$, 'c', 'hard', $q$Kimeu was a member of Richard Leakey's fossil-hunting team.$q$),
  ($q$Kenyan Geography$q$, $q$Lake Naivasha lies in which county?$q$, $q$Nakuru$q$, $q$Narok$q$, $q$Kajiado$q$, $q$Baringo$q$, 'a', 'medium', $q$Lake Naivasha is a freshwater lake in the Rift Valley.$q$),
  ($q$Kenyan Geography$q$, $q$Mount Elgon sits on the border between Kenya and which country?$q$, $q$Tanzania$q$, $q$Uganda$q$, $q$Ethiopia$q$, $q$South Sudan$q$, 'b', 'medium', $q$It is an extinct volcano.$q$),
  ($q$Kenyan Geography$q$, $q$Which Kenyan county has the largest population?$q$, $q$Kiambu$q$, $q$Nakuru$q$, $q$Nairobi$q$, $q$Mombasa$q$, 'c', 'medium', $q$Nairobi had about 4.4 million people at the 2019 census.$q$),
  ($q$Kenyan Geography$q$, $q$Kenya covers roughly how many square kilometres?$q$, $q$About 280,000$q$, $q$About 380,000$q$, $q$About 980,000$q$, $q$About 580,000$q$, 'd', 'hard', $q$That makes it a little larger than France.$q$),
  ($q$Kenyan Geography$q$, $q$Which country lies to Kenya's north-west?$q$, $q$Somalia$q$, $q$South Sudan$q$, $q$Tanzania$q$, $q$Uganda$q$, 'b', 'medium', $q$Kenya also borders Ethiopia, Somalia, Tanzania and Uganda.$q$),
  ($q$Kenyan Geography$q$, $q$Wasini Island, famous for dolphin trips, lies off which part of Kenya's coast?$q$, $q$The north coast$q$, $q$Lake Victoria$q$, $q$The south coast$q$, $q$The Lamu Archipelago$q$, 'c', 'hard', $q$It is near the fishing town of Shimoni.$q$),
  ($q$Kenyan Geography$q$, $q$Diani Beach lies in which county?$q$, $q$Kilifi$q$, $q$Lamu$q$, $q$Mombasa$q$, $q$Kwale$q$, 'd', 'medium', $q$It is known for white sand and palm trees.$q$),
  ($q$Kenyan Geography$q$, $q$Malindi town lies in which county?$q$, $q$Kilifi$q$, $q$Kwale$q$, $q$Lamu$q$, $q$Tana River$q$, 'a', 'medium', $q$Malindi is also known for its marine park.$q$),
  ($q$Kenyan Geography$q$, $q$Eldoret is the main town of which county?$q$, $q$Trans Nzoia$q$, $q$Nandi$q$, $q$Uasin Gishu$q$, $q$Kakamega$q$, 'c', 'medium', $q$Eldoret is known as a home of champion runners.$q$),
  ($q$Kenyan Geography$q$, $q$Which Nobel laureate fought to protect Nairobi's Karura Forest?$q$, $q$Richard Leakey$q$, $q$Kofi Annan$q$, $q$Ngũgĩ wa Thiong'o$q$, $q$Wangari Maathai$q$, 'd', 'hard', $q$Karura is one of the largest urban forests in the world.$q$),
  ($q$Kenyan Geography$q$, $q$Karen Blixen's Kenyan farm lay at the foot of which hills?$q$, $q$The Ngong Hills$q$, $q$The Aberdares$q$, $q$The Chyulu Hills$q$, $q$The Taita Hills$q$, 'a', 'medium', $q$Her memoir "Out of Africa" was published in 1937.$q$),
  ($q$Kenyan Geography$q$, $q$Menengai Crater, one of the world's largest calderas, overlooks which city?$q$, $q$Nairobi$q$, $q$Nakuru$q$, $q$Kisumu$q$, $q$Eldoret$q$, 'b', 'hard', $q$The area is also being used to produce geothermal power.$q$),
  ($q$Kenyan Geography$q$, $q$Mzima Springs in Tsavo West helps supply drinking water to which city?$q$, $q$Nairobi$q$, $q$Kisumu$q$, $q$Nakuru$q$, $q$Mombasa$q$, 'd', 'hard', $q$The springs are fed by water from the Chyulu Hills.$q$),
  ($q$Kenyan Geography$q$, $q$The Kenyan section of the Great Rift Valley is also known by what name?$q$, $q$The Gregory Rift$q$, $q$The Albertine Rift$q$, $q$The Afar Depression$q$, $q$The Congo Rift$q$, 'a', 'hard', $q$It is named after the geologist John Walter Gregory.$q$),
  ($q$Kenyan Geography$q$, $q$Mount Kenya is what kind of mountain?$q$, $q$A fold mountain$q$, $q$An extinct volcano$q$, $q$A coral reef$q$, $q$A glacier-carved plateau$q$, 'b', 'medium', $q$Its glaciers are shrinking fast.$q$),
  ($q$Kenyan Geography$q$, $q$Lake Turkana stretches north across the border into which country?$q$, $q$Somalia$q$, $q$Uganda$q$, $q$Ethiopia$q$, $q$South Sudan$q$, 'c', 'medium', $q$The Omo River feeds it from Ethiopia.$q$),
  ($q$Kenyan Geography$q$, $q$Kitale is the main town of which county?$q$, $q$Trans Nzoia$q$, $q$Uasin Gishu$q$, $q$Bungoma$q$, $q$Kakamega$q$, 'a', 'medium', $q$Kitale is a major maize-growing area.$q$),
  ($q$Kenyan Geography$q$, $q$Lake Baringo lies in which county?$q$, $q$Nakuru$q$, $q$Baringo$q$, $q$Laikipia$q$, $q$West Pokot$q$, 'b', 'medium', $q$Baringo and Naivasha are the Rift Valley's two freshwater lakes.$q$),
  ($q$Kenyan Geography$q$, $q$Hell's Gate National Park is said to have inspired the landscape of which Disney film?$q$, $q$Frozen$q$, $q$Moana$q$, $q$The Lion King$q$, $q$Aladdin$q$, 'c', 'medium', $q$You can walk and cycle among zebras and giraffes there.$q$),
  ($q$Kenyan Sports$q$, $q$Which Kenyan was the first man to run the 3000 m steeplechase in under eight minutes?$q$, $q$Ezekiel Kemboi$q$, $q$Julius Kariuki$q$, $q$Brimin Kipruto$q$, $q$Moses Kiptanui$q$, 'd', 'hard', $q$He did it in Zurich in 1995.$q$),
  ($q$Kenyan Sports$q$, $q$How many Olympic steeplechase gold medals did Ezekiel Kemboi win?$q$, $q$One$q$, $q$Two$q$, $q$Three$q$, $q$Four$q$, 'b', 'medium', $q$He won at Athens 2004 and London 2012.$q$),
  ($q$Kenyan Sports$q$, $q$Which Moroccan ended Kenya's run of Olympic men's steeplechase golds at Tokyo 2020?$q$, $q$Hicham El Guerrouj$q$, $q$Said Aouita$q$, $q$Soufiane El Bakkali$q$, $q$Brahim Boulami$q$, 'c', 'hard', $q$Kenya had won every Olympic steeplechase gold from 1984 to 2016.$q$),
  ($q$Kenyan Sports$q$, $q$How many World Championship marathon titles did Catherine Ndereba win?$q$, $q$One$q$, $q$Three$q$, $q$Four$q$, $q$Two$q$, 'd', 'hard', $q$She won in 2003 and 2007.$q$),
  ($q$Kenyan Sports$q$, $q$Who became the first African woman to win the New York City Marathon, in 1994?$q$, $q$Tegla Loroupe$q$, $q$Catherine Ndereba$q$, $q$Joyce Chepchumba$q$, $q$Mary Keitany$q$, 'a', 'hard', $q$She won again in 1995.$q$),
  ($q$Kenyan Sports$q$, $q$Which Kenyan set a marathon world record of 2:04:55 in Berlin in 2003?$q$, $q$Patrick Makau$q$, $q$Haile Gebrselassie$q$, $q$Paul Tergat$q$, $q$Wilson Kipsang$q$, 'c', 'hard', $q$It was the first marathon world record under 2:05.$q$),
  ($q$Kenyan Sports$q$, $q$Who was the first person to run a marathon in under 2 hours 3 minutes, in Berlin in 2014?$q$, $q$Eliud Kipchoge$q$, $q$Geoffrey Mutai$q$, $q$Emmanuel Mutai$q$, $q$Dennis Kimetto$q$, 'd', 'hard', $q$His time was 2:02:57.$q$),
  ($q$Kenyan Sports$q$, $q$John Ngugi won the World Cross Country Championships how many times?$q$, $q$Five$q$, $q$Two$q$, $q$Three$q$, $q$Seven$q$, 'a', 'hard', $q$He was also the Olympic 5000 m champion in 1988.$q$),
  ($q$Kenyan Sports$q$, $q$At which Olympic Games did Kenya win its biggest medal haul of 14 medals?$q$, $q$London 2012$q$, $q$Beijing 2008$q$, $q$Rio 2016$q$, $q$Tokyo 2020$q$, 'b', 'hard', $q$Five of those 14 medals were gold.$q$),
  ($q$Kenyan Sports$q$, $q$Which Kenyan won both the 5000 m and the 10,000 m at the Paris 2024 Olympics?$q$, $q$Faith Kipyegon$q$, $q$Hellen Obiri$q$, $q$Agnes Ngetich$q$, $q$Beatrice Chebet$q$, 'd', 'hard', $q$Chebet also broke the 10,000 m world record in 2024.$q$),
  ($q$Kenyan Sports$q$, $q$Which Kenyan won the men's 800 m at the Paris 2024 Olympics?$q$, $q$Emmanuel Wanyonyi$q$, $q$David Rudisha$q$, $q$Wycliffe Kinyamal$q$, $q$Alfred Kipketer$q$, 'a', 'hard', $q$He ran 1:41.19 to win.$q$),
  ($q$Kenyan Sports$q$, $q$In which year did Kenya return to the Africa Cup of Nations after missing it since 2004?$q$, $q$2013$q$, $q$2019$q$, $q$2015$q$, $q$2017$q$, 'b', 'hard', $q$The 2019 tournament was held in Egypt.$q$),
  ($q$Kenyan Sports$q$, $q$Which Kenyan football club is nicknamed "K'Ogalo"?$q$, $q$AFC Leopards$q$, $q$Tusker FC$q$, $q$Gor Mahia$q$, $q$Bandari FC$q$, 'c', 'medium', $q$Gor Mahia and AFC Leopards meet in the Mashemeji Derby.$q$),
  ($q$Kenyan Sports$q$, $q$The Kipchoge Keino Stadium is in which Kenyan town?$q$, $q$Eldoret$q$, $q$Nakuru$q$, $q$Kisumu$q$, $q$Nyeri$q$, 'a', 'medium', $q$It is named after the Olympic champion Kipchoge Keino.$q$),
  ($q$Kenyan Sports$q$, $q$Which Kenyan javelin thrower became world champion in 2015 after learning technique from YouTube?$q$, $q$Elijah Manangoi$q$, $q$Julius Yego$q$, $q$Ferguson Rotich$q$, $q$Timothy Kitum$q$, 'b', 'hard', $q$He was nicknamed "the YouTube Man".$q$),
  ($q$Kenyan Sports$q$, $q$Hellen Obiri won 5000 m world titles in 2017 and which other year?$q$, $q$2015$q$, $q$2013$q$, $q$2019$q$, $q$2022$q$, 'c', 'hard', $q$She later won the New York City Marathon in 2023.$q$),
  ($q$Kenyan Sports$q$, $q$At Munich 1972, Kipchoge Keino won gold in which event?$q$, $q$The 1500 m$q$, $q$The 5000 m$q$, $q$The marathon$q$, $q$The 3000 m steeplechase$q$, 'd', 'hard', $q$He also won silver in the 1500 m at those Games.$q$),
  ($q$General Knowledge$q$, $q$Which scientist created the first widely used periodic table?$q$, $q$Marie Curie$q$, $q$Dmitri Mendeleev$q$, $q$Antoine Lavoisier$q$, $q$John Dalton$q$, 'b', 'medium', $q$He left gaps for elements that had not been discovered yet.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Peru?$q$, $q$Quito$q$, $q$Bogota$q$, $q$Lima$q$, $q$La Paz$q$, 'c', 'medium', $q$Lima sits on the Pacific coast.$q$),
  ($q$General Knowledge$q$, $q$Which river flows through Baghdad?$q$, $q$The Euphrates$q$, $q$The Nile$q$, $q$The Jordan$q$, $q$The Tigris$q$, 'd', 'medium', $q$The Tigris and Euphrates enclosed ancient Mesopotamia.$q$),
  ($q$General Knowledge$q$, $q$What is the highest mountain in South America?$q$, $q$Aconcagua$q$, $q$Chimborazo$q$, $q$Huascaran$q$, $q$Cotopaxi$q$, 'a', 'hard', $q$It stands in Argentina.$q$),
  ($q$General Knowledge$q$, $q$Which is the longest river in Europe?$q$, $q$The Danube$q$, $q$The Rhine$q$, $q$The Volga$q$, $q$The Thames$q$, 'c', 'hard', $q$It flows through Russia into the Caspian Sea.$q$),
  ($q$General Knowledge$q$, $q$What is the largest island in the world?$q$, $q$Madagascar$q$, $q$Borneo$q$, $q$New Guinea$q$, $q$Greenland$q$, 'd', 'medium', $q$Most of Greenland is covered by an ice sheet.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "Things Fall Apart"?$q$, $q$Chinua Achebe$q$, $q$Wole Soyinka$q$, $q$Ngũgĩ wa Thiong'o$q$, $q$Chimamanda Ngozi Adichie$q$, 'a', 'medium', $q$It was published in 1958.$q$),
  ($q$General Knowledge$q$, $q$What is the smallest bone in the human body?$q$, $q$The femur$q$, $q$The stapes$q$, $q$The radius$q$, $q$The patella$q$, 'b', 'hard', $q$It is found in the middle ear.$q$),
  ($q$General Knowledge$q$, $q$In which country is the historic city of Timbuktu?$q$, $q$Niger$q$, $q$Chad$q$, $q$Senegal$q$, $q$Mali$q$, 'd', 'medium', $q$It was a centre of learning in the Middle Ages.$q$),
  ($q$General Knowledge$q$, $q$Which language has the most native speakers in the world?$q$, $q$Mandarin Chinese$q$, $q$English$q$, $q$Spanish$q$, $q$Hindi$q$, 'a', 'medium', $q$English has the most speakers when non-native speakers are counted too.$q$),
  ($q$General Knowledge$q$, $q$Which gas makes up most of Earth's atmosphere?$q$, $q$Oxygen$q$, $q$Nitrogen$q$, $q$Carbon dioxide$q$, $q$Argon$q$, 'b', 'medium', $q$About 78% of the air is nitrogen.$q$),
  ($q$General Knowledge$q$, $q$Which vitamin does the body make when skin is exposed to sunlight?$q$, $q$Vitamin A$q$, $q$Vitamin C$q$, $q$Vitamin D$q$, $q$Vitamin K$q$, 'c', 'medium', $q$It helps the body absorb calcium.$q$),
  ($q$General Knowledge$q$, $q$Which country has more pyramids than Egypt?$q$, $q$Sudan$q$, $q$Libya$q$, $q$Ethiopia$q$, $q$Chad$q$, 'a', 'hard', $q$Sudan's Nubian pyramids are smaller and steeper than Egypt's.$q$),
  ($q$General Knowledge$q$, $q$What is the currency of Switzerland?$q$, $q$The euro$q$, $q$The Swiss franc$q$, $q$The krone$q$, $q$The lira$q$, 'b', 'medium', $q$Switzerland is not a member of the European Union.$q$)
) as v(cat, question_text, a, b, c, d, correct, difficulty, fact)
where not exists (select 1 from public.questions q where q.question_text = v.question_text);
