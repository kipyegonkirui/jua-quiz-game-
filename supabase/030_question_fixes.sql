-- 030_question_fixes.sql
-- Corrects one answer found while fact-checking batches 6 to 11.
--   "Which is Kenya's third-largest city by population?"  Kisumu -> Nakuru
--   (2019 census: Nakuru about 570,000, Eldoret about 476,000, Kisumu about 398,000.)
-- Run it AFTER seed_kenya_questions_batch9.sql. Safe to re-run; it only touches that one question,
-- and does nothing if the question was loaded from the corrected batch 9 file.
update public.questions
   set correct_option = 'b',
       did_you_know = $q$Nairobi and Mombasa are the two largest. In the 2019 census Nakuru had about 570,000 people, ahead of Eldoret and Kisumu.$q$
 where question_text = $q$Which is Kenya's third-largest city by population?$q$
   and option_a = $q$Kisumu$q$
   and option_b = $q$Nakuru$q$
   and correct_option = 'a';
