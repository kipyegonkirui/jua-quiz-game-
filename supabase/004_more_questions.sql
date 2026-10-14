-- ============================================================================
-- 004_more_questions.sql — question bank expansion (68 new questions)
-- Run in the Supabase SQL Editor. Safe to run more than once: a question whose
-- exact text already exists is skipped.
--
-- IMPORTANT: please fact-check every question before you ship. I only used
-- facts I'm confident about, but you are the editor-in-chief of this content.
-- ============================================================================

insert into public.questions
  (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty)
select c.id, v.question_text, v.option_a, v.option_b, v.option_c, v.option_d, v.correct_option, v.difficulty
from (values
  ('Kenyan History', 'Who was Kenya''s third President?', 'Mwai Kibaki', 'Uhuru Kenyatta', 'Raila Odinga', 'Daniel arap Moi', 'a', 'easy'),
  ('Kenyan History', 'Who became Kenya''s fifth President in 2022?', 'Raila Odinga', 'William Ruto', 'Uhuru Kenyatta', 'Musalia Mudavadi', 'b', 'easy'),
  ('Kenyan History', 'Who was Kenya''s first Prime Minister at independence in 1963?', 'Tom Mboya', 'Oginga Odinga', 'Jomo Kenyatta', 'Daniel arap Moi', 'c', 'medium'),
  ('Kenyan History', 'Which Kenyan environmentalist won the Nobel Peace Prize in 2004?', 'Grace Ogot', 'Lupita Nyong''o', 'Charity Ngilu', 'Wangari Maathai', 'd', 'easy'),
  ('Kenyan History', 'Madaraka Day, celebrated on 1 June, marks Kenya achieving what in 1963?', 'Internal self-government', 'Full independence', 'A new constitution', 'Republic status', 'a', 'medium'),
  ('Kenyan History', 'On which date is Kenya''s Jamhuri Day celebrated?', '1 June', '12 December', '20 October', '27 August', 'b', 'easy'),
  ('Kenyan History', 'On which date is Mashujaa Day (Heroes'' Day) celebrated in Kenya?', '1 June', '12 December', '20 October', '1 May', 'c', 'medium'),
  ('Kenyan History', 'Which Mau Mau leader was captured by colonial forces in 1956?', 'Tom Mboya', 'Bildad Kaggia', 'Pio Gama Pinto', 'Dedan Kimathi', 'd', 'medium'),
  ('Kenyan History', 'Which Kenyan politician and trade unionist was assassinated in Nairobi in 1969?', 'Tom Mboya', 'Pio Gama Pinto', 'J.M. Kariuki', 'Ronald Ngala', 'a', 'hard'),
  ('Kenyan History', 'Uhuru Kenyatta, Kenya''s fourth President, is the son of which earlier President?', 'Daniel arap Moi', 'Jomo Kenyatta', 'Mwai Kibaki', 'No earlier President', 'b', 'easy'),
  ('Kenyan History', 'Kenya returned to multiparty politics after Section 2A of the constitution was repealed in which year?', '1985', '1988', '1991', '1995', 'c', 'hard'),
  ('Kenyan Geography', 'What is the largest lake located entirely within Kenya?', 'Lake Victoria', 'Lake Naivasha', 'Lake Baringo', 'Lake Turkana', 'd', 'medium'),
  ('Kenyan Geography', 'Lake Turkana is nicknamed what?', 'The Jade Sea', 'The Blue Pearl', 'The Salt Sea', 'The Silver Lake', 'a', 'hard'),
  ('Kenyan Geography', 'Lake Nakuru National Park is famous for large flocks of which bird?', 'Pelicans', 'Flamingos', 'Ostriches', 'Cranes', 'b', 'easy'),
  ('Kenyan Geography', 'Which of these countries does NOT border Kenya?', 'Ethiopia', 'Uganda', 'Rwanda', 'Somalia', 'c', 'medium'),
  ('Kenyan Geography', 'Which Kenyan town is famously located on the equator?', 'Mombasa', 'Nairobi', 'Malindi', 'Nanyuki', 'd', 'medium'),
  ('Kenyan Geography', 'Mount Kilimanjaro, Africa''s tallest mountain, is located in which country?', 'Tanzania', 'Kenya', 'Uganda', 'Ethiopia', 'a', 'easy'),
  ('Kenyan Geography', 'Kisumu is a major Kenyan city on the shores of which lake?', 'Lake Turkana', 'Lake Victoria', 'Lake Nakuru', 'Lake Naivasha', 'b', 'easy'),
  ('Kenyan Geography', 'What is Kenya''s second-largest city?', 'Kisumu', 'Nakuru', 'Mombasa', 'Eldoret', 'c', 'easy'),
  ('Kenyan Geography', 'Hell''s Gate National Park lies close to which lake?', 'Lake Bogoria', 'Lake Turkana', 'Lake Magadi', 'Lake Naivasha', 'd', 'medium'),
  ('Kenyan Geography', 'Which Kenyan national park lies at the foot of Mount Kilimanjaro?', 'Amboseli National Park', 'Tsavo West National Park', 'Aberdare National Park', 'Meru National Park', 'a', 'medium'),
  ('Kenyan Geography', 'What is the name of Mount Kenya''s highest peak?', 'Lenana', 'Batian', 'Nelion', 'Point Pigott', 'b', 'hard'),
  ('Kenyan Geography', 'Which Kenyan island town has an Old Town that is a UNESCO World Heritage Site?', 'Wasini', 'Funzi', 'Lamu', 'Kilifi', 'c', 'medium'),
  ('Kenyan Geography', 'Kenya''s time zone, East Africa Time, is how many hours ahead of UTC?', '1 hour', '2 hours', '5 hours', '3 hours', 'd', 'medium'),
  ('Kenyan Wildlife & Culture', 'What does the Swahili greeting ''Karibu'' mean?', 'Welcome', 'Goodbye', 'Thank you', 'Sorry', 'a', 'easy'),
  ('Kenyan Wildlife & Culture', 'The Swahili phrase ''Hakuna matata'' means what?', 'Good luck', 'No worries', 'Come here', 'Be careful', 'b', 'easy'),
  ('Kenyan Wildlife & Culture', 'What does the Swahili word ''simba'' mean?', 'Elephant', 'Giraffe', 'Lion', 'Buffalo', 'c', 'easy'),
  ('Kenyan Wildlife & Culture', 'What does the Swahili word ''rafiki'' mean?', 'Teacher', 'Brother', 'Neighbour', 'Friend', 'd', 'easy'),
  ('Kenyan Wildlife & Culture', 'What number is ''saba'' in Swahili?', 'Seven', 'Five', 'Six', 'Nine', 'a', 'medium'),
  ('Kenyan Wildlife & Culture', 'What does the Swahili noun ''jua'' mean?', 'Moon', 'Sun', 'Rain', 'Star', 'b', 'easy'),
  ('Kenyan Wildlife & Culture', 'In Kenya, what is a ''matatu''?', 'A type of drum', 'A traditional dance', 'A privately run minibus taxi', 'A local market', 'c', 'easy'),
  ('Kenyan Wildlife & Culture', '''Nyama choma'', a Kenyan favourite, is what?', 'Fried fish', 'Boiled maize', 'Vegetable stew', 'Grilled meat', 'd', 'easy'),
  ('Kenyan Wildlife & Culture', '''Sukuma wiki'' is a popular Kenyan dish made from which vegetable?', 'Collard greens (kale)', 'Cabbage', 'Carrots', 'Pumpkin leaves', 'a', 'medium'),
  ('Kenyan Wildlife & Culture', 'The Maasai are well known for wearing brightly coloured cloth wraps called what?', 'Kanzu', 'Shuka', 'Dera', 'Gomesi', 'b', 'medium'),
  ('Kenyan Wildlife & Culture', 'The Maasai ''adumu'' is best known as what kind of dance?', 'A drumming dance', 'A water dance', 'A jumping dance', 'A harvest dance', 'c', 'hard'),
  ('Kenyan Wildlife & Culture', 'Which is Kenya''s largest ethnic group?', 'Luo', 'Kalenjin', 'Luhya', 'Kikuyu', 'd', 'medium'),
  ('Kenyan Wildlife & Culture', 'Ol Pejeta Conservancy is home to the last remaining members of which animal subspecies?', 'Northern white rhino', 'Mountain gorilla', 'Grevy''s zebra', 'Black leopard', 'a', 'hard'),
  ('Kenyan Wildlife & Culture', 'A group of lions is called what?', 'A herd', 'A pride', 'A pack', 'A troop', 'b', 'easy'),
  ('Kenyan Wildlife & Culture', 'Which of these is NOT one of the ''Big Five'' game animals?', 'Lion', 'Elephant', 'Giraffe', 'Buffalo', 'c', 'medium'),
  ('Kenyan Sports', 'Eliud Kipchoge won Olympic marathon gold at which two Games?', 'Beijing 2008 and London 2012', 'London 2012 and Rio 2016', 'Tokyo 2020 and Paris 2024', 'Rio 2016 and Tokyo 2020', 'd', 'medium'),
  ('Kenyan Sports', 'Faith Kipyegon is a multiple Olympic champion in which event?', '1500 metres', '800 metres', '5000 metres', 'Marathon', 'a', 'medium'),
  ('Kenyan Sports', 'What is the nickname of Kenya''s national rugby sevens team?', 'Simbas', 'Shujaa', 'Cheetahs', 'Harambee Stars', 'b', 'medium'),
  ('Kenyan Sports', 'Tegla Loroupe was the first African woman to win which major marathon, in 1994?', 'Boston Marathon', 'London Marathon', 'New York City Marathon', 'Berlin Marathon', 'c', 'hard'),
  ('Kenyan Sports', 'Kenyan javelin thrower Julius Yego is nicknamed ''The YouTube Man'' because he learned technique from what?', 'A local radio show', 'A football coach', 'A film director', 'Online videos', 'd', 'medium'),
  ('Kenyan Sports', 'How long is a full marathon?', '42.195 km', '21.1 km', '40 km', '50 km', 'a', 'easy'),
  ('Kenyan Sports', 'The Safari Rally returned to the World Rally Championship calendar in which year?', '2015', '2021', '2018', '2024', 'b', 'hard'),
  ('Kenyan Sports', 'Which two Kenyan football clubs contest the ''Mashemeji Derby''?', 'Tusker and Ulinzi Stars', 'Sofapaka and Bandari', 'Gor Mahia and AFC Leopards', 'Kakamega Homeboyz and Posta Rangers', 'c', 'medium'),
  ('Kenyan Sports', 'The Moi International Sports Centre is located in which part of Nairobi?', 'Karen', 'Westlands', 'Embakasi', 'Kasarani', 'd', 'hard'),
  ('Kenyan Sports', 'In which year did Kenya''s cricket team reach the World Cup semi-finals?', '2003', '1996', '1999', '2011', 'a', 'hard'),
  ('Kenyan Sports', 'David Rudisha set his 800m world record at the Olympics in which city?', 'Beijing', 'London', 'Rio de Janeiro', 'Athens', 'b', 'medium'),
  ('General Knowledge', 'Which is the largest planet in our solar system?', 'Saturn', 'Neptune', 'Jupiter', 'Earth', 'c', 'easy'),
  ('General Knowledge', 'What is the chemical formula for water?', 'CO2', 'O2', 'NaCl', 'H2O', 'd', 'easy'),
  ('General Knowledge', 'How many days are there in a leap year?', '366', '365', '364', '367', 'a', 'easy'),
  ('General Knowledge', 'What is the capital city of Uganda?', 'Kigali', 'Kampala', 'Dodoma', 'Entebbe', 'b', 'medium'),
  ('General Knowledge', 'Which is the longest river in Africa?', 'The Congo', 'The Niger', 'The Nile', 'The Zambezi', 'c', 'easy'),
  ('General Knowledge', 'How many players are on the field for one football (soccer) team during a match?', '9', '10', '12', '11', 'd', 'easy'),
  ('General Knowledge', 'How many bones are there in an adult human body?', '206', '106', '306', '412', 'a', 'medium'),
  ('General Knowledge', 'What is the smallest prime number?', '0', '2', '1', '3', 'b', 'medium'),
  ('General Knowledge', 'Which is the largest continent by area?', 'Africa', 'North America', 'Asia', 'Europe', 'c', 'easy'),
  ('General Knowledge', 'Which Kenyan author wrote ''A Grain of Wheat'' and ''Petals of Blood''?', 'Binyavanga Wainaina', 'Meja Mwangi', 'Chinua Achebe', 'Ngugi wa Thiong''o', 'd', 'medium'),
  ('General Knowledge', 'Which gas do plants absorb from the air for photosynthesis?', 'Carbon dioxide', 'Oxygen', 'Nitrogen', 'Hydrogen', 'a', 'medium'),
  ('General Knowledge', 'Which planet is closest to the Sun?', 'Venus', 'Mercury', 'Mars', 'Earth', 'b', 'easy'),
  ('General Knowledge', 'What is the square root of 144?', '10', '14', '12', '16', 'c', 'easy'),
  ('General Knowledge', 'Which country uses the rand as its currency?', 'Botswana', 'Namibia', 'Zambia', 'South Africa', 'd', 'medium'),
  ('General Knowledge', 'Which is the hardest natural substance?', 'Diamond', 'Gold', 'Iron', 'Quartz', 'a', 'easy'),
  ('General Knowledge', 'Where is the headquarters of the African Union?', 'Nairobi', 'Addis Ababa', 'Abuja', 'Cairo', 'b', 'medium'),
  ('General Knowledge', 'What is the largest hot desert in the world?', 'The Kalahari', 'The Gobi', 'The Sahara', 'The Namib', 'c', 'easy'),
  ('General Knowledge', 'Nairobi hosts the headquarters of which United Nations programme?', 'UNICEF', 'WHO', 'UNESCO', 'UNEP (Environment)', 'd', 'hard')
) as v(category, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty)
join public.categories c on c.name = v.category
where not exists (
  select 1 from public.questions x where x.question_text = v.question_text
);
