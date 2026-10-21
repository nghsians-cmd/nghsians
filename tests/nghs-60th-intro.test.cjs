/* TEMPORARY — NGHS 60th Intro: dependency-free integration / removal checks.
   Real scrolling, focus, touch and layout are additionally browser-tested. */
'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const home = read('index.html');
const js = read('assets/nghs-60th-intro/intro.js');
const css = read('assets/nghs-60th-intro/intro.css');
const entry = read('assets/nghs-60th-intro/entry.css');

const removeIntroHooks = (html) => html
  .replace(/<!-- =+\s*TEMPORARY — NGHS 60th Intro \/ NGHS 60th Sign Day Intro — START[\s\S]*?<!-- TEMPORARY — NGHS 60th Intro — END -->\n\n/, '');

// The registration popup's own implementation, exactly as the homepage ships it.
const newsPopup = home.match(/\(function initNewsPopup\(\) \{[\s\S]*?\n  \}\)\(\);/);

test('only the homepage loads the temporary module', () => {
  for (const file of fs.readdirSync(root).filter((name) => name.endsWith('.html'))) {
    assert.equal(read(file).includes('assets/nghs-60th-intro/intro.js'), file === 'index.html', file);
  }
});

test('marked hooks are removable without removing original site content', () => {
  const removed = removeIntroHooks(home);
  assert.ok(!removed.includes('nghs-60th-intro'));
  for (const id of ['main', 'hero27', 'home', 'about', 'news', 'gallery', 'contact', 'siteHeader', 'newsPopup']) {
    assert.ok(removed.includes(`id="${id}"`), `Original #${id} is retained`);
  }
  assert.ok(removed.includes("const key='nghsians-signday-27-registration-2026-10-09'"));
});

test('the registration popup always shows: the intro never suppresses it', () => {
  assert.ok(newsPopup, 'initNewsPopup is still present on the homepage');
  // The popup's own implementation carries no temporary intro code at all.
  assert.doesNotMatch(newsPopup[0], /nghs-60th-intro|TEMPORARY/i);
  // It still fires on its original 1.5s timer, with its original session key.
  assert.match(newsPopup[0], /if\(!seen\)setTimeout\(\(\)=>\{[\s\S]*?\},1500\);/);
  assert.match(newsPopup[0], /if\(document\.hidden\)return;\s*\n\s*previousFocus=document\.activeElement;/);
  assert.match(newsPopup[0], /popup\.classList\.add\('show'\)/);
  // The intro never dismisses or hides the popup; it may only read it to hand
  // focus back once the visitor leaves the intro.
  assert.doesNotMatch(js, /closeNewsPopup/);
  assert.doesNotMatch(js, /classList\.(?:remove|toggle)\(['"]show['"]\)/);
  assert.doesNotMatch(js, /popup\.(?:hidden|inert)\s*=/);
  assert.doesNotMatch(js, /popup\.setAttribute/);
  assert.match(js, /popup\.classList\.contains\('show'\)/);
  // The no-native-dialog fallback must not restore a stale hidden / inert
  // snapshot over the popup once it has opened behind the intro.
  assert.match(js, /if \(element\.id === 'newsPopup' && element\.classList\.contains\('show'\)\) return;/);
});

test('registration and the two skip actions are explicit native controls', () => {
  assert.match(js, /<a class="action action-primary" href="27form\.html">Register/);
  assert.equal((js.match(/data-proceed>Proceed to NGHSIANS/g) || []).length, 2);
  assert.match(js, /<p class="deposit">399 <span>TK<\/span>/);
  assert.match(js, /if \(location\.hash\) return|\|\| location\.hash/);
  assert.match(js, /event\.key === 'Escape'/);
  assert.match(js, /function proceed\(/);
  assert.match(js, /page\.removeAttribute\(opened\)/);
});

test('the temporary code parses, stays isolated, and never calls auth / storage', () => {
  assert.doesNotThrow(() => new vm.Script(js));
  assert.match(js, /attachShadow\(\{ mode: 'open' \}\)/);
  assert.match(js, /dialog\.showModal\(\)/);
  assert.ok(!/\b(?:fetch|createClient)\s*\(|\b(?:localStorage|sessionStorage)\b/.test(js));
  assert.ok(!/https?:\/\//.test(js + css + entry));
  assert.ok(!/addEventListener\(['"](?:wheel|touchmove)['"]/.test(js));
});

test('loading, motion and accessibility fallbacks are retained', () => {
  assert.match(home, /root\.removeAttribute\('data-nghs-60th-intro-pending'\);\s*\}, 5000\)/);
  assert.match(js, /stylesheet\.addEventListener\('error', failOpen/);
  assert.match(js, /prefers-reduced-motion: reduce/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(js, /data-static/);
  assert.match(js, /aria-modal/);
  assert.match(css, /focus-visible/);
  assert.match(css, /safe-area-inset/);
  assert.match(js, /passive: true/);
});

test('every referenced local illustration / font exists and assets stay small', () => {
  const referenced = [
    ...Array.from(js.matchAll(/asset\('([^']+)'\)/g), (m) => m[1].split('?')[0]),
    ...Array.from((css + entry).matchAll(/url\("([^"]+)"\)/g), (m) => m[1])
  ];
  let bytes = 0;
  for (const file of new Set(referenced)) {
    const stat = fs.statSync(path.join(root, 'assets/nghs-60th-intro', file));
    assert.ok(stat.isFile() && stat.size > 0, file);
    bytes += stat.size;
  }
  assert.ok(bytes < 1_000_000, `Local assets are ${bytes} bytes, expected under 1 MB`);
  for (const font of ['ANTON', 'DM-SANS', 'CAVEAT']) {
    assert.match(read(`assets/nghs-60th-intro/fonts/${font}-OFL.txt`), /SIL OPEN FONT LICENSE/);
  }
});
