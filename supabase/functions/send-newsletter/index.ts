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
const TAGLINE = 'Nasirabad Government High School · Chattogram';
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
    .replace(/\{\{\s*email\s*\}\}/gi, esc(r.email || ''));
}

/* Keep in step with emailShell() in mailer.html — that one renders the preview,
   this one renders the mail that goes out. Change both together. */
function shell(o: { subject: string; preheader: string; body: string; unsub: string }): string {
  const pre = o.preheader
    ? `<div style="display:none;max-height:0;overflow:hidden;opacity:0">${esc(o.preheader)}</div>`
    : '';
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(o.subject)}</title></head>
<body style="margin:0;padding:0;background:#0b0c0d">
${pre}
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0b0c0d;padding:26px 12px">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#121316;border:1px solid rgba(255,255,255,.09);border-radius:14px;overflow:hidden;font-family:'DM Sans',Helvetica,Arial,sans-serif">
  <tr><td style="height:3px;background:linear-gradient(90deg,#FFEB80,#710C04,#FFEB80);font-size:0;line-height:0">&nbsp;</td></tr>
  <tr><td style="padding:26px 30px 20px;text-align:center;background:#0f1013;border-bottom:1px solid rgba(255,255,255,.07)">
    <div style="font-family:Anton,Impact,sans-serif;font-size:27px;letter-spacing:2px;color:#F3ECD9;text-transform:uppercase">${esc(BRAND)}</div>
    <div style="font-size:11px;letter-spacing:1.6px;text-transform:uppercase;color:rgba(255,235,128,.75);margin-top:5px">Newsletter</div>
  </td></tr>
  <tr><td style="padding:26px 30px 8px">
    <h1 style="font-family:Anton,Impact,sans-serif;font-size:23px;line-height:1.25;margin:0 0 16px;color:#F3ECD9">${esc(o.subject)}</h1>
    <div style="font-size:15px;line-height:1.75;color:#d8d2c4">${o.body}</div>
  </td></tr>
  <tr><td style="padding:22px 30px 26px">
    <div style="border-top:1px solid rgba(255,255,255,.08);padding-top:18px;font-size:12px;line-height:1.7;color:#7d7768;text-align:center">
      <strong style="color:rgba(255,235,128,.8)">${esc(BRAND)}</strong> · ${esc(TAGLINE)}<br>
      You are getting this because you have an NGHSIANS account (or asked for news) at
      <a href="${esc(SITE_URL)}" style="color:#7d7768">${esc(SITE_URL.replace(/^https?:\/\//, ''))}</a>.<br>
      <a href="${esc(o.unsub)}" style="color:#8a8474;text-decoration:underline">Unsubscribe</a>
      &nbsp;·&nbsp; <a href="${esc(SITE_URL)}/account.html" style="color:#8a8474;text-decoration:underline">Manage preferences</a>
    </div>
  </td></tr>
</table>
</td></tr></table></body></html>`;
}

interface Recipient { email: string; name?: string; batch?: string; unsub_token?: string }
interface Payload {
  pin?: string; subject?: string; preheader?: string; body?: string;
  from?: string; replyTo?: string; recipients?: Recipient[];
}

/* --------------------------------------------------------- the only Resend call */
async function deliver(batch: { from: string; reply_to: string; to: string[]; subject: string; html: string }[]) {
  if (!RESEND_API_KEY) throw new Error('RESEND_API_KEY is not set — run: supabase secrets set RESEND_API_KEY=re_…');
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(batch),
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

    // Re-read the PIN with the service role so RLS can't get in the way.
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } },
    );
    const { data: secretRow, error: pinErr } = await admin
      .from('app_secrets').select('value').eq('key', 'mailer_pin').maybeSingle();
    if (pinErr || !secretRow || secretRow.value !== pin) return json({ error: 'Wrong PIN.' }, 403);

    /* 3 · payload ---------------------------------------------------------- */
    const subject = String(body.subject ?? '').trim();
    const preheader = String(body.preheader ?? '').trim();
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
      html: shell({
        subject,
        preheader,
        body: fill(htmlBody, r),
        unsub: unsubUrl(r.unsub_token ?? ''),
      }),
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
