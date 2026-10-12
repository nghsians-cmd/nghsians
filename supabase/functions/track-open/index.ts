/* ============================================================================
   supabase/functions/track-open
   ----------------------------------------------------------------------------
   Open-tracking pixel. The send-newsletter function embeds
   <img src=".../track-open?t=TOKEN"> into every email; when a mail app loads
   the image, this records the "opened" event for that recipient. Returns a
   1×1 transparent GIF so the email layout is unaffected.

   No auth: the token is an unguessable UUID tied to one recipient row.
   ============================================================================ */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? 'https://mctjlcznxpuvtetqnaeh.supabase.co';
const SUPABASE_ANON = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

// 1×1 transparent GIF
const PIXEL = new Uint8Array([
  0x47,0x49,0x46,0x38,0x39,0x61,0x01,0x00,0x01,0x00,0x80,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x21,0xf9,0x04,0x01,0x00,0x00,0x00,0x00,0x2c,0x00,0x00,0x00,0x00,
  0x01,0x00,0x01,0x00,0x00,0x02,0x02,0x44,0x01,0x00,0x3b,
]);

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const t = url.searchParams.get('t');
  if (t) {
    try {
      const supabase = createClient(SUPABASE_URL, SUPABASE_ANON, { auth: { persistSession: false } });
      await supabase.rpc('newsletter_record_event', { p_token: t, p_event: 'opened' });
    } catch (_e) { /* best-effort; never break the image */ }
  }
  return new Response(PIXEL, {
    headers: {
      'Content-Type': 'image/gif',
      'Cache-Control': 'no-store, no-cache, must-revalidate',
      'Access-Control-Allow-Origin': '*',
    },
  });
});
