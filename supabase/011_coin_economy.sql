-- 011_coin_economy.sql
-- Phase 1 Step 13: explicit coin economy API.
-- Coins remain server-authoritative; authenticated clients may only spend.

-- Extend the existing ledger reasons for the planned economy.
alter table public.coin_ledger
  drop constraint if exists coin_ledger_reason_check;

alter table public.coin_ledger
  add constraint coin_ledger_reason_check check (reason in (
    'competition_reward',
    'hint_purchase',
    'admin_grant',
    'second_chance_purchase',
    'streak_shield_purchase',
    'cosmetic_purchase',
    'competition_entry',
    'chest_reward',
    'mission_reward',
    'achievement_reward',
    'daily_reward',
    'game_reward'
  ));

-- Current balance only. This is safe for authenticated clients because it
-- exposes no ledger rows and cannot mutate state.
create or replace function public.get_coin_balance()
returns integer
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select coins from public.profiles where id = auth.uid();
$$;

revoke all on function public.get_coin_balance() from public, anon;
grant execute on function public.get_coin_balance() to authenticated;

-- Generic user spend entry point. Granting coins remains restricted to
-- server-owned/internal functions such as _coin_apply or admin flows.
create or replace function public.spend_coins(
  p_amount integer,
  p_reason text,
  p_ref uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_balance integer;
  v_new_balance integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_amount <= 0 then
    raise exception 'amount_must_be_positive';
  end if;
  if p_ref is null then
    raise exception 'reference_required';
  end if;
  if p_reason not in (
    'hint_purchase',
    'second_chance_purchase',
    'streak_shield_purchase',
    'cosmetic_purchase',
    'competition_entry'
  ) then
    raise exception 'invalid_spend_reason';
  end if;

  v_balance := public._coin_apply(v_uid, -p_amount, p_reason, p_ref);

  if v_balance is null then
    select coins into v_balance from public.profiles where id = v_uid;
    return jsonb_build_object(
      'amount_spent', p_amount,
      'reason', p_reason,
      'ref_id', p_ref,
      'balance', v_balance,
      'applied', false
    );
  end if;

  v_new_balance := v_balance;
  return jsonb_build_object(
    'amount_spent', p_amount,
    'reason', p_reason,
    'ref_id', p_ref,
    'balance', v_new_balance,
    'applied', true
  );
end;
$$;

revoke all on function public.spend_coins(integer, text, uuid) from public, anon;
grant execute on function public.spend_coins(integer, text, uuid) to authenticated;

-- Recent history for the signed-in player. The table remains closed to direct
-- SELECT access, so this is the only supported read path for wallet history.
create or replace function public.get_coin_ledger(p_limit integer default 20)
returns table (
  id bigint,
  amount integer,
  reason text,
  ref_id uuid,
  balance_after integer,
  created_at timestamptz
)
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select c.id, c.amount, c.reason, c.ref_id, c.balance_after, c.created_at
  from public.coin_ledger c
  where c.user_id = auth.uid()
  order by c.created_at desc
  limit greatest(1, least(coalesce(p_limit, 20), 100));
$$;

revoke all on function public.get_coin_ledger(integer) from public, anon;
grant execute on function public.get_coin_ledger(integer) to authenticated;
