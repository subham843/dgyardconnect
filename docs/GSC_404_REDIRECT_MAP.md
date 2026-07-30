# GSC 404 redirect map — WordPress/WooCommerce → Flutter Web

**Source:** `dgyard.com-Coverage-Drilldown-2026-07-08.xlsx` (Not found 404)  
**Parsed unique URL samples:** 71  
**Policy:** Prefer category/page redirects over homepage. Prefer exact product remaps only when specs clearly match. Keep intentional 404 for junk, APIs, authors, and placeholder SMM posts.

Firebase rules live in `firebase.json` → `hosting.redirects`.

---

## Summary

| Decision | Count (unique path patterns) | Outcome |
|---|---|---|
| **301 redirect** | ~45 path patterns (covers almost all GSC samples via globs) | Softens crawl 404s → nearest relevant page |
| **Already exists** | `/`, `/privacy-policy` | No redirect — soft/www issues only |
| **Keep 404** | Malformed, API, author, SMM lorem/change | Avoid misleading soft-404 → ranking dilution |

Globs handle `?add-to-cart=` / `?per_page=` variants: Firebase redirects match **path**, so query strings do not need separate rules.

---

## 1. Firebase redirect rules (added)

See `firebase.json` for the complete list. Compact destination map:

| Source pattern | Destination | Type |
|---|---|---|
| `/cart` | `/store/cart` | 301 |
| `/auth/**` | `/login` | 301 |
| `/quotation` | `/calculator` | 301 |
| `/faqs`, `/faq` | `/support` | 301 |
| `/blog` | `/services` | 301 |
| `/smm`, `/smm/about` | `/services` | 301 |
| `/smm/contact` | `/contact` | 301 |
| `/category/cctv-camera` | `/store/category/cctv-camera-security` | 301 |
| `/category/home-automation` | `/store/category/smart-home-automation` | 301 |
| `/securing-your-world-…` | `/services` | 301 |
| `/transforming-houses-…` | `/store/category/smart-home-automation` | 301 |
| `/product-category/accessories/power-supply/**` | `/store/category/electrical-power-solutions` | 301 |
| `/product-category/accessories/**` | `/store/category/computer-laptop-accessories` | 301 |
| `/product-category/analog-hd-camera-kit/**` | `/store/category/cctv-camera-security` | 301 |
| `/product-category/analog-hd-camera/**` | `/store/category/cctv-camera-security` | 301 |
| `/product-category/analog-hd-camera-2/**` | `/store/category/cctv-camera-security` | 301 |
| `/product-category/**` | `/store` | 301 |
| `/product/2-4mp-ir-dome-camera-20mtr` | `/product/cp-plus-2-4mp-ir-dome-camera-dg-yard` | 301 |
| `/product/2-4mp-ir-bullet-camera-cp-plus` | `/product/2-4mp-ir-bullet-camera-20mtr` | 301 |
| `/product/cp-plus-{2,3,4}-camera-set` | CCTV category | 301 |
| `/product/8ch-1080n-digital-video-recorder` | CCTV category | 301 |
| `/product/16ch-5m-n-digital-video-recorder-cp-plus` | CCTV category | 301 |
| Long kit/night-vision product slugs (2) | CCTV category | 301 |

---

## 2. Redirect mapping table (by intent)

### A. Functional pages (exact utility match)

| Old URL | New URL | Why |
|---|---|---|
| `/cart` | `/store/cart` | Same user intent (bag/checkout path) |
| `/auth/signin…` | `/login` | Auth surface equivalent |
| `/quotation` | `/calculator` | Quote/BOQ tooling equivalent |
| `/faqs` | `/support` | Help content closest live page |
| `/smm/contact` | `/contact` | Contact form equivalent |
| `/privacy-policy` | *(live)* | Already exists — no redirect |

### B. Categories (taxonomy equivalence)

| Old Woo/WP path | New Flutter category | Why |
|---|---|---|
| `/product-category/analog-hd-camera…` (+kits, 2.4MP, 8ch, 16ch) | `/store/category/cctv-camera-security` | Same product family; Flutter catalog uses new slugs |
| `/product-category/accessories/` | `/store/category/computer-laptop-accessories` | Generic accessories closest fit |
| `/product-category/accessories/power-supply/` | `/store/category/electrical-power-solutions` | Power-supply taxonomy |
| `/category/cctv-camera/` | CCTV category | WP blog category → shop CCTV |
| `/category/home-automation/` | Smart-home category | Same topic |

### C. Products with near-match remaps

| Old product | New product | Why careful |
|---|---|---|
| `/product/2-4mp-ir-dome-camera-20mtr/` | `/product/cp-plus-2-4mp-ir-dome-camera-dg-yard` | Same dome / resolution / IR family |
| `/product/2-4mp-ir-bullet-camera-cp-plus/` | `/product/2-4mp-ir-bullet-camera-20mtr` | Same bullet camera family |

### D. Discontinued kits → category (not a wrong SKU)

Redirecting a 2/3/4-camera **kit** or 8ch DVR to a single modern camera SKU would be misleading. Destination is always CCTV category:

- `/product/cp-plus-2-camera-set/`
- `/product/cp-plus-3-camera-set/`
- `/product/cp-plus-4-camera-set/`
- `/product/8ch-1080n-digital-video-recorder/`
- `/product/16ch-5m-n-digital-video-recorder-cp-plus/`
- Long night-vision / DVR-kit bundle URLs from GSC

### E. Content / microsite

| Old | New | Why |
|---|---|---|
| `/smm`, `/smm/about` | `/services` | Digital marketing offers live under Services |
| `/blog` | `/services` | Old WP blog index gone; services is topical hub (not homepage soft-404) |
| Marketing CCTV post slug | `/services` | Services intent |
| Home automation post slug | Smart-home category | Product/topic match |

---

## 3. URLs that should intentionally remain 404

| URL / pattern | Why keep 404 |
|---|---|
| `https://www.dgyard.com/&` | Malformed junk |
| `/api/app/download/android` | Legacy API — no public HTML page |
| `/author/subham/` | Author archive has no Flutter equivalent |
| `/smm/blog`, `/smm/blog/.../{id}` | Lorem/placeholder SMM posts — redirecting would create soft/thin ranking risk |
| `/smm/change`, `/smm/change/` | Internal microsite admin path |

**Also note:** `https://www.dgyard.com/` and `/privacy-policy` appearing in “Not found” are **not missing routes** on apex `dgyard.com`. Fix with DNS/hosting for `www` (or Hosting rewrite), not a path redirect inside Flutter.

---

## 4. What we deliberately did *not* do

- No blanket `/** → /` (soft 404 / diluted relevance).
- No remap of 8ch DVR → live 16ch DVR product (channel count mismatch).
- No remap of kit bundles onto a single bullet/dome SKU.
- No redirect of SMM lorem posts onto real blog posts (would be topical spam).
- No redirect of `/api/**` to homepage.

---

## 5. Deploy

```powershell
cd e:\dgyardconnect
# Redirect rules live in firebase.json; full rebuild not strictly required,
# but deploy hosting so Hosting config updates:
firebase deploy --only hosting
```

Or SEO+hosting helper if you keep it in sync with a build:

```powershell
powershell -File scripts\build-web-prod.ps1
firebase deploy --only hosting
```

Verify after deploy:

```powershell
curl.exe -sI "https://dgyard.com/product-category/analog-hd-camera-kit/"
curl.exe -sI "https://dgyard.com/cart"
curl.exe -sI "https://dgyard.com/smm"
curl.exe -sI "https://dgyard.com/author/subham/"
```

Expect: `301` + `Location:` for mapped paths; intentional 404s still hit the SPA `200` shell unless you add a real hosting 404 (Flutter limitation). For GSC, **301s on old Woo paths are what matter**.

---

## 6. Expected GSC impact

Most of the 71 samples are:

1. Woo `product-category/*` + `add-to-cart` query noise  
2. Discontinued product/kits  
3. SMM microsite leftovers  

After deploy, category + cart + content 301s should clear the bulk of “Not found (404)” for those paths with the next crawl. Leftover intentional 404s may remain in the report until Google drops them — that is preferred over soft 404 redirects.
