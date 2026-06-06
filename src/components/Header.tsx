import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { formatNumber } from '../lib/format';
import { CROWN_STYLES, Crown } from './Crown';
import type { Profile } from '../lib/types';

interface Props {
  profile: Profile | null;
  onSignOut: () => void;
}

const FREE_CROWNS = ['default'];
const COLORS = ['#e5e7eb', '#facc15', '#f43f5e', '#34d399', '#60a5fa', '#a78bfa'];

export function Header({ profile, onSignOut }: Props) {
  const [open, setOpen] = useState(false);
  const [name, setName] = useState(profile?.username ?? '');

  const save = async (patch: Partial<Profile>) => {
    if (!profile) return;
    await supabase.from('profiles').update(patch).eq('id', profile.id);
  };

  const availableCrowns = profile?.is_subscriber ? CROWN_STYLES : FREE_CROWNS;

  return (
    <header className="flex items-center justify-between gap-4">
      <div className="flex items-center gap-2">
        <Crown style={profile?.crown_style ?? 'default'} className="h-7 w-7" />
        <span className="font-display text-xl font-bold tracking-wide">Throne Takeover</span>
      </div>

      <div className="relative flex items-center gap-3">
        {profile && (
          <span className="hidden text-sm text-white/60 sm:inline">
            <span className="font-semibold" style={{ color: profile.name_color }}>
              {profile.username}
            </span>
            {profile.is_subscriber && <span title="Subscriber"> ⭐</span>}
            <span className="ml-2 tabular-nums text-royal-200">
              {formatNumber(profile.points)} pts
            </span>
          </span>
        )}
        <button
          onClick={() => setOpen((o) => !o)}
          className="rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-sm hover:bg-white/10"
        >
          Profile
        </button>
        <button
          onClick={onSignOut}
          className="rounded-lg border border-white/10 px-3 py-1.5 text-sm text-white/60 hover:bg-white/10"
        >
          Sign out
        </button>

        {open && profile && (
          <div className="panel absolute right-0 top-12 z-20 w-72 space-y-4 p-4">
            <div>
              <label className="text-xs text-white/50">Display name</label>
              <div className="mt-1 flex gap-2">
                <input
                  value={name}
                  maxLength={24}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full rounded-lg border border-white/10 bg-black/30 px-3 py-1.5 text-sm outline-none focus:border-royal-400"
                />
                <button
                  onClick={() => save({ username: name.trim() || profile.username })}
                  className="rounded-lg bg-royal-500 px-3 text-sm font-semibold text-black"
                >
                  Save
                </button>
              </div>
            </div>

            <div>
              <label className="text-xs text-white/50">Name color</label>
              <div className="mt-1 flex gap-2">
                {COLORS.map((c) => (
                  <button
                    key={c}
                    onClick={() => save({ name_color: c })}
                    className={`h-6 w-6 rounded-full border-2 ${
                      profile.name_color === c ? 'border-white' : 'border-transparent'
                    }`}
                    style={{ background: c }}
                    aria-label={`Use color ${c}`}
                  />
                ))}
              </div>
            </div>

            <div>
              <label className="text-xs text-white/50">
                Crown {profile.is_subscriber ? '' : '(subscribe for more)'}
              </label>
              <div className="mt-1 flex flex-wrap gap-2">
                {CROWN_STYLES.map((style) => {
                  const allowed = availableCrowns.includes(style);
                  return (
                    <button
                      key={style}
                      disabled={!allowed}
                      onClick={() => save({ crown_style: style })}
                      className={`rounded-lg border p-1.5 ${
                        profile.crown_style === style ? 'border-royal-400' : 'border-white/10'
                      } ${allowed ? 'hover:bg-white/10' : 'opacity-30'}`}
                      title={allowed ? style : 'Subscribers only'}
                    >
                      <Crown style={style} className="h-6 w-6" />
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
