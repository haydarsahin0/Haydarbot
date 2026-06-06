import { useFeed } from '../hooks/useFeed';
import { formatDuration, formatNumber } from '../lib/format';

export function LiveFeed() {
  const items = useFeed(12);

  return (
    <div className="panel p-5">
      <h3 className="mb-3 font-display text-lg font-bold">Recent Takeovers</h3>
      {items.length === 0 ? (
        <p className="text-sm text-white/40">No reigns yet. Be the first king.</p>
      ) : (
        <ul className="space-y-2">
          {items.map((it) => {
            const reign = (new Date(it.ended_at).getTime() - new Date(it.started_at).getTime()) / 1000;
            const drained = it.points_earned < 0;
            return (
              <li key={it.id} className="flex items-center justify-between gap-3 text-sm">
                <span className="truncate">
                  <span className="font-semibold" style={{ color: it.name_color }}>
                    {it.username}
                  </span>{' '}
                  <span className="text-white/40">held {formatDuration(reign)}</span>
                </span>
                <span className={drained ? 'text-fuchsia-400' : 'text-royal-300'}>
                  {drained ? '' : '+'}
                  {formatNumber(it.points_earned)}
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
