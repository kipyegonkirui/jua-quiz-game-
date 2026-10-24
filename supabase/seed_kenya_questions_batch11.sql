-- ============================================================================
-- seed_kenya_questions_batch11.sql
-- 50 more questions (mostly hard and medium), each with a "Did you know?" line.
-- Run AFTER 024_content_quality.sql. Safe to re-run (skips existing question text).
-- IMPORTANT: have a Kenyan reviewer check every fact (see batch11_review.md) before release.
-- ============================================================================

insert into public.categories (name)
select c.name from (values ($q$Kenyan Food & Culture$q$), ($q$Kenyan Geography$q$)) as c(name)
where not exists (select 1 from public.categories x where x.name = c.name);

insert into public.questions
  (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty, did_you_know)
select (select id from public.categories where name = v.cat limit 1),
       v.question_text, v.a, v.b, v.c, v.d, v.correct, v.difficulty, v.fact
from (values
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Nandi County?$q$, $q$Eldoret$q$, $q$Kitale$q$, $q$Iten$q$, $q$Kapsabet$q$, 'd', 'medium', $q$Kapsabet is known for producing many top runners.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of West Pokot County?$q$, $q$Kapenguria$q$, $q$Kitale$q$, $q$Lodwar$q$, $q$Maralal$q$, 'a', 'medium', $q$The Kapenguria Six were tried there.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Turkana County?$q$, $q$Kitale$q$, $q$Lodwar$q$, $q$Maralal$q$, $q$Marsabit$q$, 'b', 'medium', $q$Lodwar lies west of Lake Turkana.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Samburu County?$q$, $q$Isiolo$q$, $q$Rumuruti$q$, $q$Maralal$q$, $q$Lodwar$q$, 'c', 'medium', $q$Maralal hosts an annual camel derby.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Laikipia County?$q$, $q$Rumuruti$q$, $q$Nanyuki$q$, $q$Nyahururu$q$, $q$Maralal$q$, 'a', 'hard', $q$Nanyuki is bigger, but Rumuruti is the county capital.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Nyandarua County?$q$, $q$Nyahururu$q$, $q$Ol Kalou$q$, $q$Naivasha$q$, $q$Nyeri$q$, 'b', 'hard', $q$Nyandarua is named after the Aberdare range.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Makueni County?$q$, $q$Machakos$q$, $q$Kitui$q$, $q$Wote$q$, $q$Emali$q$, 'c', 'hard', $q$Makueni is mostly Kamba country.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Kirinyaga County?$q$, $q$Embu$q$, $q$Nyeri$q$, $q$Murang'a$q$, $q$Kerugoya$q$, 'd', 'hard', $q$Kerugoya and the neighbouring town of Kutus are close together.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Elgeyo-Marakwet County?$q$, $q$Eldoret$q$, $q$Iten$q$, $q$Kapsabet$q$, $q$Kabarnet$q$, 'b', 'hard', $q$Iten is often called the "home of champions".$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Baringo County?$q$, $q$Nakuru$q$, $q$Marigat$q$, $q$Kabarnet$q$, $q$Eldama Ravine$q$, 'c', 'hard', $q$Kabarnet sits on the Tugen Hills.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Vihiga County?$q$, $q$Kakamega$q$, $q$Kisumu$q$, $q$Hamisi$q$, $q$Mbale$q$, 'd', 'hard', $q$Vihiga is one of Kenya's most densely populated counties.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is the capital of Tana River County?$q$, $q$Hola$q$, $q$Garissa$q$, $q$Malindi$q$, $q$Lamu$q$, 'a', 'hard', $q$The Hola detention camp was nearby.$q$),
  ($q$Kenyan Geography$q$, $q$Amboseli National Park lies in which county?$q$, $q$Narok$q$, $q$Taita-Taveta$q$, $q$Kajiado$q$, $q$Makueni$q$, 'c', 'medium', $q$Amboseli is known for its large elephant herds.$q$),
  ($q$Kenyan Geography$q$, $q$Nanyuki town lies in which county?$q$, $q$Meru$q$, $q$Nyeri$q$, $q$Isiolo$q$, $q$Laikipia$q$, 'd', 'medium', $q$The equator passes close to the town.$q$),
  ($q$Kenyan Geography$q$, $q$Hell's Gate National Park lies in which county?$q$, $q$Nakuru$q$, $q$Narok$q$, $q$Kajiado$q$, $q$Baringo$q$, 'a', 'medium', $q$It is next to Lake Naivasha.$q$),
  ($q$Kenyan Geography$q$, $q$Ol Pejeta Conservancy lies in which county?$q$, $q$Meru$q$, $q$Laikipia$q$, $q$Samburu$q$, $q$Isiolo$q$, 'b', 'medium', $q$It is the biggest black rhino sanctuary in East Africa.$q$),
  ($q$Kenyan Geography$q$, $q$The Galana River flows through which national park?$q$, $q$Amboseli$q$, $q$Meru$q$, $q$Nairobi National Park$q$, $q$Tsavo East$q$, 'd', 'hard', $q$It later joins the Sabaki and flows to the Indian Ocean.$q$),
  ($q$Kenyan Geography$q$, $q$The Mara River flows into which lake?$q$, $q$Lake Victoria$q$, $q$Lake Turkana$q$, $q$Lake Naivasha$q$, $q$Lake Baringo$q$, 'a', 'medium', $q$It flows from Kenya into Tanzania before reaching the lake.$q$),
  ($q$Kenyan Geography$q$, $q$The "Seven Forks" scheme on the Tana River produces what?$q$, $q$Rice$q$, $q$Hydroelectric power$q$, $q$Salt$q$, $q$Fish$q$, 'b', 'hard', $q$It includes the Masinga, Kamburu and Kiambere dams.$q$),
  ($q$Kenyan Geography$q$, $q$Olkaria, near Lake Naivasha, is a major source of what?$q$, $q$Soda ash$q$, $q$Coal$q$, $q$Geothermal power$q$, $q$Natural gas$q$, 'c', 'hard', $q$Kenya is one of Africa's biggest geothermal producers.$q$),
  ($q$Kenyan Geography$q$, $q$Loiyangalani, on Lake Turkana, is home to what large project?$q$, $q$A wind farm$q$, $q$A gold mine$q$, $q$A railway depot$q$, $q$A sugar plant$q$, 'a', 'hard', $q$The Lake Turkana Wind Power project is among the biggest in Africa.$q$),
  ($q$Kenyan Geography$q$, $q$Garissa town lies on which river?$q$, $q$The Athi$q$, $q$The Tana$q$, $q$The Mara$q$, $q$The Nzoia$q$, 'b', 'hard', $q$Garissa is the largest town in north-eastern Kenya.$q$),
  ($q$Kenyan Geography$q$, $q$The Giraffe Centre in Nairobi protects which subspecies of giraffe?$q$, $q$Reticulated giraffe$q$, $q$Masai giraffe$q$, $q$Rothschild's giraffe$q$, $q$Angolan giraffe$q$, 'c', 'hard', $q$Visitors can feed the giraffes from a raised platform.$q$),
  ($q$Kenyan Geography$q$, $q$The Bomas of Kenya in Nairobi is best known for what?$q$, $q$Horse racing$q$, $q$Car auctions$q$, $q$Tea tasting$q$, $q$Traditional dance and culture shows$q$, 'd', 'medium', $q$It displays homesteads of many Kenyan communities.$q$),
  ($q$Kenyan Geography$q$, $q$The Nairobi suburb of Karen is named after which writer?$q$, $q$Beryl Markham$q$, $q$Karen Blixen$q$, $q$Joy Adamson$q$, $q$Elspeth Huxley$q$, 'b', 'medium', $q$Her former house is now a museum.$q$),
  ($q$Kenyan Geography$q$, $q$Haller Park in Mombasa was turned from what into a wildlife park?$q$, $q$A rubbish dump$q$, $q$A sugar farm$q$, $q$A cement quarry$q$, $q$A railway yard$q$, 'c', 'hard', $q$Rene Haller replanted the area with trees and animals.$q$),
  ($q$Kenyan Geography$q$, $q$Egerton Castle, near Njoro, was built by which man?$q$, $q$Lord Delamere$q$, $q$Sir Evelyn Baring$q$, $q$Cecil Rhodes$q$, $q$Lord Maurice Egerton$q$, 'd', 'hard', $q$He left his land for an agricultural college, now Egerton University.$q$),
  ($q$Kenyan Geography$q$, $q$Kit Mikayi, a famous rock near Kisumu, is sacred to which community?$q$, $q$The Luo$q$, $q$The Luhya$q$, $q$The Kisii$q$, $q$The Kalenjin$q$, 'a', 'hard', $q$The name means "stone of the first wife".$q$),
  ($q$Kenyan Food & Culture$q$, $q$The Bukusu are a sub-group of which larger community?$q$, $q$The Luo$q$, $q$The Kalenjin$q$, $q$The Luhya$q$, $q$The Gusii$q$, 'c', 'hard', $q$The Luhya are made up of many sub-groups, including the Maragoli and Isukha.$q$),
  ($q$Kenyan Food & Culture$q$, $q$The Kipsigis are a sub-group of which larger community?$q$, $q$The Luo$q$, $q$The Kamba$q$, $q$The Meru$q$, $q$The Kalenjin$q$, 'd', 'hard', $q$They live mainly around Kericho and Bomet.$q$),
  ($q$Kenyan Food & Culture$q$, $q$The Maragoli are a sub-group of which larger community?$q$, $q$The Luhya$q$, $q$The Luo$q$, $q$The Kisii$q$, $q$The Kalenjin$q$, 'a', 'hard', $q$Most Maragoli live in Vihiga County.$q$),
  ($q$Kenyan Food & Culture$q$, $q$The Tugen are part of which larger community?$q$, $q$The Luhya$q$, $q$The Kalenjin$q$, $q$The Luo$q$, $q$The Meru$q$, 'b', 'hard', $q$They live mostly around Baringo County.$q$),
  ($q$Kenyan Food & Culture$q$, $q$Ekegusii is the language of which community?$q$, $q$The Kuria$q$, $q$The Meru$q$, $q$The Kamba$q$, $q$The Gusii$q$, 'd', 'medium', $q$The Gusii live in Kisii and Nyamira counties.$q$),
  ($q$Kenyan Food & Culture$q$, $q$Kimeru is the language of which community?$q$, $q$The Meru$q$, $q$The Embu$q$, $q$The Kikuyu$q$, $q$The Kamba$q$, 'a', 'medium', $q$The Meru live on the slopes of Mount Kenya and the Nyambene Hills.$q$),
  ($q$Kenyan Food & Culture$q$, $q$Kikamba is the language of which community?$q$, $q$The Meru$q$, $q$The Kamba$q$, $q$The Embu$q$, $q$The Taita$q$, 'b', 'medium', $q$The Kamba live mostly in Machakos, Kitui and Makueni.$q$),
  ($q$Kenyan Food & Culture$q$, $q$Dholuo is the language of which community?$q$, $q$The Luhya$q$, $q$The Gusii$q$, $q$The Luo$q$, $q$The Teso$q$, 'c', 'medium', $q$The Luo live mainly around Lake Victoria.$q$),
  ($q$Kenyan Food & Culture$q$, $q$The Teso of Kenya live mainly in which county?$q$, $q$Busia$q$, $q$Siaya$q$, $q$Bungoma$q$, $q$Homa Bay$q$, 'a', 'hard', $q$They speak Ateso, the same language as the Teso of Uganda.$q$),
  ($q$Kenyan Food & Culture$q$, $q$The Borana live mainly in which part of Kenya?$q$, $q$The coast$q$, $q$The north$q$, $q$The south-west$q$, $q$The central highlands$q$, 'b', 'hard', $q$Their homeland stretches from northern Kenya into southern Ethiopia.$q$),
  ($q$Kenyan Food & Culture$q$, $q$The Giriama are the largest group of which coastal people?$q$, $q$The Swahili$q$, $q$The Taita$q$, $q$The Mijikenda$q$, $q$The Pokomo$q$, 'c', 'hard', $q$The Giriama live mainly in Kilifi County.$q$),
  ($q$Kenyan Food & Culture$q$, $q$What does the name "Mijikenda" mean?$q$, $q$Nine rivers$q$, $q$Nine chiefs$q$, $q$Nine hills$q$, $q$Nine towns$q$, 'd', 'hard', $q$It refers to nine related groups along the coast.$q$),
  ($q$Kenyan Food & Culture$q$, $q$Which community is the second-largest in Kenya, after the Kikuyu?$q$, $q$The Luo$q$, $q$The Luhya$q$, $q$The Kalenjin$q$, $q$The Kamba$q$, 'b', 'hard', $q$The 2019 census counted more than 6.8 million Luhya.$q$),
  ($q$Kenyan Food & Culture$q$, $q$Kenya is home to more than how many ethnic communities?$q$, $q$10$q$, $q$20$q$, $q$40$q$, $q$100$q$, 'c', 'medium', $q$Swahili and English are the official languages that connect them.$q$),
  ($q$Kenyan Food & Culture$q$, $q$In Kikuyu tradition, what is "ruracio"?$q$, $q$A harvest dance$q$, $q$A boys' initiation$q$, $q$A funeral feast$q$, $q$The bride-price ceremony$q$, 'd', 'hard', $q$Families from both sides meet to negotiate and celebrate.$q$),
  ($q$Kenyan Food & Culture$q$, $q$What is the "Nyumba Kumi" initiative?$q$, $q$A community policing idea$q$, $q$A savings scheme$q$, $q$A farming loan$q$, $q$A school feeding scheme$q$, 'a', 'medium', $q$"Nyumba kumi" means "ten houses" in Swahili.$q$),
  ($q$Kenyan Food & Culture$q$, $q$In Kenya, what does "jua kali" refer to?$q$, $q$A type of tea$q$, $q$A matatu route$q$, $q$Small outdoor workshops and the informal sector$q$, $q$A rainy season$q$, 'c', 'medium', $q$It literally means "fierce sun".$q$),
  ($q$Kenyan Food & Culture$q$, $q$What is a "mama mboga"?$q$, $q$A school cook$q$, $q$A matatu conductor$q$, $q$A midwife$q$, $q$A vegetable seller$q$, 'd', 'medium', $q$"Mboga" means vegetables in Swahili.$q$),
  ($q$Kenyan Food & Culture$q$, $q$What is a "chama" in Kenya?$q$, $q$A group savings club$q$, $q$A football team$q$, $q$A church choir$q$, $q$A traditional court$q$, 'a', 'medium', $q$Members pay in regularly and take turns to receive the pot.$q$),
  ($q$Kenyan Food & Culture$q$, $q$What are "mitumba" in Kenya?$q$, $q$Fishing nets$q$, $q$Second-hand clothes$q$, $q$Wooden spoons$q$, $q$Cooking pots$q$, 'b', 'medium', $q$Mitumba markets sell used clothing from all over the world.$q$),
  ($q$Kenyan Food & Culture$q$, $q$What is a "mkokoteni"?$q$, $q$A bicycle taxi$q$, $q$A small boat$q$, $q$A donkey saddle$q$, $q$A handcart$q$, 'd', 'hard', $q$Handcarts are used to move goods around Kenyan towns.$q$),
  ($q$Kenyan Food & Culture$q$, $q$What is a "kibanda" in Kenyan towns?$q$, $q$A small kiosk or stall$q$, $q$A police post$q$, $q$A rooftop garden$q$, $q$A cattle pen$q$, 'a', 'medium', $q$Many people buy snacks and airtime at a kibanda.$q$)
) as v(cat, question_text, a, b, c, d, correct, difficulty, fact)
where not exists (select 1 from public.questions q where q.question_text = v.question_text);
