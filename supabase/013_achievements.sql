-- 013_achievements.sql
-- Phase 1 Step 15: permanent achievements.
-- Unlock conditions are evaluated from server-authoritative profile/game data.

create table if not exists public.achievement_definitions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  title text not null,
  description text not null,
  icon text not null,
  target integer not null default 1 check (target > 0),
  reward_xp integer not null default 0 check (reward_xp >= 0),
  reward_coins integer not null default 0 check (reward_coins >= 0),
  sort_order integer not null default 0,
  active boolean not null default true
);

create table if not exists public.user_achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  achievement_id uuid not null references public.achievement_definitions(id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  claimed_at timestamptz,
  unique (user_id, achievement_id)
);

alter table public.achievement_definitions enable row level security;
alter table public.user_achievements enable row level security;
revoke all on public.achievement_definitions from anon, authenticated;
revoke all on public.user_achievements from anon, authenticated;

insert into public.achievement_definitions
  (code,title,description,icon,target,reward_xp,reward_coins,sort_order)
values
  ('first_step','First Step','Complete your first quiz round.','flag',1,25,10,10),
  ('question_crusher','Question Crusher','Answer 50 questions.','quiz',50,50,25,20),
  ('sharp_shooter','Sharp Shooter','Get 25 questions correct.','target',25,75,35,30),
  ('quiz_veteran','Quiz Veteran','Complete 10 scored quiz attempts.','trophy',10,100,50,40),
  ('perfect_round','Perfect Round','Complete a round with every answer correct.','star',1,100,75,50),
  ('streak_3','On Fire','Reach a 3-day streak.','local_fire_department',3,75,40,60),
  ('streak_7','Week Warrior','Reach a 7-day streak.','whatshot',7,150,100,70),
  ('level_5','Level 5','Reach level 5.','military_tech',5,100,75,80),
  ('level_10','Level 10','Reach level 10.','workspace_premium',10,250,150,90)
on conflict (code) do update set
  title=excluded.title,
  description=excluded.description,
  icon=excluded.icon,
  target=excluded.target,
  reward_xp=excluded.reward_xp,
  reward_coins=excluded.reward_coins,
  sort_order=excluded.sort_order,
  active=true;

create index if not exists user_achievements_user_idx
  on public.user_achievements(user_id, unlocked_at desc);

create or replace function public.sync_achievements()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_unlocked integer := 0;
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_profile from public.profiles where id=v_uid for update;
  if not found then raise exception 'profile_not_found'; end if;

  with candidates as (
    select d.id
    from public.achievement_definitions d
    where d.active
      and (
        (d.code='first_step' and (v_profile.total_questions > 0 or v_profile.practice_rounds > 0))
        or (d.code='question_crusher' and v_profile.total_questions >= 50)
        or (d.code='sharp_shooter' and v_profile.total_correct >= 25)
        or (d.code='quiz_veteran' and v_profile.total_attempts >= 10)
        or (d.code='perfect_round' and (
          exists (select 1 from public.attempts a where a.user_id=v_uid and a.score=a.total_questions and a.total_questions>0)
          or exists (select 1 from public.practice_rounds r where r.user_id=v_uid and r.status='completed' and r.score=r.total_questions and r.total_questions>0)
          or exists (select 1 from public.speed_quiz_rounds r where r.user_id=v_uid and r.status='completed' and r.correct=r.total_questions and r.total_questions>0)
        ))
        or (d.code='streak_3' and v_profile.current_streak >= 3)
        or (d.code='streak_7' and v_profile.current_streak >= 7)
        or (d.code='level_5' and v_profile.level >= 5)
        or (d.code='level_10' and v_profile.level >= 10)
      )
  ), inserted as (
    insert into public.user_achievements(user_id, achievement_id)
    select v_uid, c.id from candidates c
    on conflict (user_id, achievement_id) do nothing
    returning id
  )
  select count(*) into v_unlocked from inserted;

  return v_unlocked;
end;
$$;

create or replace function public.get_achievements()
returns table (
  id uuid,
  code text,
  title text,
  description text,
  icon text,
  target integer,
  reward_xp integer,
  reward_coins integer,
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
  select d.id,d.code,d.title,d.description,d.icon,d.target,d.reward_xp,d.reward_coins,d.sort_order,
         ua.unlocked_at,ua.claimed_at
  from public.achievement_definitions d
  left join public.user_achievements ua
    on ua.achievement_id=d.id and ua.user_id=auth.uid()
  where d.active
  order by d.sort_order, d.id;
end;
$$;

create or replace function public.claim_achievement(p_achievement_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_ua public.user_achievements%rowtype;
  v_def public.achievement_definitions%rowtype;
  v_profile public.profiles%rowtype;
  v_new_xp integer;
  v_new_level integer;
  v_balance integer;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  select * into v_ua from public.user_achievements where user_id=v_uid and achievement_id=p_achievement_id for update;
  if not found then raise exception 'achievement_not_unlocked'; end if;
  if v_ua.claimed_at is not null then
    select coins,xp,level into v_profile.coins,v_profile.xp,v_profile.level from public.profiles where id=v_uid;
    return jsonb_build_object('claimed',false,'balance',v_profile.coins,'new_xp',v_profile.xp,'new_level',v_profile.level,'leveled_up',false,'xp_awarded',0,'coins_awarded',0);
  end if;
  select * into v_def from public.achievement_definitions where id=p_achievement_id and active;
  if not found then raise exception 'achievement_not_found'; end if;
  select * into v_profile from public.profiles where id=v_uid for update;
  v_new_xp := v_profile.xp + v_def.reward_xp;
  v_new_level := (v_new_xp / 100) + 1;
  update public.profiles set xp=v_new_xp, level=v_new_level where id=v_uid;
  v_balance := v_profile.coins;
  if v_def.reward_coins > 0 then
    v_balance := public._coin_apply(v_uid,v_def.reward_coins,'achievement_reward',v_ua.id);
  end if;
  update public.user_achievements set claimed_at=now() where id=v_ua.id;
  return jsonb_build_object('claimed',true,'balance',v_balance,'new_xp',v_new_xp,'new_level',v_new_level,'leveled_up',v_new_level>v_profile.level,'xp_awarded',v_def.reward_xp,'coins_awarded',v_def.reward_coins);
end;
$$;

revoke all on function public.sync_achievements() from public, anon;
revoke all on function public.get_achievements() from public, anon;
revoke all on function public.claim_achievement(uuid) from public, anon;
grant execute on function public.sync_achievements() to authenticated;
grant execute on function public.get_achievements() to authenticated;
grant execute on function public.claim_achievement(uuid) to authenticated;
