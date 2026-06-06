import { useCallback, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { Profile } from '../lib/types';

/** The signed-in player's own profile, live via Realtime. */
export function useProfile(userId: string | null) {
  const [profile, setProfile] = useState<Profile | null>(null);

  const refetch = useCallback(async () => {
    if (!userId) {
      setProfile(null);
      return;
    }
    const { data } = await supabase.from('profiles').select('*').eq('id', userId).single();
    setProfile((data as Profile) ?? null);
  }, [userId]);

  useEffect(() => {
    refetch();
    if (!userId) return;
    const channel = supabase
      .channel(`profile-${userId}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'profiles', filter: `id=eq.${userId}` },
        (payload) => setProfile((cur) => ({ ...(cur as Profile), ...(payload.new as Profile) })),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId, refetch]);

  return { profile, refetch };
}
