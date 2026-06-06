-- =============================================================================
-- Throne Takeover — 0003 server-authoritative throne logic
--
-- Everything here is SECURITY DEFINER: it runs as the table owner and bypasses
-- RLS, so it is the ONLY path that may mutate the throne / points. The client
-- can send nothing but "I want to take the throne" — the server validates
-- cooldown, freeze, crown-weight protection, mob overthrow, computes points
-- from held_since, and updates everything atomically inside one transaction.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Night Frenzy: one deterministic random hour per (UTC) day with 3x points.
-- Deterministic so clients can show subscribers advance notice via frenzy_status().
-- ---------------------------------------------------------------------------
create or replace function public.frenzy_hour(p_day date)
returns int
language sql
immutable
as $$
  select ((abs(hashtext(p_day::text)) % 24));
$$;

create or replace function public.is_night_frenzy(p_ts timestamptz)
returns boolean
language sql
stable
as $$
  select extract(hour from (p_ts at time zone 'UTC'))::int
         = public.frenzy_hour((p_ts at time zone 'UTC')::date);
$$;

-- Points-per-second multiplier for a holder at a given instant.
create or replace function public.points_multiplier(p_is_subscriber boolean, p_ts timestamptz)
returns double precision
language plpgsql
stable
as $$
declare
  cfg public.game_config%rowtype;
  m   double precision;
begin
  select * into cfg from public.game_config where id = 1;
  m := case when p_is_subscriber then cfg.sub_multiplier else 1.0 end;
  if cfg.night_frenzy_enabled and public.is_night_frenzy(p_ts) then
    m := m * cfg.frenzy_multiplier;
  end if;
  return m;
end;
$$;

-- Public read of frenzy state (subscribers get advance notice in the UI).
create or replace function public.frenzy_status()
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  cfg     public.game_config%rowtype;
  v_now   timestamptz := now();
  v_hour  int;
begin
  select * into cfg from public.game_config where id = 1;
  v_hour := public.frenzy_hour((v_now at time zone 'UTC')::date);
  return json_build_object(
    'enabled', cfg.night_frenzy_enabled,
    'frenzy_hour_utc', v_hour,
    'active', cfg.night_frenzy_enabled and public.is_night_frenzy(v_now),
    'multiplier', cfg.frenzy_multiplier,
    'server_time', v_now
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- close_reign: internal helper. Credits the outgoing holder, logs the reign,
-- and puts them on cooldown. Cursed throne => negative points.
-- ---------------------------------------------------------------------------
create or replace function public.close_reign(
  p_holder_id    uuid,
  p_held_since   timestamptz,
  p_now          timestamptz,
  p_is_cursed    boolean,
  cfg            public.game_config
)
returns void
language plpgsql
as $$
declare
  v_sub      boolean;
  v_elapsed  double precision;
  v_earned   bigint;
  v_cooldown int;
begin
  if p_holder_id is null or p_held_since is null then
    return;
  end if;

  select is_subscriber into v_sub from public.profiles where id = p_holder_id;
  v_elapsed := greatest(0, extract(epoch from (p_now - p_held_since)));

  if p_is_cursed then
    v_earned := -floor(v_elapsed * public.points_multiplier(v_sub, p_now))::bigint;
  else
    v_earned :=  floor(v_elapsed * public.points_multiplier(v_sub, p_now))::bigint;
  end if;

  v_cooldown := case when v_sub then cfg.sub_cooldown_seconds else cfg.free_cooldown_seconds end;

  insert into public.reign_events (player_id, season_number, started_at, ended_at, points_earned)
  values (p_holder_id, cfg.current_season, p_held_since, p_now, v_earned);

  update public.profiles
     set points               = greatest(0, points + v_earned),
         total_reign_seconds  = total_reign_seconds + floor(v_elapsed)::bigint,
         cooldown_until       = p_now + make_interval(secs => v_cooldown)
   where id = p_holder_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- take_throne(p_player_id): the one atomic entry point for seizing the throne.
--
-- IMPORTANT: soft gameplay rejections (frozen / cooldown / protected) RETURN
-- { success: false, ... } instead of raising. Each call records the click in
-- throne_clicks BEFORE deciding, and PostgREST wraps the whole call in one
-- transaction — so if we raised, the click would roll back and Mob Overthrow
-- could never accumulate. Returning lets the click commit and the mob build.
-- Only true authorization failures raise.
-- ---------------------------------------------------------------------------
create or replace function public.take_throne(p_player_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg          public.game_config%rowtype;
  v_now        timestamptz := now();
  v_throne     public.throne%rowtype;
  v_cooldown   timestamptz;
  v_mob_count  int := 0;
  v_mob        boolean := false;
  v_reject     text := null;
  v_message    text := null;
begin
  -- 1. Authorization: you may only take the throne as yourself. (Hard error.)
  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  -- 2. Load config and lock the throne row (serializes concurrent takers).
  select * into cfg from public.game_config where id = 1;
  select * into v_throne from public.throne where id = 1 for update;

  -- 3. Record this click and evaluate Mob Overthrow within the window.
  insert into public.throne_clicks (player_id) values (p_player_id);
  if cfg.mob_overthrow_enabled then
    select count(distinct player_id) into v_mob_count
      from public.throne_clicks
     where clicked_at > v_now - make_interval(secs => cfg.mob_window_seconds);
    v_mob := v_mob_count >= cfg.mob_size;
  end if;
  -- prune old click history opportunistically
  delete from public.throne_clicks where clicked_at < v_now - interval '1 minute';

  -- 4. Decide whether this take is rejected. A mob bypasses freeze, cooldown
  --    and the crown-weight shield — but you can never "take" a throne you hold.
  if v_throne.current_holder_id = p_player_id then
    v_reject := 'already_holder'; v_message := 'You already hold the throne';

  elsif not v_mob and v_throne.frozen_until is not null and v_throne.frozen_until > v_now then
    v_reject := 'frozen'; v_message := 'The throne is frozen';

  elsif not v_mob then
    -- personal cooldown
    select cooldown_until into v_cooldown from public.profiles where id = p_player_id for update;
    if v_cooldown is not null and v_cooldown > v_now then
      v_reject := 'cooldown';
      v_message := format('On cooldown for %s more seconds',
        ceil(extract(epoch from (v_cooldown - v_now)))::int);
    -- crown-weight shield on the current ruler
    elsif cfg.crown_weight_enabled
       and v_throne.current_holder_id is not null
       and v_throne.held_since is not null
       and v_now < v_throne.held_since + make_interval(secs => v_throne.protection) then
      v_reject := 'protected';
      v_message := format('Throne is protected for %s more seconds',
        ceil(extract(epoch from (v_throne.held_since + make_interval(secs => v_throne.protection) - v_now)))::int);
    end if;
  end if;

  if v_reject is not null then
    -- Click is recorded (committed) so the mob can keep building; just decline.
    return json_build_object(
      'success', false,
      'reason', v_reject,
      'message', v_message,
      'mob_count', v_mob_count,
      'server_time', v_now
    );
  end if;

  -- 5. Close out the previous reign (credit points, log, set their cooldown).
  perform public.close_reign(
    v_throne.current_holder_id, v_throne.held_since, v_now, v_throne.is_cursed, cfg
  );

  -- 6. Crown the new ruler. Maybe the throne becomes cursed.
  update public.throne
     set current_holder_id = p_player_id,
         held_since        = v_now,
         protection        = case when cfg.crown_weight_enabled then cfg.protection_seconds else 0 end,
         is_cursed         = cfg.cursed_throne_enabled and random() < cfg.cursed_chance,
         frozen_until      = null,
         updated_at        = v_now
   where id = 1
   returning * into v_throne;

  return json_build_object(
    'success',           true,
    'current_holder_id', v_throne.current_holder_id,
    'held_since',        v_throne.held_since,
    'protection',        v_throne.protection,
    'is_cursed',         v_throne.is_cursed,
    'via_mob',           v_mob,
    'server_time',       v_now
  );
end;
$$;

-- Expose RPCs to logged-in players.
grant execute on function public.take_throne(uuid)   to authenticated;
grant execute on function public.frenzy_status()     to authenticated, anon;

-- close_reign is an internal helper — never call it directly from a client.
revoke all on function public.close_reign(uuid, timestamptz, timestamptz, boolean, public.game_config)
  from public, anon, authenticated;
