# AI Business OS — Phase 2

WhatsApp AI, CSV campaigns, and Knowledge Base (Qdrant-ready).

## Edge Functions

| Function | Purpose |
|----------|---------|
| `bos-whatsapp-webhook` | Meta verify (`hub.challenge`) + inbound message ingest; `POST {test_phone,test_body}` for local sim |
| `bos-whatsapp-reply` | Draft AI reply from KB; optional Meta Cloud send (`WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`) |
| `bos-campaign-run` | Launch campaign to pending recipients; skip `bos_opt_outs`; optional voice queue |
| `bos-kb-reindex` | Chunk docs into `bos_kb_chunks`; optional Qdrant upsert (`QDRANT_URL`, `QDRANT_API_KEY`) |

Webhook URL example:
`https://xtnfmrourhzspehvhrkz.supabase.co/functions/v1/bos-whatsapp-webhook?tenant_id=b0000000-0000-4000-8000-000000000001`

Verify token default: `dgyard-bos-wa` (override with `WHATSAPP_VERIFY_TOKEN`).

## Admin UI

- **WhatsApp AI** — conversation list + thread, send, AI reply, simulate inbound
- **Campaigns** — CSV recipients, templates, launch, opt-outs, optional voice trigger
- **Knowledge Base** — collection filter, CRUD, reindex / view chunks

## New tables

- `bos_wa_templates`, `bos_opt_outs`, `bos_kb_chunks`
- Campaign counters: `sent_count`, `failed_count`, `skipped_opt_out`
- KB: `reindex_status`, `chunk_count`, `last_reindexed_at`
