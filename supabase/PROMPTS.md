# Supabase — copy-paste prompts for Cursor Agent

Likh kar bhejo — agent ko [`.cursor/skills/dgyard-supabase/SKILL.md`](../.cursor/skills/dgyard-supabase/SKILL.md) follow karna chahiye aur terminal se deploy karna chahiye.

## Deploy / fix empty database

```
Supabase par saari migrations deploy karo (db push + edge function). 
Agar .env missing ho to batao kya chahiye.
```

## New table

```
Supabase me table "vendor_payments" add karo: id uuid, firebase_uid text, 
amount numeric, status text, created_at. RLS lagao, SCHEMA.md update karo, 
db push chalao.
```

## New column

```
products table me column "discount_percent" numeric default 0 add karo — 
migration banao aur db push chalao.
```

## Seed data

```
categories me seed karo: CCTV, Networking, Accessories. 
Idempotent migration banao aur deploy karo.
```

## Edge Function

```
exchange-firebase-token function me role check improve karo, 
deploy karo, secrets .env se set karo.
```

## Flutter admin screen

```
Admin Shop module me "Coupons" CRUD screen add karo — Supabase table 
shop_coupons (pehle migration), routes + repository + list/FAB dialog.
```

## Calculator rule

```
IP CCTV template me naya formula rule add karo: output_key fiber_qty, 
expression camera_qty * 10 — migration seed + calculator_rules row.
```

## Remove / soft-delete

```
products ko hard delete mat karo — is_active false pattern use karo, 
admin list me filter lagao.
```

## Full feature (end-to-end)

```
Shop me "Wishlist" feature: table shop_wishlists, RLS, repository, 
user screen heart icon on product detail, deploy supabase.
```

---

**Note:** Agent must run `npm run deploy:supabase` (or `npx supabase db push`) after SQL changes — SQL Editor manual paste zaroori nahi.
