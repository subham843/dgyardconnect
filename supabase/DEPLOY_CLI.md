# Supabase deploy — Command Prompt (Firebase jaisa)

> **Future changes via Cursor prompt:** see [`PROMPTS.md`](PROMPTS.md) and [`AGENTS.md`](../AGENTS.md).  
> Agent skill: `.cursor/skills/dgyard-supabase/SKILL.md`

Bina SQL copy-paste ke, terminal se tables + Edge Function deploy karein.

## Pehli baar (ek baar)

### 1) Node.js installed hona chahiye

```cmd
node -v
npm -v
```

### 2) `supabase/.env` banao

```cmd
cd e:\dgyardconnect\supabase
copy .env.example .env
```

`.env` kholo, **do cheezein** paste karo:

1. **Personal Access Token** (deploy ke liye zaroori, khaas kar Windows par)  
   Dashboard → **Account** → **Access Tokens** → Generate  
   ```env
   SUPABASE_ACCESS_TOKEN=sbp_...
   ```

2. **JWT Secret** (Edge Function ke liye)  
   Dashboard → **Project Settings** → **API** → **JWT Secret**  
   (ye anon key `sb_publishable_...` **nahi** hai)

Example:

```env
SUPABASE_ACCESS_TOKEN=sbp_your_token_here
FIREBASE_PROJECT_ID=dgyard-connect
SUPABASE_JWT_SECRET=your-long-jwt-secret-here
```

### 3) Supabase login (browser khulega)

```cmd
cd e:\dgyardconnect
npx supabase@latest login
```

### 4) Project link

```cmd
npx supabase@latest link --project-ref xtnfmrourhzspehvhrkz
```

---

## Har baar deploy (schema + function)

### Option A — ek command (recommended)

```cmd
cd e:\dgyardconnect\scripts
npm run deploy:supabase
```

Ye automatically karega:

1. `supabase db push` — saari tables banayega  
2. `supabase secrets set` — `.env` se secrets  
3. `supabase functions deploy exchange-firebase-token`

### Option B — alag commands (Firebase style)

**Sirf database (tables):**

```cmd
cd e:\dgyardconnect
npx supabase@latest db push
```

**Sirf Edge Function:**

```cmd
cd e:\dgyardconnect
set SUPABASE_ACCESS_TOKEN=sbp_your_token
npx supabase@latest secrets set --project-ref xtnfmrourhzspehvhrkz FIREBASE_PROJECT_ID=dgyard-connect JWT_SECRET=your_jwt_secret
npx supabase@latest functions deploy exchange-firebase-token --project-ref xtnfmrourhzspehvhrkz --no-verify-jwt
```

---

## Firebase vs Supabase commands

| Kaam | Firebase | Supabase (is project) |
|------|----------|------------------------|
| Login | `firebase login` | `npx supabase login` |
| Deploy backend | `cd functions && npm run deploy` | `cd scripts && npm run deploy:supabase` |
| Sirf DB | — | `npx supabase db push` |
| Sirf function | `firebase deploy --only functions` | `npx supabase functions deploy exchange-firebase-token` |

---

## Verify

1. Dashboard → **Table Editor** → `categories`, `products`, …  
2. Dashboard → **Edge Functions** → `exchange-firebase-token`  
3. App restart → Admin → Shop → Category add

---

## Common errors

| Error | Fix |
|-------|-----|
| `supabase not found` | `npx supabase@latest` use karo (global install zaroori nahi) |
| `Not logged in` | `npx supabase login` |
| `Access token not provided` (secrets/functions) | `supabase/.env` me `SUPABASE_ACCESS_TOKEN=sbp_...` (Account → Access Tokens); phir `npm run deploy:supabase` |
| `project not linked` | `npx supabase link --project-ref xtnfmrourhzspehvhrkz` |
| `Env name cannot start with SUPABASE_` | Deploy script ab `JWT_SECRET` use karta hai; dubara `npm run deploy:supabase` |
| Function deploy path not found | `--workdir` repo root hona chahiye (`e:\dgyardconnect`), `supabase\supabase\...` nahi |
| `Could not find table public.categories` (app) | `db push` galat workdir se chala — `migration list` me 001–006 dikhe; phir `npm run deploy:supabase` ya `db push` dubara |
| Function 401 in app | `supabase/.env` me sahi JWT Secret + secrets deploy dubara |
