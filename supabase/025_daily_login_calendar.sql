-- ============================================================================
-- 025_daily_login_calendar.sql
-- 7-day daily reward calendar. Open the app each Nairobi day and claim the next
-- day's coins; miss a day and the calendar starts again at day 1.
-- Run after 024_content_quality.sql. Safe to re-run.
-- ============================================================================

create table if not exists public.daily_login_claims (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  claim_date date not null,
  day_number integer not null check (day_number between 1 and 7),
  coins      integer not null,
  created_at timestamptz not null default now(),
  primary key (user_id, claim_date)
);
alter table public.daily_login_claims enable row level security;
revoke all on public.daily_login_claims from anon, authenticated;

-- Coins for day 1..7 (day 7 is the big one).
create or replace function public._login_reward_coins(p_day integer)
returns integer language sql immutable as $$
  select (array[10, 10, 15, 15, 20, 25, 60])[p_day];
$$;

create or replace function public._login_calendar_state(p_uid uuid)
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  v_today date := (now() at time zone 'Africa/Nairobi')::date;
  v_last  record;
  v_claimed boolean := false;
  v_day integer;     -- the day to claim next (or the day claimed today)
  v_done integer;    -- days completed in this cycle
begin
  select claim_date, day_number into v_last
    from daily_login_claims where user_id = p_uid order by claim_date desc limit 1;

  if v_last.claim_date is null then
    v_day := 1; v_done := 0;
  elsif v_last.claim_date = v_today then
    v_claimed := true; v_day := v_last.day_number; v_done := v_last.day_number;
  elsif v_last.claim_date = v_today - 1 then
    v_day := (v_last.day_number % 7) + 1; v_done := v_day - 1;
  else
    v_day := 1; v_done := 0;
  end if;

  return jsonb_build_object(
    'claimed_today', v_claimed,
    'day', v_day,
    'days_done', v_done,
    'rewards', jsonb_build_array(10, 10, 15, 15, 20, 25, 60),
    'today_reward', public._login_reward_coins(v_day)
  );
end $$;

create or replace function public.get_login_calendar()
returns jsonb
language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return public._login_calendar_state(auth.uid());
end $$;

create or replace function public.claim_login_reward()
returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  v_today date := (now() at time zone 'Africa/Nairobi')::date;
  v_state jsonb;
  v_day integer; v_coins integer; v_balance integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  perform 1 from profiles where id = v_uid for update;   -- serialise double taps
  v_state := public._login_calendar_state(v_uid);
  if (v_state->>'claimed_today')::boolean then
    return v_state || jsonb_build_object('granted', 0, 'already_claimed', true);
  end if;
  v_day := (v_state->>'day')::integer;
  v_coins := public._login_reward_coins(v_day);
  insert into daily_login_claims (user_id, claim_date, day_number, coins)
    values (v_uid, v_today, v_day, v_coins);
  v_balance := public._coin_apply(v_uid, v_coins, 'daily_reward', gen_random_uuid());
  return public._login_calendar_state(v_uid)
      || jsonb_build_object('granted', v_coins, 'already_claimed', false, 'balance', v_balance);
end $$;

revoke all on function public._login_reward_coins(integer) from public, anon, authenticated;
revoke all on function public._login_calendar_state(uuid) from public, anon, authenticated;
revoke all on function public.get_login_calendar() from public, anon;
revoke all on function public.claim_login_reward() from public, anon;
grant execute on function public.get_login_calendar() to authenticated;
grant execute on function public.claim_login_reward() to authenticated;
