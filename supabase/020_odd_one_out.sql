-- 020_odd_one_out.sql
-- Odd One Out: spot the item that does not belong.
--
-- Two ways to play:
--   * daily  - one shared set of puzzles per Nairobi day, one attempt per day,
--              with a daily-play streak and a streak bonus on the coin reward.
--   * quick  - endless rounds; puzzles the player has not seen yet come first.
--
-- Server-authoritative, same contract as Guess It: the client never receives
-- the odd option or the explanation until it has answered that puzzle.
-- Requires: 007 (_coin_apply), 011 (coin ledger reasons), 003 (nairobi_today).

-- ---------------------------------------------------------------- tables --
create table if not exists public.odd_one_out_puzzles (
  id uuid primary key default gen_random_uuid(),
  puzzle_type text not null default 'category'
    check (puzzle_type in ('category','visual','wordplay','local','tricky')),
  item_a text not null,
  item_b text not null,
  item_c text not null,
  item_d text not null,
  odd_option text not null check (odd_option in ('a','b','c','d')),
  explanation text not null,
  difficulty text not null default 'medium' check (difficulty in ('easy','medium','hard')),
  time_limit_seconds integer not null default 12 check (time_limit_seconds between 5 and 60),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists odd_one_out_puzzle_items_unique
  on public.odd_one_out_puzzles(item_a, item_b, item_c, item_d);

create table if not exists public.odd_one_out_rounds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  mode text not null check (mode in ('daily','quick')),
  daily_date date,
  status text not null default 'open' check (status in ('open','completed','expired')),
  score integer not null default 0,
  correct integer not null default 0,
  total integer not null default 0,
  max_combo integer not null default 0,
  xp_earned integer not null default 0,
  coins_earned integer not null default 0,
  rewards_capped boolean not null default false,
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  check ((mode = 'daily') = (daily_date is not null))
);

-- One unfinished round per player per mode, and one daily round per day.
create unique index if not exists odd_one_out_one_open_round
  on public.odd_one_out_rounds(user_id, mode) where status = 'open';
create unique index if not exists odd_one_out_one_daily_per_day
  on public.odd_one_out_rounds(user_id, daily_date) where daily_date is not null;
create index if not exists odd_one_out_rounds_user_done
  on public.odd_one_out_rounds(user_id, mode, status);

create table if not exists public.odd_one_out_round_puzzles (
  round_id uuid not null references public.odd_one_out_rounds(id) on delete cascade,
  puzzle_id uuid not null references public.odd_one_out_puzzles(id) on delete cascade,
  position integer not null,
  primary key (round_id, puzzle_id),
  unique (round_id, position)
);

create table if not exists public.odd_one_out_answers (
  round_id uuid not null references public.odd_one_out_rounds(id) on delete cascade,
  puzzle_id uuid not null references public.odd_one_out_puzzles(id) on delete cascade,
  chosen text not null check (chosen in ('a','b','c','d','timeout')),
  is_correct boolean not null,
  score integer not null default 0,
  combo integer not null default 0,
  time_ms integer not null default 0 check (time_ms >= 0),
  hint_used boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (round_id, puzzle_id)
);

create table if not exists public.odd_one_out_hints (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.odd_one_out_rounds(id) on delete cascade,
  puzzle_id uuid not null references public.odd_one_out_puzzles(id) on delete cascade,
  coins_spent integer not null check (coins_spent > 0),
  eliminated_options text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (round_id, puzzle_id)
);

alter table public.odd_one_out_puzzles enable row level security;
alter table public.odd_one_out_rounds enable row level security;
alter table public.odd_one_out_round_puzzles enable row level security;
alter table public.odd_one_out_answers enable row level security;
alter table public.odd_one_out_hints enable row level security;

revoke all on public.odd_one_out_puzzles from anon, authenticated;
revoke all on public.odd_one_out_rounds from anon, authenticated;
revoke all on public.odd_one_out_round_puzzles from anon, authenticated;
revoke all on public.odd_one_out_answers from anon, authenticated;
revoke all on public.odd_one_out_hints from anon, authenticated;

-- --------------------------------------------------------------- content --
-- Starter puzzles (Kenya-focused plus general knowledge, wordplay and visual).
-- Safe to rerun: a puzzle whose four items already exist is skipped.
-- To add more later, insert rows into odd_one_out_puzzles from the Supabase
-- Table Editor (odd_option is the letter a-d of the item that does not belong).
insert into public.odd_one_out_puzzles
  (puzzle_type,item_a,item_b,item_c,item_d,odd_option,explanation,difficulty,time_limit_seconds)
values
  ('local','Yala','Naivasha','Nzoia','Tana','b','Tana, Nzoia and Yala are rivers. Naivasha is a lake.','medium',12),
  ('local','Nakuru','Kilimanjaro','Naivasha','Baringo','b','Nakuru, Baringo and Naivasha are Kenyan lakes. Kilimanjaro is a mountain in Tanzania.','easy',10),
  ('local','Ugali','Sukuma wiki','Nyama choma','Matatu','d','Ugali, sukuma wiki and nyama choma are food. A matatu is a minibus.','easy',10),
  ('local','Maji','Tatu','Moja','Mbili','a','Moja, mbili and tatu are Swahili for 1, 2 and 3. Maji means water.','easy',10),
  ('local','Eldoret','Kampala','Nakuru','Kisumu','b','Kisumu, Nakuru and Eldoret are Kenyan towns. Kampala is the capital of Uganda.','easy',10),
  ('local','Nairobi National Park','Amboseli','Tsavo','Serengeti','d','The other three are in Kenya. The Serengeti is in Tanzania.','medium',12),
  ('local','Kaizer Chiefs','AFC Leopards','Gor Mahia','Tusker FC','a','The other three are Kenyan clubs. Kaizer Chiefs play in South Africa.','medium',12),
  ('local','Eliud Kipchoge','Usain Bolt','David Rudisha','Faith Kipyegon','b','The other three are Kenyan athletes. Usain Bolt is Jamaican.','easy',10),
  ('local','Daniel arap Moi','Jomo Kenyatta','Mwai Kibaki','Nelson Mandela','d','The other three led Kenya. Nelson Mandela led South Africa.','easy',10),
  ('local','Zulu','Luo','Kikuyu','Kamba','a','Kikuyu, Luo and Kamba are Kenyan communities. Zulu is from South Africa.','medium',12),
  ('tricky','Blue','Black','Red','Green','a','Kenya''s flag has black, red, green and white. There is no blue.','medium',12),
  ('local','Submarine','Boda boda','Matatu','SGR train','a','Matatus, boda bodas and the SGR all run in Kenya. Kenya has no submarines on its roads or rails!','easy',10),
  ('local','Kisii','Dodoma','Kajiado','Machakos','b','Kisii, Kajiado and Machakos are Kenyan counties. Dodoma is the capital of Tanzania.','medium',12),
  ('local','Naivasha','Lamu','Malindi','Mombasa','a','Mombasa, Malindi and Lamu are on the coast. Naivasha is inland in the Rift Valley.','medium',12),
  ('local','Rwanda','Ethiopia','Tanzania','Uganda','a','Kenya borders Uganda, Tanzania, Ethiopia, South Sudan and Somalia. It does not border Rwanda.','medium',12),
  ('local','Mursik','Uji','Chai','Mandazi','d','Mursik, uji and chai are drinks. Mandazi is something you eat.','medium',12),
  ('local','Benga','Gengetone','Mugithi','Bossa nova','d','Benga, gengetone and mugithi are Kenyan sounds. Bossa nova began in Brazil.','medium',12),
  ('local','Airtel','KCB','Telkom','Safaricom','b','Safaricom, Airtel and Telkom are mobile networks. KCB is a bank.','medium',12),
  ('local','Netflix','T-Kash','M-Pesa','Airtel Money','a','M-Pesa, Airtel Money and T-Kash are mobile money services. Netflix is for streaming.','easy',10),
  ('local','Tembo','Simba','Twiga','Kiti','d','Simba is a lion, twiga a giraffe, tembo an elephant. Kiti means chair.','medium',12),
  ('local','Mbwa','Ng''ombe','Paka','Meza','d','Paka (cat), mbwa (dog) and ng''ombe (cow) are animals. Meza means table.','medium',12),
  ('local','Jambo','Asante','Karibu','Hello','d','Jambo, asante and karibu are Swahili. Hello is English.','easy',10),
  ('tricky','Lion','Elephant','Giraffe','Buffalo','c','The Big Five are lion, leopard, elephant, buffalo and rhino. The giraffe is not one of them.','medium',12),
  ('category','Mango','Pawpaw','Cabbage','Banana','c','Mango, pawpaw and banana are fruits. Cabbage is a vegetable.','easy',10),
  ('category','Liverpool','Chelsea','Arsenal','Barcelona','d','Chelsea, Arsenal and Liverpool are English clubs. Barcelona is Spanish.','easy',10),
  ('category','Rwandan franc','Kenyan shilling','Ugandan shilling','Tanzanian shilling','a','The other three currencies are shillings. Rwanda uses the franc.','medium',12),
  ('category','Elephant','Zebra','Flamingo','Lion','c','Lion, zebra and elephant are mammals. A flamingo is a bird.','easy',10),
  ('category','Leopard','Cheetah','Lion','Zebra','d','Cheetah, lion and leopard hunt meat. A zebra eats grass.','easy',10),
  ('tricky','Nairobi','Kampala','Lagos','Kigali','c','Nairobi, Kampala and Kigali are capitals. Lagos is Nigeria''s biggest city, but the capital is Abuja.','medium',12),
  ('category','Marathon','Steeplechase','High jump','Tennis','d','Marathon, steeplechase and high jump are athletics events. Tennis is not.','easy',10),
  ('tricky','Cricket','Rugby','Football','Chess','d','Rugby, cricket and football all use a ball. Chess does not.','easy',10),
  ('category','Mars','Moon','Venus','Saturn','b','Mars, Venus and Saturn are planets. The Moon orbits the Earth.','easy',10),
  ('wordplay','9','6','4','2','a','2, 4 and 6 are even numbers. 9 is the odd one out, literally!','easy',10),
  ('category','9','6','3','11','d','3, 6 and 9 are multiples of 3. 11 is not.','medium',12),
  ('category','13','11','7','15','d','7, 11 and 13 are prime numbers. 15 is 3 x 5.','medium',12),
  ('category','Sunday','Monday','Friday','July','d','Monday, Friday and Sunday are days. July is a month.','easy',10),
  ('tricky','Whale','Shark','Porpoise','Dolphin','b','Whales, dolphins and porpoises are mammals. A shark is a fish.','medium',12),
  ('tricky','Pumpkin','Tomato','Carrot','Cucumber','c','Botanically, tomato, cucumber and pumpkin are fruits. A carrot is a root.','hard',15),
  ('category','Butterfly','Beetle','Spider','Ant','c','Ant, beetle and butterfly are insects with six legs. A spider is an arachnid with eight.','medium',12),
  ('category','Eagle','Ostrich','Bee','Bat','b','Bats, eagles and bees fly. An ostrich cannot.','easy',10),
  ('category','Cube','Triangle','Square','Circle','a','Square, circle and triangle are flat shapes. A cube is 3D.','easy',10),
  ('category','Oxygen','Nitrogen','Iron','Hydrogen','c','Oxygen, nitrogen and hydrogen are gases. Iron is a solid metal.','medium',12),
  ('tricky','Second','Litre','Metre','Kilogram','b','Metre, kilogram and second are SI base units. The litre is not.','hard',15),
  ('tricky','Mouse','Keyboard','Scanner','Printer','d','Keyboard, mouse and scanner send information in. A printer is an output device.','medium',12),
  ('tricky','Midfielder','Goalkeeper','Umpire','Striker','c','Goalkeeper, striker and midfielder are football positions. Football has a referee; umpires are for cricket and tennis.','medium',12),
  ('category','Victoria','Atlantic','Indian','Pacific','a','Indian, Atlantic and Pacific are oceans. Victoria is a lake.','easy',10),
  ('wordplay','Civic','Lemon','Level','Radar','b','Level, radar and civic read the same backwards. Lemon does not.','medium',12),
  ('wordplay','Bat','Cat','Hat','Dog','d','Cat, hat and bat rhyme. Dog does not.','easy',10),
  ('wordplay','Arrow','Apple','Ball','Ant','c','Apple, ant and arrow start with A. Ball starts with B.','easy',10),
  ('wordplay','Cable','Chair','Stable','Table','b','Table, stable and cable rhyme. Chair does not.','easy',10),
  ('wordplay','Spoon','Bed','Pen','Cup','a','Cup, pen and bed have three letters. Spoon has five.','easy',10),
  ('wordplay','Bubble','Balloon','Tomato','Coffee','c','Coffee, balloon and bubble have double letters. Tomato has none.','medium',12),
  ('wordplay','Listen','Silent','Lesson','Enlist','c','Listen, silent and enlist are anagrams of each other. Lesson is not.','hard',15),
  ('wordplay','Ice','Egg','Owl','Pan','d','Egg, owl and ice start with a vowel. Pan starts with a consonant.','easy',10),
  ('wordplay','Dare','Read','Dear','Reed','d','Read, dear and dare use the same letters (A, D, E, R). Reed has two Es.','hard',15),
  ('wordplay','Rice','Bake','Lake','Cake','a','Bake, cake and lake rhyme. Rice does not.','easy',10),
  ('visual','🔴','🔴','🔴','🔵','d','Three red circles and one blue circle.','easy',10),
  ('visual','🟦','🟦','🟦','🔷','d','Three squares and one diamond.','easy',10),
  ('visual','🍏','🍎','🍎','🍎','a','Three red apples and one green apple.','easy',10),
  ('visual','🌳','🌳','🌴','🌳','c','Three leafy trees and one palm tree.','easy',10),
  ('visual','🌞','🌙','🌞','🌞','b','Three suns and one moon.','easy',10),
  ('visual','🐘','🦁','🦒','🐧','d','Lion, elephant and giraffe live on the African savanna. Penguins live in cold southern places.','medium',12)
on conflict (item_a,item_b,item_c,item_d) do nothing;

-- ------------------------------------------------------------- functions --

-- Consecutive Nairobi days (ending today, or yesterday if today is not played
-- yet) on which the player finished the Daily Odd One Out. Internal helper.
create or replace function public._odd_daily_streak(p_uid uuid)
returns integer
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_day date := public.nairobi_today();
  v_n integer := 0;
begin
  if not exists (
    select 1 from public.odd_one_out_rounds
    where user_id = p_uid and mode = 'daily' and status = 'completed' and daily_date = v_day
  ) then
    v_day := v_day - 1;
  end if;
  while exists (
    select 1 from public.odd_one_out_rounds
    where user_id = p_uid and mode = 'daily' and status = 'completed' and daily_date = v_day
  ) loop
    v_n := v_n + 1;
    v_day := v_day - 1;
  end loop;
  return v_n;
end;
$$;

revoke all on function public._odd_daily_streak(uuid) from public, anon, authenticated;

-- Result payload for a finished round, built from stored values. Internal helper.
create or replace function public._odd_one_out_result(p_round_id uuid, p_leveled boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'mode', r.mode,
    'score', r.score,
    'total', r.total,
    'correct', r.correct,
    'max_combo', r.max_combo,
    'xp_earned', r.xp_earned,
    'coins_earned', r.coins_earned,
    'rewards_capped', r.rewards_capped,
    'new_xp', p.xp,
    'new_level', p.level,
    'leveled_up', p_leveled,
    'best_score', (
      select coalesce(max(x.score), 0) from public.odd_one_out_rounds x
      where x.user_id = r.user_id and x.mode = r.mode and x.status = 'completed'
    ),
    'daily_streak', case when r.mode = 'daily' then public._odd_daily_streak(r.user_id) else 0 end,
    'pattern', (
      select coalesce(string_agg(case when a.is_correct then '🟩' else '🟥' end, '' order by rp.position), '')
      from public.odd_one_out_answers a
      join public.odd_one_out_round_puzzles rp on rp.round_id = a.round_id and rp.puzzle_id = a.puzzle_id
      where a.round_id = r.id
    )
  )
  from public.odd_one_out_rounds r
  join public.profiles p on p.id = r.user_id
  where r.id = p_round_id;
$$;

revoke all on function public._odd_one_out_result(uuid, boolean) from public, anon, authenticated;

-- Start (or resume) a round. p_mode: 'daily' or 'quick'.
create or replace function public.start_odd_one_out_round(p_mode text default 'quick')
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := public.nairobi_today();
  v_size constant integer := 8;
  v_round uuid;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_mode not in ('daily','quick') then raise exception 'invalid_mode'; end if;

  if p_mode = 'daily' then
    -- An unfinished daily round from an earlier day can no longer be completed.
    update public.odd_one_out_rounds
       set status = 'expired'
     where user_id = v_uid and mode = 'daily' and status = 'open' and daily_date < v_today;

    if exists (
      select 1 from public.odd_one_out_rounds
      where user_id = v_uid and mode = 'daily' and daily_date = v_today and status = 'completed'
    ) then
      raise exception 'daily_already_played';
    end if;

    select id into v_round from public.odd_one_out_rounds
     where user_id = v_uid and mode = 'daily' and daily_date = v_today and status = 'open';
    if v_round is not null then return v_round; end if;

    begin
      insert into public.odd_one_out_rounds(user_id, mode, daily_date, total)
      values (v_uid, 'daily', v_today, v_size) returning id into v_round;
    exception when unique_violation then
      select id into v_round from public.odd_one_out_rounds
       where user_id = v_uid and mode = 'daily' and daily_date = v_today and status = 'open';
      if v_round is null then raise exception 'daily_already_played'; end if;
      return v_round;
    end;

    -- Everyone gets the same puzzles, in the same order, on the same day.
    insert into public.odd_one_out_round_puzzles(round_id, puzzle_id, position)
    select v_round, p.id, (row_number() over (order by md5(p.id::text || v_today::text), p.id))::integer
    from (
      select id from public.odd_one_out_puzzles
      where is_active = true
      order by md5(id::text || v_today::text), id
      limit v_size
    ) p;
  else
    select id into v_round from public.odd_one_out_rounds
     where user_id = v_uid and mode = 'quick' and status = 'open';
    if v_round is not null then return v_round; end if;

    begin
      insert into public.odd_one_out_rounds(user_id, mode, total)
      values (v_uid, 'quick', v_size) returning id into v_round;
    exception when unique_violation then
      select id into v_round from public.odd_one_out_rounds
       where user_id = v_uid and mode = 'quick' and status = 'open';
      return v_round;
    end;

    -- Puzzles this player has answered least often come first, then random.
    insert into public.odd_one_out_round_puzzles(round_id, puzzle_id, position)
    select v_round, p.id, (row_number() over (order by p.seen, p.rnd))::integer
    from (
      select q.id,
             (select count(*) from public.odd_one_out_answers a
                join public.odd_one_out_rounds r on r.id = a.round_id
               where r.user_id = v_uid and a.puzzle_id = q.id) as seen,
             random() as rnd
      from public.odd_one_out_puzzles q
      where q.is_active = true
      order by seen, rnd
      limit v_size
    ) p;
  end if;

  update public.odd_one_out_rounds r
     set total = (select count(*) from public.odd_one_out_round_puzzles x where x.round_id = r.id)
   where r.id = v_round;

  if (select total from public.odd_one_out_rounds where id = v_round) = 0 then
    raise exception 'no_puzzles_available';
  end if;

  return v_round;
end;
$$;

revoke all on function public.start_odd_one_out_round(text) from public, anon;
grant execute on function public.start_odd_one_out_round(text) to authenticated;

-- The round's puzzles. The odd option and explanation are only included for
-- puzzles already answered, so an interrupted round can be resumed safely.
create or replace function public.get_odd_one_out_puzzles(p_round_id uuid)
returns table (
  id uuid,
  puzzle_type text,
  item_a text,
  item_b text,
  item_c text,
  item_d text,
  "position" integer,
  time_limit_seconds integer,
  difficulty text,
  answered boolean,
  chosen text,
  is_correct boolean,
  odd_option text,
  explanation text,
  score integer,
  combo integer,
  hint_used boolean,
  eliminated_options text[]
)
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select p.id, p.puzzle_type, p.item_a, p.item_b, p.item_c, p.item_d,
         rp.position, p.time_limit_seconds, p.difficulty,
         (a.puzzle_id is not null) as answered,
         a.chosen,
         a.is_correct,
         case when a.puzzle_id is not null then p.odd_option end,
         case when a.puzzle_id is not null then p.explanation end,
         coalesce(a.score, 0),
         coalesce(a.combo, 0),
         (h.id is not null) as hint_used,
         coalesce(h.eliminated_options, '{}')
  from public.odd_one_out_rounds r
  join public.odd_one_out_round_puzzles rp on rp.round_id = r.id
  join public.odd_one_out_puzzles p on p.id = rp.puzzle_id
  left join public.odd_one_out_answers a on a.round_id = r.id and a.puzzle_id = p.id
  left join public.odd_one_out_hints h on h.round_id = r.id and h.puzzle_id = p.id
  where r.id = p_round_id and r.user_id = auth.uid() and r.status = 'open'
  order by rp.position;
$$;

revoke all on function public.get_odd_one_out_puzzles(uuid) from public, anon;
grant execute on function public.get_odd_one_out_puzzles(uuid) to authenticated;

-- Hint: costs 30 coins and removes two of the three wrong items. One per puzzle.
create or replace function public.use_odd_one_out_hint(p_round_id uuid, p_puzzle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_cost constant integer := 30;
  v_hint public.odd_one_out_hints%rowtype;
  v_odd text;
  v_eliminated text[];
  v_balance integer;
  v_ref uuid := gen_random_uuid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.odd_one_out_rounds where id = p_round_id and user_id = v_uid and status = 'open') then
    raise exception 'round_not_found';
  end if;
  if not exists (select 1 from public.odd_one_out_round_puzzles where round_id = p_round_id and puzzle_id = p_puzzle_id) then
    raise exception 'puzzle_not_in_round';
  end if;
  if exists (select 1 from public.odd_one_out_answers where round_id = p_round_id and puzzle_id = p_puzzle_id) then
    raise exception 'puzzle_already_answered';
  end if;

  select * into v_hint from public.odd_one_out_hints where round_id = p_round_id and puzzle_id = p_puzzle_id;
  if found then
    select coins into v_balance from public.profiles where id = v_uid;
    return jsonb_build_object('eliminated_options', v_hint.eliminated_options,
                              'coins_spent', 0, 'coins_balance', coalesce(v_balance, 0));
  end if;

  select odd_option into v_odd from public.odd_one_out_puzzles where id = p_puzzle_id;
  select array_agg(x.c order by x.c) into v_eliminated
  from (
    select c from unnest(array['a','b','c','d']) as c
    where c <> v_odd
    order by random()
    limit 2
  ) x;

  insert into public.odd_one_out_hints(id, round_id, puzzle_id, coins_spent, eliminated_options)
  values (v_ref, p_round_id, p_puzzle_id, v_cost, v_eliminated);

  -- Raises not_enough_coins (rolling the hint row back) if the wallet is short.
  v_balance := public._coin_apply(v_uid, -v_cost, 'hint_purchase', v_ref);
  if v_balance is null then raise exception 'hint_purchase_failed'; end if;

  return jsonb_build_object('eliminated_options', v_eliminated,
                            'coins_spent', v_cost, 'coins_balance', v_balance);
end;
$$;

revoke all on function public.use_odd_one_out_hint(uuid, uuid) from public, anon;
grant execute on function public.use_odd_one_out_hint(uuid, uuid) to authenticated;

-- Answer one puzzle. Puzzles must be answered in order so the combo is honest.
--   score = (100 + 0..100 speed bonus) x combo multiplier (1.0 up to 1.5)
--   a hint costs 30 points (minimum 25 for a correct answer)
create or replace function public.answer_odd_one_out_puzzle(
  p_round_id uuid, p_puzzle_id uuid, p_choice text, p_time_ms integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_odd text;
  v_limit integer;
  v_expl text;
  v_pos integer;
  v_prev_combo integer;
  v_combo integer := 0;
  v_score integer := 0;
  v_correct boolean;
  v_hint boolean;
  v_time integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_choice not in ('a','b','c','d','timeout') then raise exception 'invalid_choice'; end if;
  if not exists (select 1 from public.odd_one_out_rounds where id = p_round_id and user_id = v_uid and status = 'open') then
    raise exception 'round_not_found';
  end if;

  select p.odd_option, p.time_limit_seconds, p.explanation, rp.position
    into v_odd, v_limit, v_expl, v_pos
  from public.odd_one_out_round_puzzles rp
  join public.odd_one_out_puzzles p on p.id = rp.puzzle_id
  where rp.round_id = p_round_id and rp.puzzle_id = p_puzzle_id;
  if v_odd is null then raise exception 'puzzle_not_in_round'; end if;

  if exists (select 1 from public.odd_one_out_answers where round_id = p_round_id and puzzle_id = p_puzzle_id) then
    raise exception 'already_answered';
  end if;
  if (select count(*) from public.odd_one_out_answers where round_id = p_round_id) <> v_pos - 1 then
    raise exception 'answer_out_of_order';
  end if;

  v_hint := exists (select 1 from public.odd_one_out_hints where round_id = p_round_id and puzzle_id = p_puzzle_id);
  v_time := greatest(0, least(coalesce(p_time_ms, 0), v_limit * 1000));
  v_correct := p_choice <> 'timeout' and p_choice = v_odd;

  select a.combo into v_prev_combo
  from public.odd_one_out_answers a
  join public.odd_one_out_round_puzzles rp on rp.round_id = a.round_id and rp.puzzle_id = a.puzzle_id
  where a.round_id = p_round_id and rp.position = v_pos - 1;
  v_prev_combo := coalesce(v_prev_combo, 0);

  if v_correct then
    v_combo := v_prev_combo + 1;
    v_score := round(
      (100 + greatest(0, 100 - floor((v_time::numeric / (v_limit * 1000)) * 100)::integer))
      * (1 + 0.1 * (least(v_combo, 6) - 1))
    )::integer;
    if v_hint then v_score := greatest(25, v_score - 30); end if;
  end if;

  insert into public.odd_one_out_answers(round_id, puzzle_id, chosen, is_correct, score, combo, time_ms, hint_used)
  values (p_round_id, p_puzzle_id, p_choice, v_correct, v_score, v_combo, v_time, v_hint);

  return jsonb_build_object(
    'puzzle_id', p_puzzle_id, 'chosen', p_choice, 'odd_option', v_odd,
    'is_correct', v_correct, 'score', v_score, 'combo', v_combo,
    'time_ms', v_time, 'hint_used', v_hint, 'explanation', v_expl
  );
end;
$$;

revoke all on function public.answer_odd_one_out_puzzle(uuid, uuid, text, integer) from public, anon;
grant execute on function public.answer_odd_one_out_puzzle(uuid, uuid, text, integer) to authenticated;

-- Finish a round and pay out. Safe to call twice: the second call returns the
-- stored result without paying again.
--   quick rounds: XP and coins for the first 8 rounds per Nairobi day (about the
--                 same daily XP ceiling as Practice); later rounds still score
--   daily round : +25 XP, +15 coins, plus a streak bonus (3 coins per streak day, up to 7)
create or replace function public.submit_odd_one_out_round(p_round_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  r public.odd_one_out_rounds%rowtype;
  v_score integer;
  v_correct integer;
  v_total integer;
  v_max_combo integer;
  v_perfect boolean;
  v_rewarded_today integer := 0;
  v_cap constant integer := 8;
  v_capped boolean := false;
  v_streak integer := 0;
  v_xp integer := 0;
  v_coins integer := 0;
  v_new_xp integer;
  v_old_level integer;
  v_new_level integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into r from public.odd_one_out_rounds where id = p_round_id and user_id = v_uid for update;
  if not found then raise exception 'round_not_found'; end if;
  if r.status = 'expired' then raise exception 'round_expired'; end if;
  if r.status = 'completed' then return public._odd_one_out_result(p_round_id, false); end if;

  select coalesce(sum(score), 0), count(*), count(*) filter (where is_correct), coalesce(max(combo), 0)
    into v_score, v_total, v_correct, v_max_combo
  from public.odd_one_out_answers where round_id = p_round_id;
  if v_total < r.total then raise exception 'round_not_finished'; end if;
  v_perfect := v_total > 0 and v_correct = v_total;

  -- Mark finished first so the streak count includes today's daily round.
  update public.odd_one_out_rounds
     set status = 'completed', score = v_score, correct = v_correct, total = v_total,
         max_combo = v_max_combo, submitted_at = now()
   where id = p_round_id;

  if r.mode = 'quick' then
    select count(*) into v_rewarded_today from public.odd_one_out_rounds
     where user_id = v_uid and mode = 'quick' and status = 'completed' and id <> p_round_id
       and xp_earned > 0
       and (submitted_at at time zone 'Africa/Nairobi')::date = public.nairobi_today();
    v_capped := v_rewarded_today >= v_cap;
  end if;

  if not v_capped then
    v_xp := least(60, v_correct * 6 + floor(v_score / 120.0)::integer);
    v_coins := v_correct * 2;
    if v_perfect then
      v_xp := v_xp + 10;
      v_coins := v_coins + 10;
    end if;
    if r.mode = 'daily' then
      v_streak := public._odd_daily_streak(v_uid);
      v_xp := v_xp + 25;
      v_coins := v_coins + 15 + least(v_streak, 7) * 3;
    end if;
  end if;

  select xp, level into v_new_xp, v_old_level from public.profiles where id = v_uid for update;
  v_new_xp := coalesce(v_new_xp, 0) + v_xp;
  v_new_level := (v_new_xp / 100) + 1;

  update public.profiles
     set xp = v_new_xp, level = v_new_level,
         total_attempts = total_attempts + 1,
         total_correct = total_correct + v_correct,
         total_questions = total_questions + v_total
   where id = v_uid;

  if v_coins > 0 then perform public._coin_apply(v_uid, v_coins, 'game_reward', p_round_id); end if;

  update public.odd_one_out_rounds
     set xp_earned = v_xp, coins_earned = v_coins, rewards_capped = v_capped
   where id = p_round_id;

  return public._odd_one_out_result(p_round_id, v_new_level > coalesce(v_old_level, 1));
end;
$$;

revoke all on function public.submit_odd_one_out_round(uuid) from public, anon;
grant execute on function public.submit_odd_one_out_round(uuid) to authenticated;

-- Lobby data: today's daily state, streak, best quick score, rewarded rounds left.
create or replace function public.get_odd_one_out_status()
returns jsonb
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_today date := public.nairobi_today();
  v_daily public.odd_one_out_rounds%rowtype;
  v_pattern text := '';
  v_used integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;

  select * into v_daily from public.odd_one_out_rounds
   where user_id = v_uid and mode = 'daily' and daily_date = v_today;

  if found and v_daily.status = 'completed' then
    select coalesce(string_agg(case when a.is_correct then '🟩' else '🟥' end, '' order by rp.position), '')
      into v_pattern
    from public.odd_one_out_answers a
    join public.odd_one_out_round_puzzles rp on rp.round_id = a.round_id and rp.puzzle_id = a.puzzle_id
    where a.round_id = v_daily.id;
  end if;

  select count(*) into v_used from public.odd_one_out_rounds
   where user_id = v_uid and mode = 'quick' and status = 'completed' and xp_earned > 0
     and (submitted_at at time zone 'Africa/Nairobi')::date = v_today;

  return jsonb_build_object(
    'daily_done', coalesce(v_daily.status = 'completed', false),
    'daily_in_progress', coalesce(v_daily.status = 'open', false),
    'daily_score', case when v_daily.status = 'completed' then v_daily.score else 0 end,
    'daily_correct', case when v_daily.status = 'completed' then v_daily.correct else 0 end,
    'daily_total', case when v_daily.status = 'completed' then v_daily.total else 0 end,
    'daily_pattern', v_pattern,
    'daily_streak', public._odd_daily_streak(v_uid),
    'best_quick_score', (select coalesce(max(score), 0) from public.odd_one_out_rounds
                          where user_id = v_uid and mode = 'quick' and status = 'completed'),
    'rewarded_rounds_left', greatest(0, 8 - v_used)
  );
end;
$$;

revoke all on function public.get_odd_one_out_status() from public, anon;
grant execute on function public.get_odd_one_out_status() to authenticated;
