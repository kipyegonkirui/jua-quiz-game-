-- ============================================================================
-- 029_odd_watch_hint.sql
-- Odd One Out: "Watch a video to remove one wrong item". Free in coins, removes
-- ONE wrong item (the 30-coin hint still removes two). One hint per puzzle,
-- at most 10 watch hints per Nairobi day. A hint still costs 30 points on that
-- puzzle (handled by the existing scoring). Run after 020_odd_one_out.
-- Safe to re-run.
-- ============================================================================

alter table public.odd_one_out_hints drop constraint if exists odd_one_out_hints_coins_spent_check;
alter table public.odd_one_out_hints add constraint odd_one_out_hints_coins_spent_check check (coins_spent >= 0);
alter table public.odd_one_out_hints add column if not exists source text not null default 'coins';
do $$ begin
  alter table public.odd_one_out_hints add constraint odd_one_out_hints_source_check check (source in ('coins','ad'));
exception when duplicate_object then null; end $$;

create or replace function public.use_odd_one_out_watch_hint(p_round_id uuid, p_puzzle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_daily_cap constant integer := 10;
  v_hint public.odd_one_out_hints%rowtype;
  v_eliminated text[];
  v_balance integer;
  v_used integer;
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

  select coins into v_balance from public.profiles where id = v_uid;

  select * into v_hint from public.odd_one_out_hints where round_id = p_round_id and puzzle_id = p_puzzle_id;
  if found then
    return jsonb_build_object('eliminated_options', v_hint.eliminated_options,
                              'coins_spent', 0, 'coins_balance', coalesce(v_balance, 0));
  end if;

  select count(*) into v_used
  from public.odd_one_out_hints h
  join public.odd_one_out_rounds r on r.id = h.round_id
  where r.user_id = v_uid and h.source = 'ad'
    and (h.created_at at time zone 'Africa/Nairobi')::date = public.nairobi_today();
  if v_used >= v_daily_cap then raise exception 'watch_limit_reached'; end if;

  select array_agg(x.c) into v_eliminated
  from (
    select c from unnest(array['a','b','c','d']) as c
    where c <> (select odd_option from public.odd_one_out_puzzles where id = p_puzzle_id)
    order by random()
    limit 1
  ) x;

  insert into public.odd_one_out_hints(round_id, puzzle_id, coins_spent, eliminated_options, source)
  values (p_round_id, p_puzzle_id, 0, v_eliminated, 'ad');

  return jsonb_build_object('eliminated_options', v_eliminated,
                            'coins_spent', 0, 'coins_balance', coalesce(v_balance, 0),
                            'watch_left', v_daily_cap - v_used - 1);
end;
$$;

revoke all on function public.use_odd_one_out_watch_hint(uuid, uuid) from public, anon;
grant execute on function public.use_odd_one_out_watch_hint(uuid, uuid) to authenticated;
