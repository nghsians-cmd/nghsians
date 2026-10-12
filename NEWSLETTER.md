# Newsletter → Account merge

**Date:** 2026-10-12 · **Status:** code done, pending the Supabase migration + one deploy

The standalone Newsletter (the MailerLite embed) is **gone**. The NGHSIANS account *is* the
subscription now: if you have an account, you're on the list, at the email you log in with.

---

## What changed

### Removed
| File | What went |
|---|---|
| `index.html` | the `Newsletter` section, the nav link, the "Join Newsletter" hero button, the MailerLite `universal.js` tag and all `.ml-*` CSS |
| `account.html`, `alumnis.html`, `dress.html`, `merch.html`, `result.html`, `sign.html` | the `Newsletter` nav link |
| `dress.html`, `result.html` | their dead copy of the `.ml-*` CSS |

No other page changed visually. `27form.html` was **not touched**, exactly as asked.

### Added
| File | What it is |
|---|---|
| `supabase-newsletter-merge.sql` | the migration — new columns, backfill, subscriber view, admin RPCs, unsubscribe |
| `mailer.html` | PIN-locked committee mailer (compose, preview, recipients, send, history, CSV import) |
| `unsubscribe.html` | the public one-click unsubscribe page linked from every email footer |
| `supabase/functions/send-newsletter/index.ts` | Supabase Edge Function that actually sends the mail (Resend) |
| `account.html` | consent checkbox on signup, one-time notice popup, newsletter row + Edit toggle |

---

## The three ways people end up on the list

| Who | What they see | `newsletter_opt_in` | `newsletter_notified` |
|---|---|---|---|
| **Existing account holders** (the SQL backfill enrols all of them) | one-time popup on their first `account.html` visit after this ships | `true` | `false` → popup; set to `true` on "I understood" |
| **New signups on `account.html`** | required checkbox *"I agree to receive news from NGHSIANS"* at the bottom of the form | `true` when ticked (can't create the account without it) | `true` — no popup |
| **Signups through `27form.html`** | no checkbox there (page untouched) → they get the same one-time popup on their first `account.html` visit | `false` → set to `true` by "I understood" | `false` → popup |

The popup has exactly one button — **I UNDERSTOOD / আমি বুঝেছি** — and cannot be
dismissed any other way, same as the WhatsApp/Instagram gate. There is deliberately no
decline link in the popup itself; the way out is the newsletter toggle in **Edit**, or
the unsubscribe link in the footer of any email (which has an Undo, for misclicks).

If the required WhatsApp/Instagram gate is also open, the newsletter notice waits
behind it — the two modals never stack, and neither do the celebrations.

---

## Setup (in order)

### 1 · Run the migration
Supabase → **SQL Editor** → new query → paste all of `supabase-newsletter-merge.sql` → **Run**.
If the "Potential issues detected" dialog appears, press **Run without RLS** (the file enables
RLS and creates its own policies).

It is safe to re-run. Nothing is dropped, nothing is deleted.

### 2 · Check the backfill
```sql
select newsletter_opt_in, newsletter_notified, newsletter_source, count(*)
  from public.verified_profiles group by 1, 2, 3 order by 4 desc;
```
Every existing account should be `opt_in = true, notified = false, source = 'legacy-account'`.
`notified = false` is deliberate — it is what fires the popup.

### 3 · Import the MailerLite subscribers
Open `mailer.html` → **⇪ Import** → paste the CSV export → **Import**.
Emails that match an account get opted in on that account; the rest become imported
contacts and still receive news.

### 4 · Deploy the sender (only needed to actually send)
**4a · the API key** — Supabase → Project Settings → Edge Functions → Secrets →
add `RESEND_API_KEY` = your Resend key (starts `re_`).

**4b · the function** — either way works:

*Dashboard (no CLI):* Edge Functions → **Deploy a new function** → name it
`send-newsletter` → paste the whole contents of
`supabase/functions/send-newsletter/index.ts` into the editor → deploy →
open the function's **Details** and turn **Verify JWT** off (the function checks
the caller's own JWT, so the gateway must not reject it first).

*CLI:*
```bash
supabase login
supabase link --project-ref mctjlcznxpuvtetqnaeh
supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxx
supabase functions deploy send-newsletter --no-verify-jwt
```

**4c · the sending domain (do not skip this)** — in Resend, add **nghsians.com** and
add the SPF/DKIM/DMARC records it gives you. Then set `MAILER.from` in `mailer.html`
to an address on that domain. Mail sent from an unverified or mismatched From address
is silently dumped in spam, and bulk mail from a `gmail.com` address is worse still.

### 5 · Change the mailer PIN
```sql
update public.app_secrets set value = 'YOUR-NEW-PIN' where key = 'mailer_pin';
```
Default is in the migration file. It is checked **in the database** — it never appears
in `mailer.html`'s source, so view-source can't reveal it (unlike the 27rep panel).

### 6 · Turn MailerLite off
Once the first send has gone out cleanly, cancel the MailerLite account / delete the
form so nobody doubles up.

---

## Where things live

```
newsletter_opt_in          → wants news            (verified_profiles)
newsletter_notified        → has seen the popup    (verified_profiles)
newsletter_unsubscribed_at → opted out on/after    (verified_profiles)
newsletter_source          → signup | notice | profile | legacy-account | import | resubscribe
newsletter_tokens          → per-account secret unsubscribe token (no client access)
newsletter_contacts        → imported people with no account
newsletter_send_log        → one row per send
app_secrets                → mailer_pin
```

**Why a separate token table?** `verified_profiles` is readable with the anon key (the
network page needs it), so a token column there would let anyone unsubscribe anyone.
`newsletter_tokens` has no client-readable policy at all.

---

## Rollback
Section 18 of `supabase-newsletter-merge.sql` has a one-pass `drop` script for
everything it created. `account.html` degrades gracefully if the migration is not run:
the consent checkbox and the ID-card row are hidden and the popup never fires, so
signup and login keep working normally.


---

## Known issue (pre-existing, not caused by this change)

`verified_profiles` carries the policy *"Public profiles are viewable by everyone"*, so
anyone with the public anon key can read every member's **email, WhatsApp number and
Instagram username** — the network page needs read access, but it currently gets
everything. Left as-is for now, deliberately.

The newsletter data added here does **not** widen that: `newsletter_tokens`,
`newsletter_contacts`, `newsletter_send_log` and `app_secrets` all have no client-readable
policy, and the subscriber list is only reachable through `newsletter_admin_list()`,
which checks the admin JWT **and** the PIN.

When we decide to close it, the fix is to swap the blanket `using (true)` select policy
for one that hides the contact columns from `anon`, and serve the network page from a
view. It needs checking against `account.html`'s network panel and `27rep.html` first.

---

## Still needed from you

| # | Item | Blocking |
|---|---|---|
| 1 | Run `supabase-newsletter-merge.sql` in the Supabase SQL editor | everything |
| 2 | MailerLite subscriber export (CSV, or just a list of emails) | importing the old list |
| 3 | Create a Resend account + add the `RESEND_API_KEY` secret | sending |
| 4 | Verify `nghsians.com` in Resend and add its DNS records | deliverability |
| 5 | Confirm the mailer PIN (default is in section 6 of the SQL) | opening mailer.html |
