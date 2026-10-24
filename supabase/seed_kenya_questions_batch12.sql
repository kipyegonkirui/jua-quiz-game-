-- ============================================================================
-- seed_kenya_questions_batch12.sql
-- 75 more questions (mostly hard and medium), each with a "Did you know?" line.
-- Run AFTER 024_content_quality.sql. Safe to re-run (skips existing question text).
-- IMPORTANT: have a Kenyan reviewer check every fact (see batch12_review.md) before release.
-- ============================================================================

insert into public.categories (name)
select c.name from (values ($q$General Knowledge$q$)) as c(name)
where not exists (select 1 from public.categories x where x.name = c.name);

insert into public.questions
  (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty, did_you_know)
select (select id from public.categories where name = v.cat limit 1),
       v.question_text, v.a, v.b, v.c, v.d, v.correct, v.difficulty, v.fact
from (values
  ($q$General Knowledge$q$, $q$What is the capital of Myanmar?$q$, $q$Naypyidaw$q$, $q$Yangon$q$, $q$Mandalay$q$, $q$Bangkok$q$, 'a', 'hard', $q$The capital moved from Yangon in the mid-2000s.$q$),
  ($q$General Knowledge$q$, $q$What is the legislative capital of Sri Lanka?$q$, $q$Colombo$q$, $q$Sri Jayawardenepura Kotte$q$, $q$Kandy$q$, $q$Galle$q$, 'b', 'hard', $q$Colombo is the largest city and the commercial capital.$q$),
  ($q$General Knowledge$q$, $q$Which city is Switzerland's federal city and seat of government?$q$, $q$Zurich$q$, $q$Geneva$q$, $q$Bern$q$, $q$Basel$q$, 'c', 'hard', $q$Zurich is bigger, but Bern hosts the government.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of New Zealand?$q$, $q$Auckland$q$, $q$Christchurch$q$, $q$Hamilton$q$, $q$Wellington$q$, 'd', 'medium', $q$It is the world's southernmost capital of a sovereign state.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Morocco?$q$, $q$Casablanca$q$, $q$Rabat$q$, $q$Marrakesh$q$, $q$Fez$q$, 'b', 'medium', $q$Casablanca is bigger, but Rabat is the capital.$q$),
  ($q$General Knowledge$q$, $q$Which city is the official capital of Tanzania?$q$, $q$Dar es Salaam$q$, $q$Arusha$q$, $q$Dodoma$q$, $q$Mwanza$q$, 'c', 'hard', $q$Dar es Salaam is the biggest city.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Nigeria?$q$, $q$Lagos$q$, $q$Kano$q$, $q$Port Harcourt$q$, $q$Abuja$q$, 'd', 'medium', $q$Abuja replaced Lagos as the capital in 1991.$q$),
  ($q$General Knowledge$q$, $q$Which city is the official political capital of Cote d'Ivoire?$q$, $q$Yamoussoukro$q$, $q$Abidjan$q$, $q$Bouake$q$, $q$San-Pedro$q$, 'a', 'hard', $q$Abidjan is the largest city and the economic centre.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Malawi?$q$, $q$Blantyre$q$, $q$Zomba$q$, $q$Lilongwe$q$, $q$Mzuzu$q$, 'c', 'hard', $q$Zomba was the capital until 1975.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Zambia?$q$, $q$Ndola$q$, $q$Kitwe$q$, $q$Livingstone$q$, $q$Lusaka$q$, 'd', 'medium', $q$Livingstone, near Victoria Falls, was once the capital.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Senegal?$q$, $q$Dakar$q$, $q$Thies$q$, $q$Saint-Louis$q$, $q$Touba$q$, 'a', 'medium', $q$Dakar sits on the westernmost point of mainland Africa.$q$),
  ($q$General Knowledge$q$, $q$Which South African city is the seat of the country's Parliament?$q$, $q$Pretoria$q$, $q$Cape Town$q$, $q$Johannesburg$q$, $q$Durban$q$, 'b', 'hard', $q$South Africa has three capitals: Pretoria, Cape Town and Bloemfontein.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Vietnam?$q$, $q$Ho Chi Minh City$q$, $q$Da Nang$q$, $q$Hue$q$, $q$Hanoi$q$, 'd', 'medium', $q$The city is more than a thousand years old.$q$),
  ($q$General Knowledge$q$, $q$Which is the smallest independent country in South America by area?$q$, $q$Suriname$q$, $q$Uruguay$q$, $q$Guyana$q$, $q$Paraguay$q$, 'a', 'hard', $q$French Guiana is smaller, but it is not independent.$q$),
  ($q$General Knowledge$q$, $q$Which strait separates Spain from Morocco?$q$, $q$The Bosphorus$q$, $q$The Strait of Gibraltar$q$, $q$The Strait of Hormuz$q$, $q$The Bering Strait$q$, 'b', 'medium', $q$It is less than 15 kilometres wide at its narrowest point.$q$),
  ($q$General Knowledge$q$, $q$Which is the smallest ocean in the world?$q$, $q$The Southern Ocean$q$, $q$The Indian Ocean$q$, $q$The Arctic Ocean$q$, $q$The Atlantic Ocean$q$, 'c', 'medium', $q$Much of it is covered by sea ice.$q$),
  ($q$General Knowledge$q$, $q$Which river flows through Vienna?$q$, $q$The Danube$q$, $q$The Rhine$q$, $q$The Elbe$q$, $q$The Seine$q$, 'a', 'medium', $q$The Danube flows through ten countries.$q$),
  ($q$General Knowledge$q$, $q$Which mountain range forms part of the boundary between Europe and Asia?$q$, $q$The Alps$q$, $q$The Urals$q$, $q$The Andes$q$, $q$The Pyrenees$q$, 'b', 'hard', $q$They run through Russia and Kazakhstan.$q$),
  ($q$General Knowledge$q$, $q$What is the highest mountain in North America?$q$, $q$Mount Logan$q$, $q$Mount Whitney$q$, $q$Denali$q$, $q$Mount Rainier$q$, 'c', 'hard', $q$It stands in Alaska.$q$),
  ($q$General Knowledge$q$, $q$Which is the deepest lake in the world?$q$, $q$Lake Tanganyika$q$, $q$Lake Superior$q$, $q$Lake Victoria$q$, $q$Lake Baikal$q$, 'd', 'hard', $q$It is in Siberia and holds about a fifth of the world's fresh surface water.$q$),
  ($q$General Knowledge$q$, $q$What is the chemical symbol for potassium?$q$, $q$P$q$, $q$K$q$, $q$Po$q$, $q$Pm$q$, 'b', 'medium', $q$The symbol comes from the Latin word "kalium".$q$),
  ($q$General Knowledge$q$, $q$What is the chemical symbol for iron?$q$, $q$Ir$q$, $q$In$q$, $q$Fe$q$, $q$Fr$q$, 'c', 'medium', $q$It comes from the Latin word "ferrum".$q$),
  ($q$General Knowledge$q$, $q$What is the chemical symbol for lead?$q$, $q$Pd$q$, $q$Pl$q$, $q$Le$q$, $q$Pb$q$, 'd', 'hard', $q$It comes from the Latin word "plumbum".$q$),
  ($q$General Knowledge$q$, $q$What is the chemical symbol for silver?$q$, $q$Ag$q$, $q$Au$q$, $q$Si$q$, $q$Sr$q$, 'a', 'medium', $q$It comes from the Latin word "argentum".$q$),
  ($q$General Knowledge$q$, $q$Which element has the atomic number 6?$q$, $q$Nitrogen$q$, $q$Oxygen$q$, $q$Carbon$q$, $q$Boron$q$, 'c', 'medium', $q$All known life is based on carbon.$q$),
  ($q$General Knowledge$q$, $q$Which metal is the most abundant in Earth's crust?$q$, $q$Iron$q$, $q$Copper$q$, $q$Calcium$q$, $q$Aluminium$q$, 'd', 'hard', $q$Aluminium makes up about 8% of the crust.$q$),
  ($q$General Knowledge$q$, $q$Which planet is the hottest in our solar system?$q$, $q$Venus$q$, $q$Mercury$q$, $q$Mars$q$, $q$Jupiter$q$, 'a', 'medium', $q$Its thick atmosphere traps heat.$q$),
  ($q$General Knowledge$q$, $q$Which planet is home to Olympus Mons, the biggest volcano in the solar system?$q$, $q$Venus$q$, $q$Mars$q$, $q$Earth$q$, $q$Mercury$q$, 'b', 'medium', $q$It is about two and a half times taller than Mount Everest.$q$),
  ($q$General Knowledge$q$, $q$Which planet spins almost on its side?$q$, $q$Neptune$q$, $q$Saturn$q$, $q$Mars$q$, $q$Uranus$q$, 'd', 'hard', $q$Its axis is tilted by about 98 degrees.$q$),
  ($q$General Knowledge$q$, $q$What is the largest moon of Saturn?$q$, $q$Titan$q$, $q$Europa$q$, $q$Ganymede$q$, $q$Io$q$, 'a', 'hard', $q$It has a thick atmosphere and lakes of methane.$q$),
  ($q$General Knowledge$q$, $q$In which layer of the atmosphere is the ozone layer found?$q$, $q$The troposphere$q$, $q$The stratosphere$q$, $q$The mesosphere$q$, $q$The exosphere$q$, 'b', 'hard', $q$The ozone layer absorbs much of the Sun's ultraviolet light.$q$),
  ($q$General Knowledge$q$, $q$What kind of chemical bond forms when atoms share electrons?$q$, $q$An ionic bond$q$, $q$A hydrogen bond$q$, $q$A covalent bond$q$, $q$A metallic bond$q$, 'c', 'hard', $q$Water molecules are held together by covalent bonds.$q$),
  ($q$General Knowledge$q$, $q$A lack of which vitamin causes scurvy?$q$, $q$Vitamin C$q$, $q$Vitamin A$q$, $q$Vitamin D$q$, $q$Vitamin B12$q$, 'a', 'medium', $q$Sailors once got scurvy on long voyages without fresh fruit.$q$),
  ($q$General Knowledge$q$, $q$A lack of which vitamin can cause rickets in children?$q$, $q$Vitamin C$q$, $q$Vitamin D$q$, $q$Vitamin A$q$, $q$Vitamin K$q$, 'b', 'hard', $q$Rickets weakens and bends the bones.$q$),
  ($q$General Knowledge$q$, $q$About how fast does light travel in a vacuum?$q$, $q$30,000 kilometres per second$q$, $q$3,000 kilometres per second$q$, $q$300,000 kilometres per second$q$, $q$3 million kilometres per second$q$, 'c', 'medium', $q$Light from the Sun takes about eight minutes to reach Earth.$q$),
  ($q$General Knowledge$q$, $q$What is the study of fungi called?$q$, $q$Entomology$q$, $q$Botany$q$, $q$Herpetology$q$, $q$Mycology$q$, 'd', 'hard', $q$Mushrooms, yeasts and moulds are all fungi.$q$),
  ($q$General Knowledge$q$, $q$What is the study of birds called?$q$, $q$Ichthyology$q$, $q$Ornithology$q$, $q$Herpetology$q$, $q$Entomology$q$, 'b', 'hard', $q$Birdwatching is the best-known way to take part.$q$),
  ($q$General Knowledge$q$, $q$Which gland is often called the "master gland"?$q$, $q$The thyroid gland$q$, $q$The adrenal gland$q$, $q$The pituitary gland$q$, $q$The pancreas$q$, 'c', 'hard', $q$It sits at the base of the brain.$q$),
  ($q$General Knowledge$q$, $q$What are the building blocks of proteins?$q$, $q$Fatty acids$q$, $q$Sugars$q$, $q$Nucleotides$q$, $q$Amino acids$q$, 'd', 'medium', $q$There are 20 standard amino acids.$q$),
  ($q$General Knowledge$q$, $q$Which organ makes bile?$q$, $q$The liver$q$, $q$The kidney$q$, $q$The pancreas$q$, $q$The stomach$q$, 'a', 'medium', $q$Bile helps the body digest fats.$q$),
  ($q$General Knowledge$q$, $q$Which empire did Genghis Khan found?$q$, $q$The Ottoman Empire$q$, $q$The Persian Empire$q$, $q$The Mongol Empire$q$, $q$The Mughal Empire$q$, 'c', 'medium', $q$It became the largest connected land empire in history.$q$),
  ($q$General Knowledge$q$, $q$Who was the first Roman emperor?$q$, $q$Julius Caesar$q$, $q$Nero$q$, $q$Constantine$q$, $q$Augustus$q$, 'd', 'hard', $q$He ruled from 27 BC.$q$),
  ($q$General Knowledge$q$, $q$Which ship carried the Pilgrims to North America in 1620?$q$, $q$The Mayflower$q$, $q$The Santa Maria$q$, $q$The Endeavour$q$, $q$The Beagle$q$, 'a', 'medium', $q$The Pilgrims settled at Plymouth in what is now Massachusetts.$q$),
  ($q$General Knowledge$q$, $q$In which year did the French Revolution begin?$q$, $q$1776$q$, $q$1789$q$, $q$1804$q$, $q$1815$q$, 'b', 'medium', $q$The storming of the Bastille happened on 14 July.$q$),
  ($q$General Knowledge$q$, $q$Which US president issued the Emancipation Proclamation in 1863?$q$, $q$George Washington$q$, $q$Ulysses S. Grant$q$, $q$Thomas Jefferson$q$, $q$Abraham Lincoln$q$, 'd', 'medium', $q$It declared enslaved people in the Confederate states to be free.$q$),
  ($q$General Knowledge$q$, $q$Which country launched Sputnik, the first artificial satellite, in 1957?$q$, $q$The Soviet Union$q$, $q$The United States$q$, $q$Germany$q$, $q$Japan$q$, 'a', 'medium', $q$The launch kicked off the Space Race.$q$),
  ($q$General Knowledge$q$, $q$Who was the first human in space, in 1961?$q$, $q$Alan Shepard$q$, $q$Yuri Gagarin$q$, $q$John Glenn$q$, $q$Neil Armstrong$q$, 'b', 'medium', $q$His flight lasted 108 minutes.$q$),
  ($q$General Knowledge$q$, $q$In which year did humans first land on the Moon?$q$, $q$1965$q$, $q$1972$q$, $q$1969$q$, $q$1975$q$, 'c', 'medium', $q$Apollo 11 landed on 20 July 1969.$q$),
  ($q$General Knowledge$q$, $q$Which people of ancient Mesopotamia developed cuneiform writing?$q$, $q$The Sumerians$q$, $q$The Egyptians$q$, $q$The Phoenicians$q$, $q$The Persians$q$, 'a', 'hard', $q$They pressed the writing into clay tablets.$q$),
  ($q$General Knowledge$q$, $q$Which city was the capital of the Inca Empire?$q$, $q$Lima$q$, $q$Cusco$q$, $q$Quito$q$, $q$La Paz$q$, 'b', 'hard', $q$Machu Picchu lies not far from it.$q$),
  ($q$General Knowledge$q$, $q$Who was the main early leader of the Haitian Revolution?$q$, $q$Simon Bolivar$q$, $q$Jose de San Martin$q$, $q$Toussaint Louverture$q$, $q$Fidel Castro$q$, 'c', 'hard', $q$Haiti became independent in 1804.$q$),
  ($q$General Knowledge$q$, $q$Which ruler of the Mali Empire made a famous pilgrimage to Mecca in 1324?$q$, $q$Sundiata Keita$q$, $q$Askia Muhammad$q$, $q$Sonni Ali$q$, $q$Mansa Musa$q$, 'd', 'hard', $q$He gave away so much gold that its price fell in Cairo.$q$),
  ($q$General Knowledge$q$, $q$Great Zimbabwe was built by the ancestors of which people?$q$, $q$The Zulu$q$, $q$The Shona$q$, $q$The Maasai$q$, $q$The Ashanti$q$, 'b', 'hard', $q$The stone ruins date from about the 11th to the 15th centuries.$q$),
  ($q$General Knowledge$q$, $q$Who was the first President of Tanzania?$q$, $q$Jomo Kenyatta$q$, $q$Milton Obote$q$, $q$Julius Nyerere$q$, $q$Kenneth Kaunda$q$, 'c', 'medium', $q$He is often called "Mwalimu", which means teacher.$q$),
  ($q$General Knowledge$q$, $q$Who led Zambia to independence in 1964 and became its first President?$q$, $q$Julius Nyerere$q$, $q$Hastings Banda$q$, $q$Robert Mugabe$q$, $q$Kenneth Kaunda$q$, 'd', 'medium', $q$Zambia was once called Northern Rhodesia.$q$),
  ($q$General Knowledge$q$, $q$Who became the first Prime Minister of independent India?$q$, $q$Jawaharlal Nehru$q$, $q$Mahatma Gandhi$q$, $q$Indira Gandhi$q$, $q$Sardar Patel$q$, 'a', 'medium', $q$India became independent in 1947.$q$),
  ($q$General Knowledge$q$, $q$Which queen of Ndongo and Matamba resisted Portuguese rule in the 1600s?$q$, $q$Queen Amina$q$, $q$Queen Nefertiti$q$, $q$Queen Nzinga$q$, $q$Queen Makeda$q$, 'c', 'hard', $q$She is remembered in Angola as a national heroine.$q$),
  ($q$General Knowledge$q$, $q$The University of al-Qarawiyyin, one of the oldest in the world, is in which city?$q$, $q$Cairo$q$, $q$Timbuktu$q$, $q$Tunis$q$, $q$Fez$q$, 'd', 'hard', $q$It was founded in 859 by Fatima al-Fihri.$q$),
  ($q$General Knowledge$q$, $q$In which Shakespeare play does the character Iago appear?$q$, $q$Othello$q$, $q$Macbeth$q$, $q$Hamlet$q$, $q$King Lear$q$, 'a', 'hard', $q$Iago tricks Othello into doubting his wife.$q$),
  ($q$General Knowledge$q$, $q$Who wrote "The Great Gatsby"?$q$, $q$Ernest Hemingway$q$, $q$F. Scott Fitzgerald$q$, $q$John Steinbeck$q$, $q$William Faulkner$q$, 'b', 'medium', $q$It was published in 1925.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "War and Peace"?$q$, $q$Fyodor Dostoevsky$q$, $q$Anton Chekhov$q$, $q$Ivan Turgenev$q$, $q$Leo Tolstoy$q$, 'd', 'medium', $q$It follows several Russian families during the Napoleonic wars.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "Don Quixote"?$q$, $q$Miguel de Cervantes$q$, $q$Gabriel Garcia Marquez$q$, $q$Federico Garcia Lorca$q$, $q$Lope de Vega$q$, 'a', 'hard', $q$The first part was published in 1605.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "Les Miserables"?$q$, $q$Alexandre Dumas$q$, $q$Victor Hugo$q$, $q$Emile Zola$q$, $q$Honore de Balzac$q$, 'b', 'medium', $q$He also wrote "The Hunchback of Notre-Dame".$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "The Alchemist"?$q$, $q$Isabel Allende$q$, $q$Jorge Amado$q$, $q$Paulo Coelho$q$, $q$Mario Vargas Llosa$q$, 'c', 'medium', $q$It follows a shepherd boy named Santiago.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "Half of a Yellow Sun"?$q$, $q$Chimamanda Ngozi Adichie$q$, $q$Buchi Emecheta$q$, $q$Ama Ata Aidoo$q$, $q$Taiye Selasi$q$, 'a', 'hard', $q$It is set during the Nigerian Civil War.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "Nervous Conditions" (1988)?$q$, $q$Doris Lessing$q$, $q$Tsitsi Dangarembga$q$, $q$Nadine Gordimer$q$, $q$Bessie Head$q$, 'b', 'hard', $q$The author is from Zimbabwe.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "So Long a Letter"?$q$, $q$Buchi Emecheta$q$, $q$Flora Nwapa$q$, $q$Mariama Ba$q$, $q$Aminata Sow Fall$q$, 'c', 'hard', $q$The author was from Senegal.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "Cry, the Beloved Country"?$q$, $q$J. M. Coetzee$q$, $q$Nadine Gordimer$q$, $q$Athol Fugard$q$, $q$Alan Paton$q$, 'd', 'hard', $q$It was published in 1948.$q$),
  ($q$General Knowledge$q$, $q$Who wrote the autobiography "Long Walk to Freedom"?$q$, $q$Desmond Tutu$q$, $q$Nelson Mandela$q$, $q$Steve Biko$q$, $q$Thabo Mbeki$q$, 'b', 'medium', $q$It was published in 1994.$q$),
  ($q$General Knowledge$q$, $q$Which Nigerian writer won the Nobel Prize in Literature in 1986?$q$, $q$Chinua Achebe$q$, $q$Ben Okri$q$, $q$Wole Soyinka$q$, $q$Ken Saro-Wiwa$q$, 'c', 'medium', $q$He was the first African to win the prize.$q$),
  ($q$General Knowledge$q$, $q$Which Tanzanian-born writer won the Nobel Prize in Literature in 2021?$q$, $q$Ngugi wa Thiong'o$q$, $q$Wole Soyinka$q$, $q$J. M. Coetzee$q$, $q$Abdulrazak Gurnah$q$, 'd', 'hard', $q$He was born in Zanzibar.$q$),
  ($q$General Knowledge$q$, $q$Which South African writer won the Nobel Prize in Literature in 1991?$q$, $q$Nadine Gordimer$q$, $q$J. M. Coetzee$q$, $q$Alan Paton$q$, $q$Doris Lessing$q$, 'a', 'hard', $q$Her novels often explored life under apartheid.$q$),
  ($q$General Knowledge$q$, $q$Which Egyptian writer won the Nobel Prize in Literature in 1988?$q$, $q$Tawfiq al-Hakim$q$, $q$Taha Hussein$q$, $q$Naguib Mahfouz$q$, $q$Alaa Al Aswany$q$, 'c', 'hard', $q$He is best known for the Cairo Trilogy.$q$),
  ($q$General Knowledge$q$, $q$Who painted "The Last Supper"?$q$, $q$Michelangelo$q$, $q$Raphael$q$, $q$Titian$q$, $q$Leonardo da Vinci$q$, 'd', 'medium', $q$It covers a wall in a convent in Milan.$q$),
  ($q$General Knowledge$q$, $q$Who composed the opera "The Magic Flute"?$q$, $q$Wolfgang Amadeus Mozart$q$, $q$Ludwig van Beethoven$q$, $q$Giuseppe Verdi$q$, $q$Richard Wagner$q$, 'a', 'hard', $q$It premiered in Vienna in 1791.$q$)
) as v(cat, question_text, a, b, c, d, correct, difficulty, fact)
where not exists (select 1 from public.questions q where q.question_text = v.question_text);
