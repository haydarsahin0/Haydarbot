import { useState } from 'react';
import { takeThrone } from '../lib/actions';
import { useNow } from '../hooks/useNow';
import { secondsUntil } from '../lib/format';
import type { Profile, Throne } from '../lib/types';

interface Props {
  userId: string;
  throne: Throne | null;
  profile: Profile | null;
  onResult: (msg: string, ok: boolean) => void;
}

export function TakeButton({ userId, throne, profile, onResult }: Props) {
  const now = useNow(200);
  void now;
  const [pressing, setPressing] = useState(false);

  const cooldownLeft = secondsUntil(profile?.cooldown_until ?? null);
  const frozenLeft = secondsUntil(throne?.frozen_until ?? null);
  const youHold = throne?.current_holder_id === userId;

  const disabled = pressing || youHold || cooldownLeft > 0;

  const label = youHold
    ? 'You rule 👑'
    : cooldownLeft > 0
      ? `Cooldown · ${Math.ceil(cooldownLeft)}s`
      : frozenLeft > 0
        ? `Throne frozen · ${Math.ceil(frozenLeft)}s`
        : 'TAKE THE THRONE';

  const press = async () => {
    setPressing(true);
    const res = await takeThrone(userId);
    setPressing(false);
    if (res.ok) onResult('👑 The throne is yours!', true);
    else onResult(res.message ?? 'Could not take the throne', false);
  };

  return (
    <button
      onClick={press}
      disabled={disabled}
      className={`w-full rounded-2xl px-6 py-5 font-display text-2xl font-black tracking-wide transition
        ${
          disabled
            ? 'cursor-not-allowed bg-white/5 text-white/40'
            : 'animate-flash bg-gradient-to-b from-royal-300 to-royal-500 text-black shadow-throne hover:from-royal-200 hover:to-royal-400 active:scale-[0.98]'
        }`}
    >
      {label}
    </button>
  );
}
