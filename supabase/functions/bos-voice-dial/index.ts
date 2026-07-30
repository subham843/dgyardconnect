// Place outbound voice call via tenant provider secrets.
// Providers: stub | exotel | twilio | plivo | vonage | knowlarity | myoperator | telnyx
// Body: { call_id, tenant_id? }
// Secrets live under api_secrets.voice.<provider> (legacy flat voice.* still works).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  resolveTenantComm,
  recordUsage,
  type TenantCommConfig,
} from "../_shared/tenant_comm.ts";
import { assertUsageLimit } from "../_shared/plan_limits.ts";

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

function basicAuth(user: string, pass: string) {
  return `Basic ${btoa(`${user}:${pass}`)}`;
}

type DialResult = {
  ok: boolean;
  sim: boolean;
  status: string;
  meta: Record<string, unknown>;
  error?: string;
  providerCallId?: string;
};

function missing(...parts: string[]) {
  return parts.some((p) => !p);
}

/** Twilio / most CPaaS need E.164. Indian 10-digit → +91… */
function toE164(raw: string, defaultCountry = "91"): string {
  let p = String(raw || "").trim();
  if (!p) return p;
  // keep leading +
  const hasPlus = p.startsWith("+");
  const digits = p.replace(/\D/g, "");
  if (!digits) return p;
  if (hasPlus || digits.length > 10) {
    return `+${digits}`;
  }
  if (digits.length === 10) {
    return `+${defaultCountry}${digits}`;
  }
  if (digits.length === 11 && digits.startsWith("0")) {
    return `+${defaultCountry}${digits.slice(1)}`;
  }
  if (digits.length === 12 && digits.startsWith(defaultCountry)) {
    return `+${digits}`;
  }
  return hasPlus ? `+${digits}` : `+${digits}`;
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function twilioErrorMessage(payload: unknown, status: number): string {
  const p = (payload ?? {}) as Record<string, unknown>;
  const msg = String(p.message || p.error_message || p.detail || "").trim();
  if (msg) return `Twilio dial failed (${status}): ${msg}`;
  return `Twilio dial failed (${status})`;
}

async function dialExotel(comm: TenantCommConfig, phone: string): Promise<DialResult> {
  if (missing(comm.voiceApiKey, comm.voiceApiToken, comm.voiceAccountSid)) {
    return {
      ok: false,
      sim: true,
      status: "queued",
      meta: { reason: "exotel_missing_api_key_token_or_sid" },
    };
  }
  const subdomain = comm.voiceExtra.subdomain || "api";
  const sid = comm.voiceAccountSid;
  const from = comm.voiceNumber || phone;
  const host = subdomain.includes(".") ? subdomain : `${subdomain}.exotel.com`;
  const url =
    `https://${host}/v1/Accounts/${encodeURIComponent(sid)}/Calls/connect.json`;
  const form = new URLSearchParams();
  form.set("From", phone);
  form.set("To", from);
  if (comm.voiceNumber) form.set("CallerId", comm.voiceNumber);

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: basicAuth(comm.voiceApiKey, comm.voiceApiToken),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: form.toString(),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      ok: false,
      sim: false,
      status: "failed",
      meta: { exotel: payload, http_status: res.status },
      error: `Exotel dial failed (${res.status})`,
    };
  }
  return {
    ok: true,
    sim: false,
    status: "in_progress",
    meta: { exotel: payload, http_status: res.status },
    providerCallId: String(
      (payload as Record<string, Record<string, string>>)?.Call?.Sid ||
        (payload as Record<string, string>)?.CallSid ||
        (payload as Record<string, string>)?.Sid ||
        "",
    ) || undefined,
  };
}

async function dialTwilio(
  comm: TenantCommConfig,
  phone: string,
  script: string,
  tenantId: string,
  callId: string,
): Promise<DialResult> {
  const accountSid = String(comm.voiceAccountSid || comm.twilioSid || "").trim();
  const token = String(comm.voiceApiToken || comm.voiceApiKey || "").trim();
  const from = toE164(String(comm.voiceNumber || comm.twilioFrom || "").trim());
  const to = toE164(phone);
  if (missing(accountSid, token, from)) {
    return {
      ok: false,
      sim: true,
      status: "queued",
      meta: { reason: "twilio_missing_sid_token_or_from" },
    };
  }
  if (!to.startsWith("+") || to.length < 11) {
    return {
      ok: false,
      sim: false,
      status: "failed",
      meta: { reason: "invalid_to_e164", phone, to },
      error: `Invalid To number "${phone}" — use E.164 like +917004582230`,
    };
  }
  if (!from.startsWith("+")) {
    return {
      ok: false,
      sim: false,
      status: "failed",
      meta: { reason: "invalid_from_e164", from },
      error: `Invalid From number "${comm.voiceNumber}" — Twilio Caller ID must be E.164 (+91…)`,
    };
  }
  const base = Deno.env.get("SUPABASE_URL") || "";
  const twimlUrl =
    `${base}/functions/v1/bos-voice-twiml?tenant_id=${encodeURIComponent(tenantId)}` +
    `&call_id=${encodeURIComponent(callId)}`;
  const statusUrl =
    `${base}/functions/v1/bos-voice-webhook?tenant_id=${encodeURIComponent(tenantId)}&provider=twilio`;

  const url =
    `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(accountSid)}/Calls.json`;
  const form = new URLSearchParams();
  form.set("To", to);
  form.set("From", from);
  // Conversational: Sarvam TTS Play + Gather (not Twilio <Say>)
  form.set("Url", twimlUrl);
  form.set("Method", "POST");
  form.set("StatusCallback", statusUrl);
  form.set("StatusCallbackEvent", "initiated ringing answered completed");
  form.set("StatusCallbackMethod", "POST");
  form.set("Record", "true");
  form.set("RecordingStatusCallback", statusUrl);
  form.set("RecordingStatusCallbackMethod", "POST");

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: basicAuth(accountSid, token),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: form.toString(),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      ok: false,
      sim: false,
      status: "failed",
      meta: { twilio: payload, http_status: res.status, to, from, twiml_url: twimlUrl },
      error: twilioErrorMessage(payload, res.status),
    };
  }
  return {
    ok: true,
    sim: false,
    status: "in_progress",
    meta: {
      twilio: payload,
      http_status: res.status,
      to,
      from,
      twiml_url: twimlUrl,
      conversational: true,
      script_preview: script.slice(0, 80),
    },
    providerCallId: String((payload as Record<string, string>)?.sid || "") || undefined,
  };
}

async function dialPlivo(
  comm: TenantCommConfig,
  phone: string,
  script: string,
): Promise<DialResult> {
  const authId = comm.voiceAccountSid;
  const authToken = comm.voiceApiToken || comm.voiceApiKey;
  const from = comm.voiceNumber;
  if (missing(authId, authToken, from)) {
    return {
      ok: false,
      sim: true,
      status: "queued",
      meta: { reason: "plivo_missing_auth_id_token_or_from" },
    };
  }
  const url = `https://api.plivo.com/v1/Account/${encodeURIComponent(authId)}/Call/`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: basicAuth(authId, authToken),
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: phone,
      answer_url: `data:application/xml,${
        encodeURIComponent(
          `<?xml version="1.0"?><Response><Speak>${
            script.slice(0, 400).replace(/[<>&]/g, "")
          }</Speak></Response>`,
        )
      }`,
      answer_method: "GET",
    }),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      ok: false,
      sim: false,
      status: "failed",
      meta: { plivo: payload, http_status: res.status },
      error: `Plivo dial failed (${res.status})`,
    };
  }
  return {
    ok: true,
    sim: false,
    status: "in_progress",
    meta: { plivo: payload, http_status: res.status },
  };
}

async function dialVonage(
  comm: TenantCommConfig,
  phone: string,
  script: string,
): Promise<DialResult> {
  if (missing(comm.voiceNumber)) {
    return {
      ok: false,
      sim: true,
      status: "queued",
      meta: { reason: "vonage_missing_from_number" },
    };
  }
  let jwt = Deno.env.get("VONAGE_JWT") || "";
  if (!jwt && comm.voiceAccountSid && comm.voiceExtra.private_key) {
    try {
      const { createVonageJwt } = await import("../_shared/vonage_jwt.ts");
      jwt = await createVonageJwt(comm.voiceAccountSid, comm.voiceExtra.private_key);
    } catch (e) {
      return {
        ok: false,
        sim: true,
        status: "queued",
        meta: { reason: "vonage_jwt_sign_failed", error: String(e) },
      };
    }
  }
  if (!jwt) {
    return {
      ok: false,
      sim: true,
      status: "queued",
      meta: {
        reason: "vonage_needs_application_id_and_private_key",
        note: "Paste Vonage Application ID + private key PEM under voice.vonage",
      },
    };
  }
  const res = await fetch("https://api.nexmo.com/v1/calls", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${jwt}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      to: [{ type: "phone", number: phone.replace(/\D/g, "") }],
      from: { type: "phone", number: comm.voiceNumber.replace(/\D/g, "") },
      ncco: [{ action: "talk", text: script.slice(0, 500) }],
    }),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      ok: false,
      sim: false,
      status: "failed",
      meta: { vonage: payload, http_status: res.status },
      error: `Vonage dial failed (${res.status})`,
    };
  }
  return {
    ok: true,
    sim: false,
    status: "in_progress",
    meta: { vonage: payload, http_status: res.status },
  };
}

async function dialKnowlarity(comm: TenantCommConfig, phone: string): Promise<DialResult> {
  const apiKey = comm.voiceExtra.x_api_key || comm.voiceApiKey;
  const auth = comm.voiceApiToken;
  const kNumber = comm.voiceAccountSid || comm.voiceNumber;
  const agent = comm.voiceNumber;
  const url = comm.voiceExtra.base_url ||
    "https://kpi.knowlarity.com/Basic/v1/account/call/makecall";
  if (missing(apiKey, kNumber, phone)) {
    return {
      ok: false,
      sim: true,
      status: "queued",
      meta: { reason: "knowlarity_missing_api_key_k_number_or_phone" },
    };
  }
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "x-api-key": apiKey,
  };
  if (auth) headers["Authorization"] = auth.startsWith("Bearer") ? auth : auth;

  const res = await fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify({
      k_number: kNumber,
      customer_number: phone,
      agent_number: agent || kNumber,
      caller_id: kNumber,
    }),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      ok: false,
      sim: false,
      status: "failed",
      meta: { knowlarity: payload, http_status: res.status },
      error: `Knowlarity dial failed (${res.status})`,
    };
  }
  return {
    ok: true,
    sim: false,
    status: "in_progress",
    meta: { knowlarity: payload, http_status: res.status },
  };
}

async function dialMyOperator(comm: TenantCommConfig, phone: string): Promise<DialResult> {
  const token = comm.voiceApiKey;
  const from = comm.voiceNumber;
  const url = comm.voiceExtra.base_url || "https://developers.myoperator.co/voice/call";
  if (missing(token, from, phone)) {
    return {
      ok: false,
      sim: true,
      status: "queued",
      meta: { reason: "myoperator_missing_token_from_or_phone" },
    };
  }
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: token.startsWith("Bearer") ? token : `Bearer ${token}`,
    },
    body: JSON.stringify({
      company_id: comm.voiceAccountSid || undefined,
      from,
      to: phone,
      secret: comm.voiceApiToken || undefined,
    }),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      ok: false,
      sim: false,
      status: "failed",
      meta: { myoperator: payload, http_status: res.status },
      error: `MyOperator dial failed (${res.status})`,
    };
  }
  return {
    ok: true,
    sim: false,
    status: "in_progress",
    meta: { myoperator: payload, http_status: res.status },
  };
}

async function dialTelnyx(
  comm: TenantCommConfig,
  phone: string,
  script: string,
  tenantId: string,
  callId: string,
): Promise<DialResult> {
  const apiKey = comm.voiceApiKey || comm.voiceApiToken;
  const connectionId = comm.voiceExtra.connection_id || comm.voiceAccountSid;
  const from = comm.voiceNumber;
  if (missing(apiKey, connectionId, from)) {
    return {
      ok: false,
      sim: true,
      status: "queued",
      meta: { reason: "telnyx_missing_api_key_connection_id_or_from" },
    };
  }
  const webhookBase = Deno.env.get("SUPABASE_URL") || "";
  const webhookUrl = webhookBase
    ? `${webhookBase}/functions/v1/bos-voice-webhook?tenant_id=${encodeURIComponent(tenantId)}&provider=telnyx`
    : undefined;
  const body: Record<string, unknown> = {
    connection_id: connectionId,
    to: phone,
    from,
    answering_machine_detection: "disabled",
    // Record from answer → call.recording.saved webhook → Sarvam STT
    record: "record-from-answer",
  };
  if (webhookUrl) {
    body.webhook_url = webhookUrl;
    body.webhook_url_method = "POST";
  }
  // Round-trip our call id so speak-on-answer can load the script
  body.client_state = btoa(JSON.stringify({
    bos_call_id: callId,
    tenant_id: tenantId,
  }));

  const res = await fetch("https://api.telnyx.com/v2/calls", {
    method: "POST",
    headers: {
      Authorization: apiKey.startsWith("Bearer ") ? apiKey : `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify(body),
  });
  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    return {
      ok: false,
      sim: false,
      status: "failed",
      meta: { telnyx: payload, http_status: res.status },
      error: `Telnyx dial failed (${res.status})`,
    };
  }
  const data = (payload as Record<string, Record<string, unknown>>)?.data ?? {};
  const callControlId = String(
    data.call_control_id || data.call_session_id || data.call_leg_id || "",
  ) || undefined;
  return {
    ok: true,
    sim: false,
    status: "in_progress",
    meta: {
      telnyx: payload,
      http_status: res.status,
      record: "record-from-answer",
      script_preview: script.slice(0, 80),
    },
    providerCallId: callControlId,
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

    const tenantId = (body.tenant_id as string) || (call.tenant_id as string) || DEFAULT_TENANT;
    await assertUsageLimit(db, tenantId, "voice_minutes", 1);

    const comm = await resolveTenantComm(db, tenantId);
    const phoneRaw = String(call.phone || "").trim();
    if (!phoneRaw) throw new Error("call has no phone");

    const provider = (comm.voiceProvider || "stub").toLowerCase();
    const script = String(call.script || "Hello from DG.YARD").slice(0, 500);

    // Twilio / Telnyx / Plivo expect E.164 — normalize 10-digit Indian numbers to +91…
    const phone = ["twilio", "telnyx", "plivo", "vonage", "nexmo"].includes(provider)
      ? toE164(phoneRaw)
      : phoneRaw;

    if (phone !== phoneRaw) {
      await db.from("bos_voice_calls").update({
        phone,
        updated_at: new Date().toISOString(),
      }).eq("id", callId);
    }

    let result: DialResult = {
      ok: false,
      sim: true,
      status: "ringing",
      meta: { reason: "stub" },
    };

    if (provider === "exotel") result = await dialExotel(comm, phone);
    else if (provider === "twilio") {
      result = await dialTwilio(comm, phone, script, tenantId, callId);
    } else if (provider === "plivo") result = await dialPlivo(comm, phone, script);
    else if (provider === "vonage" || provider === "nexmo") {
      result = await dialVonage(comm, phone, script);
    } else if (provider === "knowlarity") result = await dialKnowlarity(comm, phone);
    else if (provider === "myoperator") result = await dialMyOperator(comm, phone);
    else if (provider === "telnyx") result = await dialTelnyx(comm, phone, script, tenantId, callId);
    else {
      result = {
        ok: false,
        sim: true,
        status: "ringing",
        meta: {
          reason: "stub_provider",
          note: "Set Settings → Voice provider to exotel/twilio/plivo/vonage/knowlarity/myoperator/telnyx",
        },
      };
    }

    if (result.error) {
      await db.from("bos_voice_calls").update({
        status: "failed",
        provider,
        updated_at: new Date().toISOString(),
        meta: {
          ...(call.meta ?? {}),
          voice_provider: provider,
          dial_sim: false,
          dial_error: result.meta,
          provider_note: result.error,
        },
      }).eq("id", callId);
      throw new Error(result.error);
    }

    const status = result.sim
      ? (result.status === "queued" ? "queued" : "ringing")
      : result.status;

    await db.from("bos_voice_calls").update({
      status,
      provider: result.sim ? (call.provider || "stub") : provider,
      updated_at: new Date().toISOString(),
      meta: {
        ...(call.meta ?? {}),
        voice_provider: result.sim ? "stub" : provider,
        dial_sim: result.sim,
        dial_at: new Date().toISOString(),
        provider_call_id: result.providerCallId ||
          (call.meta as Record<string, string>)?.provider_call_id,
        provider_note: result.sim
          ? `Stub — add secrets under api_secrets.voice.${provider}`
          : `Live ${provider} dial started`,
        ...result.meta,
      },
    }).eq("id", callId);

    await recordUsage(db, tenantId, "voice_minutes", 1, {
      fn: "bos-voice-dial",
      sim: result.sim,
      provider: result.sim ? "stub" : provider,
    });
    await recordUsage(db, tenantId, "api_calls", 1, { fn: "bos-voice-dial" });

    return new Response(
      JSON.stringify({
        ok: true,
        call_id: callId,
        sim: result.sim,
        provider: result.sim ? "stub" : provider,
        status,
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
