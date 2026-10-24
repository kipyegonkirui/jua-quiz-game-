-- ============================================================================
-- seed_football_questions_2.sql
-- 43 more HARD football questions for Football Challenge (levels 41-60).
-- Run AFTER 031_football_challenge.sql and seed_football_questions.sql.
-- Safe to re-run (skips existing question text).
-- Have a reviewer check every fact (see content_reviews/football_review_2.md), starting with CHECK first rows.
-- ============================================================================

insert into public.categories (name, icon)
select 'Football', '⚽'
where not exists (select 1 from public.categories where name = 'Football');

insert into public.questions
  (category_id, question_text, option_a, option_b, option_c, option_d, correct_option, difficulty, did_you_know)
select (select id from public.categories where name = 'Football' limit 1),
       v.question_text, v.a, v.b, v.c, v.d, v.correct, 'hard', v.fact
from (values
  ($q$Who won the Golden Boot at the 1998 World Cup with 6 goals?$q$, $q$Ronaldo$q$, $q$Christian Vieri$q$, $q$Gabriel Batistuta$q$, $q$Davor Suker$q$, 'd', $q$He scored for Croatia, who finished third.$q$),
  ($q$Who won the Golden Boot at the 2002 World Cup?$q$, $q$Rivaldo$q$, $q$Oliver Neuville$q$, $q$Ronaldo$q$, $q$Miroslav Klose$q$, 'c', $q$He scored 8 goals for Brazil.$q$),
  ($q$Who won the Golden Boot at the 2006 World Cup with 5 goals?$q$, $q$Zinedine Zidane$q$, $q$Thierry Henry$q$, $q$Hernan Crespo$q$, $q$Miroslav Klose$q$, 'd', $q$He scored 5 for Germany, the host nation.$q$),
  ($q$Who won the Golden Boot at the 2010 World Cup on assists?$q$, $q$Diego Forlan$q$, $q$David Villa$q$, $q$Wesley Sneijder$q$, $q$Thomas Muller$q$, 'd', $q$He tied on five goals with three other players.$q$),
  ($q$Which English striker won the Golden Boot at the 1986 World Cup?$q$, $q$Glenn Hoddle$q$, $q$Bryan Robson$q$, $q$Gary Lineker$q$, $q$Peter Beardsley$q$, 'c', $q$He scored six goals.$q$),
  ($q$Who scored the penalty that won Germany the 1990 World Cup final?$q$, $q$Jurgen Klinsmann$q$, $q$Lothar Matthaus$q$, $q$Andreas Brehme$q$, $q$Rudi Voller$q$, 'c', $q$They beat Argentina 1-0 in Rome.$q$),
  ($q$Which country has appeared in the most World Cup finals, counting West Germany?$q$, $q$Italy$q$, $q$Brazil$q$, $q$Argentina$q$, $q$Germany$q$, 'd', $q$They have reached eight finals.$q$),
  ($q$Which goalkeeper won the Golden Ball as best player at the 2002 World Cup?$q$, $q$Gianluigi Buffon$q$, $q$Oliver Kahn$q$, $q$Fabien Barthez$q$, $q$Rene Higuita$q$, 'b', $q$Germany lost the final to Brazil.$q$),
  ($q$Which nation won the first ever European Championship in 1960?$q$, $q$Czechoslovakia$q$, $q$Spain$q$, $q$Yugoslavia$q$, $q$Soviet Union$q$, 'd', $q$Only four teams took part in the final tournament.$q$),
  ($q$Who scored the famous chipped penalty to win Euro 1976 for Czechoslovakia?$q$, $q$Antonin Panenka$q$, $q$Zdenek Nehoda$q$, $q$Ladislav Petras$q$, $q$Ivo Viktor$q$, 'a', $q$The soft chip is now called the 'Panenka'.$q$),
  ($q$Which Frenchman scored 9 goals at Euro 1984, a record for one tournament?$q$, $q$Michel Platini$q$, $q$Dominique Rocheteau$q$, $q$Alain Giresse$q$, $q$Jean-Pierre Papin$q$, 'a', $q$France won the tournament on home soil.$q$),
  ($q$Who is the all-time top scorer at the European Championship?$q$, $q$Alan Shearer$q$, $q$Cristiano Ronaldo$q$, $q$Michel Platini$q$, $q$Antoine Griezmann$q$, 'b', $q$He has scored 14 goals across six tournaments.$q$),
  ($q$Which Real Madrid player scored a famous overhead kick in the 2018 Champions League final?$q$, $q$Gareth Bale$q$, $q$Cristiano Ronaldo$q$, $q$Karim Benzema$q$, $q$Marco Asensio$q$, 'a', $q$Real beat Liverpool 3-1 in Kyiv.$q$),
  ($q$Which team did Chelsea beat on penalties in the 2012 Champions League final in Munich?$q$, $q$AC Milan$q$, $q$Barcelona$q$, $q$Bayern Munich$q$, $q$Real Madrid$q$, 'c', $q$Didier Drogba scored the winning penalty.$q$),
  ($q$Who scored a 93rd-minute equaliser for Real Madrid in the 2014 Champions League final?$q$, $q$Cristiano Ronaldo$q$, $q$Angel Di Maria$q$, $q$Gareth Bale$q$, $q$Sergio Ramos$q$, 'd', $q$Real went on to win 4-1 after extra time.$q$),
  ($q$Which defender slipped as he took a penalty in the 2008 Champions League final in Moscow?$q$, $q$Michael Ballack$q$, $q$Ashley Cole$q$, $q$John Terry$q$, $q$Frank Lampard$q$, 'c', $q$Manchester United won the shootout.$q$),
  ($q$Which player scored four goals for Real Madrid in the 1960 European Cup final, a 7-3 win?$q$, $q$Alfredo Di Stefano$q$, $q$Francisco Gento$q$, $q$Ferenc Puskas$q$, $q$Raymond Kopa$q$, 'c', $q$Di Stefano scored the other three.$q$),
  ($q$How many matches did Arsenal go unbeaten in the Premier League from 2003 to 2004, a record?$q$, $q$38$q$, $q$49$q$, $q$41$q$, $q$55$q$, 'b', $q$The run ended at Old Trafford in October 2004.$q$),
  ($q$Which club won the Premier League, FA Cup and Champions League treble in 1999?$q$, $q$Chelsea$q$, $q$Arsenal$q$, $q$Manchester United$q$, $q$Liverpool$q$, 'c', $q$It was the first English treble.$q$),
  ($q$In which year did Liverpool win their first league title in 30 years?$q$, $q$2019$q$, $q$2020$q$, $q$2018$q$, $q$2021$q$, 'b', $q$The title came during the pandemic season.$q$),
  ($q$How many trophies did Pep Guardiola's Barcelona win in 2009, a record year?$q$, $q$Six$q$, $q$Five$q$, $q$Three$q$, $q$Four$q$, 'a', $q$They won every competition they entered.$q$),
  ($q$Which German manager led Bayern Munich to the 2020 treble?$q$, $q$Hansi Flick$q$, $q$Julian Nagelsmann$q$, $q$Jupp Heynckes$q$, $q$Niko Kovac$q$, 'a', $q$They beat PSG 1-0 in the final.$q$),
  ($q$How many league goals did Lionel Messi score in La Liga in the 2011-12 season?$q$, $q$46$q$, $q$55$q$, $q$50$q$, $q$42$q$, 'c', $q$It was a Spanish top-flight record.$q$),
  ($q$How many consecutive Serie A titles did Juventus win from 2012 to 2020?$q$, $q$Seven$q$, $q$Nine$q$, $q$Eight$q$, $q$Ten$q$, 'b', $q$The run ended when Inter Milan won in 2021.$q$),
  ($q$Which club did Diego Maradona win two Serie A titles with?$q$, $q$Juventus$q$, $q$Napoli$q$, $q$AC Milan$q$, $q$Roma$q$, 'b', $q$They won in 1987 and 1990.$q$),
  ($q$Which Uruguayan won the Golden Ball at the 2010 World Cup?$q$, $q$Luis Suarez$q$, $q$Edinson Cavani$q$, $q$Sebastian Abreu$q$, $q$Diego Forlan$q$, 'd', $q$Uruguay finished fourth.$q$),
  ($q$Which African country won the 1992 Africa Cup of Nations after a record 11-10 penalty shootout?$q$, $q$Ivory Coast$q$, $q$Algeria$q$, $q$Ghana$q$, $q$Nigeria$q$, 'a', $q$They beat Ghana in Dakar.$q$),
  ($q$Which country won the Africa Cup of Nations on home soil in 1996?$q$, $q$South Africa$q$, $q$Nigeria$q$, $q$Egypt$q$, $q$Tunisia$q$, 'a', $q$Mark Williams scored twice in a 2-0 final win over Tunisia.$q$),
  ($q$Which country won the 2013 Africa Cup of Nations in South Africa?$q$, $q$Burkina Faso$q$, $q$Ivory Coast$q$, $q$Nigeria$q$, $q$Mali$q$, 'c', $q$Sunday Mba scored the only goal of the final.$q$),
  ($q$Which Egyptian club has won the CAF Champions League more than any other?$q$, $q$Al Ahly$q$, $q$Esperance$q$, $q$Zamalek$q$, $q$Wydad Casablanca$q$, 'a', $q$They have won the competition more than ten times.$q$),
  ($q$Which Kenyan club has won the most Kenyan league titles?$q$, $q$Mathare United$q$, $q$Tusker$q$, $q$Gor Mahia$q$, $q$AFC Leopards$q$, 'c', $q$They have won the league more than 20 times.$q$),
  ($q$What does CECAFA stand for?$q$, $q$Council of Eastern Cup and Football Authorities$q$, $q$Central and East African Cup Association$q$, $q$Council of East and Central Africa Football Associations$q$, $q$Confederation of East and Central African Football Alliances$q$, 'c', $q$It organises the regional cup Kenya often plays in.$q$),
  ($q$In which year did Kenya last play at the Africa Cup of Nations before 2019?$q$, $q$2004$q$, $q$1992$q$, $q$2010$q$, $q$1996$q$, 'a', $q$They went out in the group stage in Tunisia.$q$),
  ($q$Which country hosted the Africa Cup of Nations in 2008?$q$, $q$Angola$q$, $q$Ghana$q$, $q$Nigeria$q$, $q$Tunisia$q$, 'b', $q$Egypt beat Cameroon 1-0 in the final.$q$),
  ($q$In which year was goal-line technology first used at a World Cup?$q$, $q$2006$q$, $q$2014$q$, $q$2010$q$, $q$2018$q$, 'b', $q$The tournament was in Brazil.$q$),
  ($q$In which year was VAR first used at a World Cup?$q$, $q$2014$q$, $q$2022$q$, $q$2010$q$, $q$2018$q$, 'd', $q$The tournament was in Russia.$q$),
  ($q$What is the minimum number of players a team must have on the pitch to continue a match?$q$, $q$6$q$, $q$7$q$, $q$9$q$, $q$8$q$, 'b', $q$If a team falls below seven, the match is abandoned.$q$),
  ($q$Who scored the first goal in Premier League history in August 1992?$q$, $q$Brian Deane$q$, $q$Alan Shearer$q$, $q$Eric Cantona$q$, $q$Teddy Sheringham$q$, 'a', $q$He scored for Sheffield United against Manchester United.$q$),
  ($q$Which country won the Women's European Championship in 2022 on home soil?$q$, $q$Germany$q$, $q$England$q$, $q$Sweden$q$, $q$Spain$q$, 'b', $q$They beat Germany 2-1 at Wembley after extra time.$q$),
  ($q$Which country won the Women's Euro in 2025, beating Spain on penalties?$q$, $q$Germany$q$, $q$France$q$, $q$Netherlands$q$, $q$England$q$, 'd', $q$The final was in Basel, Switzerland.$q$),
  ($q$Which club won the Women's Champions League in 2025, beating Barcelona 1-0?$q$, $q$Arsenal$q$, $q$Lyon$q$, $q$Wolfsburg$q$, $q$Chelsea$q$, 'a', $q$The final was in Lisbon.$q$),
  ($q$Which country has won the Women's Africa Cup of Nations the most times?$q$, $q$Ghana$q$, $q$Cameroon$q$, $q$South Africa$q$, $q$Nigeria$q$, 'd', $q$The Super Falcons have won it ten times.$q$),
  ($q$Which brothers won the 1966 World Cup with England?$q$, $q$Ashley and Joe Cole$q$, $q$Jack and Bobby Charlton$q$, $q$Gary and Phil Neville$q$, $q$Rio and Anton Ferdinand$q$, 'b', $q$Bobby scored in the semi-final; Jack played in defence.$q$)
) as v(question_text, a, b, c, d, correct, fact)
where not exists (select 1 from public.questions q where q.question_text = v.question_text);
