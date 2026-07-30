// Extract product specs from datasheet PDF. Gemini multimodal → Groq text fallback.
// Secrets: GEMINI_API_KEY, GROQ_API_KEY (fallback when Gemini quota exceeded)

import { extractText, getDocumentProxy } from "https://esm.sh/unpdf@1.0.6";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type ExtractBody = {
  pdfBase64: string;
  fileName?: string;
  productName?: string;
  brandName?: string;
  categoryName?: string;
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

function parseJsonFromModel(text: string): Record<string, unknown> {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/);
  const raw = fenced ? fenced[1].trim() : trimmed;
  return JSON.parse(raw) as Record<string, unknown>;
}

function buildContext(body: ExtractBody): string {
  return [
    body.productName?.trim() ? `Product hint: ${body.productName.trim()}` : "",
    body.brandName?.trim() ? `Brand: ${body.brandName.trim()}` : "",
    body.categoryName?.trim() ? `Category: ${body.categoryName.trim()}` : "",
    body.fileName?.trim() ? `File: ${body.fileName.trim()}` : "",
  ].filter(Boolean).join("\n");
}

const JSON_SCHEMA_HINT = `Return ONLY valid JSON:
{
  "modelName": "manufacturer model number or null",
  "hsnCode": "4-8 digit HSN if found or null",
  "warranty": "warranty text or null",
  "warrantyMonths": number or null,
  "shortDescription": "1-2 sentence summary",
  "description": "2-4 sentence product description",
  "technicalNotes": "bullet-style technical specs as plain text",
  "installationNotes": "installation/mounting notes or null",
  "specifications": [{"label":"Resolution","value":"4MP"}],
  "attributeHints": [{"key":"resolution","value":"4MP"}]
}`;

async function extractPdfText(pdfBase64: string): Promise<string> {
  const binary = atob(pdfBase64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  const pdf = await getDocumentProxy(bytes);
  const { text } = await extractText(pdf, { mergePages: true });
  return (text ?? "").trim();
}

async function geminiExtractPdf(body: ExtractBody, apiKey: string): Promise<Record<string, unknown>> {
  const model = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.0-flash";
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const ctx = buildContext(body);

  const prompt = `You are a CCTV/security product catalog assistant for DG Yard (India).
Read this datasheet PDF and extract structured product data.
${ctx}

${JSON_SCHEMA_HINT}
Use snake_case keys in attributeHints when obvious.`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: "Return strict JSON only. No commentary." }] },
      contents: [{
        parts: [
          { inline_data: { mime_type: "application/pdf", data: body.pdfBase64 } },
          { text: prompt },
        ],
      }],
      generationConfig: { temperature: 0.2, responseMimeType: "application/json" },
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    const err = new Error(`Gemini ${res.status}: ${errText.slice(0, 300)}`);
    (err as Error & { status?: number }).status = res.status;
    throw err;
  }

  const data = await res.json();
  const parts = data.candidates?.[0]?.content?.parts as Array<{ text?: string }> | undefined;
  const content = parts?.map((p) => p.text ?? "").join("") ?? "{}";
  return parseJsonFromModel(content);
}

async function groqExtractFromText(body: ExtractBody, pdfText: string, apiKey: string): Promise<Record<string, unknown>> {
  const model = Deno.env.get("GROQ_MODEL") ?? "llama-3.3-70b-versatile";
  const ctx = buildContext(body);
  const clipped = pdfText.length > 12000 ? `${pdfText.slice(0, 12000)}\n...[truncated]` : pdfText;

  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: "Extract CCTV product catalog fields from datasheet text. Return JSON only.",
        },
        {
          role: "user",
          content: `${ctx}\n\n${JSON_SCHEMA_HINT}\n\nDatasheet text:\n${clipped}`,
        },
      ],
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Groq ${res.status}: ${errText.slice(0, 300)}`);
  }

  const data = await res.json();
  const content = (data.choices?.[0]?.message?.content as string | undefined) ?? "{}";
  return parseJsonFromModel(content);
}

async function runExtract(body: ExtractBody): Promise<{ data: Record<string, unknown>; provider: string }> {
  const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
  const groqKey = Deno.env.get("GROQ_API_KEY") ?? "";

  if (geminiKey) {
    try {
      const data = await geminiExtractPdf(body, geminiKey);
      return { data, provider: "gemini" };
    } catch (e) {
      const status = (e as Error & { status?: number }).status;
      const isQuota = status === 429 || String(e).includes("429") || String(e).toLowerCase().includes("quota");
      if (!isQuota && !groqKey) throw e;
      // fall through to Groq text path
    }
  }

  if (!groqKey) {
    throw new Error(
      "Gemini quota exceeded and GROQ_API_KEY is not set. Add GROQ_API_KEY in Supabase Edge Function secrets, or retry later.",
    );
  }

  const pdfText = await extractPdfText(body.pdfBase64);
  if (pdfText.length < 40) {
    throw new Error("Could not read text from PDF. Try a text-based datasheet (not scanned image).");
  }

  const data = await groqExtractFromText(body, pdfText, groqKey);
  return { data, provider: "groq" };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    requireSuperadmin(req);
    const body = (await req.json()) as ExtractBody;
    if (!body.pdfBase64?.trim()) {
      return new Response(JSON.stringify({ error: "pdfBase64 is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data, provider } = await runExtract(body);
    return new Response(JSON.stringify({ ok: true, data, provider }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    const status = message.includes("Unauthorized") || message.includes("Forbidden")
      ? 403
      : message.includes("quota") || message.includes("429")
      ? 429
      : 500;
    return new Response(JSON.stringify({ error: message, code: status === 429 ? "quota_exceeded" : "extract_failed" }), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
