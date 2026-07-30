# AI Business OS — Phases 4–6

## Phase 4 — Delivery & support

- **Projects:** create / from won deal (auto milestones), status changes, milestones + tasks
- **Tickets:** priority, SLA hours, project + assignee, comments, status workflow
- Table: `bos_ticket_comments`

## Phase 5 — Voice & marketing

- **AI Voice:** queue with script + lead link; `bos-voice-complete` simulates Sarvam/Exotel completion + CRM activity
- **Marketing AI:** `bos-marketing-generate` produces headline/primary/CTA/hashtags (OpenAI optional)

## Phase 6 — SaaS packaging

- **Billing:** `bos-billing` — change_plan, create_invoice, set_status (activate/suspend), record_usage
- **Reports:** funnel + tickets/projects/campaigns/quote value KPIs
- **Marketplace:** install applies item (e.g. KB pack seed)

## Edge functions

| Function | Purpose |
|----------|---------|
| `bos-voice-complete` | Complete voice call + CRM |
| `bos-marketing-generate` | Ad/content copy |
| `bos-billing` | Plan / invoice / suspend |

## Migration

`20260730163414_ai_business_os_phase4_5_6.sql`
