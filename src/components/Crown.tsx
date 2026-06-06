interface CrownProps {
  style?: string;
  className?: string;
}

// A few cosmetic crowns. Subscribers can pick the fancier ones.
const CROWNS: Record<string, { gem: string; band: string }> = {
  default: { gem: '#facc15', band: '#a16207' },
  ruby: { gem: '#f43f5e', band: '#7f1d1d' },
  emerald: { gem: '#34d399', band: '#065f46' },
  sapphire: { gem: '#60a5fa', band: '#1e3a8a' },
  obsidian: { gem: '#a78bfa', band: '#312e81' },
};

export const CROWN_STYLES = Object.keys(CROWNS);

export function Crown({ style = 'default', className = 'h-10 w-10' }: CrownProps) {
  const c = CROWNS[style] ?? CROWNS.default;
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true">
      <path
        d="M3 8l4 4 5-7 5 7 4-4-2 11H5L3 8z"
        fill={c.gem}
        stroke={c.band}
        strokeWidth={1}
        strokeLinejoin="round"
      />
      <rect x="5" y="19" width="14" height="2.5" rx="0.5" fill={c.band} />
    </svg>
  );
}
