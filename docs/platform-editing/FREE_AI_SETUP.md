# Free AI text assist (no billing card)

Shop admin **✨ AI assist** uses Supabase Edge Function `platform-text-assist`.

You only need **one** free key in Supabase secrets (Groq recommended).

## Option 1 — Groq (recommended, free tier)

1. Open [https://console.groq.com](https://console.groq.com)
2. Sign up (Google/GitHub)
3. **API Keys** → **Create API Key**
4. Copy key (`gsk_...`)

**Supabase**

1. [Supabase Dashboard](https://supabase.com/dashboard) → project **xtnfmrourhzspehvhrkz**
2. **Edge Functions** → **Secrets**
3. Add:
   - Name: `GROQ_API_KEY`
   - Value: your `gsk_...` key

Optional secrets:

| Name | Example |
|------|---------|
| `GROQ_MODEL` | `llama-3.3-70b-versatile` |
| `TEXT_AI_PROVIDER` | `groq` (force Groq only) |

**CLI**

```cmd
cd e:\dgyardconnect
npx supabase secrets set GROQ_API_KEY=gsk_your_key_here --project-ref xtnfmrourhzspehvhrkz
npx supabase functions deploy platform-text-assist --no-verify-jwt
```

---

## Option 2 — Google Gemini (free API key)

1. Open [https://aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Sign in with Google
3. **Create API key** (no credit card for free quota in many regions)
4. Copy key (`AIza...`)

**Supabase secret**

- Name: `GEMINI_API_KEY`
- Value: your key

Optional: `GEMINI_MODEL` = `gemini-2.0-flash`

If both Groq and Gemini are set, **Groq is tried first**, then Gemini.

---

## Option 3 — OpenAI (paid / billing)

Only if you already have billing:

- Secret: `OPENAI_API_KEY` = `sk-proj-...`

---

## Provider order (automatic)

```
GROQ_API_KEY → GEMINI_API_KEY → OPENAI_API_KEY → basic local rules
```

Force one provider: set `TEXT_AI_PROVIDER` to `groq`, `gemini`, or `openai`.

---

## Test in app

1. Login as **superadmin**
2. Shop → edit category/product
3. Text field → **✨** → **Fix spelling** or **Suggest SEO title**
4. Preview → **Apply**

If AI works, response includes `"provider":"groq"` or `"gemini"` in network tab (optional).

---

## DG Yard learned AI (your own database)

Every successful AI answer is saved in Supabase table `shop_ai_knowledge`.

Next time the **same text + action** is requested, the app answers from **your database** (`provider: dg-yard-learned`) — **no Groq/Gemini call**.

This is not a full custom LLM, but it **learns your approved copy** over time and cuts API usage sharply.

---

## Limits

- Free tiers have **rate limits** (requests per minute/day)
- For heavy use, add a second provider key or upgrade plan
- Never put API keys in Flutter code or git — **Supabase secrets only**
- **Rotate keys** if they were shared in chat or email
