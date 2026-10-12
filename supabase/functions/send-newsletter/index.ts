/* ============================================================================
   supabase/functions/send-newsletter
   ----------------------------------------------------------------------------
   The only place a newsletter email actually leaves the building.

   WHY THIS EXISTS
     A static page (mailer.html on GitHub Pages) cannot send email: browsers
     won't open an SMTP socket, and Gmail's API needs OAuth plus a server to
     hold the refresh token. MailerLite used to be that server. This function
     replaces it — the RESEND_API_KEY lives here, in Supabase secrets, never in
     the HTML.

   DEPLOY (once)
     supabase login
     supabase link --project-ref mctjlcznxpuvtetqnaeh
     supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxx
     supabase functions deploy send-newsletter --no-verify-jwt

   VERIFY THE SENDING DOMAIN (once, in Resend)
     Add nghsians.com, verify the DNS records, then set MAILER.from in
     mailer.html to an address on that domain. Mail from an unverified From
     address is silently dumped in spam.

   SWAPPING PROVIDER
     Only `deliver()` talks to Resend. Replace that one function to move to
     Postmark, SendGrid, Amazon SES or Brevo — nothing else changes.

   FREE TIER
     Resend: 3,000 emails/month, 100/day on the free plan. Batches of 100 with
     a small pause between them keeps us inside the 2 requests/second limit.
   ============================================================================ */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

/* ------------------------------------------------------------------ config */
const ADMIN_EMAILS = ['nghsians@gmail.com', 'umairhoquechowdhury13@gmail.com'];
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const SITE_URL = Deno.env.get('SITE_URL') ?? 'https://nghsians.com';
const BRAND = 'NGHSIANS';
const BATCH_SIZE = 100;          // Resend accepts 100 emails per request
const BATCH_PAUSE_MS = 600;      // stay under 2 requests/second

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

/* ------------------------------------------------------------------ utils */
const esc = (s: unknown) =>
  String(s ?? '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

const unsubUrl = (token: string) => `${SITE_URL}/unsubscribe.html?u=${encodeURIComponent(token || '')}`;

function fill(html: string, r: Recipient) {
  return String(html)
    .replace(/\{\{\s*name\s*\}\}/gi, esc(r.name || 'there'))
    .replace(/\{\{\s*batch\s*\}\}/gi, esc(r.batch || ''))
    .replace(/\{\{\s*email\s*\}\}/gi, esc(r.email || ''))
    .replace(/\{\{\s*unsubscribe_url\s*\}\}/gi, esc(unsubUrl(r.unsub_token ?? '')));
}

interface Recipient { email: string; name?: string; batch?: string; unsub_token?: string }
interface Payload {
  pin?: string; subject?: string; preheader?: string; body?: string;
  from?: string; replyTo?: string; recipients?: Recipient[];
}

/* --------------------------------------------------------- the only Resend call */
async function deliver(batch: { from: string; reply_to: string; to: string[]; subject: string; html: string }[]) {
  if (!RESEND_API_KEY) throw new Error('RESEND_API_KEY is not set — run: supabase secrets set RESEND_API_KEY=re_…');
  // Resend's /emails endpoint accepts ONE email object; arrays must go to
  // /emails/batch. Tests and fallback retries have one item, so send those as
  // an object too. Posting a one-item array to /emails is rejected by Resend.
  const isBatch = batch.length > 1;
  const endpoint = isBatch ? 'https://api.resend.com/emails/batch' : 'https://api.resend.com/emails';
  const payload = isBatch ? batch : batch[0];
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`Resend ${res.status}: ${text.slice(0, 300)}`);
  }
  return res.json().catch(() => ({}));
}

/* ------------------------------------------------------------------- handler */
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'POST only' }, 405);

  try {
    /* 1 · who is calling? -------------------------------------------------- */
    const auth = req.headers.get('Authorization') ?? '';
    const token = auth.replace(/^Bearer\s+/i, '');
    if (!token) return json({ error: 'Missing authorization header.' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false } },
    );
    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user?.email) return json({ error: 'Not signed in.' }, 401);
    if (!ADMIN_EMAILS.includes(userData.user.email.toLowerCase())) {
      return json({ error: 'Not an admin account.' }, 403);
    }

    /* 2 · PIN (checked in the database, not in the page) ------------------- */
    const body = (await req.json()) as Payload;
    const pin = String(body.pin ?? '').trim();
    if (!pin) return json({ error: 'Missing PIN.' }, 400);

    // Compare the PIN in the database via the security-definer RPC. app_secrets
    // has no client-readable policy, so this is the only way in — and it means
    // this function never needs the service-role key at all.
    const { data: pinOk, error: pinErr } = await supabase.rpc('newsletter_check_pin', { p_pin: pin });
    if (pinErr) return json({ error: 'PIN check failed: ' + pinErr.message }, 500);
    if (pinOk !== true) return json({ error: 'Wrong PIN.' }, 403);

    /* 3 · payload ---------------------------------------------------------- */
    const subject = String(body.subject ?? '').trim();
    const htmlBody = String(body.body ?? '').trim();
    const recipients = (body.recipients ?? []).filter((r) => r && r.email && r.email.includes('@'));
    if (!subject) return json({ error: 'Missing subject.' }, 400);
    if (!htmlBody) return json({ error: 'Empty body.' }, 400);
    if (!recipients.length) return json({ error: 'No recipients.' }, 400);

    const from = String(body.from || `${BRAND} <news@nghsians.com>`);
    const replyTo = String(body.replyTo || 'nghsians@gmail.com');

    /* 4 · build + send in batches ------------------------------------------ */
    // Everyone is BCC'd individually so no recipient sees anyone else's address.
    const jobs = recipients.map((r) => ({
      from,
      reply_to: replyTo,
      to: [r.email],
      subject,
      // mailer.html sends the complete responsive HTML (header, hero, CTA and footer).
      html: fill(htmlBody, r),
    }));

    let sent = 0;
    let failed = 0;
    const errors: string[] = [];
    for (let i = 0; i < jobs.length; i += BATCH_SIZE) {
      const slice = jobs.slice(i, i + BATCH_SIZE);
      try {
        await deliver(slice);
        sent += slice.length;
      } catch (err) {
        // One bad batch shouldn't kill the whole send — retry it one at a time.
        for (const job of slice) {
          try { await deliver([job]); sent++; }
          catch (e) { failed++; errors.push(`${job.to[0]}: ${(e as Error).message}`); }
        }
      }
      if (i + BATCH_SIZE < jobs.length) await new Promise((r) => setTimeout(r, BATCH_PAUSE_MS));
    }

    return json({ sent, failed, errors: errors.slice(0, 20), total: recipients.length });
  } catch (err) {
    console.error(err);
    return json({ error: (err as Error).message || 'Unexpected error.' }, 500);
  }
});
