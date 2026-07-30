// Place outbound voice call. Exotel when tenant/global secrets set; else stub.
// Body: { call_id, tenant_id? }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { resolveTenantComm, recordUsage } from "../_shared/tenant_comm.ts";
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
    const phone = String(call.phone || "").trim();
    if (!phone) throw new Error("call has no phone");

    const provider = (comm.voiceProvider || "stub").toLowerCase();
    const canLive =
      provider !== "stub" &&
      !!comm.voiceApiKey &&
      (provider !== "exotel" || (!!comm.voiceAccountSid && !!comm.voiceApiToken));

    let sim = true;
    let liveMeta: Record<string, unknown> = {};
    let status = "ringing";

    if (canLive && provider === "exotel") {
      const sid = comm.voiceAccountSid;
      const from = comm.voiceNumber || phone;
      const url =
        `https://api.exotel.com/v1/Accounts/${encodeURIComponent(sid)}/Calls/connect.json`;
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
      liveMeta = { exotel: payload, http_status: res.status };
      if (!res.ok) {
        status = "failed";
        sim = false;
        await db.from("bos_voice_calls").update({
          status,
          updated_at: new Date().toISOString(),
          meta: {
            ...(call.meta ?? {}),
            voice_provider: "exotel",
            dial_sim: false,
            dial_error: payload,
            provider_note: "Exotel dial failed",
          },
        }).eq("id", callId);
        throw new Error(`Exotel dial failed (${res.status})`);
      }
      sim = false;
      status = "in_progress";
    } else if (canLive && provider === "twilio") {
      // Minimal Twilio Calls create when Account SID + token present.
      const accountSid = comm.voiceAccountSid || comm.twilioSid;
      const token = comm.voiceApiToken || comm.voiceApiKey;
      const from = comm.voiceNumber || comm.twilioFrom;
      if (!accountSid || !token || !from) {
        liveMeta = { reason: "twilio_missing_sid_token_or_from" };
      } else {
        const url =
          `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(accountSid)}/Calls.json`;
        const form = new URLSearchParams();
        form.set("To", phone);
        form.set("From", from);
        form.set("Twiml", `<Response><Say>${String(call.script || "Hello from DG.YARD").slice(0, 500)}</Say></Response>`);
        const res = await fetch(url, {
          method: "POST",
          headers: {
            Authorization: basicAuth(accountSid, token),
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: form.toString(),
        });
        const payload = await res.json().catch(() => ({}));
        liveMeta = { twilio: payload, http_status: res.status };
        if (!res.ok) {
          status = "failed";
          await db.from("bos_voice_calls").update({
            status,
            updated_at: new Date().toISOString(),
            meta: {
              ...(call.meta ?? {}),
              voice_provider: "twilio",
              dial_sim: false,
              dial_error: payload,
            },
          }).eq("id", callId);
          throw new Error(`Twilio dial failed (${res.status})`);
        }
        sim = false;
        status = "in_progress";
      }
    }

    await db.from("bos_voice_calls").update({
      status,
      provider: sim ? (call.provider || "stub") : provider,
      updated_at: new Date().toISOString(),
      meta: {
        ...(call.meta ?? {}),
        voice_provider: sim ? "stub" : provider,
        dial_sim: sim,
        dial_at: new Date().toISOString(),
        provider_note: sim
          ? "Stub dial — set voice.provider=exotel + api_key/api_token/account_sid (+ number)"
          : `Live ${provider} dial started`,
        ...liveMeta,
      },
    }).eq("id", callId);

    await recordUsage(db, tenantId, "voice_minutes", 1, {
      fn: "bos-voice-dial",
      sim,
      provider: sim ? "stub" : provider,
    });
    await recordUsage(db, tenantId, "api_calls", 1, { fn: "bos-voice-dial" });

    return new Response(
      JSON.stringify({
        ok: true,
        call_id: callId,
        sim,
        provider: sim ? "stub" : provider,
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
