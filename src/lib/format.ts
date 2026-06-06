export function formatNumber(n: number): string {
  return Math.round(n).toLocaleString('en-US');
}

export function formatDuration(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${sec}s`;
  return `${sec}s`;
}

/** Seconds remaining until an ISO timestamp, never negative. */
export function secondsUntil(iso: string | null): number {
  if (!iso) return 0;
  return Math.max(0, (new Date(iso).getTime() - Date.now()) / 1000);
}

/** Seconds elapsed since an ISO timestamp, never negative. */
export function secondsSince(iso: string | null): number {
  if (!iso) return 0;
  return Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
}
