# AI Business OS — Phase 1

## Routes (admin embedded shell)

| Route | Module |
|-------|--------|
| `/admin/ai-os` | Overview dashboard |
| `/admin/ai-os/crm` | AI CRM |
| `/admin/ai-os/leads` | Lead Management |
| `/admin/ai-os/whatsapp` | WhatsApp AI |
| `/admin/ai-os/voice` | AI Voice |
| `/admin/ai-os/campaigns` | CSV/Excel Campaigns |
| `/admin/ai-os/knowledge` | Knowledge Base |
| `/admin/ai-os/proposals` | Proposal Generator |
| `/admin/ai-os/quotations` | Quotation & BOQ |
| `/admin/ai-os/marketing` | Digital Marketing AI |
| `/admin/ai-os/estimator` | Website & App Estimator |
| `/admin/ai-os/tickets` | Service & Tickets |
| `/admin/ai-os/projects` | Projects |
| `/admin/ai-os/reports` | Reports & Analytics |
| `/admin/ai-os/billing` | Subscription & Billing |
| `/admin/ai-os/marketplace` | SaaS Marketplace |
| `/admin/ai-os/settings` | Admin & Settings |

Open Admin → platform chip **AI Business OS**.

## ER (core)

```
bos_tenants 1──* bos_tenant_members
bos_tenants 1──* bos_leads ──> bos_contacts / bos_companies
bos_leads ──> bos_deals (on convert)
bos_tenants 1──* bos_deals / bos_projects / bos_tickets / …
```

Default tenant: DG.YARD `b0000000-0000-4000-8000-000000000001`.

## Auth

Firebase Auth → `exchange-firebase-token` JWT with `app_role`, `bos_tenant_id`, `bos_role`.

## Edge

- `bos-ai-qualify` — lead score + summary (+ optional OpenAI/Gemini)

## Flutter

`lib/features/ai_business_os/` — domain, data (`BosRepository`), admin screens.
