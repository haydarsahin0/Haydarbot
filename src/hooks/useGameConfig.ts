import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { FrenzyStatus, GameConfig } from '../lib/types';

export function useGameConfig() {
  const [config, setConfig] = useState<GameConfig | null>(null);
  const [frenzy, setFrenzy] = useState<FrenzyStatus | null>(null);

  useEffect(() => {
    let active = true;
    supabase
      .from('game_config')
      .select('*')
      .eq('id', 1)
      .single()
      .then(({ data }) => active && data && setConfig(data as GameConfig));

    const loadFrenzy = () =>
      supabase.rpc('frenzy_status').then(({ data }) => {
        if (active && data) setFrenzy(data as FrenzyStatus);
      });
    loadFrenzy();
    // Refresh frenzy status every minute (it flips at hour boundaries).
    const t = setInterval(loadFrenzy, 60_000);
    return () => {
      active = false;
      clearInterval(t);
    };
  }, []);

  return { config, frenzy };
}
