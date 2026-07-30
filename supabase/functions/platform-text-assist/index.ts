// Text assist + DG Yard learned knowledge (fewer external API calls).
// Secrets: GROQ_API_KEY (free), GEMINI_API_KEY (free), OPENAI_API_KEY (optional)

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type AssistAction =
  | "fix_spelling"
  | "improve_grammar"
  | "professional_rewrite"
  | "seo_optimize"
  | "shorten"
  | "expand"
  | "generate_product_description"
  | "generate_product_short_description"
  | "generate_category_description"
  | "generate_meta_description"
  | "suggest_seo_title"
  | "suggest_meta_description"
  | "suggest_slug"
  | "spell_check"
  | "capitalize";

type AssistContext = {
  productName?: string;
  categoryName?: string;
  brandName?: string;
  subCategoryName?: string;
  companyName?: string;
  companySite?: string;
};

type AssistBody = {
  action: AssistAction;
  text?: string;
  language?: "en" | "hi" | "auto";
  context?: AssistContext;
};

function seoGuidance(ctx: AssistContext): string {
  const company = ctx.companyName?.trim() || "DG Yard";
  const site = ctx.companySite?.trim() || "dgyard.com";
  const lines = [
    `Company/store: ${company} (${site}).`,
    ctx.brandName?.trim() ? `Manufacturer brand: ${ctx.brandName.trim()}.` : "",
    ctx.productName?.trim() ? `Product: ${ctx.productName.trim()}.` : "",
    ctx.categoryName?.trim() ? `Category: ${ctx.categoryName.trim()}.` : "",
    ctx.subCategoryName?.trim() ? `Sub-category: ${ctx.subCategoryName.trim()}.` : "",
    "SEO: weave company + brand naturally; title ≤60 chars e.g. [Product] | [Brand] | DG Yard; meta ≤155 chars with benefit + CTA; India CCTV/security B2B shop; no stuffing.",
  ].filter(Boolean);
  return lines.join(" ");
}

type AiProvider = "groq" | "gemini" | "openai";

function parseJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Invalid token");
  return JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
}

function requireSuperadmin(req: Request): void {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) throw new Error("Unauthorized");
  const payload = parseJwtPayload(auth.slice(7));
  const role = (payload.app_role ?? payload.role) as string | undefined;
  if (role !== "superadmin") throw new Error("Forbidden");
}

function adminClient(): SupabaseClient | null {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) return null;
  return createClient(url, key);
}

async function inputHash(body: AssistBody): Promise<string> {
  const payload = JSON.stringify({
    a: body.action,
    t: (body.text ?? "").trim(),
    l: body.language ?? "auto",
    c: body.context ?? {},
  });
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(payload));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function lookupLearned(
  admin: SupabaseClient,
  body: AssistBody,
): Promise<{ suggestion: string; suggestions?: string[] } | null> {
  const hash = await inputHash(body);
  const { data } = await admin
    .from("shop_ai_knowledge")
    .select("id, output_text, hit_count")
    .eq("action", body.action)
    .eq("input_hash", hash)
    .maybeSingle();

  if (!data?.output_text) return null;

  await admin
    .from("shop_ai_knowledge")
    .update({
      hit_count: (data.hit_count as number) + 1,
      updated_at: new Date().toISOString(),
    })
    .eq("id", data.id);

  if (body.action === "spell_check") {
    try {
      const arr = JSON.parse(data.output_text as string) as string[];
      return { suggestion: body.text ?? "", suggestions: arr };
    } catch {
      return { suggestion: body.text ?? "", suggestions: [] };
    }
  }

  return { suggestion: data.output_text as string };
}

async function saveLearned(
  admin: SupabaseClient,
  body: AssistBody,
  result: { suggestion: string; suggestions?: string[] },
  sourceProvider: string,
): Promise<void> {
  const hash = await inputHash(body);
  const output =
    body.action === "spell_check" && result.suggestions
      ? JSON.stringify(result.suggestions)
      : result.suggestion;

  await admin.from("shop_ai_knowledge").upsert(
    {
      action: body.action,
      input_hash: hash,
      input_text: (body.text ?? "").trim(),
      context_json: body.context ?? {},
      language: body.language ?? "auto",
      output_text: output,
      source_provider: sourceProvider,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "action,input_hash" },
  );
}

function buildPrompts(body: AssistBody): { system: string; user: string } {
  const lang = body.language === "hi" ? "Hindi" : body.language === "en" ? "English" : "English or Hindi as appropriate";
  const ctx = body.context ?? {};
  const ctxJson = JSON.stringify(ctx);
  const seo = seoGuidance(ctx);
  const subOnly = ctx.subCategoryName?.trim() && !ctx.productName?.trim();
  const prompts: Record<AssistAction, string> = {
    fix_spelling: `Fix spelling only. Language: ${lang}. Return ONLY the corrected text.`,
    improve_grammar: `Improve grammar. Language: ${lang}. Return ONLY the improved text.`,
    professional_rewrite: `Rewrite professionally for a B2B CCTV/security ecommerce catalog (${ctx.companyName ?? "DG Yard"}). Language: ${lang}. Return ONLY the text.`,
    seo_optimize: `Optimize for SEO. ${seo} Language: ${lang}. Return ONLY the text.`,
    shorten: `Shorten while keeping meaning. Language: ${lang}. Return ONLY the text.`,
    expand: `Expand slightly with useful detail. Language: ${lang}. Return ONLY the text.`,
    generate_product_description: `Write a product description (2-4 sentences). ${seo} Context JSON: ${ctxJson}. Language: ${lang}. Return ONLY the description.`,
    generate_product_short_description: `Write a short product summary (1-2 sentences, max 160 characters) for catalog cards. ${seo} Context JSON: ${ctxJson}. Language: ${lang}. Return ONLY the short description.`,
    generate_category_description: subOnly
      ? `Write a sub-category description (2-3 sentences). ${seo} Context JSON: ${ctxJson}. Language: ${lang}. Return ONLY the description.`
      : `Write a category description (2-3 sentences). ${seo} Context JSON: ${ctxJson}. Language: ${lang}. Return ONLY the description.`,
    generate_meta_description: `Write meta description max 155 chars. ${seo} Context JSON: ${ctxJson}. Language: ${lang}. Return ONLY the meta.`,
    suggest_seo_title: `Suggest best SEO title max 60 chars. ${seo} Context JSON: ${ctxJson}. Return ONLY the title.`,
    suggest_meta_description: `Suggest best meta description max 155 chars. ${seo} Context JSON: ${ctxJson}. Return ONLY the meta.`,
    suggest_slug: `Suggest URL slug (lowercase, hyphenated). ${seo} Context JSON: ${ctxJson}. Return ONLY the slug.`,
    spell_check: `List spelling/grammar issues as JSON array of strings for: """${body.text}""". If none, return [].`,
    capitalize: `Apply title case appropriately. Return ONLY the text.`,
  };
  const system = "You are a copy editor for DG Yard Connect (CCTV & security shop in India). Never add markdown. For spell_check return valid JSON array only.";
  const user = `${prompts[body.action]}\n\nText:\n${body.text ?? ""}`;
  return { system, user };
}

function parseAssistContent(body: AssistBody, content: string): { suggestion: string; suggestions?: string[] } {
  const trimmed = content.trim();
  if (body.action === "spell_check") {
    try {
      const arr = JSON.parse(trimmed) as string[];
      return { suggestion: body.text ?? "", suggestions: arr };
    } catch {
      return { suggestion: body.text ?? "", suggestions: [] };
    }
  }
  return { suggestion: trimmed };
}

async function chatCompletionsAssist(
  body: AssistBody,
  apiKey: string,
  baseUrl: string,
  model: string,
): Promise<{ suggestion: string; suggestions?: string[] }> {
  const { system, user } = buildPrompts(body);
  const res = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.3,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
    }),
  });
  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Chat API ${res.status}: ${errText.slice(0, 200)}`);
  }
  const data = await res.json();
  const content = (data.choices?.[0]?.message?.content as string | undefined) ?? "";
  return parseAssistContent(body, content);
}

async function geminiAssist(body: AssistBody, apiKey: string): Promise<{ suggestion: string; suggestions?: string[] }> {
  const { system, user } = buildPrompts(body);
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const tryRequest = async (withQueryKey: boolean) => {
    const fullUrl = withQueryKey ? `${url}?key=${encodeURIComponent(apiKey)}` : url;
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (!withQueryKey) headers["x-goog-api-key"] = apiKey;

    return await fetch(fullUrl, {
      method: "POST",
      headers,
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ parts: [{ text: user }] }],
        generationConfig: { temperature: 0.3 },
      }),
    });
  };

  let res = await tryRequest(apiKey.startsWith("AIza"));
  if (!res.ok) res = await tryRequest(!apiKey.startsWith("AIza"));

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini ${res.status}: ${errText.slice(0, 200)}`);
  }

  const data = await res.json();
  const parts = data.candidates?.[0]?.content?.parts as Array<{ text?: string }> | undefined;
  const content = parts?.map((p) => p.text ?? "").join("") ?? "";
  return parseAssistContent(body, content);
}

function fallbackAssist(body: AssistBody): { suggestion: string; suggestions?: string[] } {
  const text = (body.text ?? "").trim();
  const ctx = body.context ?? {};
  const name = ctx.productName ?? ctx.subCategoryName ?? ctx.categoryName ?? "";

  switch (body.action) {
    case "capitalize":
      return { suggestion: text.replace(/\b\w/g, (c) => c.toUpperCase()) };
    case "shorten": {
      const words = text.split(/\s+/);
      return { suggestion: words.slice(0, Math.max(8, Math.floor(words.length * 0.6))).join(" ") };
    }
    case "suggest_slug": {
      const base = (name || text).toLowerCase();
      const slug = base.replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
      return { suggestion: slug, suggestions: [slug] };
    }
    case "suggest_seo_title": {
      const brand = ctx.brandName?.trim();
      const company = ctx.companyName?.trim() || "DG Yard";
      if (name && brand) return { suggestion: `${name} | ${brand} | ${company}`.slice(0, 60) };
      if (name) return { suggestion: `${name} | ${company}`.slice(0, 60) };
      return { suggestion: text.slice(0, 60) };
    }
    case "suggest_meta_description": {
      const brand = ctx.brandName?.trim();
      const company = ctx.companyName?.trim() || "DG Yard";
      if (name) {
        const suggestion =
          brand && brand.length > 0
            ? `Buy ${name} by ${brand} at ${company}. Expert CCTV support & delivery across India.`
            : `Shop ${name} at ${company}. Quality CCTV & security products with expert support across India.`;
        return { suggestion: suggestion.slice(0, 155) };
      }
      return { suggestion: text.slice(0, 155) };
    }
    case "spell_check": {
      const issues: string[] = [];
      if (/\s{2,}/.test(text)) issues.push("Remove extra spaces");
      if (text.length > 0 && text[0] === text[0].toLowerCase() && body.language !== "hi") {
        issues.push("Consider capitalizing the first letter");
      }
      return { suggestion: text, suggestions: issues };
    }
    default:
      return {
        suggestion: text,
        suggestions: ["Add GROQ_API_KEY or GEMINI_API_KEY in Supabase secrets"],
      };
  }
}

function resolveProviders(): { provider: AiProvider; key: string }[] {
  const forced = (Deno.env.get("TEXT_AI_PROVIDER") ?? "auto").toLowerCase();
  const groq = Deno.env.get("GROQ_API_KEY") ?? "";
  const gemini = Deno.env.get("GEMINI_API_KEY") ?? "";
  const openai = Deno.env.get("OPENAI_API_KEY") ?? "";

  const all: { provider: AiProvider; key: string }[] = [];
  if (groq) all.push({ provider: "groq", key: groq });
  if (gemini) all.push({ provider: "gemini", key: gemini });
  if (openai) all.push({ provider: "openai", key: openai });

  if (forced === "groq" && groq) return [{ provider: "groq", key: groq }];
  if (forced === "gemini" && gemini) return [{ provider: "gemini", key: gemini }];
  if (forced === "openai" && openai) return [{ provider: "openai", key: openai }];

  return all;
}

async function runAiAssist(
  body: AssistBody,
  provider: AiProvider,
  key: string,
): Promise<{ suggestion: string; suggestions?: string[] }> {
  switch (provider) {
    case "groq":
      return await chatCompletionsAssist(
        body,
        key,
        "https://api.groq.com/openai/v1",
        Deno.env.get("GROQ_MODEL") ?? "llama-3.3-70b-versatile",
      );
    case "openai":
      return await chatCompletionsAssist(
        body,
        key,
        "https://api.openai.com/v1",
        Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini",
      );
    case "gemini":
      return await geminiAssist(body, key);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    requireSuperadmin(req);
    const body = (await req.json()) as AssistBody;
    if (!body.action) {
      return new Response(JSON.stringify({ error: "action required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = adminClient();
    let result: { suggestion: string; suggestions?: string[] } = fallbackAssist(body);
    let usedProvider: string | null = "local-rules";
    let learned = false;

    if (body.action !== "capitalize" && admin) {
      const cached = await lookupLearned(admin, body);
      if (cached) {
        result = cached;
        usedProvider = "dg-yard-learned";
        learned = true;
      }
    }

    if (!learned && body.action !== "capitalize") {
      const providers = resolveProviders();
      for (const { provider, key } of providers) {
        try {
          result = await runAiAssist(body, provider, key);
          usedProvider = provider;
          learned = true;
          if (admin) {
            await saveLearned(admin, body, result, provider);
          }
          break;
        } catch (e) {
          console.error(`AI provider ${provider} failed:`, e);
        }
      }
    } else if (body.action === "capitalize") {
      result = fallbackAssist(body);
      usedProvider = "local-rules";
    }

    return new Response(
      JSON.stringify({
        ...result,
        action: body.action,
        provider: usedProvider,
        fromKnowledge: usedProvider === "dg-yard-learned",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    const status = msg === "Unauthorized" || msg === "Forbidden" ? 403 : 400;
    return new Response(JSON.stringify({ error: msg }), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
