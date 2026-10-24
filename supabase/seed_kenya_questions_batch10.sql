-- ============================================================================
-- seed_kenya_questions_batch10.sql
-- 55 more questions (mostly hard and medium), each with a "Did you know?" line.
-- Run AFTER 024_content_quality.sql. Safe to re-run (skips existing question text).
-- IMPORTANT: have a Kenyan reviewer check every fact (see batch10_review.md) before release.
-- ============================================================================

insert into public.categories (name)
select c.name from (values ($q$General Knowledge$q$), ($q$Kenyan Geography$q$), ($q$Kenyan History$q$), ($q$Kenyan Sports$q$), ($q$Kenyan Wildlife & Culture$q$)) as c(name)
where not exists (select 1 from public.categories x where x.name = c.name);

insert into public.questions
  (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty, did_you_know)
select (select id from public.categories where name = v.cat limit 1),
       v.question_text, v.a, v.b, v.c, v.d, v.correct, v.difficulty, v.fact
from (values
  ($q$Kenyan History$q$, $q$The Berlin Conference of 1884 and 1885 set the rules for what?$q$, $q$The end of the slave trade$q$, $q$The building of the Suez Canal$q$, $q$The European "Scramble for Africa"$q$, $q$The founding of the League of Nations$q$, 'c', 'medium', $q$No African leaders were invited to the talks.$q$),
  ($q$Kenyan History$q$, $q$Which two European powers agreed in 1886 to divide their spheres of influence in East Africa?$q$, $q$France and Portugal$q$, $q$Italy and Belgium$q$, $q$Spain and the Netherlands$q$, $q$Britain and Germany$q$, 'd', 'hard', $q$Kenya fell in Britain's sphere and Tanganyika in Germany's.$q$),
  ($q$Kenyan History$q$, $q$Which company governed British East Africa before 1895?$q$, $q$The Imperial British East Africa Company$q$, $q$The Royal Niger Company$q$, $q$The British South Africa Company$q$, $q$The East India Company$q$, 'a', 'hard', $q$The British government took over from the company in 1895.$q$),
  ($q$Kenyan History$q$, $q$Which Scottish businessman founded the Imperial British East Africa Company?$q$, $q$Cecil Rhodes$q$, $q$Sir William Mackinnon$q$, $q$Lord Delamere$q$, $q$Frederick Lugard$q$, 'b', 'hard', $q$The company was set up in 1888.$q$),
  ($q$Kenyan History$q$, $q$Who was the chief engineer of the Uganda Railway?$q$, $q$John Henry Patterson$q$, $q$Ronald Preston$q$, $q$Sir Harry Johnston$q$, $q$George Whitehouse$q$, 'd', 'hard', $q$Thousands of workers from India built the railway.$q$),
  ($q$Kenyan History$q$, $q$Construction of the Uganda Railway began at Mombasa in which year?$q$, $q$1896$q$, $q$1886$q$, $q$1901$q$, $q$1912$q$, 'a', 'hard', $q$It reached Kisumu on Lake Victoria in 1901.$q$),
  ($q$Kenyan History$q$, $q$Which woman held the rank of Field Marshal in the Mau Mau movement?$q$, $q$Wangari Maathai$q$, $q$Muthoni wa Kirima$q$, $q$Mekatilili wa Menza$q$, $q$Grace Ogot$q$, 'b', 'hard', $q$She was one of the few women to lead fighters in the forest.$q$),
  ($q$Kenyan History$q$, $q$Kenya's 1963 independence constitution divided the country into what?$q$, $q$Counties$q$, $q$Provinces only$q$, $q$Regions$q$, $q$Tribal homelands$q$, 'c', 'hard', $q$The system was called "majimbo" and was changed soon after independence.$q$),
  ($q$Kenyan History$q$, $q$Which force carried out the failed 1982 coup attempt in Kenya?$q$, $q$The Kenya Air Force$q$, $q$The Kenya Navy$q$, $q$The General Service Unit$q$, $q$The Kenya Police$q$, 'a', 'hard', $q$The coup attempt was put down within hours.$q$),
  ($q$Kenyan History$q$, $q$Lord Delamere was a leading what in colonial Kenya?$q$, $q$African chief$q$, $q$White settler$q$, $q$Missionary teacher$q$, $q$Railway engineer$q$, 'b', 'medium', $q$He owned huge farms in the Rift Valley.$q$),
  ($q$Kenyan History$q$, $q$The 1923 Devonshire White Paper declared what about Kenya?$q$, $q$Kenya would become independent$q$, $q$Settlers would rule Kenya$q$, $q$African interests were paramount$q$, $q$Indians would get all the land$q$, 'c', 'hard', $q$Settlers still kept most of the power for decades.$q$),
  ($q$Kenyan Geography$q$, $q$Which Kenyan town, at about 2,300 metres, is often called the highest in the country?$q$, $q$Nakuru$q$, $q$Eldoret$q$, $q$Nyeri$q$, $q$Nyahururu$q$, 'd', 'hard', $q$It is famous for Thomson's Falls.$q$),
  ($q$Kenyan Geography$q$, $q$The Namanga border post links Kenya with which country?$q$, $q$Uganda$q$, $q$Tanzania$q$, $q$Ethiopia$q$, $q$Somalia$q$, 'b', 'medium', $q$The road connects Nairobi to Arusha.$q$),
  ($q$Kenyan Geography$q$, $q$Malaba is a major border crossing between Kenya and which country?$q$, $q$Tanzania$q$, $q$South Sudan$q$, $q$Uganda$q$, $q$Ethiopia$q$, 'c', 'medium', $q$Trucks from Mombasa pass through on their way inland.$q$),
  ($q$Kenyan Geography$q$, $q$Moyale is a border town between Kenya and which country?$q$, $q$Somalia$q$, $q$Uganda$q$, $q$Tanzania$q$, $q$Ethiopia$q$, 'd', 'medium', $q$The town is split between the two countries.$q$),
  ($q$Kenyan Geography$q$, $q$About how high is Point Lenana, the trekking peak of Mount Kenya?$q$, $q$4,985 metres$q$, $q$3,985 metres$q$, $q$5,985 metres$q$, $q$6,985 metres$q$, 'a', 'hard', $q$Most hikers aim to reach it at sunrise.$q$),
  ($q$Kenyan Geography$q$, $q$Kenya uses which time zone?$q$, $q$UTC+1$q$, $q$UTC+2$q$, $q$UTC+3$q$, $q$UTC+4$q$, 'c', 'medium', $q$The country has no daylight saving time.$q$),
  ($q$Kenyan Geography$q$, $q$About how many people lived in Kenya at the 2019 census?$q$, $q$27.6 million$q$, $q$37.6 million$q$, $q$57.6 million$q$, $q$47.6 million$q$, 'd', 'hard', $q$The census is held every ten years.$q$),
  ($q$Kenyan Geography$q$, $q$What is the international currency code of the Kenyan shilling?$q$, $q$KES$q$, $q$KSH$q$, $q$KNY$q$, $q$KEN$q$, 'a', 'medium', $q$Prices are often written as "KES" or "KSh".$q$),
  ($q$Kenyan Sports$q$, $q$Dennis Oliech, a Kenyan striker, played for which French club?$q$, $q$Lyon$q$, $q$Auxerre$q$, $q$Marseille$q$, $q$Lille$q$, 'b', 'medium', $q$He was one of the Harambee Stars' best-known strikers.$q$),
  ($q$Kenyan Sports$q$, $q$What is the nickname of Kenya's national basketball team?$q$, $q$The Lions$q$, $q$The Cheetahs$q$, $q$The Warriors$q$, $q$The Morans$q$, 'd', 'medium', $q$Morans are Maasai warriors.$q$),
  ($q$Kenyan Sports$q$, $q$In the name of Kenya's women's volleyball team, the "Malkia Strikers", what does "malkia" mean?$q$, $q$Queen$q$, $q$Lion$q$, $q$Eagle$q$, $q$Hero$q$, 'a', 'hard', $q$The team has won several African titles.$q$),
  ($q$Kenyan Sports$q$, $q$Which of these cities is NOT one of the original six World Marathon Majors?$q$, $q$Boston$q$, $q$Paris$q$, $q$Berlin$q$, $q$Chicago$q$, 'b', 'hard', $q$The original six were Tokyo, Boston, London, Berlin, Chicago and New York City.$q$),
  ($q$Kenyan Sports$q$, $q$The marathon is named after a battle fought in which country?$q$, $q$Italy$q$, $q$Turkey$q$, $q$Greece$q$, $q$Egypt$q$, 'c', 'medium', $q$The battle of Marathon took place in 490 BC.$q$),
  ($q$Kenyan Sports$q$, $q$How many water jumps are there in a 3000 m steeplechase race?$q$, $q$Seven$q$, $q$Three$q$, $q$Five$q$, $q$Nine$q$, 'a', 'hard', $q$Runners also clear 28 barriers.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Which rhino has a pointed lip for eating leaves from bushes?$q$, $q$The white rhino$q$, $q$The black rhino$q$, $q$The Indian rhino$q$, $q$The Javan rhino$q$, 'b', 'medium', $q$The white rhino has a wide, flat lip for grazing grass.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$About how many hours a day do lions spend resting?$q$, $q$Up to 4 hours$q$, $q$Up to 8 hours$q$, $q$Up to 20 hours$q$, $q$Up to 12 hours$q$, 'c', 'medium', $q$Lions hunt mostly at night or at dawn and dusk.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Which marks on a cheetah's face help tell it apart from a leopard?$q$, $q$White ears$q$, $q$A black nose ring$q$, $q$A striped forehead$q$, $q$Dark "tear" lines$q$, 'd', 'medium', $q$The lines run from the eyes to the mouth.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Which big cat often hauls its kills up into trees?$q$, $q$The lion$q$, $q$The leopard$q$, $q$The cheetah$q$, $q$The serval$q$, 'b', 'medium', $q$Hiding food high up keeps it safe from hyenas and lions.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Which African hunter is famous for catching its prey on about 80% of its hunts?$q$, $q$The lion$q$, $q$The leopard$q$, $q$The African wild dog$q$, $q$The spotted hyena$q$, 'c', 'hard', $q$Wild dogs hunt in packs and run down their prey.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$The aardwolf feeds mostly on what?$q$, $q$Fruit$q$, $q$Fish$q$, $q$Birds' eggs$q$, $q$Termites$q$, 'd', 'hard', $q$It can eat thousands of termites in one night.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$What is special about a zebra's stripes?$q$, $q$Each zebra has its own pattern$q$, $q$They change colour in the dry season$q$, $q$They are only on the males$q$, $q$They glow at night$q$, 'a', 'medium', $q$No two zebras have exactly the same stripes.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Which Kenyan conservationist leads the "Hands Off Our Elephants" campaign?$q$, $q$Daphne Sheldrick$q$, $q$Richard Leakey$q$, $q$Paula Kahumbu$q$, $q$Wangari Maathai$q$, 'c', 'hard', $q$She runs the group Wildlife Direct.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Which sea turtle is the one most often seen nesting on Kenya's coast?$q$, $q$The leatherback$q$, $q$The loggerhead$q$, $q$The flatback$q$, $q$The green turtle$q$, 'd', 'medium', $q$Nests are protected on beaches around Watamu and Diani.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$Which Kenyan county has the biggest area of mangrove forest?$q$, $q$Lamu$q$, $q$Kilifi$q$, $q$Kwale$q$, $q$Mombasa$q$, 'a', 'hard', $q$Mangroves protect the coast and are nurseries for fish.$q$),
  ($q$Kenyan Wildlife & Culture$q$, $q$How many toes does a giraffe have on each foot?$q$, $q$One$q$, $q$Two$q$, $q$Three$q$, $q$Four$q$, 'b', 'hard', $q$Its hoof is split into two parts.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Kazakhstan?$q$, $q$Almaty$q$, $q$Tashkent$q$, $q$Bishkek$q$, $q$Astana$q$, 'd', 'hard', $q$The city was renamed Astana again in 2022.$q$),
  ($q$General Knowledge$q$, $q$What is the capital of Turkey?$q$, $q$Ankara$q$, $q$Istanbul$q$, $q$Izmir$q$, $q$Antalya$q$, 'a', 'medium', $q$Istanbul is bigger, but Ankara is the capital.$q$),
  ($q$General Knowledge$q$, $q$Which is the longest river in Asia?$q$, $q$The Mekong$q$, $q$The Yangtze$q$, $q$The Ganges$q$, $q$The Indus$q$, 'b', 'hard', $q$It flows for about 6,300 kilometres through China.$q$),
  ($q$General Knowledge$q$, $q$Which body of water is the lowest place on dry land?$q$, $q$The Caspian Sea$q$, $q$Lake Baikal$q$, $q$The Dead Sea$q$, $q$The Red Sea$q$, 'c', 'medium', $q$Its shore is more than 400 metres below sea level.$q$),
  ($q$General Knowledge$q$, $q$Which is the driest continent on Earth?$q$, $q$Antarctica$q$, $q$Africa$q$, $q$Australia$q$, $q$Asia$q$, 'a', 'hard', $q$Antarctica is a cold desert with very little snowfall.$q$),
  ($q$General Knowledge$q$, $q$Which waterfall is the tallest in the world?$q$, $q$Victoria Falls$q$, $q$Angel Falls$q$, $q$Niagara Falls$q$, $q$Iguazu Falls$q$, 'b', 'medium', $q$It is in Venezuela and drops almost a kilometre.$q$),
  ($q$General Knowledge$q$, $q$Who is the ancient Greek poet said to have written "The Odyssey"?$q$, $q$Plato$q$, $q$Sophocles$q$, $q$Homer$q$, $q$Virgil$q$, 'c', 'medium', $q$He is also said to have written "The Iliad".$q$),
  ($q$General Knowledge$q$, $q$Who wrote the novel "Pride and Prejudice"?$q$, $q$Charlotte Bronte$q$, $q$George Eliot$q$, $q$Mary Shelley$q$, $q$Jane Austen$q$, 'd', 'medium', $q$It was published in 1813.$q$),
  ($q$General Knowledge$q$, $q$Which artist painted "The Starry Night"?$q$, $q$Claude Monet$q$, $q$Vincent van Gogh$q$, $q$Paul Cezanne$q$, $q$Edvard Munch$q$, 'b', 'medium', $q$He painted it in 1889 while staying in an asylum in France.$q$),
  ($q$General Knowledge$q$, $q$Which artist painted "The Persistence of Memory", with its melting clocks?$q$, $q$Pablo Picasso$q$, $q$Rene Magritte$q$, $q$Salvador Dali$q$, $q$Joan Miro$q$, 'c', 'hard', $q$He painted it in 1931.$q$),
  ($q$General Knowledge$q$, $q$Which composer wrote the "Moonlight Sonata"?$q$, $q$Wolfgang Amadeus Mozart$q$, $q$Frederic Chopin$q$, $q$Johann Sebastian Bach$q$, $q$Ludwig van Beethoven$q$, 'd', 'medium', $q$He kept composing even after he went deaf.$q$),
  ($q$General Knowledge$q$, $q$Who proposed that the Earth goes around the Sun, in 1543?$q$, $q$Nicolaus Copernicus$q$, $q$Galileo Galilei$q$, $q$Isaac Newton$q$, $q$Johannes Kepler$q$, 'a', 'medium', $q$His book is called "On the Revolutions of the Heavenly Spheres".$q$),
  ($q$General Knowledge$q$, $q$Who worked out the three laws of planetary motion?$q$, $q$Galileo Galilei$q$, $q$Tycho Brahe$q$, $q$Johannes Kepler$q$, $q$Isaac Newton$q$, 'c', 'hard', $q$He showed that planets move in ellipses, not circles.$q$),
  ($q$General Knowledge$q$, $q$Which Englishman designed the "Analytical Engine", an early mechanical computer?$q$, $q$Alan Turing$q$, $q$Isaac Newton$q$, $q$James Watt$q$, $q$Charles Babbage$q$, 'd', 'hard', $q$The machine was never completed in his lifetime.$q$),
  ($q$General Knowledge$q$, $q$Who is often called the first computer programmer?$q$, $q$Ada Lovelace$q$, $q$Grace Hopper$q$, $q$Marie Curie$q$, $q$Hedy Lamarr$q$, 'a', 'medium', $q$She wrote notes on Babbage's machine in the 1840s.$q$),
  ($q$General Knowledge$q$, $q$What does "RAM" stand for in computing?$q$, $q$Read Access Module$q$, $q$Random Access Memory$q$, $q$Rapid Action Memory$q$, $q$Remote Application Manager$q$, 'b', 'medium', $q$It holds the data a computer is using right now.$q$),
  ($q$General Knowledge$q$, $q$What is the binary number 101 in everyday numbers?$q$, $q$3$q$, $q$6$q$, $q$10$q$, $q$5$q$, 'd', 'medium', $q$Binary uses only the digits 0 and 1.$q$),
  ($q$General Knowledge$q$, $q$What is the square root of 169?$q$, $q$13$q$, $q$11$q$, $q$12$q$, $q$14$q$, 'a', 'medium', $q$13 times 13 equals 169.$q$),
  ($q$General Knowledge$q$, $q$Which year is written MCMXC in Roman numerals?$q$, $q$1890$q$, $q$1990$q$, $q$1950$q$, $q$2090$q$, 'b', 'hard', $q$M is 1000, CM is 900 and XC is 90.$q$)
) as v(cat, question_text, a, b, c, d, correct, difficulty, fact)
where not exists (select 1 from public.questions q where q.question_text = v.question_text);
