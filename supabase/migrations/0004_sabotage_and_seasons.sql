-- =============================================================================
-- Throne Takeover — 0004 sabotage cards (subscribers only) + seasons
-- All SECURITY DEFINER, server-authoritative.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- use_sabotage(card_type): subscribers spend a sabotage card.
--   freeze     -> lock the throne for freeze_seconds.
--   thief      -> steal thief_cut of the current ruler's points.
--   earthquake -> eject the ruler; throne opens, first click wins.
--   mask       -> hide your own name for mask_seconds.
-- ---------------------------------------------------------------------------
create or replace function public.use_sabotage(p_card_type text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg        public.game_config%rowtype;
  v_now      timestamptz := now();
  v_uid      uuid := auth.uid();
  v_sub      boolean;
  v_last     timestamptz;
  v_throne   public.throne%rowtype;
  v_steal    bigint := 0;
  v_holder   uuid;
begin
  if v_uid is null then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if p_card_type not in ('freeze', 'thief', 'earthquake', 'mask') then
    raise exception 'Unknown sabotage card' using errcode = 'P0001';
  end if;

  select * into cfg from public.game_config where id = 1;

  -- Subscribers only.
  select is_subscriber into v_sub from public.profiles where id = v_uid for update;
  if not coalesce(v_sub, false) then
    raise exception 'Sabotage cards are for subscribers only' using errcode = 'P0001';
  end if;

  -- Per-player sabotage cooldown.
  select max(used_at) into v_last from public.sabotage_log where player_id = v_uid;
  if v_last is not null and v_last > v_now - make_interval(secs => cfg.sabotage_cooldown_seconds) then
    raise exception 'Sabotage on cooldown for % more seconds',
      ceil(extract(epoch from (v_last + make_interval(secs => cfg.sabotage_cooldown_seconds) - v_now)))::int
      using errcode = 'P0001';
  end if;

  select * into v_throne from public.throne where id = 1 for update;
  v_holder := v_throne.current_holder_id;

  if p_card_type = 'freeze' then
    update public.throne
       set frozen_until = v_now + make_interval(secs => cfg.freeze_seconds),
           updated_at   = v_now
     where id = 1;

  elsif p_card_type = 'thief' then
    if v_holder is null or v_holder = v_uid then
      raise exception 'No rival ruler to rob' using errcode = 'P0001';
    end if;
    select floor(points * cfg.thief_cut)::bigint into v_steal
      from public.profiles where id = v_holder for update;
    update public.profiles set points = greatest(0, points - v_steal) where id = v_holder;
    update public.profiles set points = points + v_steal where id = v_uid;

  elsif p_card_type = 'earthquake' then
    -- Close the current reign (credit the ousted ruler) and open the throne.
    perform public.close_reign(v_holder, v_throne.held_since, v_now, v_throne.is_cursed, cfg);
    update public.throne
       set current_holder_id = null,
           held_since        = null,
           protection        = 0,
           is_cursed         = false,
           frozen_until      = null,
           updated_at        = v_now
     where id = 1;

  elsif p_card_type = 'mask' then
    update public.profiles
       set mask_until = v_now + make_interval(secs => cfg.mask_seconds)
     where id = v_uid;
  end if;

  insert into public.sabotage_log (player_id, card_type, target_id)
  values (v_uid, p_card_type, case when p_card_type in ('thief') then v_holder else null end);

  return json_build_object(
    'card', p_card_type,
    'stolen', v_steal,
    'server_time', v_now
  );
end;
$$;

grant execute on function public.use_sabotage(text) to authenticated;

-- ---------------------------------------------------------------------------
-- end_season(): close the open season, engrave the longest-reigning player on
-- the Eternal Kings board, reset everyone's season points, open a new season.
-- Intended to be called on a schedule (see 0005 pg_cron) or by an admin.
-- ---------------------------------------------------------------------------
create or replace function public.end_season()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg       public.game_config%rowtype;
  v_now     timestamptz := now();
  v_season  public.seasons%rowtype;
  v_winner  uuid;
  v_next    int;
begin
  select * into cfg from public.game_config where id = 1;
  if not cfg.seasons_enabled then
    return json_build_object('skipped', true, 'reason', 'seasons disabled');
  end if;

  -- The current season is the open row (ended_at is null).
  select * into v_season from public.seasons where ended_at is null
   order by season_number desc limit 1 for update;
  if not found then
    -- Nothing open; bootstrap one and stop.
    insert into public.seasons (season_number, started_at)
    values (cfg.current_season, v_now);
    return json_build_object('skipped', true, 'reason', 'no open season; bootstrapped');
  end if;

  -- Longest-reigning player this season (by total reign seconds logged).
  select player_id into v_winner
    from public.reign_events
   where started_at >= v_season.started_at
   group by player_id
   order by sum(extract(epoch from (ended_at - started_at))) desc
   limit 1;

  update public.seasons
     set ended_at = v_now, winner_id = v_winner
   where id = v_season.id;

  -- Reset the war.
  update public.profiles set points = 0;

  v_next := v_season.season_number + 1;
  insert into public.seasons (season_number, started_at) values (v_next, v_now);
  update public.game_config set current_season = v_next, updated_at = v_now where id = 1;

  return json_build_object('closed_season', v_season.season_number, 'winner_id', v_winner, 'new_season', v_next);
end;
$$;

-- end_season is privileged: only the service role / cron may run it.
revoke all on function public.end_season() from public, anon, authenticated;
