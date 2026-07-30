// Voice provider webhooks (Twilio / Exotel) — status + recording → Sarvam STT via bos-voice-complete.
// Also creates/links leads for inbound / missed calls when no matching outbound call.
// Query: ?tenant_id=…&provider=twilio|exotel

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

function normalizePhone(p: string): string {
  return p.replace(/\D/g, "");
}

async function logEvent(
  db: ReturnType<typeof admin>,
  opts: {
    tenantId: string;
    callId?: string | null;
    leadId?: string | null;
    provider?: string;
    eventType: string;
    payload: Record<string, unknown>;
  },
) {
  try {
    await db.from("bos_voice_events").insert({
      id: crypto.randomUUID(),
      tenant_id: opts.tenantId,
      call_id: opts.callId ?? null,
      lead_id: opts.leadId ?? null,
      provider: opts.provider ?? null,
      event_type: opts.eventType,
      payload: opts.payload,
    });
  } catch (_) { /* non-fatal if migration not applied yet */ }
}

async function findOrCreateLeadByPhone(
  db: ReturnType<typeof admin>,
  tenantId: string,
  phone: string,
): Promise<string | null> {
  const digits = normalizePhone(phone);
  if (digits.length < 8) return null;
  const tail = digits.slice(-10);
  const { data: leads } = await db
    .from("bos_leads")
    .select("id,phone")
    .eq("tenant_id", tenantId)
    .is("deleted_at", null)
    .order("created_at", { ascending: false })
    .limit(50);
  const existing = (leads ?? []).find((l) =>
    normalizePhone(String(l.phone || "")).endsWith(tail)
  );
  if (existing) return existing.id as string;
  const id = crypto.randomUUID();
  await db.from("bos_leads").insert({
    id,
    tenant_id: tenantId,
    full_name: `Caller ${tail.slice(-4)}`,
    phone: phone.startsWith("+") ? phone : `+${digits}`,
    source: "voice_inbound",
    stage: "new",
    score: "warm",
    meta: { inbound_voice: true },
  });
  return id;
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
      body.CallSid || body.Sid || body.call_sid || body.CallID || "";
    const recordingUrl =
      body.RecordingUrl || body.recording_url || "";
    const statusRaw =
      body.CallStatus || body.Status || body.call_status || body.DialCallStatus || "";
    const directionRaw = (body.Direction || body.direction || "").toLowerCase();
    const isInbound =
      directionRaw.includes("inbound") ||
      body.CallType === "incoming" ||
      url.searchParams.get("inbound") === "1";
    // For inbound, From is caller; for outbound Twilio To is customer
    const customerPhone = isInbound
      ? (body.From || body.from || body.CallFrom || "")
      : (body.To || body.to || body.CallTo || body.From || "");

    const db = admin();
    let call: Record<string, unknown> | null = null;

    if (callSid) {
      const { data: rows } = await db
        .from("bos_voice_calls")
        .select("*")
        .eq("tenant_id", tenantHint)
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(80);
      call = (rows ?? []).find((r) => {
        const m = (r.meta ?? {}) as Record<string, unknown>;
        return m.provider_call_id === callSid || String(m.provider_call_id) === callSid;
      }) ?? null;

      if (!call) {
        const { data: all } = await db
          .from("bos_voice_calls")
          .select("*")
          .is("deleted_at", null)
          .order("created_at", { ascending: false })
          .limit(120);
        call = (all ?? []).find((r) => {
          const m = (r.meta ?? {}) as Record<string, unknown>;
          return m.provider_call_id === callSid;
        }) ?? null;
      }
    }

    if (!call && customerPhone && !isInbound) {
      const digits = normalizePhone(customerPhone).slice(-10);
      const { data: rows } = await db
        .from("bos_voice_calls")
        .select("*")
        .eq("tenant_id", tenantHint)
        .is("deleted_at", null)
        .in("status", ["queued", "ringing", "in_progress"])
        .order("created_at", { ascending: false })
        .limit(20);
      call = (rows ?? []).find((r) =>
        normalizePhone(String(r.phone || "")).endsWith(digits)
      ) ?? null;
    }

    // Inbound / missed with no matching outbound → create call + lead
    if (!call && customerPhone && isInbound) {
      const leadId = await findOrCreateLeadByPhone(db, tenantHint, customerPhone);
      const callId = crypto.randomUUID();
      const mapped = statusRaw ? mapStatus(statusRaw) : "completed";
      const missed = mappedIsMissed(statusRaw);
      await db.from("bos_voice_calls").insert({
        id: callId,
        tenant_id: tenantHint,
        lead_id: leadId,
        phone: customerPhone,
        direction: "inbound",
        status: mapped === "failed" ? "failed" : mapped,
        provider: providerHint || "webhook",
        meta: {
          voice_provider: providerHint || "webhook",
          provider_call_id: callSid || null,
          inbound: true,
          missed,
          webhook_at: new Date().toISOString(),
          recording_url: recordingUrl || null,
          audio_url: recordingUrl || null,
        },
      });
      call = {
        id: callId,
        tenant_id: tenantHint,
        lead_id: leadId,
        phone: customerPhone,
        meta: {},
      };
      await logEvent(db, {
        tenantId: tenantHint,
        callId,
        leadId,
        provider: providerHint,
        eventType: missed ? "inbound_missed" : "inbound",
        payload: { callSid, statusRaw, customerPhone, recordingUrl },
      });
      if (leadId) {
        await db.from("bos_activities").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantHint,
          lead_id: leadId,
          activity_type: missed ? "voice_missed" : "voice_inbound",
          subject: missed ? "Missed inbound call" : "Inbound call",
          body: `Phone ${customerPhone} · ${statusRaw || "received"}`,
          completed_at: new Date().toISOString(),
        });
      }
    }

    if (!call) {
      await logEvent(db, {
        tenantId: tenantHint,
        provider: providerHint,
        eventType: "unmatched",
        payload: { callSid, statusRaw, customerPhone, body },
      });
      return new Response(JSON.stringify({ ok: false, error: "call not matched", callSid }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const tenantId = (call.tenant_id as string) || tenantHint;
    const mapped = statusRaw ? mapStatus(statusRaw) : null;
    const prevMeta = (call.meta ?? {}) as Record<string, unknown>;
    const meta = {
      ...prevMeta,
      provider_call_id: callSid || prevMeta.provider_call_id,
      webhook_provider: providerHint || "unknown",
      webhook_at: new Date().toISOString(),
      webhook_raw_status: statusRaw,
      recording_url: recordingUrl || prevMeta.recording_url,
      audio_url: recordingUrl || prevMeta.audio_url,
    };

    const patch: Record<string, unknown> = {
      meta,
      updated_at: new Date().toISOString(),
    };
    if (mapped && mapped !== "completed") patch.status = mapped;
    if (recordingUrl) patch.recording_url = recordingUrl;

    await db.from("bos_voice_calls").update(patch).eq("id", call.id);

    await logEvent(db, {
      tenantId,
      callId: call.id as string,
      leadId: (call.lead_id as string) || null,
      provider: providerHint,
      eventType: recordingUrl ? "recording" : (mapped || "status"),
      payload: { callSid, statusRaw, recordingUrl, direction: directionRaw },
    });

    const shouldComplete =
      Boolean(recordingUrl) ||
      mapped === "completed" ||
      (body.RecordingStatus || "").toLowerCase() === "completed";

    if (shouldComplete && !isInbound) {
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
        inbound: isInbound,
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

function mappedIsMissed(statusRaw: string): boolean {
  return /no-answer|no_answer|busy|missed|canceled|cancelled/i.test(statusRaw);
}
