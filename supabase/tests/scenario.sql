\set ON_ERROR_STOP on
set client_min_messages = notice;
do $$
declare
  v_uid uuid := gen_random_uuid();
  r uuid; q record; res jsonb; j jsonb; lv jsonb;
  v_correct text; n int;
begin
  insert into auth.users(id, email, is_anonymous) values (v_uid, 'test@example.com', false);
  perform set_config('request.jwt.claim.sub', v_uid::text, false);
  raise notice 'profile rows: %', (select count(*) from public.profiles where id = v_uid);

  ---------------------------------------------------------------- practice L1
  r := public.start_practice_level_round(1);
  for q in select prq.question_id, qq.correct_option from practice_round_questions prq join questions qq on qq.id=prq.question_id where prq.round_id=r order by prq.position loop
    perform public.answer_practice_question(r, q.question_id, q.correct_option);
  end loop;
  res := public.submit_practice_round(r);
  raise notice 'PRACTICE L1 stars=% xp=%', res->>'practice_stars', res->>'xp_earned';
  raise notice 'practice lives: %', public.get_practice_lives();

  -- unlock to level 10 (Math level) by faking progress
  insert into practice_level_progress(user_id, level_number, best_stars, best_score, best_total, attempts)
    select v_uid, g, 3, 5, 5, 1 from generate_series(2,9) g;
  r := public.start_practice_level_round(10);
  raise notice 'PRACTICE L10 (math) questions: %', (select string_agg(zq.question_text, ' | ' order by prq.position) from practice_round_questions prq join questions zq on zq.id=prq.question_id where prq.round_id=r);
  perform public.abandon_practice_level_round(r);

  ---------------------------------------------------------------- speed L1
  for n in 1..3 loop
    r := public.start_mode_level('speed_quiz', 1);
    raise notice 'SPEED L1 attempt % round % difficulties=%', n, r,
      (select string_agg(zq.difficulty, ',' order by o.ord) from speed_quiz_rounds sr, unnest(sr.question_order) with ordinality o(id, ord) join questions zq on zq.id=o.id where sr.id=r);
    if n = 1 then
      -- fail on purpose: wrong answers
      for q in select o.id from speed_quiz_rounds sr, unnest(sr.question_order) with ordinality o(id,ord) where sr.id=r order by o.ord loop
        select case when correct_option='a' then 'b' else 'a' end into v_correct from questions where id=q.id;
        perform public.answer_speed_quiz_question(r, q.id, v_correct, false);
      end loop;
    else
      for q in select o.id from speed_quiz_rounds sr, unnest(sr.question_order) with ordinality o(id,ord) where sr.id=r order by o.ord loop
        select correct_option into v_correct from questions where id=q.id;
        perform public.answer_speed_quiz_question(r, q.id, v_correct, false);
      end loop;
    end if;
    perform public.submit_speed_quiz_round(r);
    res := public.complete_mode_level(r);
    raise notice 'SPEED attempt % -> %  lives=%', n, res, public.get_mode_lives('speed_quiz');
    exit when n = 2;
  end loop;
  -- level 2 now open; abandon test
  r := public.start_mode_level('speed_quiz', 2);
  raise notice 'speed L2 started %, lives=%', r, public.get_mode_lives('speed_quiz');
  perform public.abandon_mode_level(r);
  raise notice 'after abandon lives=% round_exists=%', public.get_mode_lives('speed_quiz'), exists(select 1 from speed_quiz_rounds where id=r);
  raise notice 'speed journey L1..3: %', (select jsonb_agg(l) from jsonb_array_elements(public.get_mode_journey('speed_quiz', 10)->'levels') l where (l->>'level')::int <= 3);

  ---------------------------------------------------------------- guess L1
  r := public.start_mode_level('guess_it', 1);
  raise notice 'GUESS L1 round % questions=%', r, (select count(*) from guess_it_round_questions where round_id=r);
  for q in select rq.question_id, gq.correct_option from guess_it_round_questions rq join guess_it_questions gq on gq.id=rq.question_id where rq.round_id=r order by rq.position loop
    perform public.answer_guess_it_question(r, q.question_id, q.correct_option, 3000);
  end loop;
  perform public.submit_guess_it_round(r);
  raise notice 'GUESS -> %', public.complete_mode_level(r);

  ---------------------------------------------------------------- odd L1
  r := public.start_mode_level('odd_one_out', 1);
  raise notice 'ODD L1 round % puzzles=% difficulties=%', r, (select count(*) from odd_one_out_round_puzzles where round_id=r),
    (select string_agg(p.difficulty, ',' order by rp.position) from odd_one_out_round_puzzles rp join odd_one_out_puzzles p on p.id=rp.puzzle_id where rp.round_id=r);
  for q in select rp.puzzle_id, p.odd_option from odd_one_out_round_puzzles rp join odd_one_out_puzzles p on p.id=rp.puzzle_id where rp.round_id=r order by rp.position loop
    perform public.answer_odd_one_out_puzzle(r, q.puzzle_id, q.odd_option, 2500);
  end loop;
  res := public.submit_odd_one_out_round(r);
  raise notice 'ODD submit xp=% ', res->>'xp_earned';
  raise notice 'ODD -> %', public.complete_mode_level(r);
  raise notice 'ODD resume check (complete twice): %', public.complete_mode_level(r);
end $$;
