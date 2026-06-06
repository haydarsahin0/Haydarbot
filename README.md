# 👑 Throne Takeover (Taht Devralma)

A real-time, multiplayer king-of-the-hill web game. There is exactly **one global
throne**. Click to take it; while you hold it you earn points every second.
Everyone else is trying to knock you off. Free to play, with an optional
subscription that grants advantages and cosmetics.

> No gambling, no payouts to users. The only things players "win" are **status,
> points, and cosmetics**. A subscription buys concrete in-game advantages — not money.

## Tech stack

- **Frontend:** React + Vite + TypeScript + TailwindCSS
- **Backend / realtime:** Supabase (Postgres + Realtime + Row Level Security + Auth)
- **Payments:** Stripe subscriptions (Checkout + Customer Portal + webhook → `is_subscriber`)
- **Deploy:** Vercel (frontend) + Supabase (hosted)

## Architecture: server-authoritative by design

The client can only say *"I want to take the throne."* Everything that matters runs
on the server:

- **`take_throne(player_id)`** — a single atomic `SECURITY DEFINER` RPC that locks the
  throne row, checks cooldown / freeze / crown-weight / mob, **closes the previous
  reign and computes its points from `held_since`** (never trusting the client),
  crowns the new ruler, and returns the new state — all in one transaction.
- **RLS** lets players *read* the throne and profiles but **never** directly write the
  throne, their own `points`, or `is_subscriber`. Cosmetic profile columns are the
  only client-writable fields (enforced with column-level grants).
- **`is_subscriber` is written ONLY by the Stripe webhook** (service role). Nothing the
  browser sends can flip it. *Bu güvenliğin kalbi.*

See `supabase/migrations/` for the full schema, RLS policies, and RPCs.

## Chaos modules (toggleable in `game_config`)

| Module | What it does |
| --- | --- |
| **Crown Weight** | A freshly crowned ruler gets a protection shield that decays to zero — the longer you hold, the easier you are to dethrone. No one rules forever. |
| **Mob Overthrow** | If `mob_size` (5) players click within `mob_window_seconds` (2s), the mob dethrones the ruler regardless of cooldown or shield. |
| **Night Frenzy** | One deterministic random hour per day, points are `frenzy_multiplier` (3×). Subscribers get advance notice. |
| **Cursed Throne** | Occasionally a takeover curses the throne so the holder *drains* points. Subscribers see a warning. |
| **Seasons** | Every `season_length_days` (14) the longest-reigning player is engraved on the **Eternal Kings** board and all season points reset. |
| **Sabotage Cards** (subscribers) | Freeze (lock 5s), Thief (steal 10%), Earthquake (eject everyone), Mask (hide name 10s). |

Toggle any module by flipping its `*_enabled` flag in the `game_config` row.

## Free vs Subscriber

| | Free | Subscriber |
| --- | --- | --- |
| Cooldown after losing | 10s | 3s |
| Points / sec | 1× | 2× |
| Crowns & name effects | Default | Custom |
| Sabotage cards | — | ✅ |
| Reign history & event notices | — | ✅ |

## Local setup

### 1. Install

```bash
npm install
cp .env.example .env   # fill in VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
```

### 2. Database

Apply the migrations to your Supabase project:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

This creates the schema, RLS policies, RPCs, the auth→profile trigger, and adds the
gameplay tables to the `supabase_realtime` publication.

> In the Supabase dashboard, enable the **Google** auth provider if you want the
> Google sign-in button, and (optionally) **pg_cron** to auto-run season rollovers
> (uncomment the `cron.schedule(...)` line in `0005_triggers_and_realtime.sql`).

### 3. Stripe (subscriptions)

1. Create a recurring **Price** in Stripe and copy its `price_...` id.
2. Set edge-function secrets:

   ```bash
   supabase secrets set \
     STRIPE_SECRET_KEY=sk_test_... \
     STRIPE_WEBHOOK_SECRET=whsec_... \
     STRIPE_PRICE_ID=price_... \
     APP_URL=http://localhost:5173
   ```

3. Deploy the functions:

   ```bash
   supabase functions deploy create-checkout
   supabase functions deploy customer-portal
   supabase functions deploy stripe-webhook --no-verify-jwt
   ```

4. In Stripe, add a webhook endpoint pointing at the deployed `stripe-webhook`
   function URL, subscribing to `checkout.session.completed` and
   `customer.subscription.*` events. Use its signing secret as `STRIPE_WEBHOOK_SECRET`.

### 4. Run

```bash
npm run dev   # http://localhost:5173
```

## Deploy

- **Frontend → Vercel:** import the repo, set `VITE_SUPABASE_URL` and
  `VITE_SUPABASE_ANON_KEY`. `vercel.json` already configures the Vite build + SPA
  rewrites. Update `APP_URL` (and Supabase Auth redirect URLs) to your Vercel domain.
- **Backend → Supabase hosted:** migrations + edge functions as above.

## Build order (followed here)

1. Schema + RLS policies → `0001`–`0002`
2. Auth (email magic link + Google) → `Auth.tsx`, `0005` trigger
3. Atomic `take_throne` RPC + server-side points → `0003`
4. Realtime throne display + take button + cooldown → `useThrone`, `ThroneStage`, `TakeButton`
5. Leaderboard + reign history → `Leaderboard`, `LiveFeed`
6. Free vs subscriber gating → throughout
7. Stripe subscription (Checkout + webhook + `is_subscriber`) → `supabase/functions/*`
8. Chaos modules → `0003`/`0004` + UI

## Notes

- No `<form>` tags — all input uses `onClick` / `onChange` handlers.
- Point totals are finalized on dethrone; the big counter on the throne extrapolates
  live from `held_since` for display only.
- **Legal:** a subscription sells concrete in-game advantage, not money to users. If you
  take real payments, have a lawyer review your terms.
