import { useState } from 'react';
import { castSabotage } from '../lib/actions';
import { useNow } from '../hooks/useNow';
import type { GameConfig, Profile, SabotageCard } from '../lib/types';

interface Props {
  profile: Profile | null;
  config: GameConfig | null;
  onResult: (msg: string, ok: boolean) => void;
}

const CARDS: { type: SabotageCard; icon: string; name: string; desc: string }[] = [
  { type: 'freeze', icon: '❄', name: 'Freeze', desc: 'Lock the throne 5s' },
  { type: 'thief', icon: '🦝', name: 'Thief', desc: "Steal 10% of ruler's points" },
  { type: 'earthquake', icon: '🌋', name: 'Earthquake', desc: 'Eject everyone, throne opens' },
  { type: 'mask', icon: '🎭', name: 'Mask', desc: 'Hide your name 10s' },
];

export function SabotageBar({ profile, config, onResult }: Props) {
  const now = useNow(250);
  const [busy, setBusy] = useState(false);
  const [readyAt, setReadyAt] = useState(0);

  if (!profile?.is_subscriber) return null;

  const cooldownLeft = Math.max(0, (readyAt - now) / 1000);

  const play = async (card: SabotageCard) => {
    setBusy(true);
    const res = await castSabotage(card);
    setBusy(false);
    if (res.ok) {
      setReadyAt(Date.now() + (config?.sabotage_cooldown_seconds ?? 15) * 1000);
      onResult(`Sabotage cast: ${card}`, true);
    } else {
      onResult(res.message ?? 'Sabotage failed', false);
    }
  };

  const locked = busy || cooldownLeft > 0;

  return (
    <div className="panel p-5">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="font-display text-lg font-bold">Sabotage Cards</h3>
        {cooldownLeft > 0 && (
          <span className="text-xs text-white/40">ready in {Math.ceil(cooldownLeft)}s</span>
        )}
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        {CARDS.map((c) => (
          <button
            key={c.type}
            onClick={() => play(c.type)}
            disabled={locked}
            title={c.desc}
            className="flex flex-col items-center gap-1 rounded-xl border border-white/10 bg-white/5 p-3 text-center transition hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-40"
          >
            <span className="text-2xl">{c.icon}</span>
            <span className="text-sm font-semibold">{c.name}</span>
            <span className="text-[11px] leading-tight text-white/40">{c.desc}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
