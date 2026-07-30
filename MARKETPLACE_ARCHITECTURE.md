# D.G.Yard Connect — B2B Marketplace Module

This document is the **implementation anchor** for adding the marketplace, procurement, and fulfillment system **without regressing** existing job, warranty, wallet, KYC, or admin flows. It aligns with the current stack: **Flutter**, **go_router**, **Provider**, **Firebase Auth / Firestore / Functions / Storage / FCM / App Check**, and the patterns in `lib/shared/router/app_router.dart`, `lib/core/constants/route_names.dart`, `lib/shared/router/route_guards.dart`, and `lib/shared/services/firestore_service.dart`.

---

## 1. Goals and constraints

- **Additive only**: new routes, collections, functions, and storage paths. Do not rename or repurpose existing `users`, `jobs`, or billing collections.
- **Buyer-facing anonymity**: catalog and order UIs must not expose seller identity; branding remains D.G.Yard.
- **Payments**: buyers pay D.G.Yard (Razorpay + configurable COD); payouts to sellers are post-delivery and policy-gated.
- **Admin control**: listing approval, final price, COD rules, reassignment, QC, dispatch, refunds, and auditability.
- **Kill switch**: feature entry points gated by Remote Config (`feature_flags_json`) so marketplace can be disabled without a store release (see §4).

---

## 2. Repository touchpoints (where changes go)

| Area | File / location | Rule |
|------|-----------------|------|
| Route constants | `lib/core/constants/route_names.dart` | Add a **dedicated block** of `marketplace*` / `adminMarketplace*` constants; do not alter existing paths. |
| Router | `lib/shared/router/app_router.dart` | Add a **comment-delimited section** `// --- Marketplace ---` with `GoRoute` entries; keep order: after shared routes, before or after role shells as fits. |
| Redirects | `lib/shared/router/route_guards.dart` | Extend public-route allowlist **only** if you add anonymous browse; otherwise marketplace stays behind login. Add **superadmin** checks for `/admin/marketplace/*` if not already implied by role routing. |
| Firestore accessors | `lib/shared/services/firestore_service.dart` | Add static helpers for new top-level collections (same style as `jobs()`, `warrantyClaims()`). |
| Feature UI | `lib/features/marketplace/` (new) | Buyer, seller, and shared widgets; no imports from job screens except shared auth/theme/services. |
| Admin UI | `lib/features/admin/marketplace/` (new) | Queues and desks; optional separate web admin later. |
| Push / deep links | `lib/shared/services/fcm_service.dart` | New `type` values and `go(...)` targets; **append** handlers, do not replace job handlers. |
| Remote Config | `lib/core/remote_config/remote_config_keys.dart` | Document new keys inside `feature_flags_json` (see §4). |

---

## 3. URL and `RouteNames` convention

Follow existing style: **absolute paths**, admin under `/admin/...`, role homes unchanged.

### 3.1 Shared marketplace (logged-in buyer/seller hub)

Proposed constants to add to `route_names.dart` (names are indicative — keep consistent with your naming taste):

```dart
// Marketplace (shared hub — auth required unless you explicitly open browse)
static const String marketplaceHome = '/marketplace';
static const String marketplaceSearch = '/marketplace/search';
static const String marketplaceCategory = '/marketplace/category/:categoryId';
static String marketplaceProduct(String productId) => '/marketplace/p/$productId';
static const String marketplaceCart = '/marketplace/cart';
static const String marketplaceCheckout = '/marketplace/checkout';
static const String marketplacePaymentResult = '/marketplace/payment-result';
static const String marketplaceOrders = '/marketplace/orders';
static String marketplaceOrderDetail(String orderId) => '/marketplace/orders/$orderId';
static const String marketplaceRfqNew = '/marketplace/rfq/new';
static String marketplaceRfqDetail(String rfqId) => '/marketplace/rfq/$rfqId';
static const String marketplaceNotifications = '/marketplace/notifications'; // optional inbox slice
```

### 3.2 Seller (requires marketplace seller capability)

```dart
static const String marketplaceSellerHub = '/marketplace/seller';
static const String marketplaceSellerListings = '/marketplace/seller/listings';
static const String marketplaceSellerListingNew = '/marketplace/seller/listings/new';
static String marketplaceSellerListingEdit(String productId) => '/marketplace/seller/listings/$productId/edit';
static const String marketplaceSellerRequests = '/marketplace/seller/order-requests';
static String marketplaceSellerRequestDetail(String requestId) => '/marketplace/seller/order-requests/$requestId';
static const String marketplaceSellerShipments = '/marketplace/seller/shipments';
static String marketplaceSellerShipment(String shipmentId) => '/marketplace/seller/shipments/$shipmentId';
static const String marketplaceSellerPayouts = '/marketplace/seller/payouts';
```

### 3.3 Admin marketplace

```dart
static const String adminMarketplaceHome = '/admin/marketplace';
static const String adminMarketplaceProductsQueue = '/admin/marketplace/products/queue';
static String adminMarketplaceProductReview(String productId) => '/admin/marketplace/products/$productId/review';
static const String adminMarketplacePricing = '/admin/marketplace/pricing';
static const String adminMarketplaceOrders = '/admin/marketplace/orders';
static String adminMarketplaceOrderDetail(String orderId) => '/admin/marketplace/orders/$orderId';
static const String adminMarketplaceRfq = '/admin/marketplace/rfq';
static const String adminMarketplaceCodRules = '/admin/marketplace/cod-rules';
static const String adminMarketplaceInward = '/admin/marketplace/inward';
static const String adminMarketplaceQc = '/admin/marketplace/qc';
static const String adminMarketplaceDispatch = '/admin/marketplace/dispatch';
static const String adminMarketplacePayouts = '/admin/marketplace/payouts';
static const String adminMarketplaceSellers = '/admin/marketplace/sellers';
static const String adminMarketplaceAudit = '/admin/marketplace/audit';
```

**`go_router` note**: Prefer `:productId` / `:orderId` path parameters matching existing admin/dealer job routes; use `s.pathParameters['productId']` in `pageBuilder`.

---

## 4. Feature flags and runtime config

Use existing `RemoteConfigKeys.featureFlagsJson` with stable boolean keys, for example:

| Key | Purpose |
|-----|---------|
| `marketplace_enabled` | Master switch: hide nav tiles, block deep links to `/marketplace/*`. |
| `marketplace_seller_apply_enabled` | Show “Sell on D.G.Yard” onboarding entry. |
| `marketplace_cod_enabled` | Global COD availability (still subject to server eligibility). |
| `marketplace_rfq_enabled` | Bulk / RFQ entry points. |

Optional: add defaults or copy in `config/app_runtime` Firestore doc for parity with other admin-driven runtime flags (see `FirestoreService.appRuntimeConfig()`).

---

## 5. `RouteGuards` integration

- **Default**: treat all `/marketplace/**` and `/admin/marketplace/**` as **authenticated** routes (no change to public list unless product policy allows guest browse).
- If **guest catalog** is required later, add only the minimal public paths (e.g. `/marketplace` and `/marketplace/p/:id` read-only) to the public allowlist block in `route_guards.dart`, and ensure Firestore rules expose **only public projection** fields.
- **Role enforcement**:
  - `superadmin`: allow `/admin/marketplace/*` (mirror how other `/admin/*` routes are reached today — if admin routes are not hard-blocked by guard, enforce in UI + backend).
  - `dealer` / `technician`: allow `/marketplace/*`; **seller sub-routes** additionally require `marketplaceSellerApproved == true` (or equivalent field) from `users/{uid}` — preferably validated server-side; client guard is UX only.
- **Ordering**: append new guard clauses **after** existing KYC/dealer/technician checks so legacy behavior is unchanged.

---

## 6. Firestore naming (aligned with this codebase)

Existing collections use **snake_case** top-level names (`jobs`, `warranty_claims`, `platform_invoices`). Use a **`marketplace_` prefix** for all new top-level collections and config docs to avoid collisions and keep `FirestoreService` readable.

### 6.1 Recommended collections

| Collection | Purpose |
|------------|---------|
| `marketplace_seller_profiles` | Internal seller business data, settlement hooks, status; **not** buyer-readable. |
| `marketplace_categories` | Admin-managed taxonomy. |
| `marketplace_products` | Catalog + operational fields; **security rules must hide** `internal_seller_uid`, cost fields, and moderation notes from buyers. |
| `marketplace_product_versions` | Optional subcollection `marketplace_products/{id}/versions/{v}` for moderation history. |
| `marketplace_carts` | Cart by `uid` or subcollection under `users/{uid}/marketplace_cart` — pick one pattern and stick to it. |
| `marketplace_orders` | Buyer order headers, status machine, payment mode, totals snapshot ids. |
| `marketplace_order_lines` | Subcollection `marketplace_orders/{orderId}/lines/{lineId}` with line-level fulfillment state. |
| `marketplace_seller_order_requests` | Accept/reject SLA, links to order + line. |
| `marketplace_inbound_shipments` | Seller → hub leg. |
| `marketplace_grn` | Goods receipt / inward. |
| `marketplace_qc_reports` | QC pass/fail, media refs. |
| `marketplace_invoices` | D.G.Yard buyer invoices. |
| `marketplace_credit_notes` | Refunds / adjustments. |
| `marketplace_ledger_entries` | Internal financial movements. |
| `marketplace_payout_batches` | Seller payouts. |
| `marketplace_rfqs` | Bulk / quote requests. |
| `marketplace_quotes` | Admin/pricing desk responses. |
| `marketplace_audit_logs` | Marketplace-specific admin/ops actions (or namespace `action` in existing `audit_logs` with `module: marketplace` — prefer separate collection if volume is high). |
| `config` doc | e.g. `config/marketplace_rules` for COD matrices, SLA timers, fee presets. |

### 6.2 User document extensions (`users/{uid}`)

Add **optional** fields (no breaking change for existing users):

- `marketplace_buyer_enabled` (bool, default true when module on)
- `marketplace_seller_status` (`none` | `pending` | `approved` | `suspended`)
- `marketplace_cod_tier` (int or string, optional override)
- `marketplace_trust_flags` (map, optional; can reuse `trust_score_history` / strikes for eligibility)

### 6.3 `FirestoreService` pattern

Add methods such as:

```dart
static CollectionReference<Map<String, dynamic>> marketplaceProducts() =>
    _instance.collection('marketplace_products');
static CollectionReference<Map<String, dynamic>> marketplaceOrders() =>
    _instance.collection('marketplace_orders');
// ...etc.
```

---

## 7. Storage layout

Prefix Firebase Storage paths:

`marketplace/products/{productId}/{filename}`

Optional evidence:

`marketplace/qc/{orderId}/{filename}`

Rules: restrict write to authenticated sellers for their drafts; public read only for approved media URLs if you use public URLs; prefer **signed URLs** issued by Cloud Functions for buyer-facing images.

---

## 8. Cloud Functions modules (logical)

Group HTTPS / Callable functions by prefix for logs and IAM:

- `marketplaceCatalog*` — search, public product resolution (strip sensitive fields server-side if rules are complex).
- `marketplaceSeller*` — submit listing, accept/reject request, shipment updates.
- `marketplaceCheckout*` — validate cart, COD eligibility, create Razorpay order.
- `marketplacePayments*` — Razorpay webhooks (idempotent).
- `marketplaceAdmin*` — approve, price, reassign, force status (admin claim).
- `marketplaceOps*` — inward, QC, dispatch.
- `marketplaceFinance*` — refunds, payout batches.

Enforce **App Check** on callables (consistent with security expectations for the rest of the app).

---

## 9. FCM and deep links

- New notification types: prefix `mp_` in payload `type` (e.g. `mp_seller_order_request`, `mp_order_dispatched`, `mp_listing_rejected`).
- In `fcm_service.dart`, map each type to `GoRouter.of(context).go(...)` using the **RouteNames** above.
- Do not put seller identity or internal cost data in notification bodies.

---

## 10. State management

- Add `ChangeNotifier` (or similar) providers scoped under marketplace routes: cart, checkout session, seller listing draft.
- Register providers in the widget subtree for `Marketplace*` screens or at `MaterialApp.router` only if necessary — prefer **route-local** providers to avoid affecting legacy home screens.

---

## 11. UI integration with existing design

- Read colors/typography from `BrandKitProvider` / `AppTheme` (`lib/app.dart`, `lib/core/theme/`).
- Reuse shared components: app bars, cards, loading/error patterns from technician/dealer features.
- Add `lib/core/theme/marketplace_ui_tokens.dart` only if you need a few semantic colors for status chips (QC, dispatch, payout).

---

## 12. Admin home entry

In `admin_home_screen.dart`, add a single nav tile **“Marketplace”** pointing to `RouteNames.adminMarketplaceHome`, wrapped in `marketplace_enabled` flag check so superadmins do not see a dead end when disabled.

---

## 13. Order lifecycle (reference state machine)

Document states in Firestore on `marketplace_orders.status` (example — adjust to product/legal review):

`draft_cart` → `payment_pending` → `paid` → `seller_request_open` → `seller_accepted` → `awaiting_inbound` → `inbound_received` → `qc_pending` → `qc_passed` → `repacked` → `invoiced` → `dispatched` → `delivered` → `settlement_pending` → `completed`

**Branches**: `seller_rejected`, `seller_timeout`, `qc_failed`, `cancelled`, `refund_pending`, `refunded`, `dispute_open`.

Each transition should be written by **Functions** or **admin tools** with `marketplace_audit_logs` (or namespaced `audit_logs`).

---

## 14. MVP vs later phases

**MVP**

- Listings → admin approval → admin-set buyer price → catalog → cart → Razorpay → seller accept/reject → manual inward/QC/dispatch status in admin → PDF invoice stub → manual payout marking.

**Phase 2**

- Automated fallback seller suggestion, inventory holds, carrier APIs, ledger automation, stricter fraud pipelines.

**Phase 3**

- Search tier at scale, multi-hub, advanced analytics export.

---

## 15. Regression checklist (before merge)

- [ ] No edits to existing `RouteNames` values for jobs, warranty, or auth.
- [ ] `route_guards.dart` public path list unchanged unless intentionally adding guest browse.
- [ ] New Firestore rules **deny** buyer read on `internal_seller_uid` and cost fields.
- [ ] Razorpay webhook handler idempotent; amount from server only.
- [ ] With `marketplace_enabled == false`, app navigation matches pre-marketplace behavior.
- [ ] FCM: job-related handlers still fire for legacy payloads.

---

## 16. Related planning

The full product specification (flows, security, phased rollout, and operations) was produced as a separate architecture narrative; this file is the **concrete mapping** to **D.G.Yard Connect’s** router, Firestore, and service layout so implementation stays modular and safe.

---

## 17. Implementation status (Phase 1 scaffold — shipped in repo)

The following is **live in the codebase** as an additive module:

- **Routes**: All marketplace paths are registered in `app_router.dart` under `// --- Marketplace`.
- **Feature flag**: `marketplace_enabled` in Remote Config `feature_flags_json` (see `MarketplaceFeatureFlags`). Debug builds default **on**; release defaults **off** until the flag is set.
- **Guards**: `route_guards.dart` redirects marketplace URLs to the role home when the flag is off.
- **Firestore**: New collections in `firestore.rules` + `firestore.indexes.json`; accessors in `FirestoreService`.
- **App state**: `MarketplaceCartController` registered in `app.dart` (`MultiProvider`).
- **UX entry**: Dealer & technician home **Supply** shortcut when enabled; admin **Marketplace hub** in Queues (hidden when flag off).
- **Flows working end-to-end (client + rules)**: seller listing draft → submit → **superadmin** publish to `marketplace_catalog` (no seller PII on catalog docs) → buyer browse/cart/checkout → order + line items; RFQ create; admin queues (listings, orders, RFQ stream, audit append).

**Also shipped**: Storage rules for `marketplace/products/{uid}/…` and admin-only `marketplace/qc/…`; Firestore collection `marketplace_seller_order_requests` (server-written after COD or after Razorpay payment); trigger `onUserMarketplaceSellerSuspended` delists live catalog rows for that seller’s published listings.

---

## 18. Server-side checkout & Razorpay (implemented)

**Cloud Functions** (`functions/src/marketplacePayments.ts`, exported from `index.ts`):

| Export | Type | Purpose |
|--------|------|---------|
| `marketplaceCheckCodEligibility` | Callable | Authoritative COD gate from `config/marketplace_rules` + user `trustScore` + optional pincode. |
| `marketplacePlaceCodOrder` | Callable | Builds order from cart + live catalog prices; clears cart; status `awaiting_confirmation`. |
| `marketplaceCreateRazorpayCheckout` | Callable | Same cart validation; creates Razorpay order + Firestore order (`payment_pending`); clears cart. |
| `marketplaceVerifyRazorpayPayment` | Callable | HMAC verify (order id + payment id + signature); sets `paid`. |
| `marketplaceRazorpayWebhook` | HTTPS (`onRequest`) | Validates `X-Razorpay-Signature` with **raw body**; on `payment.captured` marks order `paid` (idempotent). |
| `marketplaceSellerRespondToOrderRequest` | Callable | Seller-only: `requestId` + `action` `accept` \| `reject`; updates `marketplace_seller_order_requests` (`open` → `accepted` / `rejected`). |

**FCM**: When a new `marketplace_seller_order_requests` doc is created, sellers receive payload `type: mp_seller_order_request` and `requestId` (deep link handled in `fcm_service.dart`).

**Firebase config**:

- Existing: `razorpay.key_id`, `razorpay.key_secret`
- New: `razorpay.webhook_secret` — from Razorpay Dashboard → Webhooks → signing secret  
  `firebase functions:config:set razorpay.webhook_secret "YOUR_SECRET"`

**Webhook URL**: deploy then register `https://<region>-<project>.cloudfunctions.net/marketplaceRazorpayWebhook` for event `payment.captured`.

**Firestore `config/marketplace_rules`** (optional document; defaults apply if missing):

- `cod_enabled` (bool, default true)
- `cod_max_amount_paise` (number, default 5_000_000)
- `cod_blocked_pincodes` (array of strings)
- `cod_min_trust_score` (number, default 0)

**Client**: `lib/features/marketplace/data/marketplace_checkout_service.dart` + updated `marketplace_checkout_screen.dart` (Razorpay Flutter on mobile; web → COD only messaging).

**Rules**: `marketplace_orders` / `lines` **create** denied for clients; superadmin may **update** for ops.
