# SEO Services Engine — Architecture

## Overview

Dynamic, admin-driven SEO landing pages for installation services across India.

**No static city pages.** Every URL is computed from Supabase data:

```
/{city_slug}/{service_slug}
```

Example: `/ranchi/cctv-installation`, `/patna/networking`

Adding a city in Admin → SEO Cities automatically exposes **all active services** for that city (40 URLs for 4 cities × 10 services, 500+ for 50 cities — no code changes).

## Data model (Supabase)

| Table | Role |
|-------|------|
| `seo_services` | 10 installation types + templates (`features`, `process_steps`, `faq_template`, SEO templates) |
| `seo_cities` | City master + geo + SEO overrides + `nearby_districts` + FAQ |
| `seo_city_nearby` | Directed edges for internal linking between cities |

Public reads use views: `v_public_seo_*`, `v_public_seo_landing_urls` (city × service cross join for sitemap).

## Routing (Flutter Web)

| Route | Screen |
|-------|--------|
| `/services` | `ServicesHubPage` — service menu → city picker |
| `/services/cities` | `ServicesCitiesPage` — search, state filter, all cities |
| `/:citySlug/:serviceSlug` | `SeoLandingPageScreen` — registered **last**; reserved segments blocked via `SeoRouteGuard` |

Deferred bundle: `lib/shared/router/bundles/web_seo_routes_bundle.dart`

## Content generation

`SeoContentGenerator` merges city + service + templates with variable replacement:

- `{{city}}`, `{{state}}`, `{{service}}`, `{{City}}`, `{{Service}}`

Produces unique per-page: title, meta, H1, H2, intro, FAQ, breadcrumbs, related services, JSON-LD (`LocalBusiness`, `Service`, `BreadcrumbList`, `FAQPage`).

Admin SEO overrides on `seo_cities` take precedence when set.

## Admin module

Fourth admin platform tab: **SEO** (embedded shell like Shop/Calculator).

| Screen | Path |
|--------|------|
| Hub | `/admin/seo` |
| Cities list | `/admin/seo/cities` |
| City editor | `/admin/seo/cities/new`, `/admin/seo/cities/:id/edit` |
| Services list | `/admin/seo/services` |
| Service editor | `/admin/seo/services/:id/edit` |

## Sitemap & robots

`scripts/generate_sitemap.mjs` fetches `v_public_seo_landing_urls` and emits `/{city}/{service}` entries.

Run on prod build (`build-web-prod.ps1`) or:

```bash
node scripts/generate_sitemap.mjs
```

`robots.txt` unchanged — public landing paths are allowed; `/admin` disallowed.

## Blog posts (related content)

`seo_blog_posts` — tag with `city_slugs` and `service_slugs` arrays.  
Public URL: `/blog/{slug}` · shown in **Related articles** on landing pages.

Admin: **SEO → SEO Blog Posts**

## Scale to all India

1. Admin adds city (e.g. Patna, Bihar) with slug `patna`
2. Set nearby cities for internal links
3. All `/patna/*` service URLs go live immediately
4. Rebuild web / regenerate sitemap → Google discovers new URLs

No deploy of new Dart routes or HTML files required.

## Files map

```
supabase/migrations/20260702130150_seo_services_engine.sql
lib/features/seo/
  domain/          — SeoCity, SeoService, SeoLandingPage
  data/            — PublicSeoRepository, SeoAdminRepository
  services/        — SeoContentGenerator, SeoRouteGuard
  public/pages/    — Hub, cities, landing
  admin/           — CRUD screens
lib/core/seo/public_seo_registry.dart  — /services, /services/cities meta
scripts/generate_sitemap.mjs           — dynamic URL injection
```
