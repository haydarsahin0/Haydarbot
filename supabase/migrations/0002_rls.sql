-- =============================================================================
-- Throne Takeover — 0002 Row Level Security + column grants
--
-- THE SECURITY CORE:
--   * Players may READ the throne, profiles, public logs and config.
--   * Players may NEVER directly write throne, points, is_subscriber, cooldown,
--     reign_events, seasons, etc. Those change only through SECURITY DEFINER
--     RPCs (0003/0004) and the Stripe webhook (service role).
--   * On profiles, players may update ONLY cosmetic columns. We enforce this
--     with COLUMN-LEVEL privileges (RLS is row-level only and cannot restrict
--     which columns are written).
-- =============================================================================

-- Start from a clean slate: take away the broad default grants Supabase gives
-- to the anon/authenticated roles, then hand back exactly what is allowed.
revoke all on public.profiles      from anon, authenticated;
revoke all on public.throne        from anon, authenticated;
revoke all on public.reign_events  from anon, authenticated;
revoke all on public.seasons       from anon, authenticated;
revoke all on public.sabotage_log  from anon, authenticated;
revoke all on public.throne_clicks from anon, authenticated;
revoke all on public.game_config   from anon, authenticated;

-- Enable RLS everywhere.
alter table public.profiles      enable row level security;
alter table public.throne        enable row level security;
alter table public.reign_events  enable row level security;
alter table public.seasons       enable row level security;
alter table public.sabotage_log  enable row level security;
alter table public.throne_clicks enable row level security;
alter table public.game_config   enable row level security;

-- ---------------------------------------------------------------------------
-- profiles
--   read: anyone authenticated.
--   write: ONLY the cosmetic columns, ONLY on your own row.
-- ---------------------------------------------------------------------------
grant select on public.profiles to authenticated, anon;
grant update (username, crown_style, name_color) on public.profiles to authenticated;

create policy "profiles_read_all" on public.profiles
  for select using (true);

create policy "profiles_update_own_cosmetics" on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());
-- NOTE: no INSERT/DELETE policy. Profiles are created by the auth trigger
-- (0005, security definer) and deleted via auth.users cascade only.

-- ---------------------------------------------------------------------------
-- throne / reign_events / seasons / game_config: public read, no client write.
-- (No write privilege + no write policy => writes are impossible except for
--  SECURITY DEFINER functions and the service role.)
-- ---------------------------------------------------------------------------
grant select on public.throne       to authenticated, anon;
grant select on public.reign_events to authenticated, anon;
grant select on public.seasons      to authenticated, anon;
grant select on public.sabotage_log to authenticated, anon;
grant select on public.game_config  to authenticated, anon;

create policy "throne_read_all"       on public.throne       for select using (true);
create policy "reign_events_read_all" on public.reign_events for select using (true);
create policy "seasons_read_all"      on public.seasons      for select using (true);
create policy "sabotage_log_read_all" on public.sabotage_log for select using (true);
create policy "game_config_read_all"  on public.game_config  for select using (true);

-- ---------------------------------------------------------------------------
-- throne_clicks: fully internal. No grants, no policies => clients can't touch
-- it at all; only SECURITY DEFINER functions read/write it.
-- ---------------------------------------------------------------------------
