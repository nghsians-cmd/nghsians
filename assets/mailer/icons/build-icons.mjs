/* ============================================================================
   NGHSIANS — e-mail footer icon exporter
   ----------------------------------------------------------------------------
   The newsletter footer's social icons are real vector artwork (the .svg files
   next to this script). Email clients are the problem: Gmail, Outlook and most
   Android apps strip SVG, so the *sent* e-mail links the PNG exports instead.

   This script turns every .svg in this folder into the two PNG exports the
   mailer uses, transparent background, 4× the 20px display size:

     <name>-on-light.png   dark artwork  — for a light chip (light footer text)
     <name>-on-dark.png    light artwork — for a dark chip (dark footer text)

   mailer.html picks the right one from the footer-text colour's luminance, so
   the icons always stay legible whatever palette the committee picks.

   It also mirrors the footer crest: ../footer-logo.png is a white monochrome
   mark that disappears on a light footer, so it is recoloured to ink and
   written next to it as ../footer-logo-on-light.png. The mailer picks between
   the two from the footer background's luminance.

   Usage (rarely needed — the PNGs are committed):
     npm install sharp && node assets/mailer/icons/build-icons.mjs
   Artwork: Lucide (ISC licence) — https://lucide.dev
   ============================================================================ */
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const HERE = dirname(fileURLToPath(import.meta.url));
const SIZE = 80;                                   // 4 × the 20px e-mail size
const VARIANTS = {
  'on-light': '#14110d',                           // ink   — for cream chips
  'on-dark':  '#f2ebd9'                            // cream — for dark chips
};

let sharp;
try {
  ({ default: sharp } = await import('sharp'));
} catch {
  try { ({ default: sharp } = await import(createRequire(import.meta.url)('sharp'))); }
  catch {
    console.error('\n  sharp is not installed. Run:\n\n    npm install sharp\n\n  then re-run this script.\n');
    process.exit(1);
  }
}

const files = (await readdir(HERE)).filter(f => f.endsWith('.svg')).sort();
if (!files.length) { console.error('No .svg sources found in ' + HERE); process.exit(1); }

const rows = [];
for (const file of files) {
  const name = basename(file, '.svg');
  const source = await readFile(join(HERE, file), 'utf8');
  const body = source.replace(/<!--[\s\S]*?-->/g, '');   // drop the licence notes
  for (const [variant, colour] of Object.entries(VARIANTS)) {
    const svg = body
      .replace(/currentColor/g, colour)
      .replace(/width="[\d.]+"/, `width="${SIZE}"`)
      .replace(/height="[\d.]+"/, `height="${SIZE}"`);
    const out = join(HERE, `${name}-${variant}.png`);
    await sharp(Buffer.from(svg), { density: 72 })
      .png({ compressionLevel: 9, adaptiveFiltering: true })
      .toFile(out);
    const { size } = await import('node:fs').then(fs => fs.promises.stat(out));
    rows.push([`${name}-${variant}.png`, `${size} bytes`]);
  }
}
console.log(`Wrote ${rows.length} PNGs at ${SIZE}×${SIZE} (display size 20×20):`);
for (const [name, size] of rows) console.log(`  ${name.padEnd(26)} ${size}`);

/* ---- the footer crest, mirrored for light footers ------------------------ */
const crestSrc = join(HERE, '..', 'footer-logo.png');
const crestOut = join(HERE, '..', 'footer-logo-on-light.png');
const INK = { r: 0x14, g: 0x11, b: 0x0d };
{
  // The mark is pure white on transparency: recolour the RGB and keep alpha,
  // so the ink version is the same artwork with the same antialiased edges.
  const { data, info } = await sharp(crestSrc).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  for (let i = 0; i < data.length; i += info.channels) {
    const a = data[i + 3];
    if (!a) continue;
    data[i] = INK.r; data[i + 1] = INK.g; data[i + 2] = INK.b;
  }
  // Full RGBA rather than a palette: palette PNG stores alpha per palette
  // entry, which the older mail clients that need this fallback handle badly.
  await sharp(data, { raw: { width: info.width, height: info.height, channels: info.channels } })
    .png({ compressionLevel: 9 })
    .toFile(crestOut);
  const { size } = await import('node:fs').then(fs => fs.promises.stat(crestOut));
  console.log(`\nWrote ../footer-logo-on-light.png (ink crest for light footers) — ${size} bytes`);
}
