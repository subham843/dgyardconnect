// Complete / simulate AI voice call; optional Sarvam STT; CRM close-loop.
// Body: { call_id, transcript?, audio_url?, audio_base64?, outcome?, duration_sec?, status?, next_follow_up_at? }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { recordUsage, resolveTenantComm } from "../_shared/tenant_comm.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const OUTCOMES = new Set(["interested", "callback", "not_interested", "no_answer"]);

function admin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase not configured");
  return createClient(url, key);
}

async function sarvamStt(opts: {
  apiKey: string;
  audioUrl?: string;
  audioBase64?: string;
  language?: string;
}): Promise<{ text: string; sim: boolean; meta: Record<string, unknown> }> {
  const key = opts.apiKey || Deno.env.get("SARVAM_API_KEY") || "";
  if (!key) {
    return { text: "", sim: true, meta: { reason: "sarvam_api_key_missing" } };
  }
  if (!opts.audioUrl && !opts.audioBase64) {
    return { text: "", sim: true, meta: { reason: "no_audio_for_stt" } };
  }

  try {
    // Prefer URL-based STT when available; else multipart with base64 decoded blob.
    if (opts.audioUrl) {
      const res = await fetch("https://api.sarvam.ai/speech-to-text", {
        method: "POST",
        headers: {
          "api-subscription-key": key,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "saarika:v2",
          language_code: opts.language || "unknown",
          input_audio_url: opts.audioUrl,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        return { text: "", sim: false, meta: { sarvam_error: data, http_status: res.status } };
      }
      const text = String(data.transcript || data.text || "").trim();
      return { text, sim: false, meta: { sarvam: data } };
    }

    const raw = Uint8Array.from(atob(opts.audioBase64!), (c) => c.charCodeAt(0));
    const form = new FormData();
    form.set("file", new Blob([raw], { type: "audio/wav" }), "call.wav");
    form.set("model", "saarika:v2");
    form.set("language_code", opts.language || "unknown");
    const res = await fetch("https://api.sarvam.ai/speech-to-text", {
      method: "POST",
      headers: { "api-subscription-key": key },
      body: form,
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      return { text: "", sim: false, meta: { sarvam_error: data, http_status: res.status } };
    }
    const text = String(data.transcript || data.text || "").trim();
    return { text, sim: false, meta: { sarvam: data } };
  } catch (e) {
    return { text: "", sim: true, meta: { reason: "sarvam_stt_exception", error: String(e) } };
  }
}

async function sarvamTtsHint(apiKey: string, text: string): Promise<Record<string, unknown>> {
  const key = apiKey || Deno.env.get("SARVAM_API_KEY") || "";
  if (!key || !text) return { tts: "skipped" };
  // Store that TTS is available; full audio bytes usually returned to client — keep meta only.
  return {
    tts_ready: true,
    tts_note: "Use Sarvam text-to-speech with same api-subscription-key for agent prompts",
    preview: text.slice(0, 80),
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const callId = body.call_id as string;
    if (!callId) throw new Error("call_id required");

    const db = admin();
    const { data: call } = await db.from("bos_voice_calls").select("*").eq("id", callId).single();
    if (!call) throw new Error("call not found");

    let outcome = (body.outcome as string) || "interested";
    if (!OUTCOMES.has(outcome)) outcome = "interested";

    const comm = await resolveTenantComm(db, call.tenant_id as string);
    const voiceProv = comm.voiceProvider || Deno.env.get("VOICE_PROVIDER") || "stub";

    // Optional Sarvam key from tenant openai-style secrets or env
    const { data: settingsRow } = await db
      .from("bos_tenant_settings")
      .select("api_secrets")
      .eq("tenant_id", call.tenant_id)
      .maybeSingle();
    const secrets = (settingsRow?.api_secrets ?? {}) as Record<string, Record<string, string>>;
    const sarvamKey =
      secrets.sarvam?.api_key ||
      secrets.voice?.sarvam_api_key ||
      Deno.env.get("SARVAM_API_KEY") ||
      "";

    const audioUrl =
      (body.audio_url as string) ||
      (call.meta as Record<string, string>)?.recording_url ||
      (call.meta as Record<string, string>)?.audio_url ||
      "";
    const audioBase64 = (body.audio_base64 as string) || "";

    let transcript = (body.transcript as string) || "";
    let sttMeta: Record<string, unknown> = {};
    let sttSim = true;

    if (!transcript) {
      const stt = await sarvamStt({
        apiKey: sarvamKey,
        audioUrl: audioUrl || undefined,
        audioBase64: audioBase64 || undefined,
        language: (body.language as string) || "hi-IN",
      });
      sttMeta = stt.meta;
      sttSim = stt.sim;
      if (stt.text) {
        transcript = stt.text;
      } else {
        transcript =
          `Simulated Sarvam STT transcript for ${call.phone}: outcome=${outcome}. ` +
          `(voice_provider=${voiceProv}; sarvam=${sttSim ? "sim" : "live_empty"})`;
      }
    } else {
      sttSim = false;
      sttMeta = { source: "client_transcript" };
    }

    const ttsMeta = await sarvamTtsHint(sarvamKey, String(call.script || transcript).slice(0, 200));

    const summary = (body.summary as string) ||
      (outcome === "interested"
        ? "Customer showed interest; recommend quotation."
        : outcome === "callback"
        ? "Customer asked for callback."
        : outcome === "not_interested"
        ? "Customer not interested."
        : "No answer — reschedule follow-up.");
    const interest = (body.interest as string) ||
      (outcome === "interested" ? "high" : outcome === "callback" ? "medium" : "low");
    const objection = (body.objection as string) || null;
    const nextAction = (body.next_action as string) ||
      (outcome === "interested" ? "Send quotation / assign sales" : "Follow up");

    const status = (body.status as string) || "completed";
    const duration = (body.duration_sec as number) || 90;

    await db.from("bos_voice_calls").update({
      status,
      transcript,
      outcome,
      duration_sec: duration,
      crm_updated: Boolean(call.lead_id),
      updated_at: new Date().toISOString(),
      meta: {
        ...(call.meta ?? {}),
        summary,
        interest,
        objection,
        next_action: nextAction,
        voice_provider: voiceProv,
        stt_provider: sttSim ? "sarvam_sim" : "sarvam",
        stt: sttMeta,
        tts: ttsMeta,
        provider_note: sttSim
          ? "STT simulated — set SARVAM_API_KEY + audio_url/recording for live transcript"
          : "Sarvam STT transcript applied",
      },
    }).eq("id", callId);

    let nextFollowUp: string | null = null;
    if (typeof body.next_follow_up_at === "string" && body.next_follow_up_at.length > 0) {
      nextFollowUp = body.next_follow_up_at;
    } else if (outcome === "callback" || outcome === "no_answer") {
      nextFollowUp = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    }

    if (call.lead_id) {
      await db.from("bos_activities").insert({
        id: crypto.randomUUID(),
        tenant_id: call.tenant_id,
        lead_id: call.lead_id,
        activity_type: "voice_call",
        subject: `Voice call · ${outcome}`,
        body: transcript,
        completed_at: new Date().toISOString(),
      });

      await db.from("bos_activities")
        .update({ completed_at: new Date().toISOString() })
        .eq("lead_id", call.lead_id)
        .in("activity_type", ["follow_up", "voice_queued"])
        .is("completed_at", null);

      const leadPatch: Record<string, unknown> = {
        updated_at: new Date().toISOString(),
      };

      if (outcome === "interested") {
        leadPatch.score = "hot";
        leadPatch.stage = "contacted";
        leadPatch.next_follow_up_at = null;
        leadPatch.ai_summary = summary;
        const { data: cur } = await db.from("bos_leads").select("meta").eq("id", call.lead_id).maybeSingle();
        leadPatch.meta = {
          ...(cur?.meta ?? {}),
          handover_ready: true,
          ai_recommendation: nextAction,
          interest,
          objection,
        };
      } else if (outcome === "not_interested") {
        leadPatch.score = "cold";
        leadPatch.stage = "lost";
        leadPatch.next_follow_up_at = null;
      } else {
        leadPatch.next_follow_up_at = nextFollowUp;
      }

      await db.from("bos_leads").update(leadPatch).eq("id", call.lead_id);

      if (nextFollowUp && (outcome === "callback" || outcome === "no_answer")) {
        await db.from("bos_activities").insert({
          id: crypto.randomUUID(),
          tenant_id: call.tenant_id,
          lead_id: call.lead_id,
          activity_type: "follow_up",
          subject: "Follow-up after call",
          body: `Rescheduled after ${outcome}`,
          due_at: nextFollowUp,
        });
      }
    }

    const durationSec = Number(body.duration_sec ?? 60);
    const voiceMinutes = Math.max(1, Math.ceil(durationSec / 60));
    await recordUsage(db, call.tenant_id as string, "voice_minutes", voiceMinutes, {
      call_id: callId,
      outcome,
      stt_sim: sttSim,
    });
    await recordUsage(db, call.tenant_id as string, "api_calls", 1, { fn: "bos-voice-complete" });

    return new Response(
      JSON.stringify({
        ok: true,
        transcript,
        summary,
        interest,
        objection,
        next_action: nextAction,
        outcome,
        status,
        next_follow_up_at: nextFollowUp,
        stt_sim: sttSim,
        voice_provider: voiceProv,
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
