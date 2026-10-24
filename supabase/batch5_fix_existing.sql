-- ============================================================================
-- batch5_fix_existing.sql
-- Run once. Batch 4 contains a question with a wrong premise:
--   "Who won Kenya's first Olympic gold medal, in the 1500 m at Mexico City 1968?"
-- Kenya's first Olympic gold was Naftali Temu's 10,000 m win on 13 Oct 1968.
-- Kip Keino's 1500 m gold came a week later. (Batch 2 already has the correct
-- Temu question.) This switches the wrong one off instead of deleting it, so
-- old rounds that used it keep working.
-- Also delete that row from seed_kenya_questions_batch4.sql so a re-run does
-- not add it back.
-- ============================================================================
update public.questions
set is_active = false
where question_text = 'Who won Kenya''s first Olympic gold medal, in the 1500 m at Mexico City 1968?';
