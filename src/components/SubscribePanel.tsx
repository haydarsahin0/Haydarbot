import { useState } from 'react';
import { openCustomerPortal, startCheckout } from '../lib/actions';
import type { GameConfig, Profile } from '../lib/types';

interface Props {
  profile: Profile | null;
  config: GameConfig | null;
}

export function SubscribePanel({ profile, config }: Props) {
  const [busy, setBusy] = useState(false);
  const isSub = Boolean(profile?.is_subscriber);

  const perks: { free: string; sub: string }[] = [
    {
      free: `${config?.free_cooldown_seconds ?? 10}s cooldown after losing the throne`,
      sub: `${config?.sub_cooldown_seconds ?? 3}s cooldown — back in the fight faster`,
    },
    { free: '1× points per second', sub: `${config?.sub_multiplier ?? 2}× points per second while ruling` },
    { free: 'Default crown', sub: 'Custom crowns + colored name effects' },
    { free: 'No sabotage cards', sub: 'Freeze, Thief, Earthquake & Mask sabotage cards' },
    { free: 'No reign archive', sub: 'Permanent "reign history" profile' },
    { free: 'No event warnings', sub: 'Early notice for Night Frenzy & Cursed Throne' },
  ];

  const go = async () => {
    setBusy(true);
    const url = isSub ? await openCustomerPortal() : await startCheckout();
    setBusy(false);
    if (url) window.location.href = url;
  };

  return (
    <div className="panel border-royal-400/30 p-5">
      <div className="flex items-center justify-between">
        <h3 className="font-display text-lg font-bold">
          {isSub ? 'You’re a Royal Patron ⭐' : 'Become a Royal Patron'}
        </h3>
      </div>
      <p className="mt-1 text-sm text-white/50">
        A subscription buys in-game advantages and cosmetics only. There is no gambling and no
        payouts — you’re supporting the game and ruling in style.
      </p>

      <div className="mt-4 grid grid-cols-2 gap-px overflow-hidden rounded-xl border border-white/10 bg-white/10 text-sm">
        <div className="bg-[#11101a] px-3 py-2 font-semibold text-white/50">Free</div>
        <div className="bg-[#171327] px-3 py-2 font-semibold text-royal-200">Subscriber</div>
        {perks.map((p, i) => (
          <Row key={i} free={p.free} sub={p.sub} />
        ))}
      </div>

      <button
        onClick={go}
        disabled={busy}
        className="mt-4 w-full rounded-xl bg-royal-500 px-4 py-3 font-semibold text-black transition hover:bg-royal-400 disabled:opacity-50"
      >
        {busy
          ? 'Opening…'
          : isSub
            ? 'Manage subscription'
            : 'Subscribe'}
      </button>
    </div>
  );
}

function Row({ free, sub }: { free: string; sub: string }) {
  return (
    <>
      <div className="bg-[#11101a] px-3 py-2 text-white/55">{free}</div>
      <div className="bg-[#171327] px-3 py-2 text-white/80">{sub}</div>
    </>
  );
}
