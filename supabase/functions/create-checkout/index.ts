// supabase/functions/create-checkout
// Creates a Stripe Checkout session for the Throne Takeover subscription.
// The caller must be a logged-in Supabase user (JWT in the Authorization header).
// We attach the Supabase user id to the Stripe customer + session metadata so the
// webhook can map the subscription back to a profile.
//
// Deploy: supabase functions deploy create-checkout
import Stripe from 'https://esm.sh/stripe@16.2.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';
import { corsHeaders } from '../_shared/cors.ts';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
  httpClient: Stripe.createFetchHttpClient(),
});

const APP_URL = Deno.env.get('APP_URL') ?? 'http://localhost:5173';
const PRICE_ID = Deno.env.get('STRIPE_PRICE_ID')!;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Authenticate the caller with their own JWT.
    const authHeader = req.headers.get('Authorization') ?? '';
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: userErr } = await supabase.auth.getUser();
    if (userErr || !user) {
      return json({ error: 'Not authenticated' }, 401);
    }

    // Reuse an existing Stripe customer if we have one on the profile.
    const { data: profile } = await supabase
      .from('profiles')
      .select('stripe_customer_id, username')
      .eq('id', user.id)
      .single();

    let customerId = profile?.stripe_customer_id ?? undefined;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: user.email,
        name: profile?.username,
        metadata: { supabase_user_id: user.id },
      });
      customerId = customer.id;
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer: customerId,
      line_items: [{ price: PRICE_ID, quantity: 1 }],
      client_reference_id: user.id,
      subscription_data: { metadata: { supabase_user_id: user.id } },
      success_url: `${APP_URL}/?subscribed=1`,
      cancel_url: `${APP_URL}/?canceled=1`,
      allow_promotion_codes: true,
    });

    return json({ url: session.url }, 200);
  } catch (err) {
    console.error('create-checkout error', err);
    return json({ error: (err as Error).message }, 500);
  }
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
