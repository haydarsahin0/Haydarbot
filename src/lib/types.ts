// Database row shapes (mirrors supabase/migrations).

export interface Profile {
  id: string;
  username: string;
  crown_style: string;
  name_color: string;
  is_subscriber: boolean;
  points: number;
  total_reign_seconds: number;
  cooldown_until: string | null;
  mask_until: string | null;
  created_at: string;
}

export interface Throne {
  id: number;
  current_holder_id: string | null;
  held_since: string | null;
  protection: number;
  is_cursed: boolean;
  frozen_until: string | null;
  updated_at: string;
}

export interface ReignEvent {
  id: number;
  player_id: string;
  season_number: number;
  started_at: string;
  ended_at: string;
  points_earned: number;
}

export interface Season {
  id: number;
  season_number: number;
  started_at: string;
  ended_at: string | null;
  winner_id: string | null;
}

export interface GameConfig {
  id: number;
  crown_weight_enabled: boolean;
  mob_overthrow_enabled: boolean;
  night_frenzy_enabled: boolean;
  cursed_throne_enabled: boolean;
  seasons_enabled: boolean;
  current_season: number;
  protection_seconds: number;
  free_cooldown_seconds: number;
  sub_cooldown_seconds: number;
  sub_multiplier: number;
  frenzy_multiplier: number;
  cursed_chance: number;
  mob_size: number;
  mob_window_seconds: number;
  sabotage_cooldown_seconds: number;
  thief_cut: number;
  freeze_seconds: number;
  mask_seconds: number;
  season_length_days: number;
}

export interface FrenzyStatus {
  enabled: boolean;
  frenzy_hour_utc: number;
  active: boolean;
  multiplier: number;
  server_time: string;
}

export type SabotageCard = 'freeze' | 'thief' | 'earthquake' | 'mask';
