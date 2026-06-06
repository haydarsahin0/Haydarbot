-- =============================================================================
-- Throne Takeover — 0005 auth trigger, realtime publication, season cron
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Auto-create a profile for every new auth user.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  v_name := coalesce(
    new.raw_user_meta_data ->> 'username',
    new.raw_user_meta_data ->> 'full_name',
    split_part(new.email, '@', 1),
    'Challenger'
  );
  insert into public.profiles (id, username)
  values (new.id, left(v_name, 24))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Realtime: broadcast throne/profile/reign/season changes to subscribers.
-- ---------------------------------------------------------------------------
alter table public.throne       replica identity full;
alter table public.profiles     replica identity full;
alter table public.reign_events replica identity full;
alter table public.seasons      replica identity full;

do $$
begin
  -- Add tables to the supabase_realtime publication if not already present.
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end$$;

alter publication supabase_realtime add table public.throne;
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.reign_events;
alter publication supabase_realtime add table public.seasons;

-- ---------------------------------------------------------------------------
-- Optional: schedule season rollovers with pg_cron (Supabase dashboard ->
-- Database -> Extensions -> enable "pg_cron"). Runs daily; end_season() is a
-- no-op until the open season is at least season_length_days old.
-- ---------------------------------------------------------------------------
-- Guard end_season so the daily cron only fires after season_length_days.
create or replace function public.maybe_end_season()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  cfg      public.game_config%rowtype;
  v_open   public.seasons%rowtype;
begin
  select * into cfg from public.game_config where id = 1;
  if not cfg.seasons_enabled then return; end if;
  select * into v_open from public.seasons where ended_at is null
   order by season_number desc limit 1;
  if found and v_open.started_at <= now() - make_interval(days => cfg.season_length_days) then
    perform public.end_season();
  end if;
end;
$$;

-- Only the service role / cron may trigger season rollovers.
revoke all on function public.maybe_end_season() from public, anon, authenticated;

-- Uncomment after enabling pg_cron:
-- select cron.schedule('throne-season-rollover', '0 0 * * *', $$select public.maybe_end_season();$$);
