-- 017_guess_it.sql
-- Phase 1 Step 22: Guess It visual game mode.
--
-- Server-authoritative round, answers, hint purchases, score and rewards.
-- The client never receives the correct option until an answer is submitted.

create table if not exists public.guess_it_questions (
  id uuid primary key default gen_random_uuid(),
  prompt text not null,
  image_url text not null,
  option_a text not null,
  option_b text not null,
  option_c text not null,
  option_d text not null,
  correct_option text not null check (correct_option in ('a','b','c','d')),
  difficulty text not null default 'medium' check (difficulty in ('easy','medium','hard')),
  time_limit_seconds integer not null default 15 check (time_limit_seconds between 5 and 60),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.guess_it_rounds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'open' check (status in ('open','completed')),
  score integer not null default 0,
  correct integer not null default 0,
  total integer not null default 0,
  xp_earned integer not null default 0,
  coins_earned integer not null default 0,
  created_at timestamptz not null default now(),
  submitted_at timestamptz
);

create unique index if not exists guess_it_question_prompt_unique
  on public.guess_it_questions(prompt);

create unique index if not exists guess_it_one_open_round_per_user
  on public.guess_it_rounds(user_id) where status = 'open';

create table if not exists public.guess_it_round_questions (
  round_id uuid not null references public.guess_it_rounds(id) on delete cascade,
  question_id uuid not null references public.guess_it_questions(id) on delete cascade,
  position integer not null,
  primary key (round_id, question_id),
  unique (round_id, position)
);

create table if not exists public.guess_it_answers (
  round_id uuid not null references public.guess_it_rounds(id) on delete cascade,
  question_id uuid not null references public.guess_it_questions(id) on delete cascade,
  chosen text not null check (chosen in ('a','b','c','d','timeout')),
  is_correct boolean not null,
  score integer not null default 0,
  time_ms integer not null default 0 check (time_ms >= 0),
  hint_level integer not null default 0 check (hint_level between 0 and 3),
  created_at timestamptz not null default now(),
  primary key (round_id, question_id)
);

create table if not exists public.guess_it_hints (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.guess_it_rounds(id) on delete cascade,
  question_id uuid not null references public.guess_it_questions(id) on delete cascade,
  hint_level integer not null check (hint_level between 1 and 3),
  coins_spent integer not null check (coins_spent > 0),
  eliminated_options text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (round_id, question_id, hint_level)
);

alter table public.guess_it_questions enable row level security;
alter table public.guess_it_rounds enable row level security;
alter table public.guess_it_round_questions enable row level security;
alter table public.guess_it_answers enable row level security;
alter table public.guess_it_hints enable row level security;

revoke all on public.guess_it_questions from anon, authenticated;
revoke all on public.guess_it_rounds from anon, authenticated;
revoke all on public.guess_it_round_questions from anon, authenticated;
revoke all on public.guess_it_answers from anon, authenticated;
revoke all on public.guess_it_hints from anon, authenticated;

-- Starter content uses bundled Flutter SVG assets. Production/admin content can
-- replace image_url with HTTPS media URLs without changing the game contract.
insert into public.guess_it_questions
  (prompt,image_url,option_a,option_b,option_c,option_d,correct_option,difficulty,time_limit_seconds)
values
  ('Which animal is hidden in the picture?','asset:assets/guess_it/lion.svg','Lion','Elephant','Giraffe','Zebra','a','easy',15),
  ('Which animal is shown?','asset:assets/guess_it/elephant.svg','Rhino','Elephant','Hippo','Buffalo','b','easy',15),
  ('What is this famous Kenyan scene?','asset:assets/guess_it/nairobi.svg','Nairobi skyline','Mombasa Old Town','Mount Kenya','Lake Nakuru','a','medium',15),
  ('Which sport is represented?','asset:assets/guess_it/football.svg','Basketball','Rugby','Football','Tennis','c','easy',12),
  ('What can you identify here?','asset:assets/guess_it/savanna.svg','Savanna','Desert','Arctic','Rainforest','a','medium',15),
  ('Which object is hidden in the picture?','asset:assets/guess_it/camera.svg','Camera','Microphone','Laptop','Headphones','a','medium',15)
on conflict (prompt) do nothing;

create or replace function public.start_guess_it_round()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_round uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select id into v_round from public.guess_it_rounds where user_id = v_uid and status = 'open' limit 1;
  if v_round is not null then return v_round; end if;

  insert into public.guess_it_rounds(user_id, total)
  values (v_uid, 5) returning id into v_round;

  insert into public.guess_it_round_questions(round_id, question_id, position)
  select v_round, q.id, row_number() over ()
  from (
    select id from public.guess_it_questions where is_active = true order by random() limit 5
  ) q;

  update public.guess_it_rounds r
     set total = (select count(*) from public.guess_it_round_questions x where x.round_id = r.id)
   where r.id = v_round;

  return v_round;
end;
$$;

grant execute on function public.start_guess_it_round() to authenticated;

create or replace function public.get_guess_it_questions(p_round_id uuid)
returns table (
  id uuid,
  prompt text,
  image_url text,
  option_a text,
  option_b text,
  option_c text,
  option_d text,
  "position" integer,
  time_limit_seconds integer,
  difficulty text
)
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select q.id,q.prompt,q.image_url,q.option_a,q.option_b,q.option_c,q.option_d,
         rq.position,q.time_limit_seconds,q.difficulty
  from public.guess_it_rounds r
  join public.guess_it_round_questions rq on rq.round_id=r.id
  join public.guess_it_questions q on q.id=rq.question_id
  where r.id=p_round_id and r.user_id=auth.uid() and r.status='open'
  order by rq.position;
$$;

grant execute on function public.get_guess_it_questions(uuid) to authenticated;

create or replace function public.use_guess_it_hint(p_round_id uuid, p_question_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_next integer;
  v_cost integer;
  v_eliminated text[] := '{}';
  v_ref uuid := gen_random_uuid();
  v_balance integer;
  v_wrong text[];
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.guess_it_rounds where id=p_round_id and user_id=v_uid and status='open') then raise exception 'round_not_found'; end if;
  if not exists (select 1 from public.guess_it_round_questions where round_id=p_round_id and question_id=p_question_id) then raise exception 'question_not_in_round'; end if;
  if exists (select 1 from public.guess_it_answers where round_id=p_round_id and question_id=p_question_id) then raise exception 'question_already_answered'; end if;

  select coalesce(max(hint_level),0)+1 into v_next from public.guess_it_hints where round_id=p_round_id and question_id=p_question_id;
  if v_next > 3 then raise exception 'all_hints_used'; end if;
  v_cost := case v_next when 1 then 25 when 2 then 40 else 60 end;

  if v_next = 3 then
    select array_agg(x.choice order by x.choice) into v_wrong
    from (
      select unnest(array['a','b','c','d']) choice
      except select correct_option from public.guess_it_questions where id=p_question_id
      limit 2
    ) x;
    v_eliminated := coalesce(v_wrong,'{}');
  end if;

  select coins into v_balance from public.profiles where id=v_uid for update;
  if coalesce(v_balance,0) < v_cost then raise exception 'not_enough_coins'; end if;

  insert into public.guess_it_hints(round_id,question_id,hint_level,coins_spent,eliminated_options)
  values(p_round_id,p_question_id,v_next,v_cost,v_eliminated)
  on conflict do nothing;

  if not found then
    select id, coins_spent, eliminated_options into v_ref, v_cost, v_eliminated
    from public.guess_it_hints where round_id=p_round_id and question_id=p_question_id and hint_level=v_next;
  else
    v_ref := (select id from public.guess_it_hints where round_id=p_round_id and question_id=p_question_id and hint_level=v_next);
  end if;

  v_balance := public._coin_apply(v_uid, -v_cost, 'hint_purchase', v_ref);
  if v_balance is null then raise exception 'hint_purchase_failed'; end if;

  return jsonb_build_object('hint_level',v_next,'eliminated_options',v_eliminated,'coins_spent',v_cost,'coins_balance',v_balance);
end;
$$;

grant execute on function public.use_guess_it_hint(uuid,uuid) to authenticated;

create or replace function public.answer_guess_it_question(
  p_round_id uuid, p_question_id uuid, p_choice text, p_time_ms integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_correct text;
  v_limit integer;
  v_hint integer;
  v_score integer := 0;
  v_is_correct boolean := false;
  v_time integer := greatest(0, least(coalesce(p_time_ms,0),60000));
  v_existing public.guess_it_answers%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_choice not in ('a','b','c','d','timeout') then raise exception 'invalid_choice'; end if;
  select q.correct_option,q.time_limit_seconds into v_correct,v_limit
  from public.guess_it_questions q join public.guess_it_round_questions rq on rq.question_id=q.id
  where rq.round_id=p_round_id and q.id=p_question_id;
  if v_correct is null then raise exception 'question_not_in_round'; end if;
  if not exists (select 1 from public.guess_it_rounds where id=p_round_id and user_id=v_uid and status='open') then raise exception 'round_not_found'; end if;
  if exists (select 1 from public.guess_it_answers where round_id=p_round_id and question_id=p_question_id) then raise exception 'already_answered'; end if;
  select coalesce(max(hint_level),0) into v_hint from public.guess_it_hints where round_id=p_round_id and question_id=p_question_id;

  v_is_correct := p_choice <> 'timeout' and p_choice = v_correct;
  if v_is_correct then
    v_score := 100 + greatest(0, 100 - floor((v_time::numeric / greatest(v_limit*1000,1))*100)::integer);
    v_score := greatest(25, v_score - v_hint*10);
  end if;

  insert into public.guess_it_answers(round_id,question_id,chosen,is_correct,score,time_ms,hint_level)
  values(p_round_id,p_question_id,p_choice,v_is_correct,v_score,v_time,v_hint)
  returning * into v_existing;

  return jsonb_build_object('question_id',p_question_id,'chosen',p_choice,'correct_option',v_correct,'is_correct',v_is_correct,'score',v_score,'time_ms',v_time,'hint_level',v_hint);
end;
$$;

grant execute on function public.answer_guess_it_question(uuid,uuid,text,integer) to authenticated;

create or replace function public.submit_guess_it_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  r record;
  v_score integer;
  v_correct integer;
  v_total integer;
  v_xp integer;
  v_coins integer;
  v_new_xp integer;
  v_new_level integer;
  v_old_level integer;
  v_best integer;
  v_leveled boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into r from public.guess_it_rounds where id=p_round_id and user_id=v_uid for update;
  if not found then raise exception 'round_not_found'; end if;
  if r.status='completed' then
    return jsonb_build_object('score',r.score,'total',r.total,'correct',r.correct,'xp_earned',r.xp_earned,'coins_earned',r.coins_earned,'new_xp',(select xp from public.profiles where id=v_uid),'new_level',(select level from public.profiles where id=v_uid),'leveled_up',false,'best_score',(select coalesce(max(score),0) from public.guess_it_rounds where user_id=v_uid and status='completed'));
  end if;

  select coalesce(sum(score),0),count(*),count(*) filter (where is_correct) into v_score,v_total,v_correct
  from public.guess_it_answers where round_id=p_round_id;
  if v_total < r.total then raise exception 'round_not_finished'; end if;

  v_xp := least(150, v_correct*15 + floor(v_score/50)::integer);
  if v_correct = v_total and v_total > 0 then v_xp := v_xp + 25; end if;
  v_coins := v_correct*5 + case when v_correct=v_total and v_total>0 then 20 else 0 end;

  select xp,level into v_new_xp,v_old_level from public.profiles where id=v_uid for update;
  v_new_xp := v_new_xp + v_xp;
  v_new_level := (v_new_xp / 100) + 1;
  v_leveled := v_new_level > v_old_level;

  update public.profiles set xp=v_new_xp,level=v_new_level,total_attempts=total_attempts+1,total_correct=total_correct+v_correct,total_questions=total_questions+v_total where id=v_uid;
  if v_coins > 0 then perform public._coin_apply(v_uid,v_coins,'game_reward',p_round_id); end if;
  update public.guess_it_rounds set status='completed',score=v_score,correct=v_correct,total=v_total,xp_earned=v_xp,coins_earned=v_coins,submitted_at=now() where id=p_round_id;
  select coalesce(max(score),0) into v_best from public.guess_it_rounds where user_id=v_uid and status='completed';

  return jsonb_build_object('score',v_score,'total',v_total,'correct',v_correct,'xp_earned',v_xp,'coins_earned',v_coins,'new_xp',v_new_xp,'new_level',v_new_level,'leveled_up',v_leveled,'best_score',v_best);
end;
$$;

grant execute on function public.submit_guess_it_round(uuid) to authenticated;
