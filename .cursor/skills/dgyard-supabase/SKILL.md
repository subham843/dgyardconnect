---
name: dgyard-supabase
description: >-
  Manage DG Yard Connect Supabase (PostgreSQL schema, migrations, Edge Functions,
  seed data, Flutter shop/calculator repos). Use when the user asks to add/edit/remove
  tables, columns, RLS, functions, deploy Supabase, or change shop/calculator data layer.
  Never migrate Firebase Auth or Firestore Connect data.
---

# DG Yard Supabase — Agent Playbook

## Hard constraints (never break)

- **Firebase Auth stays** — no Supabase Auth login screens.
- **Do not migrate or change** Firestore Connect (jobs, users, billing, marketplace).
- **Firebase UID** = `firebase_uid` / JWT `sub` in Supabase.
- After schema changes: **migration SQL** + `db push` + update Dart repos/models if needed.

## Project map

| What | Where |
|------|--------|
| Migrations (source of truth) | `supabase/migrations/*.sql` |
| One-shot full schema | `supabase/apply_all_schema.sql` |
| Edge Function | `supabase/functions/exchange-firebase-token/` |
| CLI config | `supabase/config.toml` (project `xtnfmrourhzspehvhrkz`) |
| Deploy script | `scripts/deploy-supabase.ps1` → `npm run deploy:supabase` |
| Flutter config | `lib/core/supabase/` |
| Shop repos/UI | `lib/features/shop/` |
| Calculator repos/UI | `lib/features/calculator/` |
| Schema reference | `supabase/SCHEMA.md` |
| User prompt examples | `supabase/PROMPTS.md` |

## When user asks X → do Y

### New table / column / index / FK

1. Read `supabase/SCHEMA.md` — avoid duplicates.
2. Create **new** file: `supabase/migrations/YYYYMMDDHHMMSS_short_name.sql`  
   (use `scripts/supabase-new-migration.ps1 -Name "add_xyz"`).
3. SQL only **forward** changes (`CREATE`, `ALTER ADD`, not destructive unless asked).
4. Update RLS in same migration if table is new (copy pattern from `005_rls.sql`).
5. Update `supabase/SCHEMA.md` table list.
6. Run: `npm run deploy:supabase` or `npx supabase db push` from repo root.
7. If user-facing: add/update Dart model + repository under `shop/` or `calculator/`.

### Edit / remove column or table

1. Confirm with migration (prefer `ALTER` / soft-delete `is_active`, avoid `DROP` unless explicit).
2. Update Flutter code that references column.
3. `db push` + deploy.

### Seed / sample data (INSERT)

1. Prefer new migration `*_seed_*.sql` or idempotent `INSERT ... ON CONFLICT`.
2. Never seed production secrets in repo.
3. `db push`.

### New / edit Edge Function

1. Edit `supabase/functions/<name>/index.ts`.
2. Register in `supabase/config.toml` if new function.
3. Secrets: `supabase/.env` → `npx supabase secrets set --env-file supabase/.env`
4. `npx supabase functions deploy <name> --no-verify-jwt` (exchange-firebase-token uses `--no-verify-jwt`).

### Deploy everything (user: "deploy supabase" / "tables nahi dikh rahi")

```cmd
cd e:\dgyardconnect\scripts
npm run deploy:supabase
```

Requires `supabase/.env` with `SUPABASE_JWT_SECRET` (see `.env.example`).

### Flutter-only feature (new admin screen / shop page)

1. Do **not** change Connect/Firebase auth screens.
2. New routes in `lib/core/constants/route_names.dart` + `lib/shared/router/app_router.dart`.
3. Repository → domain model → UI (mirror `lib/features/shop/data/shop_catalog_repository.dart`).

## Commands (run in terminal — do not ask user to paste SQL manually)

| Task | Command |
|------|---------|
| Full deploy | `cd scripts && npm run deploy:supabase` |
| DB only | `npx supabase db push` (repo root) |
| New migration file | `powershell -File scripts/supabase-new-migration.ps1 -Name "describe_change"` |
| Function only | `npx supabase functions deploy exchange-firebase-token --no-verify-jwt` |
| Login / link (once) | `npx supabase login` then `npx supabase link --project-ref xtnfmrourhzspehvhrkz` |

## RLS pattern for new tables

```sql
ALTER TABLE new_table ENABLE ROW LEVEL SECURITY;
-- read: authenticated firebase uid in JWT
CREATE POLICY new_table_read ON new_table FOR SELECT
  USING (auth_firebase_uid() <> '' OR auth_is_superadmin());
-- write: superadmin only (admin panel)
CREATE POLICY new_table_write ON new_table FOR ALL
  USING (auth_is_superadmin()) WITH CHECK (auth_is_superadmin());
-- user-owned rows: firebase_uid column
CREATE POLICY new_table_owner ON new_table FOR ALL
  USING (firebase_uid = auth_firebase_uid() OR auth_is_superadmin())
  WITH CHECK (firebase_uid = auth_firebase_uid() OR auth_is_superadmin());
```

## Response checklist after completing user request

1. What migration file was created/changed.
2. Whether `db push` / deploy was run (or tell user to run `npm run deploy:supabase`).
3. What Flutter files were updated (if any).
4. How to verify in Supabase Dashboard (table name).

## Additional references

- CLI guide: `supabase/DEPLOY_CLI.md`
- Example user prompts: `supabase/PROMPTS.md`
- Full schema doc: `supabase/SCHEMA.md`
