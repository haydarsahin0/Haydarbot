import { Crown } from './Crown';
import { useNow } from '../hooks/useNow';
import { formatNumber, secondsSince, secondsUntil } from '../lib/format';
import type { FrenzyStatus, GameConfig, Profile, Throne } from '../lib/types';

interface Props {
  throne: Throne | null;
  holder: Profile | null;
  config: GameConfig | null;
  frenzy: FrenzyStatus | null;
  currentUserId: string | null;
}

export function ThroneStage({ throne, holder, config, frenzy, currentUserId }: Props) {
  const now = useNow(100);
  void now; // used implicitly to force re-render of the live counter

  const heldSeconds = throne ? secondsSince(throne.held_since) : 0;
  const frenzyActive = Boolean(frenzy?.active);
  const cursed = Boolean(throne?.is_cursed);

  const subMult = holder?.is_subscriber ? config?.sub_multiplier ?? 2 : 1;
  const frenzyMult = frenzyActive ? config?.frenzy_multiplier ?? 3 : 1;
  const perSecond = subMult * frenzyMult * (cursed ? -1 : 1);

  const liveDelta = Math.floor(heldSeconds * Math.abs(perSecond)) * (cursed ? -1 : 1);
  const livePoints = Math.max(0, (holder?.points ?? 0) + liveDelta);

  const protectionLeft = throne
    ? Math.max(0, throne.protection - heldSeconds)
    : 0;
  const frozenLeft = secondsUntil(throne?.frozen_until ?? null);

  const isMaskedFromMe =
    holder &&
    holder.id !== currentUserId &&
    holder.mask_until &&
    new Date(holder.mask_until).getTime() > Date.now();

  const displayName = !holder
    ? 'The throne is empty'
    : isMaskedFromMe
      ? 'A masked challenger'
      : holder.username;

  const youHold = holder?.id === currentUserId;

  return (
    <div
      className={`panel relative overflow-hidden p-8 text-center ${
        cursed ? 'ring-2 ring-fuchsia-500/40' : ''
      } ${holder ? 'animate-pulse-glow' : ''}`}
    >
      {/* status ribbons */}
      <div className="mb-4 flex flex-wrap justify-center gap-2 text-xs">
        {frenzyActive && (
          <span className="rounded-full bg-amber-500/20 px-3 py-1 font-semibold text-amber-300">
            ⚡ NIGHT FRENZY · {config?.frenzy_multiplier ?? 3}x points
          </span>
        )}
        {cursed && (
          <span className="rounded-full bg-fuchsia-500/20 px-3 py-1 font-semibold text-fuchsia-300">
            ☠ CURSED THRONE · points draining
          </span>
        )}
        {frozenLeft > 0 && (
          <span className="rounded-full bg-sky-500/20 px-3 py-1 font-semibold text-sky-300">
            ❄ FROZEN · {Math.ceil(frozenLeft)}s
          </span>
        )}
      </div>

      <div className="mx-auto flex max-w-sm flex-col items-center">
        <Crown
          style={holder?.crown_style ?? 'default'}
          className={`h-16 w-16 ${holder ? '' : 'opacity-30'}`}
        />
        <p className="mt-4 text-xs uppercase tracking-[0.3em] text-white/40">
          {holder ? 'Current Ruler' : 'Up for grabs'}
        </p>
        <h2
          className="mt-1 font-display text-4xl font-bold text-glow"
          style={{ color: holder && !isMaskedFromMe ? holder.name_color : undefined }}
        >
          {displayName}
          {youHold && <span className="ml-2 align-middle text-base text-white/50">(you)</span>}
        </h2>

        {holder && (
          <>
            <div
              className={`mt-6 font-display text-6xl font-black tabular-nums ${
                cursed ? 'text-fuchsia-300' : 'text-royal-200'
              }`}
            >
              {formatNumber(livePoints)}
            </div>
            <p className="mt-1 text-sm text-white/50">
              {perSecond >= 0 ? '+' : ''}
              {perSecond}/sec · reigning {Math.floor(heldSeconds)}s
            </p>

            {protectionLeft > 0 && (
              <div className="mt-4 w-full">
                <div className="flex justify-between text-[11px] text-white/40">
                  <span>Crown weight shield</span>
                  <span>{protectionLeft.toFixed(1)}s</span>
                </div>
                <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-white/10">
                  <div
                    className="h-full bg-royal-400 transition-all"
                    style={{
                      width: `${Math.min(100, (protectionLeft / Math.max(throne!.protection, 0.001)) * 100)}%`,
                    }}
                  />
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
