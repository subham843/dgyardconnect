// Fast Twilio <Play> source — serves ephemeral Sarvam TTS without Storage hop.
// GET ?id=<clip_uuid>  → audio/mpeg|wav bytes

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function admin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase not configured");
  return createClient(url, key);
}

function decodeBase64Audio(raw: string): Uint8Array {
  let s = raw.trim();
  const comma = s.indexOf(",");
  if (s.startsWith("data:") && comma >= 0) s = s.slice(comma + 1);
  s = s.replace(/\s+/g, "");
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const url = new URL(req.url);
    const id = url.searchParams.get("id") || "";
    if (!id) {
      return new Response("missing id", { status: 400, headers: corsHeaders });
    }
    const db = admin();
    const { data, error } = await db
      .from("bos_voice_clips")
      .select("audio_b64, content_type")
      .eq("id", id)
      .maybeSingle();
    if (error || !data?.audio_b64) {
      return new Response("not found", { status: 404, headers: corsHeaders });
    }
    const bytes = decodeBase64Audio(String(data.audio_b64));
    return new Response(bytes, {
      headers: {
        ...corsHeaders,
        "Content-Type": String(data.content_type || "audio/mpeg"),
        "Cache-Control": "public, max-age=300",
        "Content-Length": String(bytes.byteLength),
      },
    });
  } catch (e) {
    return new Response(String(e), { status: 500, headers: corsHeaders });
  }
});
