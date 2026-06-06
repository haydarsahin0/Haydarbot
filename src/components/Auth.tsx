import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { Crown } from './Crown';

// No <form> tags per the brief — plain onClick/onChange handlers.
export function Auth() {
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const sendMagicLink = async () => {
    if (!email.trim()) return;
    setBusy(true);
    setError(null);
    const { error } = await supabase.auth.signInWithOtp({
      email: email.trim(),
      options: { emailRedirectTo: window.location.origin },
    });
    setBusy(false);
    if (error) setError(error.message);
    else setSent(true);
  };

  const signInWithGoogle = async () => {
    setError(null);
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin },
    });
    if (error) setError(error.message);
  };

  return (
    <div className="panel mx-auto w-full max-w-md p-8 text-center">
      <Crown className="mx-auto h-14 w-14 animate-pulse-glow rounded-full" />
      <h1 className="mt-4 font-display text-3xl font-bold text-glow">Throne Takeover</h1>
      <p className="mt-2 text-sm text-white/60">
        One throne. Everyone wants it. Sign in to take it.
      </p>

      {sent ? (
        <p className="mt-6 rounded-lg bg-emerald-500/10 p-4 text-emerald-300">
          Check your email for a magic sign-in link.
        </p>
      ) : (
        <div className="mt-6 space-y-3">
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && sendMagicLink()}
            placeholder="you@realm.com"
            className="w-full rounded-lg border border-white/10 bg-black/30 px-4 py-3 text-center outline-none focus:border-royal-400"
          />
          <button
            onClick={sendMagicLink}
            disabled={busy}
            className="w-full rounded-lg bg-royal-500 px-4 py-3 font-semibold text-black transition hover:bg-royal-400 disabled:opacity-50"
          >
            {busy ? 'Sending…' : 'Email me a magic link'}
          </button>
          <div className="flex items-center gap-3 text-xs text-white/30">
            <span className="h-px flex-1 bg-white/10" /> or <span className="h-px flex-1 bg-white/10" />
          </div>
          <button
            onClick={signInWithGoogle}
            className="w-full rounded-lg border border-white/15 bg-white/5 px-4 py-3 font-semibold transition hover:bg-white/10"
          >
            Continue with Google
          </button>
        </div>
      )}

      {error && <p className="mt-4 text-sm text-rose-400">{error}</p>}
    </div>
  );
}
