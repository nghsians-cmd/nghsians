# TEMPORARY — NGHS 60th Intro

Also called **NGHS 60th Sign Day Intro**. This is the removable opening experience
above the existing NGHSIANS homepage, not a replacement for that homepage.

## Remove NGHS 60th Sign Day Intro

1. In `index.html`, delete the head block from
   `TEMPORARY — NGHS 60th Intro / NGHS 60th Sign Day Intro — START` through
   `<!-- TEMPORARY — NGHS 60th Intro — END -->` (inclusive). That block is the
   only integration point in the homepage; the registration popup and every
   other script in `index.html` are untouched.
2. Delete `assets/nghs-60th-intro/`, `tests/nghs-60th-intro.test.cjs`, and this file.

**Do not remove or alter the existing `#hero27`, other homepage sections, original
images, `nghs-ui.*`, `27form.html`, the `#newsPopup` registration announcement,
registration code, or database scripts.** Those are independent of this intro.
No content was moved out of the homepage.

## Files and integration

- `index.html`: one marked head integration block, and nothing else.
- `assets/nghs-60th-intro/entry.css`: uniquely named, locally hosted fonts, the
  brief loading cover, and a scroll lock **only while the intro is open**.
- `assets/nghs-60th-intro/intro.js`: an isolated Shadow DOM containing a native
  modal dialog, five chapters, click navigation and scroll-linked effects.
- `assets/nghs-60th-intro/intro.css`: all intro styling, inside that Shadow DOM.
  It cannot override the real website's navigation, sections, buttons or CSS.
- Optimized WebP artwork and OFL-licensed fonts are local to the same folder.
  The original full-resolution Drive downloads are not part of the website.

## Visitor behavior

- A fresh visit to `/` or `index.html` opens the intro. There is deliberately no
  cookie, account requirement, or persistent "seen" flag for the intro.
- Direct homepage anchor links, e.g. `/#news` or `index.html#about`, bypass it.
  The existing `#ssc26-results` redirect is left alone, too.
- **Proceed to NGHSIANS** is available throughout, and again at the end. It
  dismisses only the intro, restores focus and page scrolling, and does not
  reload or redirect away from the existing homepage. Escape also dismisses it.
- **Register**, in the last chapter, is a normal same-tab link to `27form.html`.
  Modified-click / open-in-new-tab browser behavior remains available.
- The existing `#newsPopup` registration announcement is **never suppressed,
  closed or delayed by this intro** — its code in `index.html` is byte-for-byte
  the original, on its original 1.5s timer and its original once-per-session
  key. While the intro is on screen the popup simply sits behind the native
  modal; the moment the visitor proceeds (or presses Escape) the popup is
  already open and receives focus, so the announcement is never lost.
  Direct anchor visits show it exactly as before, with no intro at all.
- No JavaScript means the original site is shown. A missing or failed module /
  stylesheet fails open, and the loading cover has a five-second safety timeout.
  Missing illustrations do not prevent either required action from working.

## Motion, inputs and accessibility

- Native wheel, trackpad and touch scrolling: no wheel/touch cancellation,
  scroll-jacking, forced snapping, timers advancing the story, or autoplay.
- Keyboard scrolling, native modal focus containment, visible focus indicators,
  Escape-to-skip, clickable chapter navigation and clickable next-chapter cues.
- Pinned, curved reveals; a shrinking opening; staggered text; a final ticket.
  A CSS scroll timeline progressively enhances the progress bar. One passive,
  requestAnimationFrame-batched scroll update supplies cross-browser effects.
- Reduced-motion preferences and short landscape screens use normal flow with
  every message visible. Individual chapters unpin if their content is taller
  than the viewport (small devices, zoom or larger fonts).
- Resizing / orientation changes retain the reader's chapter. Safe-area insets,
  dynamic viewport height, 44px+ controls, and hover-independent actions are used.
- On older browsers without native dialogs, an inert/ARIA background and a
  keyboard focus trap supply a fallback. Without Shadow DOM, the site fails open.
- All imagery is from the supplied campaign artwork; illustrations are not
  presented as photographs of an event that has already happened.

## Content and visual references

Registration details are taken from the repository's **`27form.html`**:
Batch 2027; minimum deposit **399 TK**; online bKash or offline cash; sign in /
create an account; committee verification activates the pass. No event date,
registration deadline, or unconfirmed extra entertainment has been invented.

Drive reference: **27 Form → Post 1**:
<https://drive.google.com/drive/folders/1soYYIwhEOqttvhvCX6MaxPbKZUjiLg41>

- *Vintage Bengali school anniversary poster-2.png* — campaign mark and palette.
- *Our Field, Our Sixty-3.png* — signing illustration, legacy message and the
  announcement of official permission.
- *Sign Day coverage crew-4.png* — two cinematographers, one photographer,
  one drone operator.
- *NGHS 60th Sign Day shirt reveal-5.png* — T-shirt concept; B60 illustration
  credited in the slide to **@XIHIMU** and credited in the intro's caption.
- *Our legacy, our part-6.png* — deposit and participation information.
- *NGHS 60th Sign Day finale-8.png* — “NGHSIANS of sixty”, “You will make it
  happen”, the 399 TK deposit, and the registration destination. This is also
  the existing `signday-poster.jpg` artwork used by the form.
- Existing `hero27-bg.jpg` and `hero27-people.png` supply the opening's smoke /
  crowd. The small, subtle paper grain is generated locally, not a large image.

Anton, DM Sans and Caveat are self-hosted under intro-specific font-family names.
Their SIL Open Font License files are included in `assets/nghs-60th-intro/fonts/`.

## Checks

Run the zero-dependency integration checks from the repository root:

```sh
node --test tests/nghs-60th-intro.test.cjs
node --check assets/nghs-60th-intro/intro.js
python -m http.server 8000 --bind 0.0.0.0
```

Browser regression checklist: desktop / tablet / phone and landscape widths;
first and final actions; skipping each chapter; wheel, touch and keyboard;
focus containment; Escape; reduced motion; rotation; direct anchor links;
blocked JS / CSS / image requests; dialog fallback; and returning from the form.
Check that the original homepage remains interactive and scrollable after skip,
and that the `#newsPopup` registration announcement still appears — both after
**Proceed to NGHSIANS** / Escape and on direct anchor links such as `/#news`.
