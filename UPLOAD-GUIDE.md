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

- `supabase-schema.sql` — sections **10 to 14**, fenced by `TEMP-SIGNDAY-60 · START / END` banners.
- `account.html` — the CSS, HTML and JS regions tagged `TEMP-SIGNDAY-60`, plus five one-line hooks
  inside the existing code (each tagged on the line above it).

Upload both, then run the whole SQL file in **Supabase → SQL Editor**. It is idempotent: it only
adds what is missing and deletes nothing.

The SQL file deliberately contains **no `DO $$ … $$` blocks** — every conditional step is plain
idempotent DDL (`add column if not exists`, `drop policy/trigger/constraint if exists`), so a paste
that gets split up mid-block cannot leave a bare `if … then` for Postgres to choke on
(that was the `42601: syntax error at or near "if"` failure). The only multi-line statements left are
the two functions in sections 8 and 11; if your editor ever cuts a paste again, run one numbered
section at a time, and paste each whole function in a single go.

What it does:

- New role value **`27`** in `verified_profiles.role`. That is the only thing you type by hand.
  A trigger rejects it for any row whose `batch_year` is not `2027`, so the tag cannot leak to
  another batch — and if a 2027 student edits their own batch away from 2027, the tag is removed
  silently.
- Every **new** 2027 registration is given role `27` automatically, and section 12 backfills every
  2027 student already in the table.
- `signday_status` moves `unconfirmed → submitted → issued`. `submitted` is written by the student
  pressing **Register** on their own card (their account email lands in `signday_email`); a student
  cannot mark themselves `issued` — the trigger refuses that write. Only you, from the Table editor
  (or with the statements in section 13), issue passes.
- `signday_pass_code` is a ticket serial derived from the row id (`SD60-27-XXXX-XXXX`), written by
  the trigger and used to draw the barcode on the card. No manual work.

In the account page a `27` member sees: the blue **NGHS 60th Sign Day** tag beside their name (card,
network list and member detail modal), an **UNCONFIRMED / PENDING ISSUE / PASS ACTIVE** chip, the
"Register For NGHS 60th Sign Day" notice above their profile, and their ID card rebuilt as a
perforated digital pass — gold emblem in the style of the 60th Sign Day logo, punched side notches,
banknote watermark of the current status, serial and barcode on the stub. When you issue the pass the
card goes "live" (foil sweep) and they get a one-time blue confetti celebration on next sign-in.
`SIGNDAY.dateText` near the top of the JS block is a one-line place to put the real event date.

Checked with a local PostgreSQL 18 running the real schema file (auto-issue, the batch guard,
self-issue refusal, tag withdrawal, re-runs, and the section-14 rollback), and by driving the real
`account.html` in jsdom for all three states plus the existing flows (themes, verification modal,
details gate, private accounts, signup, follow, edit/save).

### Removing it after the event

1. In `account.html`, delete the `TEMP-SIGNDAY-60` CSS / HTML / JS regions and the five tagged hook
   lines, then delete the `.profile-col` wrapper around `#profile-card`.
2. In Supabase, uncomment and run section **14** of `supabase-schema.sql`: it drops the trigger,
   the two indexes, the check constraint and the five `signday_*` columns, and returns every
   `27` member to `member`.

No other page, table or script depends on any of it.
