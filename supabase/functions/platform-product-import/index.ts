// AI Product Import Engine — URL, model number, manufacturer page, datasheet PDF.
// Secrets: GROQ_API_KEY and/or GEMINI_API_KEY

import { extractText, getDocumentProxy } from "https://esm.sh/unpdf@1.0.6";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type SourceType = "url" | "model_number" | "datasheet_pdf" | "manufacturer_page";

type CatalogContext = {
  categories?: { name: string; slug: string }[];
  subCategories?: { name: string; slug: string; categorySlug: string }[];
  brands?: { name: string; slug: string }[];
  attributeGroups?: { name: string; attributeKeys: string[] }[];
  attributes?: { key: string; label: string; dataType: string; allowedValues?: string[] }[];
};

type ImportBody = {
  sourceType: SourceType;
  url?: string;
  modelNumber?: string;
  pdfBase64?: string;
  fileName?: string;
  catalogContext?: CatalogContext;
};

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

function htmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function resolveUrl(base: string, href: string): string | null {
  try {
    return new URL(href, base).toString();
  } catch {
    return null;
  }
}

function extractUrlsFromHtml(html: string, pageUrl: string): {
  imageUrls: string[];
  pdfUrls: string[];
} {
  const imageUrls = new Set<string>();
  const pdfUrls = new Set<string>();

  const og = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i);
  if (og?.[1]) {
    const u = resolveUrl(pageUrl, og[1]);
    if (u) imageUrls.add(u);
  }

  for (const m of html.matchAll(/<img[^>]+src=["']([^"']+)["']/gi)) {
    const u = resolveUrl(pageUrl, m[1]);
    if (u && !u.includes("logo") && !u.endsWith(".svg")) imageUrls.add(u);
  }

  for (const m of html.matchAll(/href=["']([^"']+\.pdf[^"']*)["']/gi)) {
    const u = resolveUrl(pageUrl, m[1]);
    if (u) pdfUrls.add(u);
  }

  return {
    imageUrls: [...imageUrls].slice(0, 12),
    pdfUrls: [...pdfUrls].slice(0, 6),
  };
}

async function fetchPage(url: string): Promise<{ text: string; html: string; finalUrl: string }> {
  const res = await fetch(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (compatible; DGYardProductImport/1.0)",
      Accept: "text/html,application/xhtml+xml",
    },
    redirect: "follow",
  });
  if (!res.ok) throw new Error(`Could not fetch URL (${res.status})`);
  const html = await res.text();
  return { text: htmlToText(html).slice(0, 18000), html, finalUrl: res.url };
}

async function extractPdfText(pdfBase64: string): Promise<string> {
  const binary = atob(pdfBase64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  const pdf = await getDocumentProxy(bytes);
  const { text } = await extractText(pdf, { mergePages: true });
  return (text ?? "").trim();
}

function detectManufacturer(url?: string, text?: string): string | null {
  const u = (url ?? "").toLowerCase();
  const known = [
    ["hikvision", "Hikvision"],
    ["dahuasecurity", "Dahua"],
    ["dahua", "Dahua"],
    ["cpplus", "CP Plus"],
    ["cp-plus", "CP Plus"],
    ["tp-link", "TP-Link"],
    ["dell.com", "Dell"],
    ["hp.com", "HP"],
    ["lenovo.com", "Lenovo"],
    ["intel.com", "Intel"],
    ["amd.com", "AMD"],
  ];
  for (const [k, label] of known) {
    if (u.includes(k)) return label;
  }
  const t = (text ?? "").toLowerCase();
  for (const [k, label] of known) {
    if (t.includes(k.replace(".com", ""))) return label;
  }
  return null;
}

function buildPrompt(
  sourceType: SourceType,
  content: string,
  ctx: CatalogContext,
  extras: { url?: string; modelNumber?: string; imageUrls?: string[]; pdfUrls?: string[]; manufacturer?: string | null },
): string {
  const catalogJson = JSON.stringify(ctx).slice(0, 8000);
  return `You are the DG Yard Connect AI Product Import Engine (India CCTV, networking, IT hardware shop).

SOURCE: ${sourceType}
${extras.url ? `URL: ${extras.url}` : ""}
${extras.modelNumber ? `MODEL: ${extras.modelNumber}` : ""}
${extras.manufacturer ? `DETECTED MANUFACTURER: ${extras.manufacturer}` : ""}

CATALOG (pick best category_slug + sub_category_slug + brand from these lists):
${catalogJson}

PAGE/DOCUMENT TEXT:
${content.slice(0, 14000)}

${extras.imageUrls?.length ? `IMAGE URLS FOUND: ${JSON.stringify(extras.imageUrls)}` : ""}
${extras.pdfUrls?.length ? `PDF URLS FOUND: ${JSON.stringify(extras.pdfUrls)}` : ""}

Return ONLY JSON:
{
  "confidence": {
    "overall": 0.0-1.0,
    "fields": {
      "name": 0.0-1.0, "brand": 0.0-1.0, "category": 0.0-1.0, "subCategory": 0.0-1.0,
      "specifications": 0.0-1.0, "pricing": 0.0-1.0, "hsn": 0.0-1.0, "gst": 0.0-1.0, "seo": 0.0-1.0, "images": 0.0-1.0
    }
  },
  "product": {
    "name": "",
    "brand_name": "",
    "model_name": "",
    "manufacturer": "",
    "category_slug": "",
    "category_name": "",
    "sub_category_slug": "",
    "sub_category_name": "",
    "attribute_group_names": ["Group names from catalog to assign"],
    "description": "",
    "short_description": "",
    "technical_notes": "",
    "installation_notes": "",
    "hsn_code": "",
    "gst_percentage": 18,
    "cost_price": null,
    "mrp": null,
    "online_price": null,
    "dealer_price": null,
    "warranty": "",
    "warranty_months": null,
    "seo_title": "",
    "meta_description": "",
    "slug": "",
    "keywords": ["keyword1", "keyword2"],
    "specifications": [{"label":"Resolution","value":"4MP"}],
    "attributes": [{"key":"resolution","label":"Resolution","data_type":"select","value":"4MP","allowed_values":["2MP","4MP"],"is_new": false}],
    "image_urls": [],
    "datasheet_urls": [],
    "manual_urls": []
  },
  "source_url": "",
  "manufacturer": ""
}

Rules:
- Map attributes to existing catalog keys when possible; set is_new:true only for genuinely new specs.
- Suggest Indian HSN (4-8 digits) and GST % for CCTV/networking/IT.
- SEO title max 60 chars, meta max 155 chars.
- Prefer product images over logos; include absolute image_urls and pdf urls when found.
- Works for CP Plus, Hikvision, Dahua, TP-Link, Dell, HP, Lenovo, Intel, AMD, any manufacturer.`;
}

async function runGroq(prompt: string, apiKey: string): Promise<Record<string, unknown>> {
  const model = Deno.env.get("GROQ_MODEL") ?? "llama-3.3-70b-versatile";
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: "Return strict JSON for product import. No markdown." },
        { role: "user", content: prompt },
      ],
    }),
  });
  if (!res.ok) throw new Error(`Groq ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  const content = (data.choices?.[0]?.message?.content as string | undefined) ?? "{}";
  return JSON.parse(content) as Record<string, unknown>;
}

async function runGemini(prompt: string, apiKey: string): Promise<Record<string, unknown>> {
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.2, responseMimeType: "application/json" },
    }),
  });
  if (!res.ok) throw new Error(`Gemini ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  const parts = data.candidates?.[0]?.content?.parts as Array<{ text?: string }> | undefined;
  const content = parts?.map((p) => p.text ?? "").join("") ?? "{}";
  return JSON.parse(content) as Record<string, unknown>;
}

async function runAi(prompt: string): Promise<{ result: Record<string, unknown>; provider: string }> {
  const groq = Deno.env.get("GROQ_API_KEY") ?? "";
  const gemini = Deno.env.get("GEMINI_API_KEY") ?? "";
  if (groq) {
    try {
      return { result: await runGroq(prompt, groq), provider: "groq" };
    } catch (e) {
      if (!gemini) throw e;
    }
  }
  if (gemini) return { result: await runGemini(prompt, gemini), provider: "gemini" };
  throw new Error("Set GROQ_API_KEY or GEMINI_API_KEY in Supabase Edge Function secrets");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    requireSuperadmin(req);
    const body = (await req.json()) as ImportBody;
    const ctx = body.catalogContext ?? {};
    let content = "";
    let sourceUrl = body.url ?? "";
    let imageUrls: string[] = [];
    let pdfUrls: string[] = [];

    if (body.sourceType === "datasheet_pdf") {
      if (!body.pdfBase64?.trim()) throw new Error("pdfBase64 required");
      content = await extractPdfText(body.pdfBase64);
      if (content.length < 40) throw new Error("Could not read PDF text");
    } else if (body.sourceType === "model_number") {
      if (!body.modelNumber?.trim()) throw new Error("modelNumber required");
      content = `Look up product specifications for model number: ${body.modelNumber.trim()}. Infer brand from model prefix (DS-=Hikvision, IPC-=Dahua, CP-=CP Plus, etc).`;
      if (body.url?.trim()) {
        const page = await fetchPage(body.url.trim());
        content += `\n\nSupplementary page:\n${page.text}`;
        sourceUrl = page.finalUrl;
        const urls = extractUrlsFromHtml(page.html, page.finalUrl);
        imageUrls = urls.imageUrls;
        pdfUrls = urls.pdfUrls;
      }
    } else {
      const targetUrl = body.url?.trim();
      if (!targetUrl) throw new Error("url required");
      const page = await fetchPage(targetUrl);
      content = page.text;
      sourceUrl = page.finalUrl;
      const urls = extractUrlsFromHtml(page.html, page.finalUrl);
      imageUrls = urls.imageUrls;
      pdfUrls = urls.pdfUrls;
    }

    const manufacturer = detectManufacturer(sourceUrl, content);
    const prompt = buildPrompt(body.sourceType, content, ctx, {
      url: sourceUrl,
      modelNumber: body.modelNumber,
      imageUrls,
      pdfUrls,
      manufacturer,
    });

    const { result, provider } = await runAi(prompt);
    const product = (result.product ?? result) as Record<string, unknown>;
    if (!Array.isArray(product.image_urls) || (product.image_urls as string[]).length === 0) {
      product.image_urls = imageUrls;
    }
    if (!Array.isArray(product.datasheet_urls) || (product.datasheet_urls as string[]).length === 0) {
      product.datasheet_urls = pdfUrls.filter((u) => /datasheet|spec|catalog/i.test(u));
    }
    if (!Array.isArray(product.manual_urls) || (product.manual_urls as string[]).length === 0) {
      product.manual_urls = pdfUrls.filter((u) => /manual|user.?guide|install/i.test(u));
    }

    return new Response(
      JSON.stringify({
        ok: true,
        provider,
        confidence: result.confidence ?? { overall: 0.7, fields: {} },
        product,
        source_url: sourceUrl,
        manufacturer: result.manufacturer ?? manufacturer,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
