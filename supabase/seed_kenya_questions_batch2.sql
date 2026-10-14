-- ============================================================================
-- Jua Quiz — Phase 0: first large batch of NEW questions (50)
-- Run after seed_kenya_questions.sql. Every row sets an explicit difficulty
-- and uses wording not present in batch 1, so there are no duplicates.
-- ============================================================================

-- ----------------------------------------------------------------- History --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty) values
((select id from public.categories where name = 'Kenyan History'),
  'Who was Kenya''s first Vice President?', 'Jaramogi Oginga Odinga', 'Daniel arap Moi', 'Mwai Kibaki', 'Tom Mboya', 'a', 'medium'),
((select id from public.categories where name = 'Kenyan History'),
  'In which year was the British East Africa Protectorate (later Kenya) formally established?', '1885', '1895', '1905', '1920', 'b', 'medium'),
((select id from public.categories where name = 'Kenyan History'),
  'Jomo Kenyatta was imprisoned during the Kapenguria trial in which decade?', '1930s', '1950s', '1940s', '1960s', 'b', 'medium'),
((select id from public.categories where name = 'Kenyan History'),
  'The colonial administration moved Kenya''s capital from Mombasa to Nairobi in which year?', '1895', '1907', '1920', '1948', 'b', 'medium'),
((select id from public.categories where name = 'Kenyan History'),
  'Who was Kenya''s third President?', 'Jomo Kenyatta', 'Daniel arap Moi', 'Mwai Kibaki', 'Uhuru Kenyatta', 'c', 'easy'),
((select id from public.categories where name = 'Kenyan History'),
  'Which town served as the British colonial capital before Nairobi?', 'Machakos', 'Mombasa', 'Kisumu', 'Eldoret', 'b', 'medium'),
((select id from public.categories where name = 'Kenyan History'),
  'Wangari Maathai won the Nobel Peace Prize in which year?', '2002', '2003', '2004', '2005', 'c', 'medium');

-- -------------------------------------------------------------- Geography --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty) values
((select id from public.categories where name = 'Kenyan Geography'),
  'Which is the longest river that flows entirely within Kenya?', 'Tana', 'Athi', 'Nzoia', 'Yala', 'a', 'medium'),
((select id from public.categories where name = 'Kenyan Geography'),
  'How many main peaks does Mount Kenya have?', '1', '2', '3', '4', 'c', 'hard'),
((select id from public.categories where name = 'Kenyan Geography'),
  'Which Kenyan lake is most famous for its large flamingo population?', 'Lake Victoria', 'Lake Nakuru', 'Lake Turkana', 'Lake Baringo', 'b', 'easy'),
((select id from public.categories where name = 'Kenyan Geography'),
  'Lake Turkana was formerly known by which name?', 'Lake Albert', 'Lake Rudolf', 'Lake Naivasha', 'Lake Eyasi', 'b', 'medium'),
((select id from public.categories where name = 'Kenyan Geography'),
  'The equator passes through which Kenyan town?', 'Nanyuki', 'Nakuru', 'Eldoret', 'Kitale', 'a', 'medium'),
((select id from public.categories where name = 'Kenyan Geography'),
  'Lamu Old Town sits on which island?', 'Lamu Island', 'Mombasa Island', 'Wasini Island', 'Funzi Island', 'a', 'medium'),
((select id from public.categories where name = 'Kenyan Geography'),
  'Which is the largest county in Kenya by area?', 'Turkana', 'Marsabit', 'Wajir', 'Garissa', 'a', 'hard'),
((select id from public.categories where name = 'Kenyan Geography'),
  'The city of Kisumu lies on the shores of which lake?', 'Lake Turkana', 'Lake Naivasha', 'Lake Baringo', 'Lake Victoria', 'd', 'easy'),
((select id from public.categories where name = 'Kenyan Geography'),
  'Which is the second-highest mountain in Kenya?', 'Mount Kenya', 'Mount Elgon', 'Mount Longonot', 'Mount Satima', 'b', 'medium');

-- -------------------------------------------------- Wildlife & Culture --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty) values
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'Which animal is the national animal of Kenya?', 'Lion', 'Leopard', 'Cheetah', 'Buffalo', 'a', 'easy'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'Besides Nakuru, which soda lake is also famous for flamingos?', 'Lake Bogoria', 'Lake Turkana', 'Lake Baringo', 'Lake Victoria', 'a', 'hard'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'The Swahili dish "nyama choma" is what?', 'Roasted meat', 'Fried fish', 'Boiled maize', 'Spiced rice', 'a', 'easy'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'In the Maa language, "Mara" means what?', 'Spotted', 'River', 'Hills', 'Plains', 'a', 'hard'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'Which community is famous for the adumu jumping dance?', 'The Maasai', 'The Luo', 'The Kikuyu', 'The Kalenjin', 'a', 'easy'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'The African buffalo is also commonly called the?', 'Water buffalo', 'Cape buffalo', 'Bush buffalo', 'Savanna buffalo', 'b', 'medium'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'In Swahili, "Jambo" means what?', 'Hello', 'Thank you', 'Goodbye', 'Sorry', 'a', 'easy'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'In Swahili, "asante" means what?', 'Hello', 'Thank you', 'Please', 'Sorry', 'b', 'easy');

-- ----------------------------------------------------------------- Sports --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty) values
((select id from public.categories where name = 'Kenyan Sports'),
  'Who won Kenya''s first Olympic gold medal, in the 10,000m at the 1968 Mexico City Games?', 'Naftali Temu', 'Kipchoge Keino', 'Wilson Kiprugut', 'Ben Jipcho', 'a', 'hard'),
((select id from public.categories where name = 'Kenyan Sports'),
  'Kenya''s first-ever Olympic medal (Wilson Kiprugut, 1964) came in which event?', '400m', '800m', '1500m', 'Marathon', 'b', 'medium'),
((select id from public.categories where name = 'Kenyan Sports'),
  'Who set the men''s marathon world record of 2:00:35 in Chicago in 2023?', 'Eliud Kipchoge', 'Kelvin Kiptum', 'Geoffrey Kamworor', 'Brigid Kosgei', 'b', 'medium'),
((select id from public.categories where name = 'Kenyan Sports'),
  'Brigid Kosgei set the women''s marathon world record in which city in 2019?', 'London', 'Chicago', 'Berlin', 'Tokyo', 'b', 'hard'),
((select id from public.categories where name = 'Kenyan Sports'),
  'Which Kenyan won the 3000m steeplechase Olympic gold in both 2004 and 2012?', 'Ezekiel Kemboi', 'Conseslus Kipruto', 'Brimin Kipruto', 'Amos Biwott', 'a', 'medium'),
((select id from public.categories where name = 'Kenyan Sports'),
  'The national motto word "Harambee" means what?', 'Pull together', 'Run fast', 'Stand tall', 'Work hard', 'a', 'easy');

-- -------------------------------------------------------- General Knowledge --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty) values
((select id from public.categories where name = 'General Knowledge'),
  'Which is the largest national park in Kenya?', 'Tsavo', 'Amboseli', 'Nakuru', 'Aberdare', 'a', 'medium'),
((select id from public.categories where name = 'General Knowledge'),
  'What is the capital city of Tanzania?', 'Dar es Salaam', 'Dodoma', 'Arusha', 'Mwanza', 'b', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'At sea level, water boils at what temperature in degrees Celsius?', '90', '100', '110', '212', 'b', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'Which gas do plants absorb from the air for photosynthesis?', 'Oxygen', 'Nitrogen', 'Carbon dioxide', 'Hydrogen', 'c', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'How many bones are in the adult human body?', '201', '206', '212', '300', 'b', 'medium'),
((select id from public.categories where name = 'General Knowledge'),
  'Which is the smallest planet in our solar system?', 'Mars', 'Mercury', 'Venus', 'Earth', 'b', 'medium'),
((select id from public.categories where name = 'General Knowledge'),
  'The Great Wall is located in which country?', 'Japan', 'India', 'China', 'Mongolia', 'c', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'Who wrote the novel "The River Between"?', 'Ngugi wa Thiong''o', 'Chinua Achebe', 'Meja Mwangi', 'Grace Ogot', 'a', 'medium'),
((select id from public.categories where name = 'General Knowledge'),
  'The name Nairobi comes from the Maasai phrase "Enkare Nairobi", meaning what?', 'Cool waters', 'Cold wind', 'Green city', 'Red dust', 'a', 'hard'),
((select id from public.categories where name = 'General Knowledge'),
  'Which is the largest hot desert in the world?', 'Sahara', 'Gobi', 'Kalahari', 'Arabian', 'a', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'Jamhuri Day (Independence Day) is celebrated on which date?', 'December 12', 'June 1', 'October 20', 'August 27', 'a', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'Madaraka Day marks what occasion?', 'Full independence', 'Self-governance', 'Becoming a republic', 'New constitution', 'b', 'medium'),
((select id from public.categories where name = 'General Knowledge'),
  'What is the capital city of Ethiopia?', 'Addis Ababa', 'Asmara', 'Kampala', 'Kigali', 'a', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'What is the capital city of Uganda?', 'Kampala', 'Kigali', 'Bujumbura', 'Juba', 'a', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'What is the capital city of Rwanda?', 'Bujumbura', 'Kampala', 'Kigali', 'Dodoma', 'c', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'Which Kenyan county is most famous for tea production?', 'Kericho', 'Nyeri', 'Kakamega', 'Meru', 'a', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'The Standard Gauge Railway connects Nairobi to which coastal city?', 'Nairobi', 'Mombasa', 'Malindi', 'Lamu', 'b', 'easy'),
((select id from public.categories where name = 'General Knowledge'),
  'Which animals hold the shield on Kenya''s coat of arms?', 'Lions', 'Elephants', 'Eagles', 'Rhinos', 'a', 'medium'),
((select id from public.categories where name = 'General Knowledge'),
  'Mount Longonot is what type of mountain?', 'Dormant volcano', 'Block mountain', 'Fold mountain', 'Plateau', 'a', 'medium'),
((select id from public.categories where name = 'General Knowledge'),
  'Which is the longest river in Africa?', 'Nile', 'Congo', 'Niger', 'Zambezi', 'a', 'easy');

-- Verify count and uniqueness (run manually after):
-- select count(*) from public.questions;
-- select question_text, count(*) from public.questions group by question_text having count(*) > 1;
