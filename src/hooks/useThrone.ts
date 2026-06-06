import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { Profile, Throne } from '../lib/types';

/**
 * Live throne state: the single throne row plus the current holder's profile,
 * kept fresh via Supabase Realtime.
 */
export function useThrone() {
  const [throne, setThrone] = useState<Throne | null>(null);
  const [holder, setHolder] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  const refetch = useCallback(async () => {
    const { data: t } = await supabase.from('throne').select('*').eq('id', 1).single();
    if (!t) {
      setThrone(null);
      setHolder(null);
      setLoading(false);
      return;
    }
    setThrone(t as Throne);
    if (t.current_holder_id) {
      const { data: p } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', t.current_holder_id)
        .single();
      setHolder((p as Profile) ?? null);
    } else {
      setHolder(null);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    refetch();
    const channel = supabase
      .channel('throne-room')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'throne' },
        () => refetch(),
      )
      // The holder's banked points / cosmetics can change while they reign.
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'profiles' },
        (payload) => {
          const row = payload.new as Profile;
          setHolder((cur) => (cur && cur.id === row.id ? { ...cur, ...row } : cur));
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [refetch]);

  return { throne, holder, loading, refetch };
}
