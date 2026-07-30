# Agent instructions — DG Yard Connect

## Supabase (Shop + Calculator + PostgreSQL)

When the user asks to **add / edit / remove tables, columns, data, Edge Functions, or deploy Supabase**:

1. Open **`.cursor/skills/dgyard-supabase/SKILL.md`** and follow it end-to-end.
2. Run terminal commands yourself (`npm run deploy:supabase`, `npx supabase db push`) — do not only tell the user to paste SQL in Dashboard.
3. Update **`supabase/SCHEMA.md`** after schema changes.

**User prompt cookbook:** [`supabase/PROMPTS.md`](supabase/PROMPTS.md)

**Quick commands:**
```cmd
cd scripts
npm run deploy:supabase          :: full deploy
npm run supabase -- db-push      :: migrations only
npm run supabase:migration -- -Name "add_something"
```

## Firebase Connect (do not break)

- Auth, Firestore jobs/users/billing, marketplace — unchanged unless user explicitly asks.
- No Supabase Auth replacement.

## Admin modules

- **Connect** — existing Firebase admin
- **Shop** — Supabase (`lib/features/shop/`)
- **Calculator** — Supabase (`lib/features/calculator/`)
