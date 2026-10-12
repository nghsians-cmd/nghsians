/* ============================================================================
   supabase/functions/resend-webhook  (optional)
   ----------------------------------------------------------------------------
   Resend posts delivery events here. Verifies the signature, then marks the
   latest send to an address as delivered (or clears it on bounce). This fills
   the "Received" column in the mailer. Without this, that column stays 0.

   Setup: Resend → Webhooks → add endpoint
   https://<project>.supabase.co/functions/v1/resend-webhook , sign with a
   secret, then set SUPABASE_SERVICE_ROLE_KEY and RESEND_WEBHOOK_SECRET in the
   function's secrets.
   ============================================================================ */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? 'https://mctjlcznxpuvtetqnaeh.supabase.co';
const SUPABASE_SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const SECRET = Deno.env.get('RESEND_WEBHOOK_SECRET') ?? '';

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, resend-signature, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function verify(raw: string, sigHeader: string | null): Promise<boolean> {
  if (!SECRET || !sigHeader) return false;
  const m = sigHeader.match(/t=(\d+),\s*v1=([0-9a-f]+)/i);
  if (!m) return false;
  const [, ts, v1] = m;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(SECRET), { name: 'HMAC' }, false, ['sign']);
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${ts}.${raw}`));
  const hex = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, '0')).join('');
  return timingSafeEqual(hex, v1);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);
  if (!SUPABASE_SERVICE) return json({ error: 'Service role key not set.' }, 500);

  const raw = await req.text();
  const ok = await verify(raw, req.headers.get('resend-signature'));
  if (!ok) return json({ error: 'Invalid signature.' }, 401);

  let payload: any;
  try { payload = JSON.parse(raw); } catch { return json({ ok: false }, 400); }

  const type = payload?.type;
  const email = payload?.data?.email;
  if (!email) return json({ ok: true, ignored: true });

  let event: 'delivered' | 'bounced' | null = null;
  if (type === 'email.delivered') event = 'delivered';
  else if (type === 'email.bounced' || type === 'email.complained') event = 'bounced';
  if (!event) return json({ ok: true, ignored: true });

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE, { auth: { persistSession: false } });
    await supabase.rpc('newsletter_record_event_by_email', { p_email: email, p_event: event });
  } catch (e) {
    console.error(e);
    return json({ error: 'DB update failed.' }, 500);
  }
  return json({ ok: true });
});
