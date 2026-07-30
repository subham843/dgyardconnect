# Supabase schema reference (DG Yard Connect)

Project: `xtnfmrourhzspehvhrkz`  
Identity: `firebase_uid` (Firebase Auth UID, JWT `sub`)

## Tables

### Platform
| Table | Purpose |
|-------|---------|
| `platform_users` | Firebase user mirror (`firebase_uid` unique) |
| `admin_audit_log` | Admin change log |

### Catalog (shared: Shop + Calculator + Quotations)
| Table | Purpose |
|-------|---------|
| `categories` | Top-level category + SEO; `image_storage_path`, `image_url`, `og_image` (from `shop-media` uploads) |
| `sub_categories` | FK → `categories`; `description`; `default_hsn_code`; `default_gst_percentage`; SEO; image storage paths |
| `product_media_assets` | Product gallery, datasheets, brochures (`shop_media_type` enum) |
| `brands` | Product brands; `logo_url`, `logo_mime_type`, `logo_scale`, `logo_offset_x/y`, `logo_background_color`, `short_description`, `is_featured_on_homepage`, `display_order` |
| `attribute_master` | Reusable attribute definitions |
| `attribute_options` | Select / multi-select options |
| `attribute_groups` | Group of attributes |
| `attribute_group_attributes` | FK group + attribute |
| `sub_category_attribute_groups` | Assign groups to sub_category |
| `products` | Product master (SKU unique): `model_name`, pricing, GST override, SEO, serial/batch flags, `online_price`; legacy `calculator_family_id` kept as primary |
| `product_calculator_families` | Many-to-many: product ↔ calculator families (Hard Disk → HD CCTV + IP CCTV + …) |
| `product_attributes` | Per-product attribute values |
| `product_images` | Denormalized product image URLs (synced from uploads) |
| `inventory` | Stock summary per product (`qty_on_hand`, `avg_cost`) — updated by receipt lines |

### Shop ERP (inventory, parties, purchases, quotes, accounting)
| Table | Purpose |
|-------|---------|
| `suppliers` | Vendor master |
| `customers` | CRM customer master (shop quotations) |
| `inventory_receipts` | Purchase header (supplier, invoice no, date) |
| `inventory_receipt_lines` | Stock-in lines → FIFO lots; never creates duplicate products |
| `inventory_receipt_serials` | Serial numbers per receipt line |
| `stock_lots` | FIFO layers (`qty_remaining`, `unit_cost`, batch) |
| `product_serials` | Serial registry + warranty dates |
| `inventory_movements` | Stock ledger (purchase_in, sale_out, …) |
| `shop_quotations` | Shop quotes (not calculator `quotations`) |
| `shop_quotation_lines` | Quote line items |
| `ledger_accounts` | Chart of accounts |
| `journal_entries` | Journal header |
| `journal_lines` | Debit/credit lines |

### Shop commerce
| Table | Purpose |
|-------|---------|
| `shop_carts` | Active cart per `firebase_uid` |
| `shop_cart_items` | Cart lines |
| `shop_orders` | Orders |
| `shop_order_items` | Order line snapshots |

### Calculator
| Table | Purpose |
|-------|---------|
| `calculator_families` | HD CCTV, IP CCTV, … (public read when `is_active`) |
| `calculator_question_groups` | Named sections per family (Camera, Storage, Accessories); order via `sort_order` / `reorder_calculator_question_groups` RPC |
| `calculator_family_attributes` | Family ↔ Shop attrs; `selected_options` subset; `question_mode`; optional `group_id` |
| `calculator_family_option_paths` | Per-option quotation path (e.g. Camera Type = HD) |
| `calculator_family_option_path_attributes` | Optional shop-attribute follow-ups for a path |
| `calculator_family_option_path_questions` | Questions created for a path (shown when that option is selected) |
| `calculator_templates` | Versioned templates |
| `calculator_questions` | Dynamic questions |
| `calculator_rule_groups` | Admin folders for rules under an option (Recorders, Power, …) |
| `calculator_rules` | Rule engine; optional `option_scope_*` + `rule_group_id` |
| `calculator_rule_products` | Rule → product links |
| `calculator_sessions` | Runtime answers |
| `quotations` | Calculator saved quotes (`customer_name`, `customer_address`, `customer_phone` for PDF "Prepared for") |
| `quotation_lines` | Calculator quote lines |

### SEO Services Engine
| Table | Purpose |
|-------|---------|
| `seo_services` | Installation service types (CCTV, networking, …) + content/SEO templates |
| `seo_cities` | Service cities with geo, SEO overrides, FAQ, business copy |
| `seo_city_nearby` | Nearby city internal linking (many-to-many) |
| `seo_city_services` | Which services are offered in which cities (navbar, landing pages, sitemap) |
| `seo_blog_posts` | SEO articles tagged by city/service slugs for related links |

## Views (reports)
| View | Purpose |
|------|---------|
| `v_inventory_stock_report` | Stock on hand, value, FIFO lots, serials |
| `v_purchase_register` | Posted purchase lines |
| `v_gst_summary` | Monthly input GST |

## Public views (anonymous storefront read)
| View | Purpose |
|------|---------|
| `v_public_categories` / `v_public_subcategories` | Active taxonomy + images + SEO |
| `v_public_products` | Active products, public pricing only; includes `main_image_placements` + editor source for storefront framing |
| `v_public_product_images` | Gallery URLs for active products |
| `v_public_product_attributes` | Auto-extracted/admin specs for active products |
| `v_public_product_media` | Datasheet/brochure PDFs (documents) for active products; downloads via public `shop-media` bucket |
| `v_public_seo_services` | Active installation services for public hub + landing pages |
| `v_public_seo_cities` | Active service-available cities |
| `v_public_seo_city_nearby` | Nearby city links for internal linking |
| `v_public_seo_city_services` | Cities available per service (admin-mapped) |
| `v_public_seo_landing_urls` | Mapped city × service URLs for sitemap (`/{city}/{service}`) |
| `v_public_seo_blog_posts` | Active blog posts for `/blog/{slug}` |

## Enums
- `attribute_data_type`: text, long_text, number, select, multi_select, bool, date
- `shop_order_status`: draft, pending_payment, paid, processing, shipped, delivered, cancelled
- `calculator_rule_type`: suggest, formula, visibility, dependency, recommendation
- `quotation_status`: draft, sent, accepted, rejected, expired (calculator)
- `inventory_valuation_method`: fifo, weighted_average
- `inventory_movement_type`: purchase_in, purchase_return, sale_out, …
- `product_serial_status`: in_stock, reserved, sold, …
- `shop_quotation_status`: draft, sent, accepted, rejected, expired, converted
- `ledger_account_type`: asset, liability, equity, income, expense
- `journal_source_type`: inventory_receipt, shop_order, shop_quotation, manual

## Functions (SQL)
- `set_updated_at()` — trigger helper
- `seed_product_attributes_on_insert()` — on `products` INSERT
- `resolve_product_gst_percentage(product_id)` — subcategory default vs product override
- `apply_inventory_receipt_line_core(line_id)` — post stock from receipt line
- `finalize_inventory_receipt(receipt_id)` — draft → posted, apply lines, journal
- `consume_stock_fifo(product_id, qty, …)` — FIFO issue for sales
- `auth_firebase_uid()`, `auth_is_superadmin()` — RLS helpers

## Edge Functions
| Name | Path | Purpose |
|------|------|---------|
| `exchange-firebase-token` | `supabase/functions/exchange-firebase-token/` | Firebase ID token → Supabase JWT (+ optional `bos_tenant_id` / `bos_role`) |
| `shop-razorpay` | `supabase/functions/shop-razorpay/` | Create/verify Razorpay payment for `shop_orders` (secrets: `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`) |
| `bos-ai-qualify` | `supabase/functions/bos-ai-qualify/` | AI Business OS lead qualification (OpenAI/Gemini optional; heuristic fallback) |
| `bos-whatsapp-webhook` | `supabase/functions/bos-whatsapp-webhook/` | Meta WA webhook verify + inbound ingest (+ test payload) |
| `bos-whatsapp-reply` | `supabase/functions/bos-whatsapp-reply/` | AI reply from tenant KB (optional Meta send) |
| `bos-campaign-run` | `supabase/functions/bos-campaign-run/` | Launch campaign; opt-out skip; optional voice queue |
| `bos-kb-reindex` | `supabase/functions/bos-kb-reindex/` | Chunk KB docs; Qdrant upsert stub (BGE-M3-ready) |
| `bos-proposal-draft` | `supabase/functions/bos-proposal-draft/` | AI/template proposal from deal + lead + quotation + KB |
| `bos-voice-complete` | `supabase/functions/bos-voice-complete/` | Complete/simulate voice call + CRM/follow-up close-loop |
| `bos-voice-dial` | `supabase/functions/bos-voice-dial/` | Outbound dial (Exotel/Twilio when secrets set; else stub) |
| `bos-voice-script` | `supabase/functions/bos-voice-script/` | Generate outbound follow-up call script (OpenAI optional / heuristic) |
| `bos-marketing-generate` | `supabase/functions/bos-marketing-generate/` | Digital marketing copy from brief + KB |
| `bos-sales-orchestrate` | `supabase/functions/bos-sales-orchestrate/` | Auto qualify + WA/voice first touch + handover |
| `bos-sales-followups` | `supabase/functions/bos-sales-followups/` | Due follow-up sequence runner |
| `bos-ai-reply` | `supabase/functions/bos-ai-reply/` | Omnichannel AI reply + intent → CRM |
| `bos-chat-ingest` | `supabase/functions/bos-chat-ingest/` | Web/app chat ingest + lead create |
| `bos-campaign-ai-copy` | `supabase/functions/bos-campaign-ai-copy/` | AI campaign message generation |
| `bos-tenant-secrets` | `supabase/functions/bos-tenant-secrets/` | Per-tenant API config + masked secrets |
| `bos-invite-email` | `supabase/functions/bos-invite-email/` | Send invite via Resend/stub |

## Storage
| Bucket | Purpose |
|--------|---------|
| `shop-media` | Category/subcategory/product images, PDFs (public read; superadmin write) |

Paths: `categories/{id}/`, `subcategories/{id}/`, `products/{id}/main|gallery|datasheets|brochures/`

## Flutter mapping
| Layer | Path |
|-------|------|
| Config | `lib/core/supabase/` |
| Shop repo | `lib/features/shop/data/` |
| Shop ERP repo | `lib/features/shop/data/shop_erp_repository.dart` |
| Calculator repo | `lib/features/calculator/data/` |
| SEO engine repo/UI | `lib/features/seo/` |
| Admin Shop UI | `lib/features/shop/admin/` |
| Shop ERP admin | `lib/features/shop/admin/erp/` |
| Shop media (upload/editor) | `lib/features/shop/admin/media/`, `lib/features/shop/data/shop_media_*.dart` |
| Platform editing (Google images + assist) | `lib/core/editing/`, Edge Function `platform-text-assist` |
| `shop_ai_knowledge` | Learned SEO/copy from AI assist (reuse without external API) |
| Architecture doc | `supabase/docs/shop-erp/ARCHITECTURE.md` |

## AI Business OS (`bos_*`) — multi-tenant SaaS

Identity: Firebase UID + JWT claims `bos_tenant_id`, `bos_role`. Default tenant: DG.YARD `b0000000-0000-4000-8000-000000000001`.

**Auth bridge:** `exchange-firebase-token` accepts optional `bosTenantId`; resolves membership (superadmin → owner on requested/default tenant; others → active membership with fallback). Flutter `SupabaseAuthService.setActiveBosTenant` re-exchanges JWT when tenant/role claims drift. Session exposes `activeBosTenantId` / `activeBosRole`.

**CRM MVP notes:** Customers = `bos_companies` + `bos_contacts`. Lead board stages map `won` → “converted”. Deal win probability stored in `bos_deals.meta.probability` (no extra column). Pipeline seeds in `bos_pipeline_stages` (auto-ensured per tenant from Flutter if empty). Member/CRM mutations write `bos_audit_log`. RBAC: role → capabilities in `bos_capabilities.dart` / `bos_permissions.dart` (includes `products.view|manage`). Plan module gating via `bos_plans.features.modules` + `BosFeatureFlags` filters AI OS Mega Menu. Departments: `bos_departments` + `bos_tenant_members.department_id`. Invites: `bos_tenant_invites` + RPC `bos_accept_invite` (copy-link accept at `/admin/ai-os/accept-invite?token=`).

**CRM complete notes:** Unified timeline via `bos_activities` (`addActivity` / `listActivities` for lead/contact/deal; company timeline aggregates contact+deal activities). Lead follow-ups use `bos_leads.next_follow_up_at`. Deal→quotation close-loop: `createQuotationFromDeal` writes `bos_quotations` + activity + `bos_audit_log` action `deal.quote_create` (no migration).

**AI follow-up + call:** `queueFollowUpCall` → `bos_voice_calls` with AI script (`bos-voice-script`) + `scheduled_at` → `bos-voice-dial` when due. Complete via `bos-voice-complete` outcomes `interested|callback|not_interested|no_answer` clears or reschedules follow-up and writes CRM activity.

**Phase B onboarding:** Public trial at `/ai-os/trial` → Firebase signup → RPC `bos_bootstrap_tenant` (tenant status `trial`, starter plan, owner member, 14-day `trialing` subscription, pipeline stages, departments). Wizard `/admin/ai-os/onboarding` → `bos_complete_onboarding` sets `settings.onboarding_completed`. Hub shows quick actions + setup banner when incomplete.

**Phase C billing:** `bos-billing` Edge — `create_checkout` / `verify_payment` (Razorpay + 18% CGST/SGST on `bos_invoices`), `usage_summary`, `mrr_overview` (superadmin). Invoice columns: `taxable_paise`, `cgst_paise`, `sgst_paise`, `igst_paise`, `gst_rate_pct`, `razorpay_*`. Flutter Billing: Pay & upgrade via Shop Razorpay launcher; usage meters; Super Admin MRR card.

**AI Sales Agent:** Lead create → `bos-sales-orchestrate` (qualify + WA first touch and/or voice queue + `meta.handover_ready`). WA inbound webhook creates/links lead + reply + CRM update. Voice complete stores transcript/summary/interest in `meta`. Due follow-ups via `bos-sales-followups`. Settings `ai_sales` JSON. Hub AI KPIs; Leads **AI Queue** filter. No parallel `ai_*` tables.

**Omnichannel marketing:** Chat via `bos_conversations.channel` (`whatsapp|web|app|facebook|instagram`) + `bos-chat-ingest` / `bos-ai-reply` (intent → CRM). Campaigns `channel` `whatsapp|sms|email` + `segment` JSON; `bos-campaign-run` stub-first providers; delivery in `bos_campaign_recipients.delivery_status` + `bos_outbound_events`. Templates `bos_wa_templates.channel`. Sequence in `settings.ai_sales.sequence`. Public chat `/ai-os/chat`.

**SaaS multi-tenant control:** Extend `bos_tenants` (gstin, business_type, contact_*, address) + `bos_tenant_settings.api_config` / `api_secrets` (per-company WA/SMS/Email/Voice; Edge `bos-tenant-secrets` + resolve in campaign/reply). `settings.ai_agent` persona. Usage via `bos_usage_events` from AI/voice/campaign Edges. Super Admin Hub platform KPIs (companies, MRR, usage). Trial signup + onboarding collect GST/logo. No parallel `tenants`/`companies`/`api_configurations` tables.

**Voice multi-provider:** Tenant secrets under `api_secrets.voice.<provider>` (`exotel` | `twilio` | `plivo` | `vonage` | `knowlarity` | `myoperator`). Active provider in `api_config.voice.provider`. `bos-voice-dial`: Exotel/Twilio/Plivo/Knowlarity/MyOperator live; Vonage RS256 JWT from tenant private key (`_shared/vonage_jwt.ts`). Settings: masked saved keys + Test dial + **Verify keys** (`bos-voice-verify`) + **webhook URL copy** + **Sarvam TTS preview** (`bos-voice-tts`). Webhooks `bos-voice-webhook` (Twilio/Exotel status/recording → events in `bos_voice_events`; inbound/missed → find/create lead + call row; outbound recording → `bos-voice-complete` Sarvam STT). Soft-delete via `bos_voice_calls.deleted_at`. Sales/campaigns use tenant voice provider. Reports: voice live/stub/STT/inbound/avg duration.

**Phase D CRM + harden + RAG:** Tasks/calendar (`bos_activities.due_at` UI). Configurable deal stages (`bos_deals.stage` text + stage CRUD). Lead merge RPC `bos_merge_leads`. Attachments `bos_attachments` + storage bucket `bos-attachments` (Flutter file upload + URL link). Plan limits `bos_assert_lead_limit` / `bos_assert_user_limit` + Edge `assertUsageLimit` + Billing upgrade CTA. Invite email `bos-invite-email` (sent/stub feedback in UI). KB embeddings on chunks + vector/keyword retrieve in `bos-ai-reply` with **citations** in response/Inbox/public chat. Voice dial `bos-voice-dial` (Exotel/Twilio when tenant secrets set; else stub). Campaign run marks live API failures as `failed`; optional voice auto-dial. Reports: usage 30d + delivery breakdown + Super Admin block.

| Table | Purpose |
|-------|---------|
| `bos_plans` | SaaS plan catalog (`features.modules`, `limits`) |
| `bos_tenants` | Companies (isolated data/branding; gstin, business_type, contact, address, logo) |
| `bos_tenant_members` | firebase_uid ↔ tenant + role + optional `department_id` |
| `bos_departments` | Tenant departments (Sales/Support/Operations seeded for DG.YARD) |
| `bos_tenant_invites` | Email invites + token (pending/accepted/revoked/expired); accept via `bos_accept_invite` |
| `bos_subscriptions` / `bos_invoices` / `bos_usage_events` | Billing + usage meters (ai_messages, voice_minutes, api_calls) |
| `bos_tenant_settings` | settings JSON (`ai_sales`, `ai_agent`) + `api_config` + `api_secrets` |
| `bos_audit_log` | Tenant-scoped audit (member + CRM + invite/department mutations) |
| `bos_leads` / `bos_lead_activities` / `bos_lead_assignments` | Lead management |
| `bos_contacts` / `bos_companies` / `bos_deals` / `bos_activities` / `bos_notes` | AI CRM (customer master + pipeline) |
| `bos_pipeline_stages` | Configurable deal stages (seeded; admin CRUD) |
| `bos_attachments` | Lead/deal/contact file links (bucket `bos-attachments`) |
| `bos_conversations` / `bos_messages` | Omnichannel chat (`whatsapp|web|app|facebook|instagram`) |
| `bos_wa_templates` | Message templates (`channel`: whatsapp/sms/email) |
| `bos_opt_outs` | Campaign / channel opt-out list |
| `bos_campaigns` / `bos_campaign_recipients` | Bulk campaigns (WA/SMS/Email + `segment`) |
| `bos_outbound_events` | Delivery/open/click/reply analytics events |
| `bos_kb_documents` / `bos_kb_chunks` | Knowledge base + chunk/reindex (Qdrant-ready) |
| `bos_quotations` / `bos_quotation_lines` | Quotation & BOQ |
| `bos_proposals` / `bos_proposal_templates` / `bos_estimates` | Proposals + website/app estimator |
| `bos_projects` / `bos_project_milestones` / `bos_project_tasks` | Projects |
| `bos_tickets` / `bos_ticket_comments` | Service & tickets |
| `bos_voice_calls` | AI Voice (`script`, `outcome`, `scheduled_at`, `deleted_at`; dial/webhook/STT) |
| `bos_voice_events` | Webhook/status event log (provider callbacks, inbound/missed) |
| `bos_marketing_campaigns` | Digital Marketing AI |
| `bos_marketplace_items` / `bos_marketplace_installs` | SaaS template marketplace |

RLS helpers: `bos_auth_tenant_id()`, `bos_auth_member_role()`, `bos_is_member(tenant_id)`, `bos_tenant_ok(tenant_id)`.

Flutter: `lib/features/ai_business_os/`. Admin module: `AdminModule.aiBusinessOs`.  
Docs: `docs/ai-business-os/PHASE1.md`.

## Adding a new table (agent checklist)
1. New file in `supabase/migrations/`
2. Enable RLS + policies
3. Update this file
4. `npx supabase db push`
5. Optional: repository + admin screen in Flutter
