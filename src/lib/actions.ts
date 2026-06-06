import { supabase } from './supabase';
import type { SabotageCard } from './types';

/** Ask the server to seize the throne. All validation happens server-side. */
export async function takeThrone(userId: string): Promise<{ ok: boolean; message?: string }> {
  const { data, error } = await supabase.rpc('take_throne', { p_player_id: userId });
  if (error) return { ok: false, message: cleanError(error.message) };
  // Soft rejections (cooldown/frozen/protected) come back as { success: false }.
  if (data && data.success === false) {
    return { ok: false, message: (data.message as string) ?? 'Could not take the throne' };
  }
  return { ok: true };
}

export async function castSabotage(card: SabotageCard): Promise<{ ok: boolean; message?: string }> {
  const { error } = await supabase.rpc('use_sabotage', { p_card_type: card });
  if (error) return { ok: false, message: cleanError(error.message) };
  return { ok: true };
}

/** Kick off Stripe Checkout via the edge function and redirect. */
export async function startCheckout(): Promise<string | null> {
  const { data, error } = await supabase.functions.invoke('create-checkout');
  if (error || !data?.url) return null;
  return data.url as string;
}

export async function openCustomerPortal(): Promise<string | null> {
  const { data, error } = await supabase.functions.invoke('customer-portal');
  if (error || !data?.url) return null;
  return data.url as string;
}

// Postgres RAISE messages arrive prefixed; trim to the human part.
function cleanError(msg: string): string {
  return msg.replace(/^.*?:\s*/, '').trim() || msg;
}
