// Generate category/sub-category banner images with Gemini (Nano Banana models).
// Secret: GEMINI_API_KEY

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type GenerateBody = {
  categoryName?: string;
  description?: string;
  preset?: "category" | "sub_category";
};

const DEFAULT_IMAGE_MODELS = [
  "gemini-2.5-flash-image",
  "gemini-3.1-flash-image",
  "gemini-2.0-flash-exp",
];

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

function buildPrompt(body: GenerateBody): string {
  const name = (body.categoryName ?? "Technology").trim();
  const desc = (body.description ?? "").trim();
  return `Create a premium ecommerce category hero banner photograph for "${name}".
${desc ? `Context: ${desc}.` : ""}
Subject: professional product/environment imagery for Indian tech retail (CCTV, networking, computers, security).
Style: modern, cinematic, high-end catalog photography, soft lighting, shallow depth of field.
Composition: wide landscape 16:9, subject centered with breathing room for text overlay at bottom.
Rules: NO text, NO logos, NO watermarks, NO brand names, NO people faces close-up.
Output: single photorealistic banner suitable for a website category card.`;
}

function imageModels(): string[] {
  const custom = (Deno.env.get("GEMINI_IMAGE_MODEL") ?? "").trim();
  if (custom) return [custom, ...DEFAULT_IMAGE_MODELS.filter((m) => m !== custom)];
  return DEFAULT_IMAGE_MODELS;
}

async function tryGenerateWithModel(
  model: string,
  prompt: string,
  apiKey: string,
): Promise<string | null> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseModalities: ["TEXT", "IMAGE"],
        imageConfig: { aspectRatio: "16:9" },
      },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    console.warn(`Gemini image model ${model} failed: ${res.status} ${err.slice(0, 200)}`);
    return null;
  }

  const data = await res.json();
  const parts = data.candidates?.[0]?.content?.parts as Array<{ inlineData?: { data?: string } }> | undefined;
  for (const p of parts ?? []) {
    const b64 = p.inlineData?.data;
    if (b64 && b64.length > 100) return b64;
  }
  return null;
}

async function generateWithGemini(prompt: string, apiKey: string): Promise<{ b64: string; model: string }> {
  const errors: string[] = [];
  for (const model of imageModels()) {
    const b64 = await tryGenerateWithModel(model, prompt, apiKey);
    if (b64) return { b64, model };
    errors.push(model);
  }
  throw new Error(
    `Gemini image generation failed. Tried: ${errors.join(", ")}. ` +
      "Ensure GEMINI_API_KEY has image generation access, or set GEMINI_IMAGE_MODEL to a supported model " +
      "(e.g. gemini-2.5-flash-image).",
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    requireSuperadmin(req);
    const body = (await req.json()) as GenerateBody;
    const name = body.categoryName?.trim();
    if (!name) throw new Error("categoryName required");

    const apiKey = Deno.env.get("GEMINI_API_KEY") ?? "";
    if (!apiKey) throw new Error("Set GEMINI_API_KEY in Supabase Edge Function secrets");

    const prompt = buildPrompt(body);
    const { b64: imageBase64, model } = await generateWithGemini(prompt, apiKey);

    return new Response(
      JSON.stringify({ ok: true, provider: "gemini", model, imageBase64, categoryName: name }),
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
