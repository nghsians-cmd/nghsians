/* ============================================================================
   NGHSIANS — "NEW UI" shared behaviour
   ----------------------------------------------------------------------------
   Loaded with `defer` on every page except 27form.html / 27rep.html.
   Only adds behaviour — it never removes or overrides page logic.
   ============================================================================ */
(function () {
  'use strict';

  /* feature-detect everything: the UI must never take a page down */
  var mq = function (q) {
    try { return window.matchMedia ? window.matchMedia(q).matches : false; }
    catch (e) { return false; }
  };
  var reduceMotion = mq('(prefers-reduced-motion: reduce)');
  var finePointer  = mq('(hover: hover) and (pointer: fine)');

  /* ------------------------------------------------------------------------
     1 · Ambient glow field
     ------------------------------------------------------------------------ */
  function mountAmbient() {
    if (document.querySelector('.nghs-ambient')) return;
    var el = document.createElement('div');
    el.className = 'nghs-ambient';
    el.setAttribute('aria-hidden', 'true');
    document.body.insertBefore(el, document.body.firstChild);
  }

  /* ------------------------------------------------------------------------
     2 · Header state
     ------------------------------------------------------------------------ */
  function headerState() {
    var h = document.getElementById('siteHeader');
    if (!h) return;
    var update = function () {
      if (window.scrollY > 10) h.classList.add('is-stuck');
      else h.classList.remove('is-stuck');
    };
    window.addEventListener('scroll', update, { passive: true });
    update();
  }

  /* ------------------------------------------------------------------------
     3 · Click ripple + press feedback
     ------------------------------------------------------------------------ */
  var RIPPLE_SELECTOR = [
    'header .nav-link',
    '#mobileMenu .nav-link',
    '.menu-toggle',
    '.user-icon-btn',
    '.dropdown-item',
    '.btn',
    '.btn-action',
    '.btn-edit',
    '.btn-save',
    '.btn-cancel',
    '.sd-btn',
    '.back-link',
    '.social-icon-link',
    '.hero-socials a',
    '.play-button',
    '.skip-link'
  ].join(',');

  function rippleFor(el, x, y) {
    var r = document.createElement('span');
    r.className = 'nghs-ripple';
    var rect = el.getBoundingClientRect();
    var size = Math.max(rect.width, rect.height) * 1.15;
    r.style.width = r.style.height = size + 'px';
    r.style.left = (x - rect.left) + 'px';
    r.style.top = (y - rect.top) + 'px';
    el.appendChild(r);
    window.setTimeout(function () { if (r.parentNode) r.parentNode.removeChild(r); }, 700);
  }

  function enableRipples() {
    document.addEventListener('pointerdown', function (e) {
      if (e.button !== undefined && e.button !== 0) return;
      var el = e.target.closest ? e.target.closest(RIPPLE_SELECTOR) : null;
      if (!el) return;
      if (getComputedStyle(el).position === 'static') el.style.position = 'relative';
      if (getComputedStyle(el).overflow !== 'hidden') el.style.overflow = 'hidden';
      rippleFor(el, e.clientX, e.clientY);
    }, { passive: true });
  }

  function enablePress() {
    var sel = '.btn, .btn-action, .sd-btn, .pill, .status-badge, .result-board-chip, .play-button';
    document.querySelectorAll(sel).forEach(function (el) { el.classList.add('nghs-press'); });
  }

  /* ------------------------------------------------------------------------
     4 · Scroll reveal (pages that don't ship their own)
     ------------------------------------------------------------------------ */
  var REVEAL_SELECTOR = [
    '.video-card', '.archive-card', '.featured-card', '.product-card',
    '.batch-showcase', '.nghs-reveal'
  ].join(',');

  function enableReveal() {
    var nodes = document.querySelectorAll(REVEAL_SELECTOR);
    if (!nodes.length) return;
    if (reduceMotion || !('IntersectionObserver' in window)) {
      nodes.forEach(function (n) { n.classList.add('is-visible'); });
      return;
    }
    /* only animate what starts below the fold — anything already on screen
       must never be left at opacity 0 */
    var fold = window.innerHeight || 800;
    var pending = [];
    nodes.forEach(function (n) {
      if (n.getBoundingClientRect().top < fold * 0.92) return;
      n.classList.add('nghs-reveal');
      pending.push(n);
    });
    if (!pending.length) return;
    nodes = pending;
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        e.target.classList.add('is-visible');
        io.unobserve(e.target);
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    nodes.forEach(function (n) { io.observe(n); });
  }

  /* ------------------------------------------------------------------------
     5 · Pointer-follow glow + subtle 3D tilt on cards (desktop only)
     ------------------------------------------------------------------------ */
  var TILT_SELECTOR = [
    '.stat-card', '.rank-card', '.news-small-card', '.alumni-card',
    '.product-card', '.featured-card', '.archive-card', '.video-card',
    '.result-preview-card', '.result-feature-card', '.topper-card'
  ].join(',');

  function enableTilt() {
    if (!finePointer || reduceMotion) return;
    var MAX = 5; /* degrees */
    document.querySelectorAll(TILT_SELECTOR).forEach(function (card) {
      var raf = null;
      function move(e) {
        if (raf) cancelAnimationFrame(raf);
        raf = requestAnimationFrame(function () {
          var r = card.getBoundingClientRect();
          var px = (e.clientX - r.left) / r.width;
          var py = (e.clientY - r.top) / r.height;
          card.style.transform =
            'perspective(900px) translateY(-6px) rotateX(' + ((0.5 - py) * MAX).toFixed(2) +
            'deg) rotateY(' + ((px - 0.5) * MAX).toFixed(2) + 'deg)';
          card.style.setProperty('--mx', (px * 100).toFixed(1) + '%');
          card.style.setProperty('--my', (py * 100).toFixed(1) + '%');
        });
      }
      function reset() {
        if (raf) cancelAnimationFrame(raf);
        card.style.transform = '';
      }
      card.addEventListener('pointermove', move);
      card.addEventListener('pointerleave', reset);
    });
  }

  /* ------------------------------------------------------------------------
     6 · Menu consistency
        • every nav link carries the same classes/attributes
        • the link pointing at the current page is the active one
        • the mobile sheet closes when a link is tapped
     ------------------------------------------------------------------------ */
  function normaliseMenu() {
    var links = document.querySelectorAll('header .nav-link');
    if (!links.length) return;

    var here = (location.pathname.split('/').pop() || 'index.html').toLowerCase();

    links.forEach(function (a) {
      a.classList.add('nghs-nav-item');
      if (!a.hasAttribute('data-nghs-ripple')) a.setAttribute('data-nghs-ripple', '');

      var href = (a.getAttribute('href') || '').toLowerCase();
      var isPage = /\.html/.test(href.split('#')[0]);
      if (!isPage) return;                       /* section links: leave to the page's own scroll-spy */

      var file = href.split('#')[0].split('/').pop();
      var isIndex = (file === 'index.html' || file === '' || file === 'nghsians.com');
      var match = isIndex ? (here === 'index.html' || here === '') : (file === here);

      if (match) {
        links.forEach(function (o) { if (o !== a) o.classList.remove('active'); });
        a.classList.add('active');
        a.setAttribute('aria-current', 'page');
      } else {
        a.removeAttribute('aria-current');
      }
    });

    /* keep the mobile sheet in sync and make sure a tap always closes it */
    document.addEventListener('click', function (e) {
      var link = e.target.closest ? e.target.closest('#mobileMenu .nav-link') : null;
      if (!link) return;
      var menu = document.getElementById('mobileMenu');
      var btn = document.getElementById('menuToggle');
      if (menu && menu.classList.contains('open')) {
        window.setTimeout(function () {
          menu.classList.remove('open');
          menu.setAttribute('aria-hidden', 'true');
          if (btn) btn.setAttribute('aria-expanded', 'false');
          document.body.style.overflow = '';
        }, 90);
      }
    });
  }

  /* ------------------------------------------------------------------------
     7 · Keep the mobile sheet's cloned links styled
     ------------------------------------------------------------------------ */
  function syncMobileClasses() {
    var menu = document.getElementById('mobileMenu');
    if (!menu) return;
    var mo = new MutationObserver(function () {
      menu.querySelectorAll('.nav-link').forEach(function (a) {
        a.classList.add('nghs-nav-item');
      });
    });
    mo.observe(menu, { childList: true, subtree: true });
  }

  /* ------------------------------------------------------------------------
     8 · Brand mark must always be a working "home" link
        Most pages use <a href="index.html">. index.html uses a <div> whose
        own handler scrolls back to the hero. This only catches the case
        where a page renders the logo with no href and no handler at all.
     ------------------------------------------------------------------------ */
  function brandHome() {
    var brand = document.getElementById('brandBtn');
    if (!brand) return;

    var here = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
    var isHome = (here === 'index.html' || here === '' || here === 'nghsians.com');

    /* already a real link — nothing to do */
    if (brand.tagName === 'A' && brand.getAttribute('href')) {
      if (!brand.getAttribute('aria-label')) brand.setAttribute('aria-label', 'Home');
      return;
    }
    /* on the home page the logo means "back to top", handled by that page */
    if (isHome) return;

    brand.setAttribute('role', 'link');
    brand.setAttribute('tabindex', '0');
    brand.setAttribute('aria-label', 'Home');
    brand.style.cursor = 'pointer';

    var go = function (e) {
      if (e.type === 'keydown' && e.key !== 'Enter' && e.key !== ' ') return;
      e.preventDefault();
      window.location.href = 'index.html';
    };
    brand.addEventListener('click', go);
    brand.addEventListener('keydown', go);
  }

  /* ------------------------------------------------------------------------
     boot
     ------------------------------------------------------------------------ */
  function boot() {
    mountAmbient();
    headerState();
    enableRipples();
    enablePress();
    enableReveal();
    enableTilt();
    normaliseMenu();
    syncMobileClasses();
    brandHome();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
