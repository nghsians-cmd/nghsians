/* ============================================================================
   TEMPORARY — NGHS 60th Intro / NGHS 60th Sign Day Intro
   A removable, isolated layer ABOVE the existing NGHSIANS homepage.
   Search for "NGHS 60th Intro" or see NGHS-60TH-INTRO.md to remove it.
   No framework, third-party requests, cookies, or changes to registration/auth.
   ============================================================================ */
(function () {
  'use strict';

  const page = document.documentElement;
  const pending = 'data-nghs-60th-intro-pending';
  const opened = 'data-nghs-60th-intro-open';
  // The early bootstrap deliberately excludes direct homepage anchor links.
  // Never open late, after its fail-open timeout has revealed the real site.
  if (!page.hasAttribute(pending) || location.hash || document.querySelector('nghs-60th-intro')) return;

  const base = new URL('.', document.currentScript.src);
  const asset = (name) => new URL(name, base).href;
  const arrow = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>';
  const down = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><path d="M12 4v16m-6-6 6 6 6-6"/></svg>';
  const explore = (index, text) => `<button class="explore" type="button" data-chapter-link="${index}"><span class="explore-icon">${down}</span>${text}</button>`;
  const chapterNames = ['Our sixty', 'Our field', 'Our stories', 'Wear the memory', 'Be part of it'];
  const host = document.createElement('nghs-60th-intro');
  host.id = 'nghs-60th-intro';
  host.setAttribute('data-temporary-section', 'NGHS 60th Intro');
  // Unsupported browsers simply keep the original site. Nothing is hidden.
  if (!host.attachShadow) { page.removeAttribute(pending); return; }
  const shadow = host.attachShadow({ mode: 'open' });
  shadow.innerHTML = `
    <dialog class="intro" data-theme="paper" data-motion="reduced" aria-labelledby="nghs60-title" aria-describedby="nghs60-description">
      <nav class="intro-navigation" aria-label="Sign Day introduction">
        <div class="navigation-inner">
          <div class="brand">
            <svg class="brand-mark" viewBox="0 0 40 40" fill="none" stroke="currentColor" aria-hidden="true">
              <path d="M4 12Q20 2 36 12M7 12v22h5V16h16v18h5V12M4 35h32" stroke-width="1.7"/>
              <path d="M12 12h16M16 21h8M16 25h8M16 29h8" stroke-width="1.2"/>
            </svg>
            <div class="brand-copy">NGHSIANS<small>60TH SIGN DAY</small></div>
            <span class="chapter-counter" aria-hidden="true">01 / 05</span>
          </div>
          <button class="skip" type="button" data-proceed>Proceed to NGHSIANS ${arrow}</button>
        </div>
      </nav>

      <div class="intro-scroll" tabindex="0" role="region" aria-label="NGHS 60th Intro. Scroll to explore; Escape skips to NGHSIANS.">
        <div class="story">
          <section class="chapter opening" data-theme="paper" aria-labelledby="nghs60-title">
            <div class="stage paper">
              <div class="opening-composition">
                <div class="opening-copy">
                  <p class="eyebrow red">NGHS 60th Sign Day · Batch 2027</p>
                  <h1 class="display" id="nghs60-title"><span>This is</span><span class="red">our sixty.</span></h1>
                  <p class="copy" id="nghs60-description">A day for the signatures.<br>A lifetime for the memories.</p>
                </div>
                <figure class="hero-artwork">
                  <img src="${asset('sign-day-mark.webp')}" width="682" height="546" alt="NGHS 60th Sign Day official campaign artwork" fetchpriority="high" decoding="async">
                  <figcaption>NASIRABAD GOVERNMENT HIGH SCHOOL</figcaption>
                  <span class="hand" aria-hidden="true">The chapter is ours.</span>
                </figure>
              </div>
              <img class="hero-crowd" src="${asset('crowd.webp')}" width="1376" height="263" alt="" aria-hidden="true" decoding="async">
              <div class="opening-meta">
                <span>Nasirabad Government High School<br>Chattogram, Bangladesh</span>
                ${explore(1, 'Scroll to feel it')}
                <span>One school. One batch.<br>One unforgettable chapter.</span>
              </div>
            </div>
          </section>

          <section class="chapter field" data-theme="dark" aria-labelledby="nghs60-field">
            <div class="stage">
              <img class="field-image" src="${asset('our-field.webp')}" width="1092" height="366" alt="Campaign illustration of friends signing each other’s school shirts" decoding="async">
              <div class="permission-stamp" aria-label="Official permission granted, as announced in the Sign Day slides">Official<br>permission<br>granted<small>THE SIXTIETH CHAPTER</small></div>
              <div class="field-content">
                <p class="eyebrow">02 — A place that made us</p>
                <h2 class="display" id="nghs60-field">Our field.<br><span>Our sixty.</span></h2>
                <div class="field-bottom">
                  <p class="copy">Not just another day at school. A celebration of our batch, our legacy, and the memories we’ll carry long after the last bell.</p>
                  ${explore(2, 'Keep the memories')}
                </div>
              </div>
            </div>
          </section>

          <section class="chapter voices" data-theme="dark" aria-labelledby="nghs60-stories">
            <div class="stage">
              <div class="voices-grid">
                <div class="voices-heading">
                  <p class="eyebrow">03 — Made of all of us</p>
                  <h2 class="display" id="nghs60-stories">A shirt.<br>A thousand<br> stories.</h2>
                  <p class="copy">Some things don’t fit in a photograph.<br>So we carry them with us.</p>
                </div>
                <div class="messages" role="group" aria-label="The memories we share">
                  <p class="message">The last bench.</p>
                  <p class="message">The friends for life.</p>
                  <p class="message">Names on our shirts.</p>
                  <p class="message">Memories that stay.</p>
                  <p class="message">And all of us, together.</p>
                </div>
              </div>
              <div class="voices-next">${explore(3, 'The memory we’ll wear')}</div>
            </div>
          </section>

          <section class="chapter keepsake" data-theme="paper" aria-labelledby="nghs60-keepsake">
            <div class="stage paper">
              <div class="keepsake-grid">
                <div class="keepsake-copy">
                  <p class="eyebrow red">04 — More than a keepsake</p>
                  <h2 class="display" id="nghs60-keepsake">Wear the<br><span class="red">memory.</span></h2>
                  <p class="copy">The special Sign Day T-shirt.<br>Made to wear. Made to sign.<br>Made to remember.</p>
                </div>
                <figure class="shirt-figure">
                  <img src="${asset('shirt.webp')}" width="975" height="402" alt="Front and back of the cream NGHS 60th Sign Day T-shirt concept, with the Sign Day mark and B60 illustration" decoding="async">
                  <figcaption><span>THE SIGN DAY T-SHIRT CONCEPT</span><span>B60 ILLUSTRATION: @XIHIMU</span></figcaption>
                  <span class="hand" aria-hidden="true">Leave your mark.</span>
                </figure>
                <div class="coverage" role="group" aria-label="Professional event coverage announced in the Sign Day slides">
                  <p class="coverage-label">Every moment.<br>Documented.</p>
                  <div class="coverage-counts">
                    <div class="coverage-item"><strong>02</strong><span>Cinematographers</span></div>
                    <div class="coverage-item"><strong>01</strong><span>Photographer</span></div>
                    <div class="coverage-item"><strong>01</strong><span>Drone operator</span></div>
                  </div>
                </div>
              </div>
              <div class="keepsake-next">${explore(4, 'Be part of the chapter')}</div>
            </div>
          </section>

          <section class="chapter finale" data-theme="red" aria-labelledby="nghs60-finale">
            <div class="stage">
              <div class="finale-grid">
                <div>
                  <p class="eyebrow">05 — Your name belongs here</p>
                  <h2 class="display" id="nghs60-finale">It’s now.<br><span>Or never.</span></h2>
                  <p class="hand finale-tagline">You will make it happen.</p>
                </div>
                <div class="ticket">
                  <div class="ticket-top"><span>BATCH 2027</span><span class="registration-open">REGISTRATION OPEN</span></div>
                  <p class="deposit-label">Minimum deposit</p>
                  <p class="deposit">399 <span>TK</span></p>
                  <p class="copy">Per Batch 2027 student.<br>Pay online via bKash or offline in cash.</p>
                  <div class="ticket-actions">
                    <a class="action action-primary" href="27form.html">Register ${arrow}</a>
                    <button class="action action-secondary" type="button" data-proceed>Proceed to NGHSIANS ${arrow}</button>
                  </div>
                  <p class="ticket-note">Account, payment details &amp; pass verification on the registration page.</p>
                </div>
              </div>
              <div class="finale-footer"><span>Nasirabad Government High School · Chattogram</span><span>NGHSIANS OF SIXTY.</span></div>
            </div>
          </section>
        </div>
      </div>

      <nav class="chapter-navigation" aria-label="Introduction chapters">
        ${chapterNames.map((name, index) => `<button class="chapter-dot" type="button" data-chapter-link="${index}" aria-label="Chapter ${index + 1}: ${name}"${index === 0 ? ' aria-current="step"' : ''}><span class="chapter-dot-label">0${index + 1} — ${name}</span></button>`).join('')}
      </nav>
      <div class="reading-progress" aria-hidden="true"></div>
    </dialog>`;

  const dialog = shadow.querySelector('.intro');
  const scroller = shadow.querySelector('.intro-scroll');
  const chapters = Array.from(shadow.querySelectorAll('.chapter'));
  const dots = Array.from(shadow.querySelectorAll('.chapter-dot'));
  const messages = Array.from(shadow.querySelectorAll('.message'));
  const counter = shadow.querySelector('.chapter-counter');
  const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
  const cleanup = [];
  const fallbackBackground = [];
  let active = false;
  let frame = 0;
  let bounds = [];
  let viewport = 0;
  let current = -1;
  let resizeObserver;
  let savedFocus;
  let loadTimeout;
  let removePageLock = false;
  const clamp = (value) => Math.max(0, Math.min(1, value));
  const listen = (target, event, fn, options) => {
    target.addEventListener(event, fn, options);
    cleanup.push(() => target.removeEventListener(event, fn, options));
  };

  function failOpen() {
    clearTimeout(loadTimeout);
    page.removeAttribute(pending);
    if (removePageLock) page.removeAttribute(opened);
    if (frame) cancelAnimationFrame(frame);
    if (resizeObserver) resizeObserver.disconnect();
    cleanup.splice(0).forEach((fn) => fn());
    host.remove();
  }

  function proceed() {
    if (!active) return;
    active = false;
    if (frame) cancelAnimationFrame(frame);
    if (resizeObserver) resizeObserver.disconnect();
    cleanup.splice(0).forEach((fn) => fn());
    if (typeof dialog.close === 'function' && dialog.open) dialog.close();
    else dialog.removeAttribute('open');
    // Keep the inert, hidden marker for the lifetime of this page, solely to
    // prevent the old registration popup from repeating the same announcement.
    host.hidden = true;
    page.removeAttribute(opened);
    fallbackBackground.forEach(({ element, inert, ariaHidden }) => {
      element.inert = inert;
      if (ariaHidden === null) element.removeAttribute('aria-hidden');
      else element.setAttribute('aria-hidden', ariaHidden);
    });
    const target = savedFocus && savedFocus !== document.body && savedFocus.isConnected && !savedFocus.closest('[inert]')
      ? savedFocus : document.getElementById('main');
    if (target) {
      const needsTabindex = !target.hasAttribute('tabindex') && !target.matches('a[href], button, input, select, textarea');
      if (needsTabindex) {
        target.setAttribute('tabindex', '-1');
        // Removing tabindex immediately can send focus back to <body>. Restore
        // the original markup after the visitor naturally leaves the landmark.
        target.addEventListener('blur', () => target.removeAttribute('tabindex'), { once: true });
      }
      target.focus({ preventScroll: true });
    }
  }

  function render() {
    frame = 0;
    if (!active || !viewport) return;
    const y = scroller.scrollTop;
    const total = Math.max(1, scroller.scrollHeight - viewport);
    dialog.style.setProperty('--progress', clamp(y / total).toFixed(5));
    let nextCurrent = 0;
    bounds.forEach((item, index) => {
      if (y + viewport * 0.36 >= item.top) nextCurrent = index;
      const enter = clamp((y + viewport - item.top) / viewport);
      const hold = clamp((y - item.top) / Math.max(1, item.height - viewport));
      const section = chapters[index];
      section.style.setProperty('--enter', enter.toFixed(4));
      section.style.setProperty('--curve', `${(220 - enter * 120).toFixed(2)}%`);
      section.style.setProperty('--image-scale', (1.18 - enter * 0.18).toFixed(4));
      section.style.setProperty('--rise', (1 - enter).toFixed(4));
      if (index === 0) section.style.setProperty('--out', clamp(y / (viewport * 0.95)).toFixed(4));
      if (index === 2) {
        section.style.setProperty('--away', clamp((y - (item.top + item.height - viewport)) / (viewport * 0.55)).toFixed(4));
        messages.forEach((message, n) => {
          const reveal = dialog.dataset.motion === 'reduced' || section.hasAttribute('data-static')
            ? 1 : clamp((hold + 0.15 - n * 0.17) / 0.14);
          message.style.setProperty('--reveal', reveal.toFixed(4));
        });
      }
    });
    if (nextCurrent !== current) {
      current = nextCurrent;
      dialog.dataset.theme = chapters[current].dataset.theme;
      counter.textContent = `0${current + 1} / 05`;
      dots.forEach((dot, index) => {
        if (index === current) dot.setAttribute('aria-current', 'step');
        else dot.removeAttribute('aria-current');
      });
    }
  }

  function scheduleRender() {
    if (!frame && active) frame = requestAnimationFrame(render);
  }

  function measure() {
    if (!active) return;
    const oldViewport = viewport;
    const oldBounds = bounds;
    const oldY = scroller.scrollTop;
    viewport = scroller.clientHeight;
    dialog.style.setProperty('--screen', `${viewport}px`);
    const fullMotion = !motionQuery.matches && viewport >= 600 && CSS.supports('position', 'sticky');
    dialog.dataset.motion = fullMotion ? 'full' : 'reduced';
    // Large fonts, browser zoom, and short devices must never clip a chapter.
    // Unpin only overflowing chapters, retaining motion where there is room.
    chapters.forEach((section) => section.removeAttribute('data-static'));
    if (fullMotion) {
      ['.voices-grid', '.keepsake-grid', '.finale-grid', '.field-content'].forEach((selector) => {
        const content = shadow.querySelector(selector);
        if (content.offsetHeight > viewport - 2) content.closest('.chapter').setAttribute('data-static', '');
      });
    }
    bounds = chapters.map((section) => ({ top: section.offsetTop, height: section.offsetHeight }));
    // Resizing / rotating keeps the reader in the same chapter, rather than
    // throwing them to the end as the pinned scroll distances change.
    if (oldViewport && oldBounds.length && Math.abs(oldViewport - viewport) > 2) {
      const index = Math.max(0, oldBounds.findLastIndex
        ? oldBounds.findLastIndex((item) => oldY >= item.top)
        : oldBounds.reduce((last, item, i) => oldY >= item.top ? i : last, 0));
      const fraction = clamp((oldY - oldBounds[index].top) / Math.max(1, oldBounds[index].height));
      scroller.scrollTop = bounds[index].top + fraction * bounds[index].height;
    }
    scheduleRender();
  }

  function goToChapter(index) {
    if (!active || !bounds[index]) return;
    scroller.scrollTo({ top: bounds[index].top, behavior: motionQuery.matches ? 'auto' : 'smooth' });
  }

  function start() {
    clearTimeout(loadTimeout);
    if (!page.hasAttribute(pending) || location.hash) { failOpen(); return; }
    try {
      savedFocus = document.activeElement;
      // If a slow stylesheet let the old popup appear first, dismiss it before
      // the native modal takes over. Its original implementation is unchanged.
      if (document.getElementById('newsPopup')?.classList.contains('show') && window.closeNewsPopup) window.closeNewsPopup();
      if (typeof dialog.showModal === 'function') dialog.showModal();
      else {
        dialog.setAttribute('open', '');
        dialog.setAttribute('data-fallback', '');
        dialog.setAttribute('role', 'dialog');
        dialog.setAttribute('aria-modal', 'true');
        Array.from(document.body.children).forEach((element) => {
          if (element === host || /^(SCRIPT|STYLE|LINK)$/.test(element.tagName)) return;
          fallbackBackground.push({ element, inert: element.inert, ariaHidden: element.getAttribute('aria-hidden') });
          element.inert = true;
          element.setAttribute('aria-hidden', 'true');
        });
      }
      active = true;
      host.setAttribute('data-intro-shown', '');
      page.setAttribute(opened, '');
      removePageLock = true;
      page.removeAttribute(pending);
      scroller.focus({ preventScroll: true });
      listen(scroller, 'scroll', scheduleRender, { passive: true });
      listen(window, 'resize', measure, { passive: true });
      listen(window, 'hashchange', proceed);
      listen(dialog, 'cancel', (event) => { event.preventDefault(); proceed(); });
      listen(dialog, 'close', proceed);
      listen(dialog, 'click', (event) => {
        const proceedButton = event.target.closest('[data-proceed]');
        const chapterButton = event.target.closest('[data-chapter-link]');
        if (proceedButton) proceed();
        else if (chapterButton) goToChapter(Number(chapterButton.dataset.chapterLink));
      });
      listen(dialog, 'keydown', (event) => {
        if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); proceed(); return; }
        // Explicit wrapping also covers native dialog traversal across a
        // Shadow DOM boundary at the end of the keyboard focus cycle.
        if (event.key !== 'Tab') return;
        const controls = Array.from(shadow.querySelectorAll('button, a[href], [tabindex="0"]')).filter((el) => el.getClientRects().length);
        const first = controls[0], last = controls[controls.length - 1];
        if (event.shiftKey && shadow.activeElement === first) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && shadow.activeElement === last) { event.preventDefault(); first.focus(); }
      });
      listen(dialog, 'focusin', (event) => {
        const section = event.target.closest('.chapter');
        if (section && chapters.indexOf(section) !== current) {
          scroller.scrollTop = section.offsetTop;
          scheduleRender();
        }
      });
      if (motionQuery.addEventListener) listen(motionQuery, 'change', measure);
      else {
        motionQuery.addListener(measure);
        cleanup.push(() => motionQuery.removeListener(measure));
      }
      if ('ResizeObserver' in window) {
        resizeObserver = new ResizeObserver(measure);
        resizeObserver.observe(scroller);
        ['.opening-composition', '.voices-grid', '.keepsake-grid', '.finale-grid'].forEach((selector) => resizeObserver.observe(shadow.querySelector(selector)));
      }
      if (document.fonts) document.fonts.ready.then(() => { if (active) measure(); });
      measure();
    } catch (error) {
      // A temporary event intro must never make the real website unusable.
      active = false;
      if (dialog.open && typeof dialog.close === 'function') dialog.close();
      fallbackBackground.forEach(({ element, inert, ariaHidden }) => {
        element.inert = inert;
        if (ariaHidden === null) element.removeAttribute('aria-hidden');
        else element.setAttribute('aria-hidden', ariaHidden);
      });
      failOpen();
      console.warn('NGHS 60th Intro could not open; the homepage is available.', error);
    }
  }

  const stylesheet = document.createElement('link');
  stylesheet.rel = 'stylesheet';
  stylesheet.href = asset('intro.css?v=1');
  stylesheet.addEventListener('load', start, { once: true });
  stylesheet.addEventListener('error', failOpen, { once: true });
  loadTimeout = setTimeout(failOpen, 4500);
  shadow.prepend(stylesheet);
  document.body.appendChild(host);
})();
