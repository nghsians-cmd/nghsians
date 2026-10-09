# NGHSIANS — revised website files

Upload these files into the same directory as your existing homepage. The package has not been deployed.

- `index.html`: community homepage, Result and Dress Code menu links, and the September 28 Sign Day announcement.
- `result.html`: “SSC Batch 26 Results” opens the existing showcase; “SEE ALL” searches the unchanged 242 records.
- `dress.html`: simplified uniform page, the homepage menu and footer, six expandable details, regular/winter views, and the slide image by itself.
- `outfit.png`: the revised Instagram slide, 1122 × 1402 pixels.
- `uniform-front.png`, `uniform-turntable.png`, `uniform-winter.png`, `uniform-winter-turntable.png`: all four are required by the interactive viewer.
- `NGHS PRIME LOGO RE.png`: supplied school badge.
- `sitemap-nghsians-update.xml`: supplemental sitemap for the three pages; merge its URLs into your existing sitemap or submit it separately.

Keep your existing assets and other pages, including `logo.png`, `favLogo.ico`, `banner.jpg`, `linkhero.jpg`, gallery images, and account/alumni/merch/Sign Day pages. This package does not replace them.

Add the announcement artwork as `NGHS 60th Sign Day Hero.png` if it is not already present. The popup and news card reference that filename; the button links to https://www.instagram.com/p/DdneRfRueG8/.

## Uniform viewer

The viewer uses photographic images with eight camera angles, not a polygon mesh. It turns slowly while idle; hovering, keyboard focus, dragging or opening a detail pauses it. Drag horizontally, use the arrow buttons/keys, or move the slider to turn. Selecting a garment opens its explanation and animates a close-up. The reset icon returns to the complete outfit. The winter switch adds the navy V-neck sweatshirt; selecting the shirt or badge switches back to the regular outfit.

Vertical touch scrolling remains available. Reduced-motion preferences stop automatic rotation and transitions. Rotation stops when the viewer is offscreen or the tab is hidden. The front image loads first, the angle sheet loads when needed, and winter images load on selection. No 3D library is required.

## Search titles

- Home: **NGHSIANS - Nasirabad Government High School**
- Results: **SSC 2026 Results — NGHSIANS**
- Uniform: **NGHSIANS - School Uniform**

The pages retain distinct descriptions, canonical URLs, social metadata and structured data. All six uniform explanations are ordinary HTML. After uploading, submit the pages and sitemap in Google Search Console if you manage the domain. Google controls crawling, indexing and displayed titles; posting on Instagram alone does not guarantee an update.

## Image brief

The images were created using the built-in image-generation tool, referencing the existing uniform poster, supplied school badge and navy winter sweatshirt photo. The slide brief was: a simple dark portrait infographic, modern sans-serif type, one realistic headless uniform, five short numbered callouts, and no winter layer. The viewer brief was: matching photorealistic transparent garment cutouts, with eight turntable angles and a separate plain navy V-neck winter version. The notes describe practical and visual benefits of the community-specified uniform.

## Checks

Checked in Chromium at desktop and phone sizes: all six details, close-ups, winter switching, rotation, keyboard controls, mouse/touch dragging, mobile navigation, and the image-only poster area. No horizontal overflow at widths from 320 to 1920 pixels. Results search and Escape closing work, and all 242 original records remain unchanged. Both inner pages use the homepage footer and navigation; homepage section links return to `index.html`.

Existing authentication and external services were preserved; no live account operations were performed.

## ⏳ Temporary: NGHS 60th Sign Day pass (batch 2027)

Two files carry this one-off feature, and nothing else does:

- `supabase-schema.sql` — sections **8 to 12**, fenced by `TEMP-SIGNDAY-60 · START / END` banners
  (sections 0–7 are the rest of the site's schema, unchanged apart from formatting).
- `supabase-signday-60.sql` — **the same sections 8–12 as a standalone file**, for running on a
  project that already has `verified_profiles` (this one). Prefer this file: it has no
  `create table`, so Supabase does not offer to "enable RLS" and cannot rewrite the script.
- `account.html` — the CSS, HTML and JS regions tagged `TEMP-SIGNDAY-60`, plus six one-line hooks
  inside the existing code (each tagged on the line above it).

Upload both, then run one SQL file in **Supabase → SQL Editor → New query**. They are idempotent:
they only add what is missing and delete nothing.

### If Supabase shows "Potential issues detected" — press **Run without RLS**

The dialog offers *Cancel · Run without RLS · Run and enable RLS*. **Choose "Run without RLS".**
"Run and enable RLS" is an automatic fixer: it rewrites the script before running it, inserting its
own `alter table … enable row level security;` line after each `create table`. Those files already
enable RLS and create every policy themselves, so the rewrite only gets in the way — and in earlier
versions it landed *inside* the multi-line `create table` statement, which is what produced errors
like `42601: syntax error at or near "alter"` pointing at a line that does not exist in the file.

Both SQL files are now written to survive that rewrite: **every statement is a single line**, so a
line-based injector has nothing to cut into, and all comments are `/* … */` blocks, so they survive
being joined or stripped. The only multi-line statements left are the two function bodies
(section 6 of `supabase-schema.sql`, section S2 of `supabase-signday-60.sql`).

The files also contain **no `DO $$ … $$` blocks** — every conditional step is plain idempotent DDL
(`add column if not exists`, `drop policy/trigger/constraint if exists`), so a paste that gets split
up mid-block cannot leave a bare `if … then` for Postgres to choke on (that was the earlier
`42601: syntax error at or near "if"` failure). If an editor ever cuts a paste again, run one
numbered section at a time and paste each whole function in a single go.

### If you see `23514: violates check constraint "verified_profiles_role_check"`

That means the live database had a pre-existing role check which allowed the site's normal roles but
rejected `27`. The v5 standalone SQL now replaces that check with one that permits `27` only when
`batch_year = '2027'` (and keeps `member`, `elite`, `alumni`, and `architect`). The failed backfill
statement did not complete; re-run the updated whole `supabase-signday-60.sql` file in **SQL Editor →
New query**. The migration is safe to re-run.

What it does:

- New role value **`27`** in `verified_profiles.role`. That is the only thing you type by hand.
  Version 5 also replaces the existing `verified_profiles_role_check` constraint that rejected `27`;
  the new check accepts `27` only with `batch_year = '2027'`, alongside the four normal roles
  (`member`, `elite`, `alumni`, `architect`). The trigger independently rejects `27` on any other
  batch, and if a 2027 student edits their own batch away from 2027, the tag is removed silently.
- Every **new** 2027 registration is given role `27` automatically, and section 10 backfills every
  2027 student already in the table.
- `signday_status` moves `unconfirmed → submitted → issued`. `submitted` is written by the student
  pressing **Register** on their own card (their account email lands in `signday_email`); a student
  cannot mark themselves `issued` — the trigger refuses that write. Only you, from the Table editor
  (or with the statements in section 11), issue passes.
- `signday_pass_code` is a ticket serial derived from the row id (`SD60-27-XXXX-XXXX`), written by
  the trigger and used to draw the barcode on the card. No manual work.

In the account page a `27` member sees: the blue **NGHS 60th Sign Day** tag beside their name (card,
network list and member detail modal), an **UNCONFIRMED / PENDING ISSUE / PASS ACTIVE** chip, the
"Register For NGHS 60th Sign Day" notice above their profile, and their ID card rebuilt as a
perforated digital pass — gold emblem in the style of the 60th Sign Day logo, punched side notches,
banknote watermark of the current status, serial and barcode on the stub. When you issue the pass the
card goes "live" (foil sweep) and they get a one-time blue confetti celebration on next sign-in.
`SIGNDAY.dateText` near the top of the JS block is a one-line place to put the real event date.

Checked with a local PostgreSQL 18 running both real files: fresh install, install on top of the previous
schema and its legacy role check, re-runs, every rewrite Supabase's editor can apply to a paste (RLS
injection, comment stripping, one-line joining), auto-issue, the batch guard, self-issue refusal, tag
withdrawal, and the section-12 rollback — 52 SQL checks passed. The front end was checked by driving
the real `account.html` in jsdom for all three states plus the existing flows (themes, verification
modal, details gate, private accounts, signup, follow, edit/save).

### Verify the SQL ran

In **Supabase Dashboard → SQL Editor → New query** (not the Table Editor), paste this read-only
query and click **Run**:

```sql
select count(*) filter (where role = '27') as tagged,
       count(*) filter (where role = '27' and signday_status = 'submitted') as waiting
  from public.verified_profiles;
```

`tagged` is the number of batch-2027 profiles carrying the Sign Day tag; `waiting` is how many of
them pressed **Register** and are awaiting pass issue. The first number should match the batch-2027
headcount.

### Removing it after the event

1. In `account.html`, delete the `TEMP-SIGNDAY-60` CSS / HTML / JS regions and the six tagged hook
   lines, then delete the `.profile-col` wrapper around `#profile-card`.
2. In Supabase, uncomment and run section **12** of `supabase-schema.sql` (or section **S5** of
   `supabase-signday-60.sql`): it drops the trigger and two indexes, removes the Sign Day status
   constraint and five `signday_*` columns, restores the normal four-role check, and returns every
   `27` member to `member`.

No other page, table or script depends on any of it.

## Duplicate accounts and the phone member card (2026-10-08)

**Upload** the updated `account.html`. On phones, the 2027 Sign Day pass in the member detail panel now shows its name and emblem at the top, scrolls by hand, has wider sides, and closes when you tap either side. A sign-up whose email is already in use now gets a clear message.

**Duplicate accounts** uses two SQL files in the repository:

- `supabase-dedupe-accounts.sql`: a read-only preview, an audit table, a guard that refuses a new login or profile email that another account already uses, and the email lock. It deletes nothing.
- `supabase-dedupe-terminate.sql`: deletes the older duplicates. Run it only after you have read the preview.

A duplicate is two or more accounts with the same email once capitals and spaces are ignored, comparing both the login email and the profile email. The most recently created account is kept and the older ones are terminated. Accounts that use an admin email, or a role other than member or 27, are never removed automatically; they are listed as REVIEW.

1. Supabase → SQL Editor → New query → paste `supabase-dedupe-accounts.sql` → **Run without RLS**. Its last statement, the email lock, fails while any duplicate is left. That is expected.
2. Read the preview: select the single line under "2. PREVIEW" and press Run. Check every TERMINATE row. Then select the single line under "3." and press Run to see every table that points at `auth.users`.
3. When the TERMINATE rows are the ones you expect, paste `supabase-dedupe-terminate.sql` and Run it. A copy of each removed profile and its follow links is kept in `account_dedupe_audit`, which the public API cannot read.
4. Resolve any REVIEW rows by hand, then run section 6 of the first file again. The email lock builds once no duplicate is left.
