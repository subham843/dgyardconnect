// Voice provider webhooks (Twilio / Exotel) — status + recording → Sarvam STT via bos-voice-complete.
// Twilio: application/x-www-form-urlencoded (CallSid, CallStatus, RecordingUrl, …)
// Exotel: form or JSON (CallSid, Status, RecordingUrl, …)
// Query: ?tenant_id=…&provider=twilio|exotel  (optional; matched via CallSid when possible)

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

async function parseBody(req: Request): Promise<Record<string, string>> {
  const ct = req.headers.get("content-type") || "";
  if (ct.includes("application/json")) {
    const j = await req.json().catch(() => ({}));
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(j as Record<string, unknown>)) {
      if (v != null) out[k] = String(v);
    }
    return out;
  }
  const text = await req.text();
  const params = new URLSearchParams(text);
  const out: Record<string, string> = {};
  for (const [k, v] of params.entries()) out[k] = v;
  return out;
}

function mapStatus(raw: string): string {
  const s = raw.toLowerCase();
  if (["completed", "complete", "answered"].includes(s)) return "completed";
  if (["busy", "no-answer", "no_answer", "failed", "canceled", "cancelled"].includes(s)) {
    return "failed";
  }
  if (["ringing", "queued", "initiated"].includes(s)) return "ringing";
  if (["in-progress", "in_progress", "ongoing"].includes(s)) return "in_progress";
  return raw || "in_progress";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const tenantHint = url.searchParams.get("tenant_id") || DEFAULT_TENANT;
    const providerHint = (url.searchParams.get("provider") || "").toLowerCase();
    const body = await parseBody(req);

    const callSid =
      body.CallSid || body.Sid || body.call_sid || body.CallSid || body.CallID || "";
    const recordingUrl =
      body.RecordingUrl ||
      body.recording_url ||
      body.RecordingUrl ||
      body.Digits ||
      body.CustomField ||
      "";
    // Exotel sometimes uses RecordingUrl after status callback
    const statusRaw =
      body.CallStatus || body.Status || body.call_status || body.DialCallStatus || "";
    const phone = body.To || body.to || body.CallTo || body.From || "";

    const db = admin();
    let call: Record<string, unknown> | null = null;

    if (callSid) {
      // Match provider_call_id in meta (json contains)
      const { data: rows } = await db
        .from("bos_voice_calls")
        .select("*")
        .eq("tenant_id", tenantHint)
        .order("created_at", { ascending: false })
        .limit(80);
      call = (rows ?? []).find((r) => {
        const m = (r.meta ?? {}) as Record<string, unknown>;
        return m.provider_call_id === callSid || String(m.provider_call_id) === callSid;
      }) ?? null;

      if (!call) {
        // Broader search across tenants if tenant hint wrong
        const { data: all } = await db
          .from("bos_voice_calls")
          .select("*")
          .order("created_at", { ascending: false })
          .limit(120);
        call = (all ?? []).find((r) => {
          const m = (r.meta ?? {}) as Record<string, unknown>;
          return m.provider_call_id === callSid;
        }) ?? null;
      }
    }

    if (!call && phone) {
      const digits = phone.replace(/\D/g, "").slice(-10);
      const { data: rows } = await db
        .from("bos_voice_calls")
        .select("*")
        .eq("tenant_id", tenantHint)
        .in("status", ["queued", "ringing", "in_progress"])
        .order("created_at", { ascending: false })
        .limit(20);
      call = (rows ?? []).find((r) => String(r.phone || "").replace(/\D/g, "").endsWith(digits)) ??
        null;
    }

    if (!call) {
      return new Response(JSON.stringify({ ok: false, error: "call not matched", callSid }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const tenantId = (call.tenant_id as string) || tenantHint;
    const mapped = statusRaw ? mapStatus(statusRaw) : null;
    const meta = {
      ...((call.meta ?? {}) as Record<string, unknown>),
      provider_call_id: callSid || (call.meta as Record<string, string>)?.provider_call_id,
      webhook_provider: providerHint || "unknown",
      webhook_at: new Date().toISOString(),
      webhook_raw_status: statusRaw,
      recording_url: recordingUrl || (call.meta as Record<string, string>)?.recording_url,
      audio_url: recordingUrl || (call.meta as Record<string, string>)?.audio_url,
    };

    const patch: Record<string, unknown> = {
      meta,
      updated_at: new Date().toISOString(),
    };
    if (mapped && mapped !== "completed") patch.status = mapped;

    await db.from("bos_voice_calls").update(patch).eq("id", call.id);

    // When recording arrives (or call completed), run STT complete loop
    const shouldComplete =
      Boolean(recordingUrl) ||
      mapped === "completed" ||
      (body.RecordingStatus || "").toLowerCase() === "completed";

    if (shouldComplete) {
      const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      const completeUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-voice-complete`;
      const outcome =
        mapped === "failed" && /no-answer|no_answer|busy/i.test(statusRaw)
          ? "no_answer"
          : "interested";
      await fetch(completeUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          call_id: call.id,
          tenant_id: tenantId,
          audio_url: recordingUrl || undefined,
          outcome: recordingUrl ? outcome : (mapped === "failed" ? "no_answer" : outcome),
          status: "completed",
        }),
      }).catch(() => {});
    }

    // Twilio expects 200 empty / TwiML
    if (providerHint === "twilio" || body.AccountSid) {
      return new Response("<Response></Response>", {
        headers: { ...corsHeaders, "Content-Type": "text/xml" },
      });
    }

    return new Response(
      JSON.stringify({
        ok: true,
        call_id: call.id,
        recording: Boolean(recordingUrl),
        status: mapped,
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
