// Sarvam Voice Agents Instant Outbound webhook.
// Body: attempt status + transcript (see docs.sarvam.ai conversations instant-outbound webhook).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-key",
};

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
    const url = new URL(req.url);
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const meta =
      ((body.webhook_config as Record<string, unknown>)?.metadata as Record<string, unknown>) ||
      {};
    const callId =
      String(meta.call_id || url.searchParams.get("call_id") || body.call_id || "");
    const tenantId =
      String(meta.tenant_id || url.searchParams.get("tenant_id") || body.tenant_id || "");
    const attemptId = String(body.attempt_id || "");
    const statusRaw = String(body.status || "").toLowerCase();
    const status =
      statusRaw === "connected"
        ? "completed"
        : statusRaw === "no_answer"
        ? "no_answer"
        : statusRaw === "busy"
        ? "busy"
        : statusRaw === "failed"
        ? "failed"
        : statusRaw || "completed";

    const transcriptTurns = Array.isArray(body.interaction_transcript)
      ? (body.interaction_transcript as Array<Record<string, string>>)
      : [];
    const transcript = transcriptTurns
      .map((t) => `${t.role === "user" ? "Customer" : "Agent"}: ${t.en_text || ""}`)
      .filter((l) => l.trim().length > 8)
      .join("\n");

    const db = admin();
    if (callId) {
      const { data: call } = await db.from("bos_voice_calls").select("meta, tenant_id").eq("id", callId)
        .maybeSingle();
      const prev = (call?.meta ?? {}) as Record<string, unknown>;
      await db.from("bos_voice_calls").update({
        status,
        transcript: transcript || undefined,
        provider: "sarvam_agent",
        meta: {
          ...prev,
          sarvam_attempt_id: attemptId || prev.sarvam_attempt_id,
          sarvam_interaction_id: body.interaction_id || null,
          sarvam_duration: body.duration ?? null,
          sarvam_failure_reason: body.failure_reason || null,
          sarvam_channel: body.channel_info || null,
          sarvam_final_variables: body.final_agent_variables || null,
          sarvam_webhook: true,
          conversational: true,
          voice_engine: "sarvam_voice_agent",
        },
        updated_at: new Date().toISOString(),
      }).eq("id", callId);

      await db.from("bos_voice_events").insert({
        id: crypto.randomUUID(),
        tenant_id: tenantId || call?.tenant_id || null,
        call_id: callId,
        provider: "sarvam_agent",
        event_type: `sarvam_outbound_${statusRaw || status}`,
        payload: body,
      });
    } else if (attemptId) {
      // Correlate by attempt_id stored at dial time
      const { data: rows } = await db
        .from("bos_voice_calls")
        .select("id, meta, tenant_id")
        .contains("meta", { sarvam_attempt_id: attemptId })
        .limit(1);
      const call = rows?.[0];
      if (call) {
        const prev = (call.meta ?? {}) as Record<string, unknown>;
        await db.from("bos_voice_calls").update({
          status,
          transcript: transcript || undefined,
          meta: {
            ...prev,
            sarvam_interaction_id: body.interaction_id || null,
            sarvam_duration: body.duration ?? null,
            sarvam_failure_reason: body.failure_reason || null,
            sarvam_webhook: true,
          },
          updated_at: new Date().toISOString(),
        }).eq("id", call.id);
      }
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
