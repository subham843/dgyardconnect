// Sarvam text-to-speech preview. Body: { text, tenant_id?, speaker?, language? }
// Returns { ok, sim, audio_base64?, content_type?, meta }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_TENANT = "b0000000-0000-4000-8000-000000000001";

function admin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase not configured");
  return createClient(url, key);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const text = String(body.text || "").trim().slice(0, 500);
    if (!text) throw new Error("text required");
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const db = admin();
    const { data: row } = await db
      .from("bos_tenant_settings")
      .select("api_secrets")
      .eq("tenant_id", tenantId)
      .maybeSingle();
    const secrets = (row?.api_secrets ?? {}) as Record<string, Record<string, string>>;
    const apiKey =
      secrets.sarvam?.api_key || Deno.env.get("SARVAM_API_KEY") || "";

    if (!apiKey) {
      return new Response(
        JSON.stringify({
          ok: true,
          sim: true,
          note: "Set Sarvam API key in Settings for live TTS preview",
          preview_text: text,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const res = await fetch("https://api.sarvam.ai/text-to-speech", {
      method: "POST",
      headers: {
        "api-subscription-key": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        inputs: [text],
        target_language_code: (body.language as string) || "hi-IN",
        speaker: (body.speaker as string) || "meera",
        pitch: 0,
        pace: 1,
        loudness: 1,
        speech_sample_rate: 22050,
        enable_preprocessing: true,
        model: "bulbul:v1",
      }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      return new Response(
        JSON.stringify({ ok: false, sim: false, error: data, http_status: res.status }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const audioBase64 =
      (Array.isArray(data.audios) && data.audios[0]) ||
      data.audio ||
      data.audio_base64 ||
      null;

    return new Response(
      JSON.stringify({
        ok: true,
        sim: false,
        audio_base64: audioBase64,
        content_type: "audio/wav",
        meta: { request_id: data.request_id },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
