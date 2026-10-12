/* ============================================================================
   supabase/functions/track-click
   ----------------------------------------------------------------------------
   Click-tracking redirect. The send-newsletter function rewrites email links to
   .../track-click?t=TOKEN&u=ENCODED_URL. This records the "link opened" event,
   then 302-redirects the reader to the real URL. Only http(s) destinations are
   followed, so the endpoint cannot be used as an open redirect.
   ============================================================================ */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? 'https://mctjlcznxpuvtetqnaeh.supabase.co';
const SUPABASE_ANON = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const t = url.searchParams.get('t');
  const u = url.searchParams.get('u');

  if (t && u) {
    try {
      const supabase = createClient(SUPABASE_URL, SUPABASE_ANON, { auth: { persistSession: false } });
      await supabase.rpc('newsletter_record_event', { p_token: t, p_event: 'clicked' });
    } catch (_e) { /* best-effort */ }
  }

  if (u && /^https?:\/\//i.test(u)) {
    return Response.redirect(u, 302);
  }
  return new Response('Invalid link.', { status: 400 });
});
