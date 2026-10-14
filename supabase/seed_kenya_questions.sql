-- ============================================================================
-- Jua Quiz — starter question bank
-- Run this AFTER schema.sql, in the same SQL Editor. Gives you enough
-- questions for several days of challenges (5 questions/day) right away.
-- Add more any time through the admin panel or by editing this pattern.
-- ============================================================================

insert into public.categories (name) values
  ('Kenyan History'),
  ('Kenyan Geography'),
  ('Kenyan Wildlife & Culture'),
  ('Kenyan Sports'),
  ('General Knowledge');

-- ---------------------------------------------------------------- History --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option) values
((select id from public.categories where name = 'Kenyan History'),
  'In what year did Kenya gain independence from Britain?', '1960', '1963', '1965', '1970', 'b'),
((select id from public.categories where name = 'Kenyan History'),
  'Who was Kenya''s first President?', 'Daniel arap Moi', 'Jomo Kenyatta', 'Mwai Kibaki', 'Uhuru Kenyatta', 'b'),
((select id from public.categories where name = 'Kenyan History'),
  'Kenya''s current constitution was promulgated in which year?', '2002', '2005', '2010', '2013', 'c'),
((select id from public.categories where name = 'Kenyan History'),
  'Who was Kenya''s second President?', 'Jomo Kenyatta', 'Daniel arap Moi', 'Mwai Kibaki', 'Raila Odinga', 'b'),
((select id from public.categories where name = 'Kenyan History'),
  'The Mau Mau uprising of the 1950s was a rebellion against which colonial power?', 'France', 'Germany', 'Britain', 'Portugal', 'c'),
((select id from public.categories where name = 'Kenyan History'),
  'Kenya became a republic, with a president as head of state, in which year?', '1963', '1964', '1966', '1969', 'b');

-- --------------------------------------------------------------- Geography --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option) values
((select id from public.categories where name = 'Kenyan Geography'),
  'What is the capital city of Kenya?', 'Mombasa', 'Kisumu', 'Nairobi', 'Nakuru', 'c'),
((select id from public.categories where name = 'Kenyan Geography'),
  'What is the highest mountain in Kenya?', 'Mount Kilimanjaro', 'Mount Kenya', 'Mount Elgon', 'Mount Longonot', 'b'),
((select id from public.categories where name = 'Kenyan Geography'),
  'Into how many counties is Kenya divided?', '37', '42', '47', '52', 'c'),
((select id from public.categories where name = 'Kenyan Geography'),
  'Which major geological feature runs north to south through Kenya?', 'The Sahara Desert', 'The Great Rift Valley', 'The Congo Basin', 'The Atlas Mountains', 'b'),
((select id from public.categories where name = 'Kenyan Geography'),
  'Kenya borders which large lake, shared with Uganda and Tanzania?', 'Lake Tanganyika', 'Lake Malawi', 'Lake Victoria', 'Lake Turkana', 'c'),
((select id from public.categories where name = 'Kenyan Geography'),
  'Which Kenyan city is the country''s main port on the Indian Ocean?', 'Nairobi', 'Mombasa', 'Kisumu', 'Eldoret', 'b');

-- ------------------------------------------------------- Wildlife & Culture --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option) values
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'The Maasai Mara is famous for hosting the annual "Great Migration" of which animal?', 'Elephants', 'Zebras', 'Wildebeest', 'Giraffes', 'c'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'Which two languages are Kenya''s official languages?', 'Swahili and French', 'English and Swahili', 'English and Arabic', 'Swahili and Amharic', 'b'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'Ugali, a Kenyan staple food, is made primarily from what?', 'Rice', 'Maize (corn) flour', 'Wheat flour', 'Cassava', 'b'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'The "Big Five" African game animals include the lion, leopard, elephant, buffalo, and which other animal?', 'Cheetah', 'Hippopotamus', 'Rhinoceros', 'Zebra', 'c'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'Which community is traditionally known for a cattle-centred, pastoralist way of life in the Rift Valley region?', 'The Maasai', 'The Luo', 'The Kikuyu', 'The Swahili', 'a'),
((select id from public.categories where name = 'Kenyan Wildlife & Culture'),
  'Which colour does NOT appear on the Kenyan national flag?', 'Black', 'Red', 'Blue', 'Green', 'c');

-- ------------------------------------------------------------------ Sports --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option) values
((select id from public.categories where name = 'Kenyan Sports'),
  'Kenyan athletes have earned a global reputation for dominating which category of track events?', 'Sprints (100m-400m)', 'Middle- and long-distance running', 'Field events like javelin', 'Relays only', 'b'),
((select id from public.categories where name = 'Kenyan Sports'),
  'Which Kenyan runner became the first person to run a marathon distance in under two hours, in Vienna in 2019?', 'Eliud Kipchoge', 'Kip Keino', 'Wilson Kipsang', 'David Rudisha', 'a'),
((select id from public.categories where name = 'Kenyan Sports'),
  'What is the nickname of the Kenyan national football (soccer) team?', 'The Lions', 'Harambee Stars', 'The Eagles', 'Black Stars', 'b'),
((select id from public.categories where name = 'Kenyan Sports'),
  'Kenyan athletics legend Kip Keino won 1500m Olympic gold at the 1968 Games, held in which city?', 'Tokyo', 'Mexico City', 'Munich', 'Montreal', 'b'),
((select id from public.categories where name = 'Kenyan Sports'),
  'Kenyan Olympic champion David Rudisha is best known for which track event?', '100m', '800m', 'Marathon', 'Long jump', 'b'),
((select id from public.categories where name = 'Kenyan Sports'),
  'What is the traditional Swahili/Kenyan call-and-response spirit of communal effort, also a national motto word?', 'Ubuntu', 'Harambee', 'Simba', 'Jambo', 'b');

-- ----------------------------------------------------------- General Knowledge --
insert into public.questions (category_id, question_text, option_a, option_b, option_c, option_d, correct_option) values
((select id from public.categories where name = 'General Knowledge'),
  'What is the official currency of Kenya?', 'Kenyan Pound', 'Kenyan Shilling', 'Kenyan Rand', 'Kenyan Franc', 'b'),
((select id from public.categories where name = 'General Knowledge'),
  'What is the chemical symbol for gold?', 'Ag', 'Gd', 'Au', 'Go', 'c'),
((select id from public.categories where name = 'General Knowledge'),
  'Which planet is known as the "Red Planet"?', 'Venus', 'Mars', 'Jupiter', 'Saturn', 'b'),
((select id from public.categories where name = 'General Knowledge'),
  'Which is the largest ocean on Earth?', 'Atlantic', 'Indian', 'Arctic', 'Pacific', 'd'),
((select id from public.categories where name = 'General Knowledge'),
  'In the commonly taught model, how many continents are there?', '5', '6', '7', '8', 'c'),
((select id from public.categories where name = 'General Knowledge'),
  '"Things Fall Apart" is a classic novel by which African author?', 'Ngugi wa Thiong''o', 'Chinua Achebe', 'Wole Soyinka', 'Chimamanda Ngozi Adichie', 'b');

-- ============================================================================
-- Optional: make your own account the admin (do this AFTER you've signed up
-- once through the app, so a profiles row exists for you). Find your uid in
-- Dashboard > Authentication > Users, then:
--
--   update public.profiles set is_admin = true where id = 'PASTE-YOUR-UID-HERE';
-- ============================================================================
