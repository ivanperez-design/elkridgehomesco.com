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
    /* Carry the click to the form pages (A3, 2026-09-09). Internal hrefs are bare relative
       paths, so localStorage was the ONLY carrier across a navigation — and it is unavailable
       under Safari "Block All Cookies"/Lockdown Mode and is capped at 7 days of browser use by
       ITP. Decorating only the six form destinations keeps the rest of the site's URLs clean. */
    var FORM_PAGES = ['contact.html','custom-homes.html','whole-home-remodel-steamboat-springs.html',
                      'large-remodel-steamboat-springs.html','new-home-builder-steamboat-springs.html',
                      'carpentry-steamboat-springs.html'];
    var carry = {};
    KEYS.forEach(function(k){ var v = fromUrl[k] || stored[k]; if (v) carry[k] = v; });
    if (Object.keys(carry).length) {
      document.querySelectorAll('a[href]').forEach(function(a){
        var href = a.getAttribute('href') || '';
        if (!FORM_PAGES.some(function(p){ return href.indexOf(p) === 0 || href.indexOf('/' + p) === 0; })) return;
        try {
          var u = new URL(a.href, location.href);
          if (u.origin !== location.origin) return;
          Object.keys(carry).forEach(function(k){ if (!u.searchParams.get(k)) u.searchParams.set(k, carry[k]); });
          a.setAttribute('href', u.pathname + u.search + u.hash);
        } catch(e){}
      });
    }
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
  /* ?sent=1 return. Two problems fixed here (A3 failure simulation, 2026-09-09):
     (1) the note stated a promise no clock backs — the campaign now serves Mon–Sun 06:00–21:00
         while Ivan answers the phone Mon–Fri 07:00–17:00 (SOP-Ad-Lead-Response §1);
     (2) erh_form_sent fired on EVERY load carrying ?sent=1 — a refresh, a forward-nav or a
         shared link each booked another conversion. Guarded with sessionStorage, then the
         parameter is stripped from the address bar so a reload cannot repeat it. */
  var q = new URLSearchParams(location.search);
  if (q.get('sent') === '1') {
    var n = document.getElementById('form-note');
    if (n) { n.textContent = 'Got it — your request is in. Monday through Friday, 7am to 8pm Mountain time, I reply within the hour. Evenings after 8pm and weekends, you will hear from me by 7:15 the next weekday morning. Sooner: call or text 970-393-6239.'; }
    var key = 'erh_form_sent:' + location.pathname, fired = false;
    try { fired = sessionStorage.getItem(key) === '1'; } catch(e){}
    if (!fired) {
      try { sessionStorage.setItem(key, '1'); } catch(e){}
      if (window.dataLayer) window.dataLayer.push({event: 'erh_form_sent'});
      if (window.gtag) window.gtag('event', 'erh_form_sent', {page_path: location.pathname});
    }
    try {
      q.delete('sent');
      var qs = q.toString();
      history.replaceState(null, '', location.pathname + (qs ? '?' + qs : '') + location.hash);
    } catch(e){}
  }
})();
