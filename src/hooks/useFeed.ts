import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { ReignEvent } from '../lib/types';

export interface FeedItem extends ReignEvent {
  username: string;
  name_color: string;
}

/** Recent takeovers ("X dethroned after Ns, +P points"), live via Realtime. */
export function useFeed(limit = 12) {
  const [items, setItems] = useState<FeedItem[]>([]);

  useEffect(() => {
    let active = true;

    const hydrate = async (rows: ReignEvent[]): Promise<FeedItem[]> => {
      const ids = [...new Set(rows.map((r) => r.player_id))];
      if (ids.length === 0) return [];
      const { data: profiles } = await supabase
        .from('profiles')
        .select('id, username, name_color')
        .in('id', ids);
      const map = new Map((profiles ?? []).map((p) => [p.id, p]));
      return rows.map((r) => ({
        ...r,
        username: map.get(r.player_id)?.username ?? 'A challenger',
        name_color: map.get(r.player_id)?.name_color ?? '#e5e7eb',
      }));
    };

    supabase
      .from('reign_events')
      .select('*')
      .order('ended_at', { ascending: false })
      .limit(limit)
      .then(async ({ data }) => {
        if (active && data) setItems(await hydrate(data as ReignEvent[]));
      });

    const channel = supabase
      .channel('reign-feed')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'reign_events' },
        async (payload) => {
          const [item] = await hydrate([payload.new as ReignEvent]);
          if (active && item) setItems((cur) => [item, ...cur].slice(0, limit));
        },
      )
      .subscribe();

    return () => {
      active = false;
      supabase.removeChannel(channel);
    };
  }, [limit]);

  return items;
}
