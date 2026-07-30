// Multi-channel campaign run: WhatsApp / SMS / Email (stub-first providers).
// Body: { campaign_id, tenant_id? }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { recordUsage, resolveTenantComm } from "../_shared/tenant_comm.ts";
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

function renderTemplate(body: string, name?: string | null, email?: string | null) {
  return body
    .replaceAll("{{name}}", name?.trim() || "there")
    .replaceAll("{{email}}", email?.trim() || "");
}

async function sendWhatsApp(
  phone: string,
  text: string,
  token: string,
  phoneId: string,
): Promise<{ sent: boolean; meta?: unknown }> {
  if (!token || !phoneId) return { sent: false };
  const res = await fetch(`https://graph.facebook.com/v19.0/${phoneId}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to: phone,
      type: "text",
      text: { body: text },
    }),
  });
  const meta = await res.json().catch(() => ({}));
  return { sent: res.ok, meta };
}

async function sendSms(
  phone: string,
  text: string,
  provider: string,
  apiKey: string,
  sid: string,
  from: string,
): Promise<{ sent: boolean; meta?: unknown; sim: boolean }> {
  if (provider === "stub" || !apiKey) {
    return { sent: false, sim: true, meta: { provider: "stub" } };
  }
  if (provider === "twilio") {
    if (!sid || !apiKey || !from) return { sent: false, sim: true, meta: { provider: "twilio_missing" } };
    const auth = btoa(`${sid}:${apiKey}`);
    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ To: phone, From: from, Body: text }),
    });
    const meta = await res.json().catch(() => ({}));
    return { sent: res.ok, sim: false, meta };
  }
  return { sent: false, sim: true, meta: { provider } };
}

async function sendEmail(
  email: string,
  subject: string,
  text: string,
  provider: string,
  apiKey: string,
  from: string,
): Promise<{ sent: boolean; meta?: unknown; sim: boolean }> {
  if (provider === "stub" || !apiKey) {
    return { sent: false, sim: true, meta: { provider: "stub" } };
  }
  if (provider === "resend") {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from, to: [email], subject, text }),
    });
    const meta = await res.json().catch(() => ({}));
    return { sent: res.ok, sim: false, meta };
  }
  return { sent: false, sim: true, meta: { provider } };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const campaignId = body.campaign_id as string;
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    if (!campaignId) throw new Error("campaign_id required");

    const db = admin();
    const { data: campaign } = await db
      .from("bos_campaigns")
      .select("*")
      .eq("id", campaignId)
      .single();
    if (!campaign) throw new Error("campaign not found");

    const channel = ((campaign.channel as string) || "whatsapp").toLowerCase();
    await assertUsageLimit(db, tenantId, "api_calls", 1);
    await assertUsageLimit(db, tenantId, "ai_messages", 1);
    const comm = await resolveTenantComm(db, tenantId);

    let messageBody = campaign.message_body as string | null;
    if (!messageBody && campaign.template_id) {
      const { data: tpl } = await db
        .from("bos_wa_templates")
        .select("body")
        .eq("id", campaign.template_id)
        .maybeSingle();
      messageBody = tpl?.body ?? null;
    }
    if (!messageBody) {
      messageBody = "Hi {{name}}, this is DG.YARD following up on your enquiry.";
    }

    const { data: recipients } = await db
      .from("bos_campaign_recipients")
      .select("*")
      .eq("campaign_id", campaignId)
      .eq("status", "pending");

    const { data: optOuts } = await db
      .from("bos_opt_outs")
      .select("phone,email,channel")
      .eq("tenant_id", tenantId)
      .eq("channel", channel);

    const blockedPhones = new Set(
      (optOuts ?? []).filter((o) => o.phone).map((o) => o.phone as string),
    );
    const blockedEmails = new Set(
      (optOuts ?? [])
        .filter((o) => o.email)
        .map((o) => String(o.email).toLowerCase()),
    );

    let sent = 0;
    let skipped = 0;
    let failed = 0;

    await db.from("bos_campaigns").update({
      status: "running",
      started_at: new Date().toISOString(),
    }).eq("id", campaignId);

    for (const r of recipients ?? []) {
      const phone = r.phone as string | null;
      const email = (r.email as string | null)?.toLowerCase() ?? null;

      const opted =
        (phone && blockedPhones.has(phone)) ||
        (email && blockedEmails.has(email)) ||
        (channel === "whatsapp" && !phone) ||
        (channel === "sms" && !phone) ||
        (channel === "email" && !email);

      if (opted && ((phone && blockedPhones.has(phone)) || (email && blockedEmails.has(email)))) {
        skipped++;
        await db.from("bos_campaign_recipients").update({
          status: "skipped_opt_out",
          delivery_status: "skipped_opt_out",
        }).eq("id", r.id);
        continue;
      }
      if ((channel === "whatsapp" || channel === "sms") && !phone) {
        failed++;
        await db.from("bos_campaign_recipients").update({
          status: "failed",
          delivery_status: "failed",
          error: "phone required",
        }).eq("id", r.id);
        continue;
      }
      if (channel === "email" && !email) {
        failed++;
        await db.from("bos_campaign_recipients").update({
          status: "failed",
          delivery_status: "failed",
          error: "email required",
        }).eq("id", r.id);
        continue;
      }

      try {
        const text = renderTemplate(messageBody, r.full_name, email);
        let deliveryStatus = "queued";
        let providerMeta: unknown = null;
        let activityType = `${channel}.sent`;

        if (channel === "whatsapp" && phone) {
          const wa = await sendWhatsApp(
            phone,
            text,
            comm.whatsappToken,
            comm.whatsappPhoneNumberId,
          );
          providerMeta = wa.meta;
          // Missing secrets → queued (retry later); live API failure → failed
          deliveryStatus = wa.sent
            ? "sent"
            : (!comm.whatsappToken || !comm.whatsappPhoneNumberId)
            ? "queued"
            : "failed";

          let { data: conv } = await db
            .from("bos_conversations")
            .select("id")
            .eq("tenant_id", tenantId)
            .eq("phone", phone)
            .eq("channel", "whatsapp")
            .is("deleted_at", null)
            .maybeSingle();

          if (!conv) {
            const id = crypto.randomUUID();
            const { data: created } = await db.from("bos_conversations").insert({
              id,
              tenant_id: tenantId,
              channel: "whatsapp",
              phone,
              status: "open",
              last_message_at: new Date().toISOString(),
            }).select("id").single();
            conv = created;
          }

          if (conv?.id) {
            await db.from("bos_messages").insert({
              id: crypto.randomUUID(),
              tenant_id: tenantId,
              conversation_id: conv.id,
              direction: "outbound",
              body: text,
              status: deliveryStatus,
              meta: { campaign_id: campaignId, provider: providerMeta },
            });
          }
        } else if (channel === "sms" && phone) {
          const sms = await sendSms(
            phone,
            text,
            comm.smsProvider,
            comm.smsApiKey,
            comm.twilioSid,
            comm.twilioFrom,
          );
          providerMeta = sms.meta;
          deliveryStatus = sms.sent ? "sent" : (sms.sim ? "sent_sim" : "failed");
          activityType = "sms.sent";
        } else if (channel === "email" && email) {
          const subject = (campaign.name as string) || "DG.YARD update";
          const em = await sendEmail(
            email,
            subject,
            text,
            comm.emailProvider,
            comm.emailApiKey,
            comm.emailFrom,
          );
          providerMeta = em.meta;
          deliveryStatus = em.sent ? "sent" : (em.sim ? "sent_sim" : "failed");
          activityType = "email.sent";
        }

        if (campaign.trigger_voice && phone) {
          const callId = crypto.randomUUID();
          const when = new Date().toISOString();
          const script = (messageBody || "Hello from DG.YARD — following up on our message.").slice(0, 500);
          await db.from("bos_voice_calls").insert({
            id: callId,
            tenant_id: tenantId,
            phone,
            direction: "outbound",
            status: "queued",
            provider: comm.voiceProvider === "stub" ? "stub" : comm.voiceProvider,
            script,
            scheduled_at: when,
            meta: {
              campaign_id: campaignId,
              from_campaign: true,
              voice_provider: comm.voiceProvider,
              scheduled_at: when,
            },
          });
          // Leave queued for Hub/Voice “Run due” (or dial immediately if already due)
          try {
            const dialUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-voice-dial`;
            const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
            await fetch(dialUrl, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${key}`,
              },
              body: JSON.stringify({ call_id: callId, tenant_id: tenantId }),
            });
          } catch (_) { /* non-fatal — remains queued for Run due */ }
        }

        const recipStatus =
          deliveryStatus === "failed"
            ? "failed"
            : deliveryStatus === "queued"
            ? "queued"
            : "sent";

        await db.from("bos_campaign_recipients").update({
          status: recipStatus,
          delivery_status: deliveryStatus,
          sent_at: deliveryStatus === "failed" ? null : new Date().toISOString(),
          error: deliveryStatus === "failed" ? JSON.stringify(providerMeta).slice(0, 400) : null,
          meta: {
            ...(r.meta ?? {}),
            provider: providerMeta,
            channel,
          },
        }).eq("id", r.id);

        await db.from("bos_outbound_events").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          campaign_id: campaignId,
          recipient_id: r.id,
          lead_id: r.lead_id ?? null,
          channel,
          event_type: deliveryStatus,
          payload: { provider: providerMeta, preview: text.slice(0, 120) },
        });

        if (r.lead_id) {
          await db.from("bos_activities").insert({
            id: crypto.randomUUID(),
            tenant_id: tenantId,
            lead_id: r.lead_id,
            activity_type: activityType,
            subject: `Campaign ${channel}: ${campaign.name}`,
            body: text.slice(0, 400),
            completed_at: new Date().toISOString(),
            meta: { campaign_id: campaignId, delivery_status: deliveryStatus },
          });
        }

        if (deliveryStatus === "failed") failed++;
        else sent++;
      } catch (err) {
        failed++;
        await db.from("bos_campaign_recipients").update({
          status: "failed",
          delivery_status: "failed",
          error: String(err),
        }).eq("id", r.id);
        await db.from("bos_outbound_events").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          campaign_id: campaignId,
          recipient_id: r.id,
          channel,
          event_type: "failed",
          payload: { error: String(err) },
        });
      }
    }

    await db.from("bos_campaigns").update({
      status: "completed",
      completed_at: new Date().toISOString(),
      sent_count: sent,
      failed_count: failed,
      skipped_opt_out: skipped,
    }).eq("id", campaignId);

    await recordUsage(db, tenantId, "api_calls", Math.max(sent, 1), {
      fn: "bos-campaign-run",
      channel,
    });
    if (channel === "whatsapp" || channel === "sms" || channel === "email") {
      await recordUsage(db, tenantId, "ai_messages", sent, { channel, campaign_id: campaignId });
    }

    return new Response(JSON.stringify({ sent, failed, skipped, channel }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
