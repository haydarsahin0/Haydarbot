import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { Profile, Season } from '../lib/types';

export interface EternalKing extends Season {
  winner_name: string | null;
  winner_color: string | null;
}

/** Current-season top scorers + the all-time "Eternal Kings" engraving. */
export function useLeaderboard() {
  const [top, setTop] = useState<Profile[]>([]);
  const [kings, setKings] = useState<EternalKing[]>([]);

  useEffect(() => {
    let active = true;

    const loadTop = () =>
      supabase
        .from('profiles')
        .select('*')
        .order('points', { ascending: false })
        .limit(10)
        .then(({ data }) => active && setTop((data as Profile[]) ?? []));

    const loadKings = async () => {
      const { data: seasons } = await supabase
        .from('seasons')
        .select('*')
        .not('ended_at', 'is', null)
        .order('season_number', { ascending: false })
        .limit(10);
      const rows = (seasons as Season[]) ?? [];
      const winnerIds = rows.map((s) => s.winner_id).filter(Boolean) as string[];
      const { data: winners } = winnerIds.length
        ? await supabase.from('profiles').select('id, username, name_color').in('id', winnerIds)
        : { data: [] as any[] };
      const map = new Map((winners ?? []).map((w: any) => [w.id, w]));
      if (active) {
        setKings(
          rows.map((s) => ({
            ...s,
            winner_name: s.winner_id ? map.get(s.winner_id)?.username ?? 'Unknown' : null,
            winner_color: s.winner_id ? map.get(s.winner_id)?.name_color ?? '#e5e7eb' : null,
          })),
        );
      }
    };

    loadTop();
    loadKings();

    const channel = supabase
      .channel('leaderboard')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, loadTop)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'seasons' }, loadKings)
      .subscribe();

    return () => {
      active = false;
      supabase.removeChannel(channel);
    };
  }, []);

  return { top, kings };
}
