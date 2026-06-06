// supabase/functions/stripe-webhook
// THE SECURITY HEART OF MONETIZATION:
//   profiles.is_subscriber is written ONLY here, using the service-role key,
//   and only after verifying Stripe's webhook signature. Nothing the browser
//   sends can ever flip is_subscriber.
//
// Configure this function to skip Supabase's JWT check (Stripe has no JWT):
//   supabase functions deploy stripe-webhook --no-verify-jwt
// Then point a Stripe webhook endpoint at it and set STRIPE_WEBHOOK_SECRET.
import Stripe from 'https://esm.sh/stripe@16.2.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
  httpClient: Stripe.createFetchHttpClient(),
});
const cryptoProvider = Stripe.createSubtleCryptoProvider();
const WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;

// Service-role client bypasses RLS — this is the only writer of is_subscriber.
const admin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (req) => {
  const signature = req.headers.get('stripe-signature');
  const body = await req.text();
  if (!signature) return new Response('Missing signature', { status: 400 });

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      WEBHOOK_SECRET,
      undefined,
      cryptoProvider,
    );
  } catch (err) {
    console.error('Signature verification failed', err);
    return new Response('Invalid signature', { status: 400 });
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        const userId =
          session.client_reference_id ??
          (session.metadata?.supabase_user_id as string | undefined);
        if (userId) {
          await setSubscriber(userId, true, session.customer as string | null);
        }
        break;
      }
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted': {
        const sub = event.data.object as Stripe.Subscription;
        const active = sub.status === 'active' || sub.status === 'trialing';
        const userId = await resolveUserId(sub);
        if (userId) {
          await setSubscriber(userId, active, sub.customer as string);
        }
        break;
      }
      default:
        // Ignore everything else.
        break;
    }
  } catch (err) {
    console.error('Webhook handler error', err);
    return new Response('Handler error', { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});

// Map a subscription back to a Supabase user via metadata, then customer id.
async function resolveUserId(sub: Stripe.Subscription): Promise<string | null> {
  const fromMeta = sub.metadata?.supabase_user_id as string | undefined;
  if (fromMeta) return fromMeta;

  const customerId = typeof sub.customer === 'string' ? sub.customer : sub.customer?.id;
  if (!customerId) return null;
  const { data } = await admin
    .from('profiles')
    .select('id')
    .eq('stripe_customer_id', customerId)
    .maybeSingle();
  return data?.id ?? null;
}

async function setSubscriber(userId: string, value: boolean, customerId: string | null) {
  const patch: Record<string, unknown> = { is_subscriber: value };
  if (customerId) patch.stripe_customer_id = customerId;
  const { error } = await admin.from('profiles').update(patch).eq('id', userId);
  if (error) throw error;
  console.log(`is_subscriber=${value} for ${userId}`);
}
