\set ON_ERROR_STOP on
set client_min_messages = notice;
do $$
declare v_uid uuid := gen_random_uuid(); r uuid; r2 uuid; lv int;
begin
  insert into auth.users(id, email) values (v_uid, 'b@example.com');
  perform set_config('request.jwt.claim.sub', v_uid::text, false);
  insert into mode_level_progress(user_id, mode, level_number, best_stars, best_score, best_total, attempts)
    select v_uid, 'odd_one_out', g, 3, 8, 8, 1 from generate_series(1,44) g;
  foreach lv in array array[25,30,45] loop
    -- gate: level 21,31,41 are batch starts; ensure gate satisfied via cumulative stars (44*3=132 stars)
    insert into mode_level_progress(user_id, mode, level_number, best_stars) select v_uid,'odd_one_out',g,3 from generate_series(1,lv-1) g on conflict do nothing;
    r := public.start_mode_level('odd_one_out', lv);
    raise notice 'ODD L% difficulties=%', lv, (select string_agg(p.difficulty, ',' order by rp.position) from odd_one_out_round_puzzles rp join odd_one_out_puzzles p on p.id=rp.puzzle_id where rp.round_id=r);
    -- switching levels auto-abandons
    if lv = 25 then
      r2 := public.start_mode_level('odd_one_out', lv-1);
      raise notice '  switched: old round exists=% attempt status=%', exists(select 1 from odd_one_out_rounds where id=r), (select status from mode_level_attempts where round_id=r);
      perform public.abandon_mode_level(r2);
    else
      perform public.abandon_mode_level(r);
    end if;
  end loop;
  -- batch gate on fresh mode: speed level 11 needs level 10 first
  begin perform public.start_mode_level('speed_quiz', 5); exception when others then raise notice 'speed L5 locked: %', sqlerrm; end;
  -- ad unlock for batch 2
  raise notice 'ad1: %', (public.unlock_mode_batch_by_ad('guess_it', 2))->>'ad_unlocks_used';
  perform public.unlock_mode_batch_by_ad('guess_it', 2); perform public.unlock_mode_batch_by_ad('guess_it', 2);
  begin perform public.unlock_mode_batch_by_ad('guess_it', 2); exception when others then raise notice 'ad4 refused: %', sqlerrm; end;
  begin perform public.start_mode_level('bogus', 1); exception when others then raise notice 'bad mode: %', sqlerrm; end;
  -- lives exhaustion
  for lv in 1..5 loop
    r := public.start_mode_level('guess_it', 1);
    perform public.abandon_mode_level(r);
  end loop;
  begin perform public.start_mode_level('guess_it', 1); exception when others then raise notice 'no lives: %', sqlerrm; end;
  raise notice 'guess lives: %', public.get_mode_lives('guess_it');
  raise notice 'speed lives untouched: %', public.get_mode_lives('speed_quiz');
end $$;
