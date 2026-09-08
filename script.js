/* Elk Ridge Home — Site v8 shared behavior (matches the approved mockup) */
(function(){
  var reduce = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
  var hdr = document.getElementById('hdr');
  if (hdr) {
    var onScroll = function(){ hdr.classList.toggle('solid', window.scrollY > 60); };
    onScroll(); addEventListener('scroll', onScroll, {passive:true});
  }
  var mb = document.getElementById('menuBtn'), dr = document.getElementById('drawer');
  if (mb && dr) {
    mb.addEventListener('click', function(){ var o = dr.classList.toggle('open'); mb.setAttribute('aria-expanded', o); });
    dr.querySelectorAll('a').forEach(function(a){ a.addEventListener('click', function(){ dr.classList.remove('open'); mb.setAttribute('aria-expanded', false); }); });
  }
  var obs = document.querySelectorAll('.reveal, .tl');
  if (reduce || !('IntersectionObserver' in window)) { obs.forEach(function(e){ e.classList.add('in'); }); }
  else {
    var io = new IntersectionObserver(function(en){ en.forEach(function(x){ if (x.isIntersecting) { x.target.classList.add('in'); io.unobserve(x.target); } }); }, {threshold:.12, rootMargin:'0px 0px -7% 0px'});
    obs.forEach(function(e){ io.observe(e); });
  }
  /* Conversion events: every tel/sms/mailto link carries data-evt="call|text|email".
     Pushes to GA4/GTM when present; harmless no-op otherwise. Wire-up: runbook §4.5. */
  document.addEventListener('click', function(e){
    var a = e.target.closest ? e.target.closest('[data-evt]') : null;
    if (!a) return;
    var evt = 'erh_' + a.getAttribute('data-evt');
    if (window.dataLayer) window.dataLayer.push({event: evt, page: location.pathname});
    if (window.gtag) window.gtag('event', evt, {page_path: location.pathname});
  });
})();
/* Attribution passthrough (site PR-1, 2026-09-08 — Google Ads plan §5.4). On every page load,
   read the Google click IDs (gclid / wbraid / gbraid) and utm_* from the URL, persist them in
   localStorage ('erh_attrib', 90-day TTL) so a visitor who lands on a service page and opens
   /contact later still carries the click, then fill the matching hidden form inputs —
   URL value first, stored value second. A new non-empty value overwrites the stored one; a
   param-less page view never erases a stored click. No external libraries. */
(function(){
  try {
    if (!('URLSearchParams' in window)) return;
    var KEYS = ['gclid','wbraid','gbraid','utm_source','utm_medium','utm_campaign','utm_content','utm_term'];
    var STORE = 'erh_attrib', TTL = 90 * 864e5, now = Date.now();
    var q = new URLSearchParams(location.search), fromUrl = {}, any = false;
    KEYS.forEach(function(k){ var v = q.get(k); if (v) { fromUrl[k] = v; any = true; } });
    var stored = {};
    try {
      var o = JSON.parse(localStorage.getItem(STORE) || 'null');
      if (o && o.ts && now - Date.parse(o.ts) <= TTL) stored = o;
    } catch(e){}
    if (any) {
      var next = {};
      KEYS.forEach(function(k){ if (stored[k]) next[k] = stored[k]; });
      KEYS.forEach(function(k){ if (fromUrl[k]) next[k] = fromUrl[k]; });
      next.landing = location.pathname;
      next.ts = new Date(now).toISOString();
      stored = next;
      try { localStorage.setItem(STORE, JSON.stringify(next)); } catch(e){}
    }
    KEYS.concat('landing').forEach(function(k){
      var v = fromUrl[k] || stored[k] || '';
      if (!v) return;
      document.querySelectorAll('input[type="hidden"][name="' + k + '"]').forEach(function(el){ el.value = v; });
    });
  } catch(e){}
})();

/* Real form: FormSubmit posts to the monitored inbox. Analytics fire on submit;
   ?sent=1 (the _next redirect) shows the confirmation note. */
(function(){
  var f = document.getElementById('walkthrough-form');
  if (f) f.addEventListener('submit', function(){
    if (window.dataLayer) window.dataLayer.push({event: 'erh_form', page: location.pathname});
    if (window.gtag) window.gtag('event', 'erh_form', {page_path: location.pathname});
  });
  if (new URLSearchParams(location.search).get('sent') === '1') {
    var n = document.getElementById('form-note');
    if (n) { n.textContent = 'Got it — your walkthrough request is in. We reply the same business day (Mon–Sat). Sooner: call or text 970-393-6239.'; }
    if (window.dataLayer) window.dataLayer.push({event: 'erh_form_sent'});
    if (window.gtag) window.gtag('event', 'erh_form_sent', {page_path: location.pathname});
  }
})();
