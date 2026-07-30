// Voice provider webhooks (Twilio / Exotel / Telnyx) — status + recording → Sarvam STT.
// Telnyx: call.answered → speak script; record-from-answer → call.recording.saved → complete.
// Also creates/links leads for inbound / missed calls when no matching outbound call.
// Query: ?tenant_id=…&provider=twilio|exotel|telnyx

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { resolveTenantComm } from "../_shared/tenant_comm.ts";

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

function decodeClientState(raw: string | undefined): Record<string, string> {
  if (!raw) return {};
  try {
    const json = atob(raw);
    const obj = JSON.parse(json) as Record<string, unknown>;
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(obj)) {
      if (v != null) out[k] = String(v);
    }
    return out;
  } catch {
    return {};
  }
}

async function telnyxSpeak(
  apiKey: string,
  callControlId: string,
  script: string,
  language = "en-US",
) {
  const text = script.replace(/\s+/g, " ").trim().slice(0, 1500);
  if (!text || !callControlId) return;
  await fetch(
    `https://api.telnyx.com/v2/calls/${encodeURIComponent(callControlId)}/actions/speak`,
    {
      method: "POST",
      headers: {
        Authorization: apiKey.startsWith("Bearer ") ? apiKey : `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        payload: text,
        voice: "female",
        language,
      }),
    },
  ).catch(() => {});
}

async function telnyxAnswer(apiKey: string, callControlId: string) {
  if (!callControlId || !apiKey) return;
  await fetch(
    `https://api.telnyx.com/v2/calls/${encodeURIComponent(callControlId)}/actions/answer`,
    {
      method: "POST",
      headers: {
        Authorization: apiKey.startsWith("Bearer ") ? apiKey : `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ record: "record-from-answer" }),
    },
  ).catch(() => {});
}

function scheduleDeferredComplete(
  job: () => Promise<void>,
) {
  const g = globalThis as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } };
  const p = job().catch(() => {});
  if (typeof g.EdgeRuntime?.waitUntil === "function") {
    g.EdgeRuntime.waitUntil(p);
  }
}

async function parseBody(req: Request): Promise<Record<string, string>> {
  const ct = req.headers.get("content-type") || "";
  if (ct.includes("application/json")) {
    const j = await req.json().catch(() => ({}));
    const out: Record<string, string> = {};
    for (const [k, v] of Object.entries(j as Record<string, unknown>)) {
      if (v != null && typeof v !== "object") out[k] = String(v);
    }
    // Telnyx Call Control webhook envelope: { data: { event_type, payload: {...} } }
    const data = (j as Record<string, unknown>)?.data;
    if (data && typeof data === "object") {
      const d = data as Record<string, unknown>;
      if (d.event_type != null) out.event_type = String(d.event_type);
      const payload = d.payload;
      if (payload && typeof payload === "object") {
        const p = payload as Record<string, unknown>;
        for (const [k, v] of Object.entries(p)) {
          if (v != null && typeof v !== "object") out[k] = String(v);
        }
        if (p.call_control_id) out.call_control_id = String(p.call_control_id);
        if (p.call_session_id) out.call_session_id = String(p.call_session_id);
        if (p.from) out.from = String(p.from);
        if (p.to) out.to = String(p.to);
        if (p.direction) out.direction = String(p.direction);
        if (p.state) out.state = String(p.state);
        if (p.hangup_cause) out.hangup_cause = String(p.hangup_cause);
        if (p.client_state) out.client_state = String(p.client_state);
        const recUrls = p.recording_urls;
        if (recUrls && typeof recUrls === "object") {
          const ru = recUrls as Record<string, unknown>;
          out.recording_url = String(ru.mp3 || ru.wav || Object.values(ru)[0] || "");
        }
        if (p.recording_url) out.recording_url = String(p.recording_url);
        if (p.public_recording_urls && typeof p.public_recording_urls === "object") {
          const pr = p.public_recording_urls as Record<string, unknown>;
          out.recording_url = String(pr.mp3 || pr.wav || out.recording_url || "");
        }
      }
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
  if (["completed", "complete", "answered", "hangup"].includes(s)) return "completed";
  if (["busy", "no-answer", "no_answer", "failed", "canceled", "cancelled", "rejected"].includes(s)) {
    return "failed";
  }
  if (["ringing", "queued", "initiated", "call.initiated"].includes(s)) return "ringing";
  if (["in-progress", "in_progress", "ongoing", "active"].includes(s)) return "in_progress";
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

    const eventType = (body.event_type || "").toLowerCase();
    const isTelnyx = providerHint === "telnyx" || eventType.startsWith("call.") ||
      Boolean(body.call_control_id);

    const callSid =
      body.CallSid ||
      body.Sid ||
      body.call_sid ||
      body.CallID ||
      body.call_control_id ||
      body.call_session_id ||
      "";
    const recordingUrl =
      body.RecordingUrl || body.recording_url || "";
    let statusRaw =
      body.CallStatus || body.Status || body.call_status || body.DialCallStatus || body.state || "";
    if (isTelnyx && eventType) {
      if (eventType === "call.answered") statusRaw = "in_progress";
      else if (eventType === "call.initiated") statusRaw = "ringing";
      else if (eventType === "call.hangup" || eventType === "call.recording.saved") {
        statusRaw = statusRaw || "completed";
        if (/no.?answer|busy|rejected|originator_cancel/i.test(body.hangup_cause || "")) {
          statusRaw = "no-answer";
        }
      }
    }
    const directionRaw = (body.Direction || body.direction || "").toLowerCase();
    const isInbound =
      directionRaw.includes("inbound") ||
      directionRaw === "incoming" ||
      body.CallType === "incoming" ||
      url.searchParams.get("inbound") === "1";
    // For inbound, From is caller; for outbound Twilio To is customer
    const customerPhone = isInbound
      ? (body.From || body.from || body.CallFrom || "")
      : (body.To || body.to || body.CallTo || body.From || body.from || "");

    const clientState = decodeClientState(body.client_state);
    const bosCallIdHint = clientState.bos_call_id || "";

    const db = admin();
    let call: Record<string, unknown> | null = null;

    if (bosCallIdHint) {
      const { data } = await db
        .from("bos_voice_calls")
        .select("*")
        .eq("id", bosCallIdHint)
        .is("deleted_at", null)
        .maybeSingle();
      if (data) call = data as Record<string, unknown>;
    }

    if (!call && callSid) {
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
      const mapped = statusRaw ? mapStatus(statusRaw) : (eventType === "call.initiated" ? "ringing" : "completed");
      const missed = mappedIsMissed(statusRaw);
      const greeting =
        "Namaste, DG.YARD mein aapka swagat hai. Please hold — hum aapki madad ke liye yahan hain.";
      await db.from("bos_voice_calls").insert({
        id: callId,
        tenant_id: tenantHint,
        lead_id: leadId,
        phone: customerPhone,
        direction: "inbound",
        status: mapped === "failed" ? "failed" : mapped,
        provider: providerHint || (isTelnyx ? "telnyx" : "webhook"),
        script: greeting,
        meta: {
          voice_provider: providerHint || (isTelnyx ? "telnyx" : "webhook"),
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
        script: greeting,
        status: mapped,
        meta: {},
      };
      await logEvent(db, {
        tenantId: tenantHint,
        callId,
        leadId,
        provider: providerHint || (isTelnyx ? "telnyx" : undefined),
        eventType: missed ? "inbound_missed" : "inbound",
        payload: { callSid, statusRaw, customerPhone, recordingUrl, eventType },
      });
      if (leadId) {
        await db.from("bos_activities").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantHint,
          lead_id: leadId,
          activity_type: missed ? "voice_missed" : "voice_inbound",
          subject: missed ? "Missed inbound call" : "Inbound call",
          body: `Phone ${customerPhone} · ${statusRaw || eventType || "received"}`,
          completed_at: new Date().toISOString(),
        });
      }
    }

    // Telnyx inbound with call_control_id but no phone yet (rare) — still try match by sid
    if (!call && isTelnyx && isInbound && callSid && eventType === "call.initiated") {
      await logEvent(db, {
        tenantId: tenantHint,
        provider: "telnyx",
        eventType: "inbound_no_phone",
        payload: { callSid, body },
      });
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
      provider: providerHint || (isTelnyx ? "telnyx" : undefined),
      eventType: recordingUrl
        ? "recording"
        : (eventType || mapped || "status"),
      payload: { callSid, statusRaw, recordingUrl, direction: directionRaw, eventType },
    });

    // Telnyx inbound: answer + greet on call.initiated
    if (
      isTelnyx &&
      isInbound &&
      eventType === "call.initiated" &&
      callSid &&
      !prevMeta.telnyx_answered
    ) {
      try {
        const comm = await resolveTenantComm(db, tenantId);
        const apiKey = comm.voiceApiKey || comm.voiceApiToken;
        if (apiKey) {
          await telnyxAnswer(apiKey, callSid);
          const greeting = String(
            call.script ||
              "Namaste, DG.YARD mein aapka swagat hai. Please hold — hum aapki madad ke liye yahan hain.",
          );
          const lang = greeting.match(/[\u0900-\u097F]/) ? "hi-IN" : "en-US";
          // brief pause so answer settles
          await new Promise((r) => setTimeout(r, 400));
          await telnyxSpeak(apiKey, callSid, greeting, lang);
          await db.from("bos_voice_calls").update({
            status: "in_progress",
            meta: {
              ...meta,
              telnyx_answered: true,
              inbound_greeted: true,
            },
            updated_at: new Date().toISOString(),
          }).eq("id", call.id);
          await logEvent(db, {
            tenantId,
            callId: call.id as string,
            leadId: (call.lead_id as string) || null,
            provider: "telnyx",
            eventType: "inbound_answer_speak",
            payload: { call_control_id: callSid, language: lang },
          });
        }
      } catch (_) { /* non-fatal */ }
    }

    // Telnyx outbound: speak queued script when callee answers
    if (isTelnyx && !isInbound && eventType === "call.answered" && callSid) {
      try {
        const comm = await resolveTenantComm(db, tenantId);
        const apiKey = comm.voiceApiKey || comm.voiceApiToken;
        const script = String(
          call.script ||
            (prevMeta.script_preview as string) ||
            "Hello from DG.YARD",
        );
        if (apiKey) {
          const lang = script.match(/[\u0900-\u097F]/) ? "hi-IN" : "en-US";
          await telnyxSpeak(apiKey, callSid, script, lang);
          await logEvent(db, {
            tenantId,
            callId: call.id as string,
            leadId: (call.lead_id as string) || null,
            provider: "telnyx",
            eventType: "speak",
            payload: { call_control_id: callSid, language: lang },
          });
        }
      } catch (_) { /* non-fatal */ }
    }

    const alreadyDone = call.status === "completed" || call.status === "failed";
    const hasRecordingEvent =
      Boolean(recordingUrl) || eventType === "call.recording.saved";
    const shouldComplete =
      !alreadyDone &&
      (
        hasRecordingEvent ||
        (eventType === "call.hangup" && mapped === "failed") ||
        (!isInbound &&
          eventType !== "call.answered" &&
          eventType !== "call.initiated" &&
          eventType !== "call.speak.started" &&
          eventType !== "call.speak.ended" &&
          (mapped === "completed" ||
            (body.RecordingStatus || "").toLowerCase() === "completed" ||
            eventType === "call.hangup"))
      );

    if (shouldComplete) {
      const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      const completeUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-voice-complete`;
      const outcome =
        mapped === "failed" && /no-answer|no_answer|busy/i.test(statusRaw + body.hangup_cause)
          ? "no_answer"
          : "interested";
      const waitForRecording =
        isTelnyx && eventType === "call.hangup" && !recordingUrl && mapped !== "failed";

      if (waitForRecording) {
        const pendingUntil = new Date(Date.now() + 45_000).toISOString();
        await db.from("bos_voice_calls").update({
          meta: {
            ...meta,
            hangup_at: new Date().toISOString(),
            pending_complete_at: pendingUntil,
          },
          updated_at: new Date().toISOString(),
        }).eq("id", call.id);

        const callIdForJob = call.id as string;
        scheduleDeferredComplete(async () => {
          await new Promise((r) => setTimeout(r, 45_000));
          const { data: fresh } = await db
            .from("bos_voice_calls")
            .select("id,status,meta,recording_url,tenant_id")
            .eq("id", callIdForJob)
            .maybeSingle();
          if (!fresh) return;
          if (fresh.status === "completed" || fresh.status === "failed") return;
          const fm = (fresh.meta ?? {}) as Record<string, unknown>;
          const audio =
            fresh.recording_url ||
            fm.recording_url ||
            fm.audio_url ||
            undefined;
          await fetch(completeUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${key}`,
            },
            body: JSON.stringify({
              call_id: callIdForJob,
              tenant_id: fresh.tenant_id || tenantId,
              audio_url: audio,
              outcome: "interested",
              status: "completed",
            }),
          }).catch(() => {});
        });
      } else {
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
            outcome: hasRecordingEvent
              ? outcome
              : (mapped === "failed" ? "no_answer" : outcome),
            status: "completed",
          }),
        }).catch(() => {});
      }
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
        event_type: eventType || null,
        spoke: isTelnyx && (eventType === "call.answered" || eventType === "call.initiated"),
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
