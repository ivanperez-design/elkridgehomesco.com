# GA4 Install — staged, awaiting Measurement ID

**Status:** ✅ **INSTALLED AND VERIFIED LIVE 2026-08-18.**
**Date staged:** 2026-08-17 · **Date installed:** 2026-08-18
**Measurement ID:** `G-QK8KM3LY16` · **Property:** Elk Ridge Home LLC / `elkridgehomesco.com` (id `550302482`, account `404951749`), owned by **info@elkridgeinteriors.com**
**Commit:** `6886f2f` on `main`, deployed to `gh-pages` via `deploy.sh`.

**Verification actually performed (not assumed):**
- `curl` on the live site: **2** occurrences of `G-QK8KM3LY16` on `/` and on `/contact.html` (loader `src` + `gtag("config")`).
- `curl` on live `script.js`: the `gtag('event', 'erh_form_sent', …)` patch is serving — the bug where the confirmed-lead event was pushed to `dataLayer` only (which gtag.js ignores) is **fixed in production**.
- **GA4 Realtime showed 1 active user with `page_view`, `session_start`, `first_visit`** from a live page load. Data is genuinely flowing; the instrument is proven, per the "verify the instrument before believing the number" rule.

**Setup choices recorded:** Industry = Home & Garden (Google's taxonomy files construction/home-improvement there; affects benchmarking only, changeable in Admin → Property details) · Business size = Small (1–10) · Objective = Generate leads · Enhanced measurement ON · Google-products data sharing left OFF · Google Analytics marketing emails declined.

**Still open (deliberately not done — each needs data or is a settings change worth Ivan's eyes):**
1. **Mark key events** — Admin → Events → toggle *Mark as key event* on `erh_form_sent`, then `erh_call`, `erh_text`. Requires the events to have fired at least once, so do this after real traffic.
2. **Exclude the FormSubmit referral** — Admin → Data streams → stream → Configure tag settings → Show all → List unwanted referrals → add `formsubmit.co`. Without it GA4 logs your own leads as referred by formsubmit.co and mis-attributes them away from Google/direct.
3. **Link Google Ads** (Admin → Product links) — the actual reason the tracking gate existed. Do before any ad spend.
4. **Link Search Console** (Admin → Product links).

---

## Why this file exists

`script.js` already fires conversion events on every page — call taps, text taps, email taps, and the contact-form submit. But **every one of those calls is wrapped in `if (window.gtag)` / `if (window.dataLayer)`, and no analytics loader exists on any page.** So today every event is a silent no-op: the tracking code runs, finds no analytics library, and does nothing. Nobody is watching.

The site is live at elkridgehomesco.com and Google Ads is gated on tracking. Until the loader below is on the pages, there is no proof any click, call, or form ever happened, and no conversion data to optimize ads against.

**Deliberate choice:** the loader is NOT pre-inserted with a fake ID. A placeholder `G-XXXXXXXXXX` on production is dead code that loads a script, gets ignored, and looks installed while reporting nothing — worse than nothing, because it hides the gap. Real ID or no ID.

---

## (a) The snippet to insert

Standard Google gtag.js loader. Replace **both** occurrences of `G-XXXXXXXXXX` with the real Measurement ID (the one-command inserter in section (c) does this for you):

```html
<!-- Google tag (gtag.js) — GA4 -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-XXXXXXXXXX');
</script>
```

That's it — no GTM container, no tag manager. gtag.js is the lighter option and `script.js` already calls `window.gtag(...)` directly, so it works with zero changes to the event code.

*(The inserter in section (c) emits this exact block with double quotes instead of single — identical JavaScript, it just avoids quote-escaping inside the shell command.)*

---

## (b) Exact insertion point

Every one of the 26 indexable pages shares an identical head. Line 8 of each file is byte-for-byte:

```html
<meta name="theme-color" content="#2D4A3E" />
```

**Insert the snippet immediately after that line** (it becomes lines 9–15), so the loader sits high in `<head>` — above the canonical link, the fonts preconnect, and the stylesheet. Verified 2026-08-17: that anchor line is at line 8 in all 26 pages, and appears exactly once per file.

Head structure for reference (index.html):

```
1  <!doctype html>
2  <html lang="en">
3  <head>
4  <meta charset="utf-8" />
5  <meta name="viewport" content="width=device-width, initial-scale=1" />
6  <title>…</title>
7  <meta name="description" content="…" />
8  <meta name="theme-color" content="#2D4A3E" />   ← INSERT AFTER THIS LINE
9  <link rel="canonical" href="…">
```

### Files that get the tag (26)

about · basement-finishing-steamboat-springs · bathroom-remodel-steamboat-springs · bronze-metal-roofing-steamboat-springs · cleaning-steamboat-springs · contact · custom-closets-steamboat-springs · custom-homes · deck-builder-steamboat-springs · exteriors · flooring-steamboat-springs · index · interior-remodels · kitchen-remodel-steamboat-springs · our-work · plan-your-project · projects · remodel-process · remodels · roofing-steamboat-springs · shower-waterproofing-steamboat-springs · siding-steamboat-springs · soundproofing-steamboat-springs · weatherproofing-steamboat-springs · whole-home-remodel-steamboat-springs · window-replacement-steamboat-springs

### Files deliberately SKIPPED (2)

| File | Why skipped |
|---|---|
| `404.html` | Error page, `noindex`. Tagging it pollutes the report with bot 404s and inflates sessions. |
| `materials.html` | `noindex` redirect stub — a 0-second meta-refresh to `exteriors.html#materials`. Tagging it would log a bounce-and-vanish hit on every redirect and double-count the real page. |

Neither file contains the anchor line, so the inserter skips them both by name **and** by anchor — belt and suspenders.

---

## (c) One command to install (run after you have the real ID)

Paste the real Measurement ID into the last line, then paste the whole block into Terminal. It is idempotent — re-running it will not double-tag.

```bash
cd /Users/ivanperez/Documents/elkridgehomesco.com && python3 -c '
import glob, re, sys
ga = sys.argv[1]
if not re.fullmatch(r"G-[A-Z0-9]{8,12}", ga):
    sys.exit("STOP: %r is not a GA4 Measurement ID (expected G-XXXXXXXXXX)" % ga)
SKIP   = {"404.html", "materials.html"}
ANCHOR = "<meta name=\"theme-color\" content=\"#2D4A3E\" />\n"
BLOCK  = ("<!-- Google tag (gtag.js) — GA4 -->\n"
          "<script async src=\"https://www.googletagmanager.com/gtag/js?id=" + ga + "\"></script>\n"
          "<script>\n"
          "  window.dataLayer = window.dataLayer || [];\n"
          "  function gtag(){dataLayer.push(arguments);}\n"
          "  gtag(\"js\", new Date());\n"
          "  gtag(\"config\", \"" + ga + "\");\n"
          "</script>\n")
n = 0
for f in sorted(glob.glob("*.html")):
    if f in SKIP:
        print("skipped by design:", f); continue
    s = open(f, encoding="utf-8").read()
    if "googletagmanager.com/gtag/js" in s:
        print("already tagged:     ", f); continue
    if ANCHOR not in s:
        print("!! ANCHOR MISSING:  ", f, "(not tagged — check this file by hand)"); continue
    open(f, "w", encoding="utf-8").write(s.replace(ANCHOR, ANCHOR + BLOCK, 1))
    n += 1; print("tagged:             ", f)
# script.js: erh_form_sent only pushed to dataLayer. gtag.js ignores raw dataLayer
# {event:...} objects (that is a GTM behavior), so without this line the single most
# important event — a CONFIRMED submission — would never reach GA4.
j   = open("script.js", encoding="utf-8").read()
old = "    if (window.dataLayer) window.dataLayer.push({event: \x27erh_form_sent\x27});"
new = old + "\n    if (window.gtag) window.gtag(\x27event\x27, \x27erh_form_sent\x27, {page_path: location.pathname});"
if "window.gtag(\x27event\x27, \x27erh_form_sent\x27" in j:
    print("already patched:     script.js")
elif old in j:
    open("script.js", "w", encoding="utf-8").write(j.replace(old, new, 1))
    print("patched:             script.js (erh_form_sent -> gtag)")
else:
    print("!! script.js line not found — patch erh_form_sent by hand")
print("\nDONE — %d pages tagged. Review with: git diff --stat" % n)
' G-XXXXXXXXXX
```

Then review, commit, and deploy:

```bash
cd /Users/ivanperez/Documents/elkridgehomesco.com
git diff --stat                    # expect 26 .html + script.js
git add -A && git commit -m "ga4: install gtag.js loader on all indexable pages"
./deploy.sh                        # main -> gh-pages -> live (Pages build takes 1-10 min)
```

⚠️ **`git push origin main` alone does NOT deploy.** GitHub Pages serves from the `gh-pages` branch. `deploy.sh` handles the merge; do not skip it.

**If you need to back it out:** `git revert` the commit and re-run `./deploy.sh`. Nothing else in the site depends on the tag.

---

## (d) What starts reporting the moment it goes live

All events are already wired in `script.js` — they light up the instant the loader exists.

| Event | Fires when | What it means for the business |
|---|---|---|
| `page_view` | Automatic on every page load (from `gtag('config', …)`) | Traffic, top landing pages, which service pages actually get read. The base for every ad decision. |
| `erh_call` | Someone taps a `tel:` link — **244 of them across the site** | Phone-call intent. The highest-value signal ERH has; most mountain remodel leads call. |
| `erh_text` | Someone taps an `sms:` link — 163 across the site | Text intent. Ivan's fastest-closing channel. |
| `erh_email` | Someone taps a `mailto:` link — 82 across the site | Lower-intent inquiry. |
| `erh_form` | The walkthrough form on `contact.html` is submitted (fires on submit, before the post) | Attempted lead. Compare against `erh_form_sent` — a gap between the two means the form is breaking. |
| `erh_form_sent` | The `?sent=1` confirmation page loads after FormSubmit redirects back | **Confirmed lead.** This is the real conversion — the one to import into Google Ads. |

Every event carries `page_path`, so you can see which page produced the call or the lead.

**Mark as conversions in GA4** once data appears (Admin → Events → toggle "Mark as key event"): `erh_form_sent` first, then `erh_call` and `erh_text`. Those three are the ads-optimization targets. Leave `erh_email` and `erh_form` as plain events.

---

## (e) Ivan's part — creating the property (5 minutes, non-technical)

1. Go to **analytics.google.com** and sign in with the **info@elkridgeinteriors.com** Google account (the same one that owns the Business Profile — keeps everything in one place).
2. If it's a brand-new account, Google walks you through **Account setup** first. Account name: `Elk Ridge Home LLC`. Accept the defaults on the data-sharing checkboxes, click **Next**.
3. **Create property** — property name: `elkridgehomesco.com`. Time zone: **United States → (GMT-07:00) Mountain Time**. Currency: **US Dollar**. Click **Next**.
4. Business details: Industry = **Home & Garden** (or Real Estate — it only affects benchmark comparisons, not your data). Business size = **Small (1–10 employees)**. Click **Next**.
5. Business objectives: check **Generate leads**. Click **Create**, then accept the Terms of Service if prompted.
6. Google now asks to **start collecting data** — choose the **Web** platform.
7. Website URL: `https://elkridgehomesco.com` · Stream name: `Elk Ridge Home website`. Leave **Enhanced measurement ON**. Click **Create stream**.
8. The **Web stream details** panel opens. Near the top right you'll see **Measurement ID** — it looks like `G-ABC1234XYZ`. **Copy it.** That is the one thing needed.
9. Google will show you an "installation instructions" panel with a code snippet. **Ignore it and close the panel** — the snippet is already written above and the command in section (c) installs it correctly across all 26 pages.

Already have the ID and can't find it later: **Admin** (gear, bottom left) → **Data streams** → click the stream → Measurement ID is top right.

**Hand the `G-` ID over and the install is one command.**

---

## (f) Verification — proving data actually flows

Do this within ~10 minutes of running `./deploy.sh` (allow the Pages build to finish first).

**1. Confirm the tag is on the live site (not just on your Mac)** — put the real ID in place of `G-XXXXXXXXXX`:
```bash
curl -s https://elkridgehomesco.com/ | grep -c "G-XXXXXXXXXX"
```
Expect `2` — the loader `<script src>` line and the `gtag("config", …)` line. This also proves the *real* ID went live, not a placeholder. If you get `0`, the Pages build hasn't finished — wait 2 minutes and re-run. (Baseline before install: `0`, confirmed against the live site 2026-08-17.)

**2. Watch yourself in Realtime:**
- In GA4, open **Reports → Realtime** (left sidebar).
- On your phone (use cellular data, not the office Wi-Fi, so it's a clean separate visit) open **elkridgehomesco.com**.
- Within ~30 seconds Realtime should show **1 user in last 30 minutes** and a `page_view`.
- **If it stays at 0:** you're likely blocking your own hit with an ad blocker or Brave — try a different browser or phone before assuming the install failed.

**3. Prove the conversion path end-to-end (the one that matters):**
- On the phone, tap the **Call** button on the site → Realtime "Event count by Event name" should list **`erh_call`**.
- Go to **contact.html**, fill out the walkthrough form with your own name and a note like `TEST — analytics verification, ignore`, and **submit it**.
- Realtime should show **`erh_form`**, then after FormSubmit redirects you back to the `?sent=1` confirmation, **`erh_form_sent`**.
- Check **info@elkridgeinteriors.com** — the test lead email should be sitting there. That proves the form and the tracking both work, on the same submission.

**4. Then, and only then:** GA4 **Admin → Events** → toggle **Mark as key event** on `erh_form_sent`, `erh_call`, `erh_text`.

✅ Verified when: `erh_form_sent` appears in Realtime **and** the test email lands in the inbox.

---

## Follow-on settings worth 60 seconds each (after verification passes)

- **Exclude the FormSubmit referral.** The form posts to `formsubmit.co` and redirects back, which GA4 would otherwise log as a new session referred by formsubmit.co — mis-attributing your own leads away from Google/direct. Fix: **Admin → Data streams → (your stream) → Configure tag settings → Show all → List unwanted referrals** → add `formsubmit.co`.
- **Link Google Ads** before spending a dollar: **Admin → Product links → Google Ads links**. Without this, the ad account can't optimize toward `erh_form_sent` and the spend flies blind. This is the actual reason the tracking gate exists.
- **Link Search Console** (**Admin → Product links**) to see which queries land on which page.

---

## Notes / open items

- **`erh_form_sent` needed a code fix, included above.** In `script.js` that event was pushed only to `dataLayer`. GTM reads raw `{event: …}` objects from `dataLayer`; **gtag.js does not** — it only processes entries pushed through the `gtag()` shim. Left alone, the single most important event would have stayed silent while everything else reported, which is the worst kind of failure: it looks like it's working. The command in section (c) adds the matching `window.gtag('event', 'erh_form_sent', …)` call.
- **URLs report with and without `.html`.** GitHub Pages serves `/contact` and `/contact.html` as the same page, so both paths can appear in reports. Cosmetic; ignore unless it gets confusing, in which case a redirect is the fix, not a GA setting.
- **No cookie banner is on the site.** The Colorado Privacy Act's obligations attach above consumer-volume thresholds ERH is nowhere near, so this is very likely a non-issue at current traffic — **NEEDS VERIFICATION** by counsel before any large paid-traffic push.
- **Nothing in this file has been applied.** No HTML was modified; no deploy was run. The repo is exactly as it was, plus this document.
