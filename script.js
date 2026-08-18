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
/* UTM passthrough — reads campaign params from the URL on load and fills the hidden
   form fields so attribution carries through. Inert until the Squarespace Form Block migration. */
(function(){
  if (!('URLSearchParams' in window)) return;
  var q = new URLSearchParams(location.search);
  ['utm_source','utm_medium','utm_campaign','utm_content','utm_term'].forEach(function(k){
    var el = document.getElementById(k);
    if (el && q.has(k)) el.value = q.get(k);
  });
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
