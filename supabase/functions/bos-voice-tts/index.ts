// Sarvam text-to-speech preview.
// Body: { text, tenant_id?, speaker?, language?, model? }
// Returns { ok, sim, audio_base64?, content_type?, meta, speakers? }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_TENANT = "b0000000-0000-4000-8000-000000000001";

/** bulbul:v2 voices */
export const SARVAM_SPEAKERS_V2 = [
  "anushka",
  "abhilash",
  "manisha",
  "vidya",
  "arya",
  "karun",
  "hitesh",
] as const;

/** bulbul:v3 voices (Indian catalog) */
export const SARVAM_SPEAKERS_V3 = [
  "shubh",
  "aditya",
  "priya",
  "neha",
  "rahul",
  "pooja",
  "rohan",
  "simran",
  "kavya",
  "amit",
  "dev",
  "ishita",
  "shreya",
  "ratan",
  "varun",
  "manan",
  "sumit",
  "roopa",
  "kabir",
  "aayan",
  "ashutosh",
  "advait",
  "anand",
  "tanya",
  "tarun",
  "sunny",
  "mani",
  "gokul",
  "vijay",
  "shruti",
  "suhani",
  "mohit",
  "kavitha",
  "rehan",
  "soham",
  "rupali",
  "rilu",
  "ritu",
] as const;

const ALL_SPEAKERS = new Set<string>([...SARVAM_SPEAKERS_V2, ...SARVAM_SPEAKERS_V3]);

function admin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase not configured");
  return createClient(url, key);
}

function normalizeModel(raw: string | undefined): "bulbul:v2" | "bulbul:v3" {
  const m = String(raw || "bulbul:v3").toLowerCase();
  if (m.includes("v2")) return "bulbul:v2";
  return "bulbul:v3";
}

function defaultSpeaker(model: "bulbul:v2" | "bulbul:v3"): string {
  return model === "bulbul:v2" ? "anushka" : "shubh";
}

function resolveSpeaker(raw: string | undefined, model: "bulbul:v2" | "bulbul:v3"): string {
  const s = String(raw || "").trim().toLowerCase();
  if (!s || s === "meera" || !ALL_SPEAKERS.has(s)) return defaultSpeaker(model);
  if (model === "bulbul:v2" && !(SARVAM_SPEAKERS_V2 as readonly string[]).includes(s)) {
    return defaultSpeaker(model);
  }
  if (model === "bulbul:v3" && !(SARVAM_SPEAKERS_V3 as readonly string[]).includes(s)) {
    // allow v2 names only on v2; otherwise fall back
    return defaultSpeaker(model);
  }
  return s;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    if (body.action === "speakers") {
      return new Response(
        JSON.stringify({
          ok: true,
          models: ["bulbul:v2", "bulbul:v3"],
          speakers_v2: SARVAM_SPEAKERS_V2,
          speakers_v3: SARVAM_SPEAKERS_V3,
          default_model: "bulbul:v3",
          default_speaker_v2: "anushka",
          default_speaker_v3: "shubh",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const text = String(body.text || "").trim().slice(0, 1500);
    if (!text) throw new Error("text required");
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const db = admin();
    const { data: row } = await db
      .from("bos_tenant_settings")
      .select("api_secrets, api_config")
      .eq("tenant_id", tenantId)
      .maybeSingle();
    const secrets = (row?.api_secrets ?? {}) as Record<string, Record<string, string>>;
    const voiceCfg = ((row?.api_config as Record<string, unknown>)?.voice ?? {}) as Record<
      string,
      string
    >;
    const apiKey =
      secrets.sarvam?.api_key || Deno.env.get("SARVAM_API_KEY") || "";

    const model = normalizeModel(
      (body.model as string) || voiceCfg.sarvam_model || voiceCfg.tts_model,
    );
    const speaker = resolveSpeaker(
      (body.speaker as string) || voiceCfg.sarvam_speaker || voiceCfg.tts_speaker,
      model,
    );
    const language =
      (body.language as string) ||
      voiceCfg.sarvam_language ||
      voiceCfg.tts_language ||
      "hi-IN";

    if (!apiKey) {
      return new Response(
        JSON.stringify({
          ok: true,
          sim: true,
          note: "Set Sarvam API key in Settings for live TTS preview",
          preview_text: text,
          model,
          speaker,
          speakers_v2: SARVAM_SPEAKERS_V2,
          speakers_v3: SARVAM_SPEAKERS_V3,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const payload: Record<string, unknown> = {
      text,
      target_language_code: language,
      speaker,
      model,
      pace: 1.0,
      speech_sample_rate: model === "bulbul:v2" ? 22050 : 24000,
      enable_preprocessing: true,
      output_audio_codec: "wav",
    };
    if (model === "bulbul:v2") {
      payload.pitch = 0;
      payload.loudness = 1;
      // older clients also accepted inputs[]
      payload.inputs = [text];
    }

    const res = await fetch("https://api.sarvam.ai/text-to-speech", {
      method: "POST",
      headers: {
        "api-subscription-key": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      const msg =
        (data as { error?: { message?: string } })?.error?.message ||
        (data as { message?: string })?.message ||
        JSON.stringify(data);
      return new Response(
        JSON.stringify({
          ok: false,
          sim: false,
          error: msg,
          detail: data,
          http_status: res.status,
          model,
          speaker,
          speakers_v2: SARVAM_SPEAKERS_V2,
          speakers_v3: SARVAM_SPEAKERS_V3,
        }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
    const audioBase64 =
      (Array.isArray((data as { audios?: string[] }).audios) &&
        (data as { audios: string[] }).audios[0]) ||
      (data as { audio?: string }).audio ||
      (data as { audio_base64?: string }).audio_base64 ||
      null;

    return new Response(
      JSON.stringify({
        ok: true,
        sim: false,
        audio_base64: audioBase64,
        content_type: "audio/wav",
        model,
        speaker,
        meta: { request_id: (data as { request_id?: string }).request_id },
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
