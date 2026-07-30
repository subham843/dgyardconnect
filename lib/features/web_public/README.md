# Public Web Experience

Premium public marketing site for DG Yard (Shop, Calculator, Connect).

## Design systems

**V2 (primary)** — `v2/`:

- `v2_colors.dart`, `v2_tokens.dart`, `v2_text.dart` — tokens and typography
- `v2/widgets/` — navbar, footer, buttons, paper surfaces, lazy sections
- `v2/sections/` — home page sections (hero, store intro, testimonials, etc.)

**V1 (store chrome only)** — `core/design_system/public_colors|spacing|typography|theme` + `pages/shop/widgets/`:

- Used only on `/store` catalog UI — migrate to V2 tokens when store is redesigned

## Routing

Routes live in `lib/shared/router/app_router_web.dart` (web) and are merged into the mobile router for native builds.

| Path | Page |
|------|------|
| `/` | `HomePage` |
| `/store` | `StorePage` |
| `/product/:slug` | `ProductDetailPage` |
| `/calculator` | `CalculatorListPage` |
| `/calculator/:slug` | `CalculatorDetailPage` |
| `/services` | `ServicesPage` |
| `/about` | `AboutPage` |
| `/contact` | `ContactPage` |
| `/connect` | `ConnectPage` |
| `/privacy-policy` | `PrivacyPolicyScreen` |
| `/data-deletion` | `DataDeletionScreen` |

Web uses a slim router with deferred admin shop/calculator routes (`web_admin_routes_bundle.dart`).

## Data layer

`data/repositories/`:

- `public_catalog_repository.dart` — shop catalog via Supabase views
- `public_store_repository.dart` — store landing content
- `public_calculator_repository.dart` — calculator families

Anonymous read via `v_public_*` SQL views (no cost/dealer pricing).

## Performance notes

- Home below-fold sections use `V2LazySection` to defer first paint
- Hero uses reduced blur layers (orbs only) for cheaper web compositing
- Splash intro uses gradient fallback (no bundled `intro_bg.png`)

---

Built with Flutter Web, Supabase, GoRouter.
