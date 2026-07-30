# SEO Audit & Remediation Report — dgyard.com

**Date:** 2026-06-26  
**Stack:** Flutter Web · Firebase Hosting · Supabase catalog  
**Production domain:** https://dgyard.com

---

## Executive summary

Google Search Console reported **96× 404**, **18× 5xx**, **17× crawled-not-indexed**, **8× noindex**, redirects, canonical conflicts, **1× soft 404**, and **1× robots.txt block**.

Root causes identified in code:

| Issue | Root cause | Fix applied |
|-------|------------|-------------|
| 404 errors | Old `/shop/*` URLs, wrong domain in sitemap (`dgyard-connect.web.app`), missing product/category URLs in sitemap | 301 redirects, regenerated sitemap (45 URLs on `dgyard.com`) |
| Canonical conflicts | `index.html` + DB canonicals pointed at `dgyard-connect.web.app`; shop canonical paths used `/shop/...` while live routes are `/store/...` and `/product/...` | Unified on `https://dgyard.com`; fixed `ShopSeoConfig` paths |
| noindex (8 pages) | No route-level robots control; admin/login served with default `index, follow` | `noindex, nofollow` for private routes via `WebSeoBinder` |
| Soft 404 | SPA returns HTTP 200 for missing products/categories | `noindex` + explicit “not found” titles/descriptions on missing entities |
| robots.txt block | Sitemap referenced wrong host; private routes not disallowed | Updated `robots.txt` with disallows + `https://dgyard.com/sitemap.xml` |
| Crawled-not-indexed | Thin/duplicate meta (single static `index.html` for all routes) | Per-route dynamic title, description, canonical, OG, Twitter, JSON-LD |
| Missing sitemap URLs | Only 11 static URLs; no products/categories/calculators | `scripts/generate_sitemap.mjs` pulls live Supabase catalog |
| Deep-link 404 on refresh | Already handled by Firebase `** → /index.html` rewrite | Verified; no change required |
| 5xx errors | Likely transient Firebase / function / asset hits (no reproducible 5xx on public routes in audit) | Hardened static asset headers; monitor post-deploy |

---

## Files modified

### New files
| File | Purpose |
|------|---------|
| `lib/core/seo/site_seo_config.dart` | Canonical base URL (`https://dgyard.com`) |
| `lib/core/seo/web_seo_meta.dart` | SEO payload model |
| `lib/core/seo/web_document_head.dart` | Conditional export |
| `lib/core/seo/web_document_head_web.dart` | Updates `<head>` at runtime (web) |
| `lib/core/seo/web_document_head_stub.dart` | No-op stub (mobile) |
| `lib/core/seo/public_seo_registry.dart` | Static + dynamic SEO definitions, private-path rules |
| `lib/core/seo/web_seo_binder.dart` | Route listener + `WebSeoScope` widget |
| `scripts/generate_sitemap.mjs` | Builds `web/sitemap.xml` from Supabase |

### Updated files
| File | Change |
|------|--------|
| `web/index.html` | Canonical, OG, Twitter, JSON-LD → `dgyard.com` |
| `web/robots.txt` | Disallow private routes; sitemap → `dgyard.com` |
| `web/sitemap.xml` | Regenerated — **45 indexable URLs** (was 11 on wrong domain) |
| `firebase.json` | 301 redirects: `/shop/**`, `/marketplace/**`, `index.html`, web.app → `dgyard.com` |
| `lib/app/web_material_app.dart` | Wraps app with `WebSeoBinder` on web |
| `lib/features/shop/config/shop_seo_config.dart` | Canonical paths match public routes |
| `lib/features/web_public/pages/shop/product_detail_page.dart` | Dynamic product SEO + soft-404 noindex |
| `lib/features/web_public/pages/shop/store_category_page.dart` | Dynamic category SEO + soft-404 noindex |
| `lib/features/web_public/pages/calculator/calculator_detail_page.dart` | Dynamic calculator SEO |
| `lib/shared/router/bundles/web_static_routes_bundle.dart` | Unknown routes → noindex |
| `lib/shared/router/bundles/web_store_routes_bundle.dart` | Unknown store routes → noindex |
| `scripts/build-web-prod.ps1` | Runs sitemap generation on each prod build |
| `scripts/package.json` | `generate-sitemap` npm script |

---

## Before / after highlights

### Domain & canonical (index.html)

**Before**
```html
<link rel="canonical" href="https://dgyard-connect.web.app/">
<meta property="og:url" content="https://dgyard-connect.web.app/">
```

**After**
```html
<link rel="canonical" href="https://dgyard.com/">
<meta property="og:url" content="https://dgyard.com/">
```

### robots.txt

**Before**
```
Sitemap: https://dgyard-connect.web.app/sitemap.xml
```

**After**
```
Disallow: /admin
Disallow: /shop
…
Sitemap: https://dgyard.com/sitemap.xml
```

### Sitemap

**Before:** 11 URLs on `dgyard-connect.web.app` (included `/login`)  
**After:** 45 URLs on `dgyard.com` — static pages + 6 categories + 27 products + 2 calculators  
**Removed from sitemap:** `/login`, `/admin/*`, `/shop/*`, cart, auth flows

### Shop canonical paths (DB writes)

**Before:** `/shop/{categorySlug}`  
**After:** `/store/category/{categorySlug}` and `/product/{slug}`

### Firebase redirects (new)

| Source | Destination | Type |
|--------|-------------|------|
| `/index.html` | `/` | 301 |
| `/shop`, `/shop/**` | `/store` | 301 |
| `/marketplace`, `/marketplace/**` | `/store` | 301 |
| `dgyard-connect.web.app/**` | `https://dgyard.com/:splat` | 301 |
| `dgyard-connect.firebaseapp.com/**` | `https://dgyard.com/:splat` | 301 |

---

## Per-page SEO coverage (public)

Every indexable public route now receives at runtime:

- Unique `<title>`
- Unique `meta description`
- `link rel="canonical"` on `dgyard.com`
- Open Graph (`og:title`, `og:description`, `og:url`, `og:image`, `og:type`)
- Twitter Card tags
- JSON-LD where applicable (Organization, LocalBusiness, Product, CollectionPage, WebApplication)

Private routes (`/admin`, `/login`, `/dealer`, `/technician`, `/marketplace`, `/shop`, etc.) receive **`noindex, nofollow`**.

---

## Sitemap contents (45 URLs)

- **Static (10):** `/`, `/store`, `/calculator`, `/services`, `/connect`, `/about`, `/contact`, `/support`, `/privacy-policy`, `/data-deletion`
- **Categories (6):** `/store/category/{slug}`
- **Products (27):** `/product/{slug}`
- **Calculators (2):** `/calculator/hd-cctv`, `/calculator/ip-cctv`

Regenerate after catalog changes:
```bash
node scripts/generate_sitemap.mjs
# or full prod build:
powershell -File scripts/build-web-prod.ps1
```

---

## Flutter Web / hosting

- **Deep links:** `firebase.json` rewrite `** → /index.html` — confirmed working (all tested paths return 200 shell).
- **Trailing slashes:** `trailingSlash: false` — consistent non-trailing URLs.
- **Performance (existing):** deferred route bundles, deferred Flutter boot, GA deferred until interaction — retained.

---

## Post-deploy checklist (Google Search Console)

1. **Deploy:** `powershell -File scripts/build-web-prod.ps1` then `firebase deploy --only hosting`
2. **Submit sitemap:** Search Console → Sitemaps → `https://dgyard.com/sitemap.xml`
3. **Validate fixes** for 404, soft 404, noindex, canonical, robots.txt
4. **Request indexing** for key URLs: `/`, `/store`, top product pages
5. **Monitor 5xx** for 7 days — if persistent, export sample URLs from GSC for targeted investigation (likely Cloud Functions or old asset paths, not public SPA routes)
6. **Remove old property** URLs from index over time as `dgyard-connect.web.app` 301s propagate

---

## Expected GSC impact

| Report | Expected outcome |
|--------|------------------|
| Not found (404) | Sharp drop as `/shop/*` 301s apply and sitemap uses live slugs only |
| Server error (5xx) | Monitor; no reproducible public-route 5xx in audit |
| Crawled – not indexed | Improves as unique meta + JSON-LD + internal nav (footer) strengthen signals |
| Excluded by noindex | Stable on private routes; public pages explicitly `index, follow` |
| Alternative canonical | Resolved — single canonical host `dgyard.com` |
| Soft 404 | Missing products/categories emit `noindex` |
| Blocked by robots.txt | Resolved — sitemap URL + Allow `/` |

---

## Maintenance

- Run sitemap generation on every production web build (automated in `build-web-prod.ps1`).
- When adding public routes, add an entry to `PublicSeoRegistry` and static routes in `generate_sitemap.mjs`.
- Keep `SITE_SEO_BASE_URL` / `SHOP_SEO_BASE_URL` as `https://dgyard.com` in CI builds.

### Dynamic SEO Services Engine (2026-07)

Admin-driven city × service landing pages — no static city HTML:

| URL | Purpose |
|-----|---------|
| `/services` | Service menu + city picker |
| `/services/cities` | All cities (search + state filter) |
| `/{city}/{service}` | e.g. `/ranchi/cctv-installation` |
| `/blog/{slug}` | Related articles |

- **Admin:** fourth module **SEO** → Cities, Services, Blog Posts
- **DB:** `seo_cities`, `seo_services`, `seo_city_nearby`, `seo_blog_posts` (Supabase)
- **Sitemap:** auto-includes all active city×service URLs + blog posts via `v_public_seo_*` views
- **Docs:** `supabase/docs/seo-services/ARCHITECTURE.md`

Adding a city in Admin instantly exposes all service URLs for that city (scale to all India without code changes).

### Critical: Firebase deploys `build/web`, not `web/`

`firebase.json` sets `"public": "build/web"`. Flutter copies `web/sitemap.xml` → `build/web/sitemap.xml` **during** `flutter build web`. If the generator ran **after** the build and only updated `web/sitemap.xml`, the deploy bundle could still ship the **old 11-URL `dgyard-connect.web.app` sitemap**.

**Fixed:** `generate_sitemap.mjs` writes to **both** `web/sitemap.xml` and `build/web/sitemap.xml`. `build-web-prod.ps1` verifies hashes match and rejects `web.app` / `/login` in the deploy bundle.

**Quick SEO-only deploy** (when `build/web` already exists):

```powershell
powershell -File scripts/deploy-hosting-seo.ps1
```

**Verify all sitemap URLs return HTTP 200:**

```bash
node scripts/verify_sitemap.mjs https://dgyard.com
```
