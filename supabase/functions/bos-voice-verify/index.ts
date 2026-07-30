// Verify voice provider secrets without placing a real call.
// Body: { tenant_id?, provider? }

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

function basicAuth(user: string, pass: string) {
  return `Basic ${btoa(`${user}:${pass}`)}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const db = admin();
    const comm = await resolveTenantComm(db, tenantId);
    const provider = ((body.provider as string) || comm.voiceProvider || "stub").toLowerCase();

    const checks: Record<string, unknown> = {
      provider,
      number_set: Boolean(comm.voiceNumber),
    };

    if (provider === "stub") {
      return new Response(
        JSON.stringify({ ok: true, provider: "stub", live: false, note: "Stub — no live verify" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    let live = false;
    let detail: unknown = null;
    let error: string | null = null;

    if (provider === "exotel") {
      checks.api_key = Boolean(comm.voiceApiKey);
      checks.api_token = Boolean(comm.voiceApiToken);
      checks.account_sid = Boolean(comm.voiceAccountSid);
      if (comm.voiceApiKey && comm.voiceApiToken && comm.voiceAccountSid) {
        const subdomain = comm.voiceExtra.subdomain || "api";
        const host = subdomain.includes(".") ? subdomain : `${subdomain}.exotel.com`;
        const url =
          `https://${host}/v1/Accounts/${encodeURIComponent(comm.voiceAccountSid)}.json`;
        const res = await fetch(url, {
          headers: { Authorization: basicAuth(comm.voiceApiKey, comm.voiceApiToken) },
        });
        detail = await res.json().catch(() => ({}));
        live = res.ok;
        if (!res.ok) error = `Exotel account lookup ${res.status}`;
      } else {
        error = "Missing Exotel api_key / api_token / account_sid";
      }
    } else if (provider === "twilio") {
      const sidRaw = String(comm.voiceAccountSid || comm.twilioSid || "").trim();
      const tokenRaw = String(comm.voiceApiToken || comm.voiceApiKey || "").trim();
      const sid = sidRaw.replace(/^["']|["']$/g, "");
      const token = tokenRaw.replace(/^["']|["']$/g, "");
      checks.account_sid = Boolean(sid);
      checks.auth_token = Boolean(token);
      checks.sid_prefix = sid.slice(0, 2).toUpperCase() || null;
      if (!sid || !token) {
        error = "Missing Twilio Account SID / Auth Token — Save settings pehle, phir Verify";
      } else if (sid.toUpperCase().startsWith("SK")) {
        error =
          "Account SID field me API Key (SK…) hai. Console → Account → Account SID (AC…) paste karo. " +
          "API Key ke liye alag SK + Secret + AC SID chahiye.";
      } else if (!sid.toUpperCase().startsWith("AC")) {
        error =
          `Account SID "${sid.slice(0, 4)}…" galat lag raha hai — Twilio Account SID AC se start hota hai`;
      } else {
        const res = await fetch(
          `https://api.twilio.com/2010-04-01/Accounts/${encodeURIComponent(sid)}.json`,
          { headers: { Authorization: basicAuth(sid, token) } },
        );
        const bodyJson = await res.json().catch(() => ({})) as Record<string, unknown>;
        detail = bodyJson;
        live = res.ok;
        if (!res.ok) {
          const twilioMsg = String(
            bodyJson.message || bodyJson.error_message || bodyJson.code || "",
          );
          const isTest =
            /test account credentials/i.test(twilioMsg) ||
            /test credentials/i.test(twilioMsg);
          if (isTest) {
            error =
              "Twilio TEST Auth Token detect hua. Console → Account → API keys & tokens → " +
              "LIVE Auth Token (Reveal) copy karo — neeche 'Test credentials' section mat use karo.";
          } else if (res.status === 401 || res.status === 403) {
            error =
              `Twilio ${res.status} — Auth Token Account SID se match nahi karta. ` +
              `Console → Account → API keys & tokens → Auth Token (Reveal) copy karke dubara Save + Verify. ` +
              (twilioMsg ? `Twilio: ${twilioMsg}` : "");
          } else {
            error = `Twilio account lookup ${res.status}${twilioMsg ? ` · ${twilioMsg}` : ""}`;
          }
          return new Response(
            JSON.stringify({
              ok: false,
              live: false,
              provider,
              checks,
              error,
              test_credentials: isTest,
              detail: bodyJson,
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
      }
    } else if (provider === "plivo") {
      checks.auth_id = Boolean(comm.voiceAccountSid);
      checks.auth_token = Boolean(comm.voiceApiToken || comm.voiceApiKey);
      if (comm.voiceAccountSid && (comm.voiceApiToken || comm.voiceApiKey)) {
        const res = await fetch(
          `https://api.plivo.com/v1/Account/${encodeURIComponent(comm.voiceAccountSid)}/`,
          {
            headers: {
              Authorization: basicAuth(
                comm.voiceAccountSid,
                comm.voiceApiToken || comm.voiceApiKey,
              ),
            },
          },
        );
        detail = await res.json().catch(() => ({}));
        live = res.ok;
        if (!res.ok) error = `Plivo account lookup ${res.status}`;
      } else {
        error = "Missing Plivo Auth ID / Token";
      }
    } else if (provider === "vonage") {
      checks.application_id = Boolean(comm.voiceAccountSid);
      checks.private_key = Boolean(comm.voiceExtra.private_key);
      checks.from_number = Boolean(comm.voiceNumber);
      if (comm.voiceAccountSid && comm.voiceExtra.private_key) {
        try {
          const { createVonageJwt } = await import("../_shared/vonage_jwt.ts");
          const jwt = await createVonageJwt(comm.voiceAccountSid, comm.voiceExtra.private_key, 60);
          live = jwt.split(".").length === 3;
          detail = { jwt_created: true, length: jwt.length };
        } catch (e) {
          error = `Vonage JWT sign failed: ${e}`;
        }
      } else {
        error = "Missing Vonage application_id / private_key";
      }
    } else if (provider === "knowlarity") {
      checks.api_key = Boolean(comm.voiceApiKey || comm.voiceExtra.x_api_key);
      checks.k_number = Boolean(comm.voiceAccountSid || comm.voiceNumber);
      live = Boolean(
        (comm.voiceApiKey || comm.voiceExtra.x_api_key) &&
          (comm.voiceAccountSid || comm.voiceNumber),
      );
      detail = { note: "Credentials present — Click2Call verified on Test dial" };
      if (!live) error = "Missing Knowlarity x-api-key or k_number";
    } else if (provider === "myoperator") {
      checks.api_key = Boolean(comm.voiceApiKey);
      checks.from = Boolean(comm.voiceNumber);
      live = Boolean(comm.voiceApiKey && comm.voiceNumber);
      detail = { note: "Credentials present — verified on Test dial" };
      if (!live) error = "Missing MyOperator token or from number";
    } else if (provider === "telnyx") {
      const apiKey = comm.voiceApiKey || comm.voiceApiToken;
      const connectionId = comm.voiceExtra.connection_id || comm.voiceAccountSid;
      checks.api_key = Boolean(apiKey);
      checks.connection_id = Boolean(connectionId);
      checks.from = Boolean(comm.voiceNumber);
      if (apiKey) {
        const res = await fetch("https://api.telnyx.com/v2/phone_numbers?page[size]=1", {
          headers: {
            Authorization: apiKey.startsWith("Bearer ") ? apiKey : `Bearer ${apiKey}`,
            Accept: "application/json",
          },
        });
        detail = await res.json().catch(() => ({}));
        live = res.ok;
        if (!res.ok) error = `Telnyx API key check ${res.status}`;
        else if (!connectionId) {
          live = false;
          error = "API key OK — set Connection ID (Voice API app)";
        } else if (!comm.voiceNumber) {
          live = false;
          error = "API key OK — set Telnyx From number";
        }
      } else {
        error = "Missing Telnyx API key";
      }
    } else {
      error = `Unknown provider ${provider}`;
    }

    return new Response(
      JSON.stringify({
        ok: live,
        live,
        provider,
        checks,
        error,
        detail: live ? detail : undefined,
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
