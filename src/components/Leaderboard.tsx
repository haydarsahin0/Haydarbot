import { useLeaderboard } from '../hooks/useLeaderboard';
import { formatNumber } from '../lib/format';

interface Props {
  currentUserId: string | null;
  seasonNumber?: number;
}

export function Leaderboard({ currentUserId, seasonNumber }: Props) {
  const { top, kings } = useLeaderboard();

  return (
    <div className="panel p-5">
      <div className="mb-3 flex items-baseline justify-between">
        <h3 className="font-display text-lg font-bold">Leaderboard</h3>
        {seasonNumber != null && (
          <span className="text-xs text-white/40">Season {seasonNumber}</span>
        )}
      </div>

      <ol className="space-y-1.5">
        {top.length === 0 && <p className="text-sm text-white/40">No scores yet.</p>}
        {top.map((p, i) => (
          <li
            key={p.id}
            className={`flex items-center justify-between rounded-lg px-2 py-1.5 text-sm ${
              p.id === currentUserId ? 'bg-royal-500/10' : ''
            }`}
          >
            <span className="flex items-center gap-2 truncate">
              <span className="w-5 text-right text-white/40">{i + 1}</span>
              <span className="font-medium" style={{ color: p.name_color }}>
                {p.username}
              </span>
              {p.is_subscriber && <span title="Subscriber">⭐</span>}
            </span>
            <span className="tabular-nums text-royal-200">{formatNumber(p.points)}</span>
          </li>
        ))}
      </ol>

      <h4 className="mb-2 mt-6 flex items-center gap-2 font-display text-sm font-bold text-white/70">
        👑 Eternal Kings
      </h4>
      {kings.length === 0 ? (
        <p className="text-xs text-white/40">
          The first season is still being fought. History awaits a winner.
        </p>
      ) : (
        <ul className="space-y-1 text-sm">
          {kings.map((k) => (
            <li key={k.id} className="flex justify-between">
              <span className="text-white/50">Season {k.season_number}</span>
              <span className="font-medium" style={{ color: k.winner_color ?? '#e5e7eb' }}>
                {k.winner_name ?? '—'}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
