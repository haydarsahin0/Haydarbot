import { useState } from 'react';
import { isConfigured } from './lib/supabase';
import { useAuth } from './hooks/useAuth';
import { useProfile } from './hooks/useProfile';
import { useThrone } from './hooks/useThrone';
import { useGameConfig } from './hooks/useGameConfig';
import { Auth } from './components/Auth';
import { Header } from './components/Header';
import { ThroneStage } from './components/ThroneStage';
import { TakeButton } from './components/TakeButton';
import { SabotageBar } from './components/SabotageBar';
import { LiveFeed } from './components/LiveFeed';
import { Leaderboard } from './components/Leaderboard';
import { SubscribePanel } from './components/SubscribePanel';
import { FrenzyNotice } from './components/FrenzyNotice';
import { Toast, type ToastState } from './components/Toast';

export default function App() {
  const { user, loading, signOut } = useAuth();
  const { profile } = useProfile(user?.id ?? null);
  const { throne, holder } = useThrone();
  const { config, frenzy } = useGameConfig();
  const [toast, setToast] = useState<ToastState | null>(null);

  const notify = (msg: string, ok: boolean) =>
    setToast({ msg, ok, id: Date.now() });

  if (!isConfigured) return <SetupNeeded />;

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center text-white/40">Loading…</div>
    );
  }

  if (!user) {
    return (
      <div className="flex min-h-screen items-center justify-center p-4">
        <Auth />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-6xl px-4 py-6">
      <Header profile={profile} onSignOut={signOut} />

      <main className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Throne + actions */}
        <section className="space-y-4 lg:col-span-2">
          <ThroneStage
            throne={throne}
            holder={holder}
            config={config}
            frenzy={frenzy}
            currentUserId={user.id}
          />
          <TakeButton userId={user.id} throne={throne} profile={profile} onResult={notify} />
          <SabotageBar profile={profile} config={config} onResult={notify} />
          <LiveFeed />
        </section>

        {/* Standings + monetization */}
        <section className="space-y-6">
          <FrenzyNotice frenzy={frenzy} profile={profile} />
          <Leaderboard currentUserId={user.id} seasonNumber={config?.current_season} />
          <SubscribePanel profile={profile} config={config} />
        </section>
      </main>

      <footer className="mt-10 pb-6 text-center text-xs text-white/30">
        Status, points & cosmetics only — no gambling, no payouts. Built on Supabase + Stripe.
      </footer>

      <Toast toast={toast} onDone={() => setToast(null)} />
    </div>
  );
}

function SetupNeeded() {
  return (
    <div className="mx-auto flex min-h-screen max-w-lg flex-col justify-center px-6 text-center">
      <h1 className="font-display text-2xl font-bold text-glow">Throne Takeover</h1>
      <p className="mt-3 text-white/60">
        Almost there. Copy <code className="text-royal-300">.env.example</code> to{' '}
        <code className="text-royal-300">.env</code> and set your Supabase URL and anon key, then
        run the migrations in <code className="text-royal-300">supabase/migrations</code>.
      </p>
      <p className="mt-3 text-sm text-white/40">See the README for full setup steps.</p>
    </div>
  );
}
