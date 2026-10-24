-- ============================================================================
-- seed_kenya_questions_batch9.sql
-- 65 more questions (mostly hard and medium), each with a "Did you know?" line.
-- Run AFTER 024_content_quality.sql. Safe to re-run (skips existing question text).
-- IMPORTANT: have a Kenyan reviewer check every fact (see batch9_review.md) before release.
-- ============================================================================

insert into public.categories (name)
select c.name from (values ($q$General Knowledge$q$), ($q$Kenyan Geography$q$), ($q$Kenyan History$q$), ($q$Kenyan Sports$q$), ($q$Kenyan Wildlife & Culture$q$)) as c(name)
where not exists (select 1 from public.categories x where x.name = c.name);

insert into public.questions
  (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty, did_you_know)
select (select id from public.categories where name = v.cat limit 1),
       v.question_text, v.a, v.b, v.c, v.d, v.correct, v.difficulty, v.fact
from (values
  ($q$General Knowledge$q$, $q$What is the chemical symbol for sodium?$q$, $q$So$q$, $q$Na$q$, $q$Sd$q$, $q$Nm$q$, 'b', 'medium', $q$Its symbol comes from the Latin word "natrium".$q$),
  ($q$General Knowledge$q$, $q$What is the powerhouse of the cell?$q$, $q$The nucleus$q$, $q$The ribosome$q$, $q$The mitochondrion$q$, $q$The vacuole$q$, 'c', 'medium', $q$It makes most of a cell's energy.$q$),
  ($q$General Knowledge$q$, $q$Which scientist discovered radioactivity in 1896?$q$, $q$Marie Curie$q$, $q$Ernest Rutherford$q$, $q$Wilhelm Roentgen$q$, $q$Henri Becquerel$q$, 'd', 'hard', $q$He found it while studying uranium salts.$q$),
  ($q$General Knowledge$q$, $q$Who discovered the electron in 1897?$q$, $q$J. J. Thomson$q$, $q$Niels Bohr$q$, $q$James Chadwick$q$, $q$Max Planck$q$, 'a', 'hard', $q$He won the Nobel Prize in Physics in 1906.$q$),
  ($q$General Knowledge$q$, $q$What is the SI unit of force?$q$, $q$The joule$q$, $q$The watt$q$, $q$The newton$q$, $q$The pascal$q$, 'c', 'medium', $q$It is named after Isaac Newton.$q$),
  ($q$General Knowledge$q$, $q$What is the SI unit of power?$q$, $q$The volt$q$, $q$The ohm$q$, $q$The joule$q$, $q$The watt$q$, 'd', 'medium', $q$One watt is one joule per second.$q$),
  ($q$General Knowledge$q$, $q$What is the largest organ of the human body?$q$, $q$The skin$q$, $q$The liver$q$, $q$The brain$q$, $q$The lungs$q$, 'a', 'medium', $q$An adult's skin covers about two square metres.$q$),
  ($q$General Knowledge$q$, $q$Which part of the eye controls how much light enters?$q$, $q$The cornea$q$, $q$The iris$q$, $q$The retina$q$, $q$The lens$q$, 'b', 'medium', $q$The iris changes the size of the pupil.$q$),
  ($q$General Knowledge$q$, $q$Which gas makes up most of the Sun?$q$, $q$Helium$q$, $q$Oxygen$q$, $q$Carbon$q$, $q$Hydrogen$q$, 'd', 'medium', $q$Helium is the second most common gas in the Sun.$q$),
  ($q$General Knowledge$q$, $q$Which star is closest to Earth after the Sun?$q$, $q$Proxima Centauri$q$, $q$Sirius$q$, $q$Betelgeuse$q$, $q$Vega$q$, 'a', 'hard', $q$It is about 4.2 light years away.$q$),
  ($q$General Knowledge$q$, $q$How many chromosomes do humans normally have in each body cell?$q$, $q$23$q$, $q$46$q$, $q$44$q$, $q$48$q$, 'b', 'medium', $q$They come in 23 pairs.$q$),
  ($q$General Knowledge$q$, $q$What is the pH of pure water at room temperature?$q$, $q$1$q$, $q$5$q$, $q$7$q$, $q$14$q$, 'c', 'medium', $q$A pH below 7 is acidic and above 7 is alkaline.$q$),
  ($q$General Knowledge$q$, $q$Which planet has the shortest day, spinning once in about ten hours?$q$, $q$Jupiter$q$, $q$Mars$q$, $q$Venus$q$, $q$Mercury$q$, 'a', 'hard', $q$Despite its huge size, Jupiter spins very fast.$q$),
  ($q$General Knowledge$q$, $q$In which year did World War I begin?$q$, $q$1912$q$, $q$1914$q$, $q$1916$q$, $q$1918$q$, 'b', 'medium', $q$It ended in 1918.$q$),
  ($q$General Knowledge$q$, $q$Which ancient wonder stood on the island of Pharos near Alexandria?$q$, $q$The hanging gardens$q$, $q$The colossus$q$, $q$The lighthouse$q$, $q$The temple of Artemis$q$, 'c', 'hard', $q$The Lighthouse of Alexandria guided ships for centuries.$q$),
  ($q$General Knowledge$q$, $q$Who became the first female Prime Minister of the United Kingdom, in 1979?$q$, $q$Theresa May$q$, $q$Indira Gandhi$q$, $q$Golda Meir$q$, $q$Margaret Thatcher$q$, 'd', 'medium', $q$She served until 1990.$q$),
  ($q$General Knowledge$q$, $q$Which country was the first to give women the vote in national elections, in 1893?$q$, $q$The United Kingdom$q$, $q$New Zealand$q$, $q$The United States$q$, $q$Australia$q$, 'b', 'hard', $q$Women there could not stand for parliament until 1919.$q$),
  ($q$General Knowledge$q$, $q$Who painted the ceiling of the Sistine Chapel?$q$, $q$Leonardo da Vinci$q$, $q$Raphael$q$, $q$Michelangelo$q$, $q$Donatello$q$, 'c', 'medium', $q$He painted it between 1508 and 1512.$q$),
  ($q$General Knowledge$q$, $q$Which city hosted the first modern Olympic Games in 1896?$q$, $q$Paris$q$, $q$London$q$, $q$Rome$q$, $q$Athens$q$, 'd', 'medium', $q$Fewer than 250 athletes took part.$q$),
  ($q$General Knowledge$q$, $q$Who wrote "On the Origin of Species"?$q$, $q$Charles Darwin$q$, $q$Alfred Wallace$q$, $q$Gregor Mendel$q$, $q$Thomas Huxley$q$, 'a', 'medium', $q$It was published in 1859.$q$),
  ($q$General Knowledge$q$, $q$Which treaty formally ended World War I with Germany?$q$, $q$The Treaty of Paris$q$, $q$The Treaty of Vienna$q$, $q$The Treaty of Versailles$q$, $q$The Treaty of Rome$q$, 'c', 'medium', $q$It was signed in 1919.$q$),
  ($q$General Knowledge$q$, $q$Which African country defeated Italy at the Battle of Adwa in 1896?$q$, $q$Sudan$q$, $q$Egypt$q$, $q$Libya$q$, $q$Ethiopia$q$, 'd', 'hard', $q$The victory kept Ethiopia independent.$q$),
  ($q$General Knowledge$q$, $q$Who became the first President of Ghana in 1960?$q$, $q$Kwame Nkrumah$q$, $q$Julius Nyerere$q$, $q$Kenneth Kaunda$q$, $q$Haile Selassie$q$, 'a', 'medium', $q$Ghana became independent in 1957, with Nkrumah as Prime Minister.$q$),
  ($q$General Knowledge$q$, $q$Which is the largest country in Africa by area?$q$, $q$DR Congo$q$, $q$Algeria$q$, $q$Sudan$q$, $q$Libya$q$, 'b', 'hard', $q$Most of it is covered by the Sahara.$q$),
  ($q$General Knowledge$q$, $q$Which is the smallest country in Africa by area?$q$, $q$The Gambia$q$, $q$Mauritius$q$, $q$Djibouti$q$, $q$Seychelles$q$, 'd', 'hard', $q$It is an island nation in the Indian Ocean.$q$),
  ($q$General Knowledge$q$, $q$Which desert covers much of Botswana?$q$, $q$The Kalahari$q$, $q$The Namib$q$, $q$The Sahara$q$, $q$The Danakil$q$, 'a', 'medium', $q$The Okavango Delta lies at its edge.$q$),
  ($q$General Knowledge$q$, $q$Which African lake is the deepest?$q$, $q$Lake Victoria$q$, $q$Lake Tanganyika$q$, $q$Lake Malawi$q$, $q$Lake Turkana$q$, 'b', 'hard', $q$It is also one of the longest freshwater lakes in the world.$q$),
  ($q$General Knowledge$q$, $q$Victoria Falls lies on the border of Zambia and which other country?$q$, $q$Malawi$q$, $q$Mozambique$q$, $q$Zimbabwe$q$, $q$Botswana$q$, 'c', 'medium', $q$The local name means "the smoke that thunders".$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Brazil?$q$, $q$Brasília$q$, $q$Rio de Janeiro$q$, $q$São Paulo$q$, $q$Salvador$q$, 'a', 'medium', $q$The city was built in the late 1950s and opened in 1960.$q$),
  ($q$General Knowledge$q$, $q$Which country has the most islands in the world?$q$, $q$Norway$q$, $q$Sweden$q$, $q$Finland$q$, $q$Indonesia$q$, 'b', 'hard', $q$Most of its islands are small and uninhabited.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Ethiopia?$q$, $q$Asmara$q$, $q$Khartoum$q$, $q$Addis Ababa$q$, $q$Mogadishu$q$, 'c', 'medium', $q$Addis Ababa is also the home of the African Union.$q$),
  ($q$General Knowledge$q$, $q$Which country has the largest population in Africa?$q$, $q$Ethiopia$q$, $q$Egypt$q$, $q$DR Congo$q$, $q$Nigeria$q$, 'd', 'medium', $q$Nigeria has more than 200 million people.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "1984"?$q$, $q$Aldous Huxley$q$, $q$George Orwell$q$, $q$Ray Bradbury$q$, $q$H. G. Wells$q$, 'b', 'medium', $q$It was published in 1949.$q$),
  ($q$General Knowledge$q$, $q$Who composed "The Four Seasons"?$q$, $q$Johann Sebastian Bach$q$, $q$Wolfgang Amadeus Mozart$q$, $q$Antonio Vivaldi$q$, $q$Ludwig van Beethoven$q$, 'c', 'medium', $q$He was a Venetian composer and violinist.$q$),
  ($q$General Knowledge$q$, $q$Who is credited with inventing the World Wide Web in 1989?$q$, $q$Bill Gates$q$, $q$Steve Jobs$q$, $q$Vint Cerf$q$, $q$Tim Berners-Lee$q$, 'd', 'medium', $q$He proposed it while working at CERN.$q$),
  ($q$General Knowledge$q$, $q$What does "HTTP" stand for?$q$, $q$Hypertext Transfer Protocol$q$, $q$High Transfer Text Process$q$, $q$Hyperlink Text Tracking Program$q$, $q$Home Tool Transfer Page$q$, 'a', 'medium', $q$The "S" in HTTPS stands for secure.$q$),
  ($q$General Knowledge$q$, $q$Which language is used to style web pages?$q$, $q$SQL$q$, $q$Python$q$, $q$CSS$q$, $q$XML$q$, 'c', 'medium', $q$CSS stands for Cascading Style Sheets.$q$),
  ($q$Kenyan Geography$q$, $q$Which Kenyan city is known as the "Lake City"?$q$, $q$Naivasha$q$, $q$Nakuru$q$, $q$Homa Bay$q$, $q$Kisumu$q$, 'd', 'medium', $q$It sits on the shore of Lake Victoria.$q$),
  ($q$Kenyan Geography$q$, $q$Which is Kenya's third-largest city by population?$q$, $q$Kisumu$q$, $q$Nakuru$q$, $q$Eldoret$q$, $q$Thika$q$, 'b', 'hard', $q$Nairobi and Mombasa are the two largest. In the 2019 census Nakuru had about 570,000 people, ahead of Eldoret and Kisumu.$q$),
  ($q$Kenyan Geography$q$, $q$Narok town is the usual gateway to which reserve?$q$, $q$Amboseli$q$, $q$The Maasai Mara$q$, $q$Samburu$q$, $q$Lake Nakuru$q$, 'b', 'medium', $q$The reserve lies in Narok County.$q$),
  ($q$Kenyan Geography$q$, $q$Which town is a main gateway to Amboseli National Park?$q$, $q$Kitale$q$, $q$Nyahururu$q$, $q$Kapenguria$q$, $q$Loitokitok$q$, 'd', 'hard', $q$Loitokitok sits at the foot of Mount Kilimanjaro.$q$),
  ($q$Kenyan Geography$q$, $q$Lake Elmenteita lies between which two lakes?$q$, $q$Naivasha and Nakuru$q$, $q$Baringo and Bogoria$q$, $q$Turkana and Victoria$q$, $q$Magadi and Naivasha$q$, 'a', 'hard', $q$It is a soda lake that attracts flamingos and pelicans.$q$),
  ($q$Kenyan Geography$q$, $q$The Chyulu Hills are what kind of hills?$q$, $q$Limestone cliffs$q$, $q$Young volcanic hills$q$, $q$Sand dunes$q$, $q$Coral hills$q$, 'b', 'medium', $q$Rain that falls there feeds springs such as Mzima.$q$),
  ($q$Kenyan Geography$q$, $q$The Taita Hills lie in which county?$q$, $q$Kitui$q$, $q$Machakos$q$, $q$Taita-Taveta$q$, $q$Kwale$q$, 'c', 'medium', $q$The hills rise from the dry plains near Tsavo.$q$),
  ($q$Kenyan Geography$q$, $q$The Cherangani Hills lie in which part of Kenya?$q$, $q$The west$q$, $q$The north-east$q$, $q$The coast$q$, $q$The south-east$q$, 'a', 'medium', $q$Streams from the hills feed rivers in western Kenya.$q$),
  ($q$Kenyan Geography$q$, $q$Marsabit Mountain is famous for what?$q$, $q$A permanent glacier$q$, $q$A green forest rising out of the desert$q$, $q$A salt flat$q$, $q$A coral reef$q$, 'b', 'hard', $q$It has crater lakes, including Lake Paradise.$q$),
  ($q$Kenyan History$q$, $q$Which Kenyan president served the longest, at about 24 years?$q$, $q$Jomo Kenyatta$q$, $q$Mwai Kibaki$q$, $q$Daniel arap Moi$q$, $q$Uhuru Kenyatta$q$, 'c', 'medium', $q$He took office in 1978 and left in 2002.$q$),
  ($q$Kenyan History$q$, $q$Under Kenya's 2010 Constitution, Parliament has which two houses?$q$, $q$The Senate and the Council of Elders$q$, $q$The House of Lords and the Assembly$q$, $q$The Assembly and the Cabinet$q$, $q$The National Assembly and the Senate$q$, 'd', 'medium', $q$The Senate represents the 47 counties.$q$),
  ($q$Kenyan History$q$, $q$In which year did Kenya hold its first general election after multi-party politics returned?$q$, $q$1988$q$, $q$1992$q$, $q$1997$q$, $q$2002$q$, 'b', 'hard', $q$Daniel arap Moi won the presidency that year.$q$),
  ($q$Kenyan History$q$, $q$Kenya's long-term development plan "Vision 2030" was launched in which year?$q$, $q$2003$q$, $q$2010$q$, $q$2008$q$, $q$2013$q$, 'c', 'hard', $q$It aims to turn Kenya into a middle-income country.$q$),
  ($q$Kenyan History$q$, $q$The Kenya shilling replaced which currency in 1966?$q$, $q$The Indian rupee$q$, $q$The British pound$q$, $q$The Ethiopian birr$q$, $q$The East African shilling$q$, 'd', 'hard', $q$The Central Bank of Kenya was also set up in 1966.$q$),
  ($q$Kenyan Sports$q$, $q$Which Kenyan won the 5000 m gold at the Rio 2016 Olympics?$q$, $q$Vivian Cheruiyot$q$, $q$Hellen Obiri$q$, $q$Faith Kipyegon$q$, $q$Mercy Cherono$q$, 'a', 'hard', $q$Hellen Obiri took silver in the same race.$q$),
  ($q$Kenyan Sports$q$, $q$How many times did Mary Keitany win the New York City Marathon?$q$, $q$Two$q$, $q$Three$q$, $q$Four$q$, $q$Five$q$, 'c', 'hard', $q$She won in 2014, 2015, 2016 and 2018.$q$),
  ($q$Kenyan Sports$q$, $q$What is the nickname of Kenya's national women's football team?$q$, $q$Lady Stars$q$, $q$Lionesses$q$, $q$Queens$q$, $q$Harambee Starlets$q$, 'd', 'medium', $q$The men's team is the Harambee Stars.$q$),
  ($q$Kenyan Sports$q$, $q$What is the nickname of Kenya's women's rugby sevens team?$q$, $q$The Lionesses$q$, $q$Shujaa$q$, $q$Starlets$q$, $q$Simbas$q$, 'a', 'medium', $q$The men's sevens team is called Shujaa.$q$),
  ($q$Kenyan Sports$q$, $q$Robert Wangila won Kenya's first Olympic boxing gold at which Games?$q$, $q$Montreal 1976$q$, $q$Seoul 1988$q$, $q$Los Angeles 1984$q$, $q$Barcelona 1992$q$, 'b', 'hard', $q$He won the welterweight title.$q$),
  ($q$Kenyan Sports$q$, $q$Which city hosted the 2021 World Athletics U20 Championships?$q$, $q$Eldoret$q$, $q$Mombasa$q$, $q$Kampala$q$, $q$Nairobi$q$, 'd', 'hard', $q$The events were held at Kasarani Stadium.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$In which national park did Joy Adamson release Elsa the lioness?$q$, $q$Meru National Park$q$, $q$Maasai Mara$q$, $q$Tsavo East$q$, $q$Aberdare$q$, 'a', 'hard', $q$Elsa's story was told in "Born Free".$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Who wrote the book "Born Free" (1960)?$q$, $q$Karen Blixen$q$, $q$Joy Adamson$q$, $q$Daphne Sheldrick$q$, $q$Beryl Markham$q$, 'b', 'medium', $q$It was later made into a film.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Saiwa Swamp National Park protects which semi-aquatic antelope?$q$, $q$The sable$q$, $q$The bongo$q$, $q$The sitatunga$q$, $q$The oryx$q$, 'c', 'hard', $q$Saiwa is one of Kenya's smallest national parks.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Shimba Hills National Reserve is the Kenyan home of which rare antelope?$q$, $q$The sable antelope$q$, $q$The bongo$q$, $q$The sitatunga$q$, $q$The oryx$q$, 'a', 'hard', $q$The reserve is also known for its elephants.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$The Aberdare Range is home to which rare, striped forest antelope?$q$, $q$The sable$q$, $q$The mountain bongo$q$, $q$The gerenuk$q$, $q$The eland$q$, 'b', 'hard', $q$The mountain bongo is critically endangered.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$The 1898 "Tsavo man-eaters" attacked workers building what?$q$, $q$A bridge in Nairobi$q$, $q$A fort in Mombasa$q$, $q$The Uganda Railway$q$, $q$A mission station$q$, 'c', 'hard', $q$They were two male lions.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Who shot the two Tsavo man-eating lions in 1898?$q$, $q$Frederick Selous$q$, $q$Denys Finch Hatton$q$, $q$Bror Blixen$q$, $q$John Henry Patterson$q$, 'd', 'hard', $q$He wrote a book about it, "The Man-Eaters of Tsavo".$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$In which museum are the Tsavo man-eaters displayed today?$q$, $q$The British Museum$q$, $q$The Field Museum in Chicago$q$, $q$The Smithsonian$q$, $q$The Nairobi National Museum$q$, 'b', 'hard', $q$The museum acquired them in the 1920s.$q$)
) as v(cat, question_text, a, b, c, d, correct, difficulty, fact)
where not exists (select 1 from public.questions q where q.question_text = v.question_text);
