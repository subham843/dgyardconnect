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
};

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
  } as Record<string, Record<string, string> | string>;
  const aiSales = ((row?.settings as Record<string, unknown>)?.ai_sales ?? {}) as Record<
    string,
    string
  >;

  const waSec = (typeof sec.whatsapp === "object" ? sec.whatsapp : {}) as Record<string, string>;
  const smsSec = (typeof sec.sms === "object" ? sec.sms : {}) as Record<string, string>;
  const emailSec = (typeof sec.email === "object" ? sec.email : {}) as Record<string, string>;
  const voiceSec = (typeof sec.voice === "object" ? sec.voice : {}) as Record<string, string>;

  // Legacy flat placeholders
  const legacyWa = typeof sec.whatsapp === "string" ? sec.whatsapp : "";
  const legacyOpenAi = typeof sec.openai === "string" ? sec.openai : "";
  void legacyOpenAi;

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
    voiceProvider:
      cfg.voice?.provider ||
      aiSales.voice_provider ||
      Deno.env.get("VOICE_PROVIDER") ||
      "stub",
    voiceApiKey: voiceSec.api_key || Deno.env.get("EXOTEL_API_KEY") || "",
    voiceApiToken:
      voiceSec.api_token ||
      voiceSec.token ||
      Deno.env.get("EXOTEL_API_TOKEN") ||
      "",
    voiceAccountSid:
      voiceSec.account_sid ||
      voiceSec.sid ||
      Deno.env.get("EXOTEL_SID") ||
      Deno.env.get("EXOTEL_ACCOUNT_SID") ||
      "",
    voiceNumber: cfg.voice?.number || voiceSec.number || Deno.env.get("EXOTEL_NUMBER") || "",
  };
}
