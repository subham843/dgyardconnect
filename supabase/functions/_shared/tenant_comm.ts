// Shared helpers for tenant API credentials + usage (imported by Edge functions).
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase not configured");
  return createClient(url, key);
}

export async function recordUsage(
  db: SupabaseClient,
  tenantId: string,
  metric: string,
  quantity = 1,
  meta: Record<string, unknown> = {},
) {
  try {
    await db.from("bos_usage_events").insert({
      tenant_id: tenantId,
      metric,
      quantity,
      meta,
      occurred_at: new Date().toISOString(),
    });
  } catch (_) { /* non-fatal */ }
}

export type TenantCommConfig = {
  whatsappToken: string;
  whatsappPhoneNumberId: string;
  smsProvider: string;
  smsApiKey: string;
  twilioSid: string;
  twilioFrom: string;
  emailProvider: string;
  emailApiKey: string;
  emailFrom: string;
  voiceProvider: string;
  voiceApiKey: string;
  voiceApiToken: string;
  voiceAccountSid: string;
  voiceNumber: string;
  /** Extra provider-specific fields (e.g. Exotel subdomain). */
  voiceExtra: Record<string, string>;
  openaiApiKey: string;
};

function asObj(v: unknown): Record<string, string> {
  if (v && typeof v === "object" && !Array.isArray(v)) {
    const out: Record<string, string> = {};
    for (const [k, val] of Object.entries(v as Record<string, unknown>)) {
      if (typeof val === "string") out[k] = val;
    }
    return out;
  }
  return {};
}

/** Resolve credentials for the active voice provider (nested or legacy flat). */
export function resolveVoiceCreds(
  sec: Record<string, unknown>,
  cfg: Record<string, Record<string, string>>,
  aiSales: Record<string, string>,
): Pick<
  TenantCommConfig,
  | "voiceProvider"
  | "voiceApiKey"
  | "voiceApiToken"
  | "voiceAccountSid"
  | "voiceNumber"
  | "voiceExtra"
> {
  const provider = (
    cfg.voice?.provider ||
    aiSales.voice_provider ||
    Deno.env.get("VOICE_PROVIDER") ||
    "stub"
  ).toLowerCase();

  const voiceRoot = asObj(sec.voice);
  // Nested: api_secrets.voice.exotel / .twilio / .plivo / .vonage
  const nestedRaw = (sec.voice && typeof sec.voice === "object")
    ? (sec.voice as Record<string, unknown>)[provider]
    : undefined;
  const nested = asObj(nestedRaw);
  const pick = { ...voiceRoot, ...nested };

  const envKey = (k: string) => Deno.env.get(k) || "";

  if (provider === "exotel") {
    return {
      voiceProvider: provider,
      voiceApiKey: pick.api_key || envKey("EXOTEL_API_KEY"),
      voiceApiToken: pick.api_token || pick.token || envKey("EXOTEL_API_TOKEN"),
      voiceAccountSid:
        pick.account_sid || pick.sid || envKey("EXOTEL_SID") || envKey("EXOTEL_ACCOUNT_SID"),
      voiceNumber: cfg.voice?.number || pick.number || envKey("EXOTEL_NUMBER"),
      voiceExtra: {
        subdomain: pick.subdomain || envKey("EXOTEL_SUBDOMAIN") || "api",
      },
    };
  }

  if (provider === "twilio") {
    return {
      voiceProvider: provider,
      voiceApiKey: pick.auth_token || pick.api_key || envKey("TWILIO_AUTH_TOKEN"),
      voiceApiToken: pick.auth_token || pick.api_token || pick.api_key || envKey("TWILIO_AUTH_TOKEN"),
      voiceAccountSid:
        pick.account_sid || pick.sid || envKey("TWILIO_ACCOUNT_SID"),
      voiceNumber:
        cfg.voice?.number || pick.number || pick.from || envKey("TWILIO_VOICE_FROM") ||
        envKey("TWILIO_FROM"),
      voiceExtra: {},
    };
  }

  if (provider === "plivo") {
    return {
      voiceProvider: provider,
      voiceApiKey: pick.auth_token || pick.api_key || envKey("PLIVO_AUTH_TOKEN"),
      voiceApiToken: pick.auth_token || pick.api_token || envKey("PLIVO_AUTH_TOKEN"),
      voiceAccountSid: pick.auth_id || pick.account_sid || envKey("PLIVO_AUTH_ID"),
      voiceNumber: cfg.voice?.number || pick.number || envKey("PLIVO_NUMBER"),
      voiceExtra: {},
    };
  }

  if (provider === "vonage" || provider === "nexmo") {
    return {
      voiceProvider: "vonage",
      voiceApiKey: pick.api_key || envKey("VONAGE_API_KEY") || envKey("NEXMO_API_KEY"),
      voiceApiToken:
        pick.api_secret || pick.api_token || envKey("VONAGE_API_SECRET") || envKey("NEXMO_API_SECRET"),
      voiceAccountSid:
        pick.application_id || pick.app_id || envKey("VONAGE_APPLICATION_ID"),
      voiceNumber: cfg.voice?.number || pick.number || envKey("VONAGE_NUMBER"),
      voiceExtra: {
        private_key: pick.private_key || envKey("VONAGE_PRIVATE_KEY") || "",
      },
    };
  }

  if (provider === "knowlarity") {
    return {
      voiceProvider: provider,
      voiceApiKey: pick.api_key || pick.x_api_key || envKey("KNOWLARITY_API_KEY"),
      voiceApiToken: pick.authorization || pick.api_token || envKey("KNOWLARITY_AUTHORIZATION"),
      voiceAccountSid: pick.k_number || pick.sr_number || pick.account_sid || "",
      voiceNumber: cfg.voice?.number || pick.agent_number || pick.number || envKey("KNOWLARITY_NUMBER"),
      voiceExtra: {
        channel: pick.channel || "Basic",
        base_url:
          pick.base_url ||
          envKey("KNOWLARITY_BASE_URL") ||
          "https://kpi.knowlarity.com/Basic/v1/account/call/makecall",
        x_api_key: pick.x_api_key || pick.api_key || "",
      },
    };
  }

  if (provider === "myoperator") {
    return {
      voiceProvider: provider,
      voiceApiKey: pick.api_key || pick.token || envKey("MYOPERATOR_API_KEY"),
      voiceApiToken: pick.secret || pick.api_token || envKey("MYOPERATOR_SECRET"),
      voiceAccountSid: pick.company_id || pick.account_sid || envKey("MYOPERATOR_COMPANY_ID"),
      voiceNumber: cfg.voice?.number || pick.number || pick.from || envKey("MYOPERATOR_NUMBER"),
      voiceExtra: {
        base_url:
          pick.base_url ||
          envKey("MYOPERATOR_BASE_URL") ||
          "https://developers.myoperator.co/voice/call",
      },
    };
  }

  // stub / unknown — still surface any flat legacy keys for debugging
  return {
    voiceProvider: provider || "stub",
    voiceApiKey: pick.api_key || envKey("EXOTEL_API_KEY"),
    voiceApiToken: pick.api_token || envKey("EXOTEL_API_TOKEN"),
    voiceAccountSid: pick.account_sid || envKey("EXOTEL_SID"),
    voiceNumber: cfg.voice?.number || pick.number || envKey("EXOTEL_NUMBER"),
    voiceExtra: {},
  };
}

/** Prefer tenant api_secrets/api_config; fall back to global Edge env. */
export async function resolveTenantComm(
  db: SupabaseClient,
  tenantId: string,
): Promise<TenantCommConfig> {
  const { data: row } = await db
    .from("bos_tenant_settings")
    .select("api_config, api_secrets, api_keys_placeholder, settings")
    .eq("tenant_id", tenantId)
    .maybeSingle();

  const cfg = (row?.api_config ?? {}) as Record<string, Record<string, string>>;
  const sec = {
    ...((row?.api_keys_placeholder ?? {}) as Record<string, unknown>),
    ...((row?.api_secrets ?? {}) as Record<string, unknown>),
  } as Record<string, unknown>;
  const aiSales = ((row?.settings as Record<string, unknown>)?.ai_sales ?? {}) as Record<
    string,
    string
  >;

  const waSec = asObj(sec.whatsapp);
  const smsSec = asObj(sec.sms);
  const emailSec = asObj(sec.email);
  const openaiSec = asObj(sec.openai);

  const legacyWa = typeof sec.whatsapp === "string" ? sec.whatsapp : "";
  const legacyOpenAi =
    typeof sec.openai === "string"
      ? sec.openai
      : openaiSec.api_key ||
        (typeof (row?.api_keys_placeholder as Record<string, string>)?.openai === "string"
          ? (row?.api_keys_placeholder as Record<string, string>).openai
          : "");

  const voice = resolveVoiceCreds(sec, cfg, aiSales);

  return {
    whatsappToken: waSec.access_token || legacyWa || Deno.env.get("WHATSAPP_TOKEN") || "",
    whatsappPhoneNumberId:
      cfg.whatsapp?.phone_number_id ||
      waSec.phone_number_id ||
      Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") ||
      "",
    smsProvider:
      cfg.sms?.provider ||
      aiSales.sms_provider ||
      Deno.env.get("SMS_PROVIDER") ||
      "stub",
    smsApiKey: smsSec.api_key || Deno.env.get("SMS_API_KEY") || "",
    twilioSid: smsSec.account_sid || Deno.env.get("TWILIO_ACCOUNT_SID") || "",
    twilioFrom: cfg.sms?.sender_id || smsSec.from || Deno.env.get("TWILIO_FROM") || "",
    emailProvider:
      cfg.email?.provider ||
      aiSales.email_provider ||
      Deno.env.get("EMAIL_PROVIDER") ||
      "stub",
    emailApiKey:
      emailSec.api_key ||
      Deno.env.get("EMAIL_API_KEY") ||
      Deno.env.get("RESEND_API_KEY") ||
      "",
    emailFrom: cfg.email?.from || emailSec.from || Deno.env.get("EMAIL_FROM") || "noreply@dgyard.com",
    ...voice,
    openaiApiKey: legacyOpenAi || Deno.env.get("OPENAI_API_KEY") || "",
  };
}
