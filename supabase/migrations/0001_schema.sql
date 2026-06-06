-- =============================================================================
-- Throne Takeover — 0001 schema
-- Core tables. All gameplay writes happen through SECURITY DEFINER functions
-- (see 0003/0004); clients never write these tables directly (see 0002 RLS).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- profiles: one row per auth user.
--   points               -> current-season score (reset each season)
--   total_reign_seconds  -> lifetime seconds spent holding the throne
--   is_subscriber        -> written ONLY by the Stripe webhook (service role)
--   cooldown_until       -> when this player may take the throne again
--   mask_until           -> name hidden from others until this time (Mask card)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id                  uuid primary key references auth.users (id) on delete cascade,
  username            text not null,
  crown_style         text not null default 'default',
  name_color          text not null default '#e5e7eb',
  is_subscriber       boolean not null default false,
  points              bigint not null default 0,
  total_reign_seconds bigint not null default 0,
  cooldown_until      timestamptz,
  mask_until          timestamptz,
  stripe_customer_id  text,
  created_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- throne: a SINGLE row (id = 1). The one global throne.
--   protection   -> seconds of "crown weight" grace granted at last takeover.
--                   Effective shield = held_since + protection; decays to 0.
--   is_cursed    -> while true the holder LOSES points instead of earning.
--   frozen_until -> throne locked (Freeze card) until this time.
-- ---------------------------------------------------------------------------
create table if not exists public.throne (
  id                int primary key,
  current_holder_id uuid references public.profiles (id) on delete set null,
  held_since        timestamptz,
  protection        double precision not null default 0,
  is_cursed         boolean not null default false,
  frozen_until      timestamptz,
  updated_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- reign_events: an immutable log of every reign (for history + leaderboards).
-- ---------------------------------------------------------------------------
create table if not exists public.reign_events (
  id            bigint generated always as identity primary key,
  player_id     uuid not null references public.profiles (id) on delete cascade,
  season_number int  not null default 1,
  started_at    timestamptz not null,
  ended_at      timestamptz not null,
  points_earned bigint not null default 0
);
create index if not exists reign_events_player_idx on public.reign_events (player_id);
create index if not exists reign_events_ended_idx  on public.reign_events (ended_at desc);

-- ---------------------------------------------------------------------------
-- seasons: the current season is the single row with ended_at IS NULL.
-- Closed seasons hold the engraved "Eternal Kings" winner.
-- ---------------------------------------------------------------------------
create table if not exists public.seasons (
  id            bigint generated always as identity primary key,
  season_number int not null unique,
  started_at    timestamptz not null default now(),
  ended_at      timestamptz,
  winner_id     uuid references public.profiles (id) on delete set null
);

-- ---------------------------------------------------------------------------
-- sabotage_log: every sabotage card use (subscribers only).
-- ---------------------------------------------------------------------------
create table if not exists public.sabotage_log (
  id        bigint generated always as identity primary key,
  player_id uuid not null references public.profiles (id) on delete cascade,
  card_type text not null check (card_type in ('freeze', 'thief', 'earthquake', 'mask')),
  target_id uuid references public.profiles (id) on delete set null,
  used_at   timestamptz not null default now()
);
create index if not exists sabotage_log_player_idx on public.sabotage_log (player_id, used_at desc);

-- ---------------------------------------------------------------------------
-- throne_clicks: raw take-attempt log, used to detect Mob Overthrow.
-- Internal only (no client read). Pruned opportunistically inside take_throne.
-- ---------------------------------------------------------------------------
create table if not exists public.throne_clicks (
  id         bigint generated always as identity primary key,
  player_id  uuid not null references public.profiles (id) on delete cascade,
  clicked_at timestamptz not null default now()
);
create index if not exists throne_clicks_time_idx on public.throne_clicks (clicked_at desc);

-- ---------------------------------------------------------------------------
-- game_config: a SINGLE row (id = 1). Tunables + toggleable chaos modules.
-- ---------------------------------------------------------------------------
create table if not exists public.game_config (
  id                    int primary key,
  -- chaos module toggles
  crown_weight_enabled  boolean not null default true,
  mob_overthrow_enabled boolean not null default true,
  night_frenzy_enabled  boolean not null default true,
  cursed_throne_enabled boolean not null default true,
  seasons_enabled       boolean not null default true,
  -- tunables
  current_season        int    not null default 1,
  protection_seconds    double precision not null default 2.0,
  free_cooldown_seconds int    not null default 10,
  sub_cooldown_seconds  int    not null default 3,
  sub_multiplier        double precision not null default 2.0,
  frenzy_multiplier     double precision not null default 3.0,
  cursed_chance         double precision not null default 0.05,
  mob_size              int    not null default 5,
  mob_window_seconds    int    not null default 2,
  sabotage_cooldown_seconds int not null default 15,
  thief_cut             double precision not null default 0.10,
  freeze_seconds        int    not null default 5,
  mask_seconds          int    not null default 10,
  season_length_days    int    not null default 14,
  updated_at            timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Seed singletons.
-- ---------------------------------------------------------------------------
insert into public.game_config (id) values (1) on conflict (id) do nothing;
insert into public.throne (id, protection) values (1, 0) on conflict (id) do nothing;
insert into public.seasons (season_number, started_at)
  values (1, now())
  on conflict (season_number) do nothing;
