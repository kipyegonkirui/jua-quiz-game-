-- Phase 1 Step 17: progression reward chests.
-- Chests are unlocked and rewarded by server-authoritative RPCs.

create table if not exists public.reward_chest_definitions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  description text not null,
  icon text not null,
  required_level integer not null check (required_level > 1),
  min_coins integer not null check (min_coins >= 0),
  max_coins integer not null check (max_coins >= min_coins),
  reward_xp integer not null default 0 check (reward_xp >= 0),
  sort_order integer not null default 0,
  active boolean not null default true
);

create table if not exists public.user_reward_chests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  chest_id uuid not null references public.reward_chest_definitions(id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  claimed_at timestamptz,
  unique (user_id, chest_id)
);

alter table public.reward_chest_definitions enable row level security;
alter table public.user_reward_chests enable row level security;
revoke all on public.reward_chest_definitions from anon, authenticated;
revoke all on public.user_reward_chests from anon, authenticated;

insert into public.reward_chest_definitions
  (code,title,description,icon,required_level,min_coins,max_coins,reward_xp,sort_order)
values
  ('wooden','Wooden Chest','A small reward for reaching Level 2.','inventory_2',2,25,100,0,10),
  ('silver','Silver Chest','A bigger reward for reaching Level 5.','redeem',5,100,300,25,20),
  ('gold','Gold Chest','A major reward for reaching Level 10.','workspace_premium',10,300,1000,100,30)
on conflict (code) do update set
  title=excluded.title,
  description=excluded.description,
  icon=excluded.icon,
  required_level=excluded.required_level,
  min_coins=excluded.min_coins,
  max_coins=excluded.max_coins,
  reward_xp=excluded.reward_xp,
  sort_order=excluded.sort_order,
  active=true;

create index if not exists user_reward_chests_user_idx
  on public.user_reward_chests(user_id, unlocked_at desc);

create or replace function public.sync_reward_chests()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_level integer;
  v_unlocked integer := 0;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select level into v_level from public.profiles where id=v_uid;
  if v_level is null then raise exception 'profile_not_found'; end if;

  with candidates as (
    select d.id
    from public.reward_chest_definitions d
    where d.active and d.required_level <= v_level
  ), inserted as (
    insert into public.user_reward_chests(user_id, chest_id)
    select v_uid, c.id from candidates c
    on conflict (user_id, chest_id) do nothing
    returning id
  )
  select count(*) into v_unlocked from inserted;

  return v_unlocked;
end;
$$;

create or replace function public.get_reward_chests()
returns table (
  id uuid,
  code text,
  title text,
  description text,
  icon text,
  required_level integer,
  min_coins integer,
  max_coins integer,
  reward_xp integer,
  sort_order integer,
  unlocked_at timestamptz,
  claimed_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  return query
  select d.id,d.code,d.title,d.description,d.icon,d.required_level,d.min_coins,d.max_coins,
         d.reward_xp,d.sort_order,uc.unlocked_at,uc.claimed_at
  from public.reward_chest_definitions d
  left join public.user_reward_chests uc
    on uc.chest_id=d.id and uc.user_id=auth.uid()
  where d.active
  order by d.sort_order,d.id;
end;
$$;

create or replace function public.claim_reward_chest(p_chest_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_uc public.user_reward_chests%rowtype;
  v_def public.reward_chest_definitions%rowtype;
  v_profile public.profiles%rowtype;
  v_coins integer;
  v_new_xp integer;
  v_new_level integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_uc from public.user_reward_chests
    where user_id=v_uid and chest_id=p_chest_id for update;
  if not found then raise exception 'chest_not_unlocked'; end if;

  select * into v_def from public.reward_chest_definitions
    where id=p_chest_id and active;
  if not found then raise exception 'chest_not_found'; end if;

  select * into v_profile from public.profiles where id=v_uid for update;

  if v_uc.claimed_at is not null then
    return jsonb_build_object(
      'claimed',false,'balance',v_profile.coins,'coins_awarded',0,
      'xp_awarded',0,'new_xp',v_profile.xp,'new_level',v_profile.level,'leveled_up',false
    );
  end if;

  v_coins := floor(random() * (v_def.max_coins - v_def.min_coins + 1))::integer + v_def.min_coins;
  v_new_xp := v_profile.xp + v_def.reward_xp;
  v_new_level := (v_new_xp / 100) + 1;

  update public.profiles set xp=v_new_xp, level=v_new_level where id=v_uid;
  v_coins := public._coin_apply(v_uid,v_coins,'chest_reward',v_uc.id);
  update public.user_reward_chests set claimed_at=now() where id=v_uc.id;

  return jsonb_build_object(
    'claimed',true,'balance',v_coins,'coins_awarded',v_coins-v_profile.coins,
    'xp_awarded',v_def.reward_xp,'new_xp',v_new_xp,'new_level',v_new_level,
    'leveled_up',v_new_level>v_profile.level
  );
end;
$$;

revoke all on function public.sync_reward_chests() from public, anon;
revoke all on function public.get_reward_chests() from public, anon;
revoke all on function public.claim_reward_chest(uuid) from public, anon;
grant execute on function public.sync_reward_chests() to authenticated;
grant execute on function public.get_reward_chests() to authenticated;
grant execute on function public.claim_reward_chest(uuid) to authenticated;
