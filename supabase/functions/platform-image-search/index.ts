// Search stock images via approved providers (Pexels). Superadmin only.
// Secret: PEXELS_API_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type SearchBody = {
  productName?: string;
  categoryName?: string;
  brandName?: string;
  page?: number;
  perPage?: number;
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

function buildQuery(body: SearchBody): string {
  const parts = [body.productName, body.categoryName, body.brandName]
    .map((s) => (s ?? "").trim())
    .filter((s) => s.length > 0);
  return parts.join(" ") || "product";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    requireSuperadmin(req);
    const body = (await req.json()) as SearchBody;
    const apiKey = Deno.env.get("PEXELS_API_KEY") ?? "";
    if (!apiKey) {
      return new Response(
        JSON.stringify({
          error: "Image search not configured",
          hint: "Set PEXELS_API_KEY in Supabase secrets",
          results: [],
        }),
        { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const q = encodeURIComponent(buildQuery(body));
    const page = Math.max(1, body.page ?? 1);
    const perPage = Math.min(40, Math.max(1, body.perPage ?? 20));
    const res = await fetch(
      `https://api.pexels.com/v1/search?query=${q}&page=${page}&per_page=${perPage}`,
      { headers: { Authorization: apiKey } },
    );
    if (!res.ok) {
      const errText = await res.text();
      return new Response(
        JSON.stringify({ error: `Pexels error: ${res.status}`, detail: errText, results: [] }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const data = await res.json();
    const photos = (data.photos ?? []) as Array<Record<string, unknown>>;
    const results = photos.map((p) => {
      const src = p.src as Record<string, string> | undefined;
      const photographer = (p.photographer as string) ?? "Unknown";
      const url = (p.url as string) ?? "";
      return {
        id: String(p.id ?? ""),
        provider: "pexels",
        previewUrl: src?.medium ?? src?.small ?? "",
        fullUrl: src?.large2x ?? src?.large ?? src?.original ?? "",
        sourcePageUrl: url,
        attribution: `Photo by ${photographer} on Pexels`,
        photographer,
        width: p.width as number | undefined,
        height: p.height as number | undefined,
      };
    });

    return new Response(
      JSON.stringify({ results, query: buildQuery(body), provider: "pexels" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : "Unknown error";
    const status = msg === "Unauthorized" || msg === "Forbidden" ? 403 : 400;
    return new Response(JSON.stringify({ error: msg, results: [] }), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
