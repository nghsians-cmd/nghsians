# Newsletter → Account merge

**Date:** 2026-10-12 · **Status:** account/signup migration in place; mailer UX refreshed; sending still requires the deployed Edge Function and verified sender domain

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
| `supabase-newsletter-media.sql` | legacy optional storage-bucket policy; the current mailer embeds uploaded images inline |
| `assets/mailer/logo.png`, `assets/mailer/footer-logo.png` | site-hosted NGHSIANS artwork used by the mailer and generated email footer |
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
Open `mailer.html` → **⇪ Import** → choose the CSV or paste its contents → review the import summary → confirm.
The importer recognizes both an `email` column and MailerLite's `Subscriber` column, de-duplicates addresses, and ignores open/click/location analytics. If a status column exists, only active/subscribed/confirmed records are imported; unsubscribed, bounced, junk and unknown statuses are skipped. If the file has no status column, the panel warns you to verify it is an active-subscriber export before proceeding. Matching emails join their account; others become imported contacts. An account with an explicit unsubscribe is skipped rather than re-added as a separate contact. Importing never sends mail.

Do not add the CSV or subscriber addresses to GitHub. They are private contact data; the CSV stays in Drive and is imported through the PIN-locked panel.

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

**4d · optional campaign images** — no storage bucket is required for the current editor. An uploaded PNG, JPEG or WebP is cropped in the browser and attached directly to the email; alternatively, paste a public HTTPS image URL. The legacy `supabase-newsletter-media.sql` migration is not used by this inline-image flow.

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

## Mailer design builder

The compose panel starts with the essentials: subject and message. Templates, inbox preview text, images, headlines, buttons and styling are optional and tucked away until needed. The generated email is a single-column, centered, 600px layout with a branded masthead and footer; optional blocks are omitted when left blank. The preview can be opened on demand, and desktop/mobile inbox sizing is available there. The CTA's new-tab preference is advisory because many email apps control link-opening behavior themselves.

Two presets are included:

- **NGHSIANS** — the existing charcoal, gold and red identity; DM Sans and Anton are the defaults.
- **60th Sign Day** — paper, ink, deep red and gold inspired by `27form.html`, `27rep.html`, and the 60th Sign Day card in `index.html`.

Every palette role is editable (canvas, card, text, muted text, accents, button and footer); heading/body fonts can be changed. Center alignment is the default, with left alignment available. The email uses table-based structure, inline styles, optional image alt text, a test send, local draft autosave, and per-recipient name/batch/email merge tags. It declares light/dark color-scheme support and includes explicit dark-mode colors; some mail clients may still apply their own color transformations. The footer includes the logo, social links, brand, copy, unsubscribe link and account-preferences link. The full HTML is generated before sending so preview and delivered content use the same layout.

These decisions follow established builders' useful patterns—saved/reusable content blocks and responsive previews—while keeping this campaign structure intentionally simple and reliable across email clients. See [Mailchimp's new builder guide](https://mailchimp.com/help/design-an-email-new-builder/) and [Litmus's accessibility checklist](https://www.litmus.com/blog/7-simple-tricks-to-make-your-email-code-more-accessible) for the reference patterns (responsive preview, semantic structure, alt text, readable color contrast).

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
storage.buckets            → newsletter-media (legacy/optional; inline campaign images need no bucket)
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

## Remaining rollout steps

| # | Item | Blocking |
|---|---|---|
| 1 | After merge, safely rerun `supabase-newsletter-merge.sql` (updates the importer opt-out guard), then deploy the updated `send-newsletter` Edge Function | importer safety + full-render email delivery |
| 2 | Confirm that the Mail Files CSV is the current active/subscribed list before importing; it has no status column | safe import of the legacy contacts |
| 3 | Send a test and check the delivered message in desktop and mobile inboxes | production send confidence |
| 4 | After the first clean campaign, retire the MailerLite account/form to avoid double opt-ins | MailerLite shutdown |
