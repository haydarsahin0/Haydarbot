import type { FrenzyStatus, Profile } from '../lib/types';

interface Props {
  frenzy: FrenzyStatus | null;
  profile: Profile | null;
}

/** Subscribers-only advance notice of today's Night Frenzy hour. */
export function FrenzyNotice({ frenzy, profile }: Props) {
  if (!frenzy?.enabled || !profile?.is_subscriber || frenzy.active) return null;

  // Convert the UTC frenzy hour to the viewer's local time for readability.
  const local = new Date();
  local.setUTCHours(frenzy.frenzy_hour_utc, 0, 0, 0);
  const label = local.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });

  return (
    <div className="panel border-amber-400/30 p-4 text-sm">
      <span className="font-semibold text-amber-300">⚡ Patron tip:</span>{' '}
      Today’s Night Frenzy ({frenzy.multiplier}× points) hits around{' '}
      <span className="font-semibold">{label}</span> your time. Hold the throne then.
    </div>
  );
}
