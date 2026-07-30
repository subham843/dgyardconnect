// Complete / simulate AI voice call; CRM lead + follow-up close-loop.
// Body: { call_id, transcript?, outcome?, duration_sec?, status?, next_follow_up_at? }
// Outcomes: interested | callback | not_interested | no_answer

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { recordUsage } from "../_shared/tenant_comm.ts";

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

    const transcript = (body.transcript as string) ||
      `Simulated Sarvam STT transcript for ${call.phone}: outcome=${outcome}. ` +
      `(VOICE_PROVIDER=${Deno.env.get("VOICE_PROVIDER") || "stub"})`;

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
    const provider = Deno.env.get("VOICE_PROVIDER") || "stub";

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
        voice_provider: provider,
        provider_note: provider === "stub"
          ? "Simulated dial — Exotel/Twilio + Sarvam STT/TTS hooks ready"
          : "Live provider path",
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

      // Complete prior follow-up / queued voice activities.
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
        leadPatch.meta = {
          ...(call.meta ?? {}),
          handover_ready: true,
          ai_recommendation: nextAction,
          interest,
          objection,
        };
        // merge with existing lead meta
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
        // callback / no_answer — keep stage; reschedule follow-up
        leadPatch.next_follow_up_at = nextFollowUp;
        if (outcome === "callback" && !leadPatch.stage) {
          // leave stage as-is
        }
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
