# Supabase — DG Yard Connect unified platform

## Setup

### Deploy from Command Prompt (recommended — Firebase jaisa)

See **[DEPLOY_CLI.md](DEPLOY_CLI.md)** for full steps.

```cmd
cd e:\dgyardconnect\scripts
npm run deploy:supabase
```

(Pehle `supabase/.env` banao from `.env.example` with JWT Secret.)

---

### Tables empty in Supabase Dashboard?

The Flutter app only **connects** to Supabase. **Tables are created by SQL migrations** — they are not uploaded automatically.

**CLI:** `npx supabase db push` from repo root.

**Manual (SQL Editor):**

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project `xtnfmrourhzspehvhrkz`
2. Go to **SQL Editor** → **New query**
3. Open [`apply_all_schema.sql`](apply_all_schema.sql) from this repo, copy **all** contents, paste into the editor
4. Click **Run** (should succeed with no errors)
5. Refresh **Table Editor** — you should see ~20 tables (`categories`, `products`, `shop_orders`, `calculator_families`, etc.)

Or run files one by one in order: `migrations/001_platform.sql` … `006_seed_calculator.sql`.

1. Create a Supabase project and run migrations in order under `migrations/`.
2. Deploy Edge Function `exchange-firebase-token` with secrets:
   - `FIREBASE_PROJECT_ID`
   - `SUPABASE_JWT_SECRET` (Dashboard → Settings → API → JWT Secret)
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. **Permanent Flutter config** — defaults are in [`lib/core/supabase/supabase_config.dart`](../lib/core/supabase/supabase_config.dart). No `--dart-define` needed:

```bash
flutter run -d chrome
```

   Cursor/VS Code: use **dgyardconnect (Chrome)** in [`.vscode/launch.json`](../.vscode/launch.json) (optional `dart_defines.json` override).

   To change project/key: edit `_defaultUrl` / `_defaultAnonKey` in `supabase_config.dart`, or copy [`dart_defines.example.json`](../dart_defines.example.json) → `dart_defines.json`.

## Remote Config (Firebase)

Add to `feature_flags_json`:

```json
{
  "supabase_shop_enabled": true,
  "hide_marketplace_buyer": true
}
```

## Architecture

- Firebase Auth remains the only login system.
- `firebase_uid` is stored in `platform_users` and used as JWT `sub` for RLS.
- Shop, Calculator, and Quotations share the `products` catalog in PostgreSQL.
