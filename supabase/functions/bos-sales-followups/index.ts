// Process due AI sales follow-ups with multi-channel sequence (manual or cron).
// Body: { tenant_id?, limit? }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_TENANT = "b0000000-0000-4000-8000-000000000001";

const SEQUENCE_DEFAULT = [
  { day: 0, type: "first_contact", channel: "whatsapp" },
  { day: 1, type: "reminder", channel: "sms" },
  { day: 3, type: "product_details", channel: "email" },
  { day: 7, type: "offer", channel: "whatsapp" },
  { day: 15, type: "reactivation", channel: "email" },
];

function admin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase not configured");
  return createClient(url, key);
}

function pickStep(
  sequence: typeof SEQUENCE_DEFAULT,
  createdAt: string,
  meta: Record<string, unknown>,
) {
  const ageDays = Math.floor((Date.now() - new Date(createdAt).getTime()) / 86400000);
  const done = Array.isArray(meta.sequence_done) ? (meta.sequence_done as number[]) : [];
  const candidates = sequence
    .filter((s) => s.day > 0 && ageDays >= s.day && !done.includes(s.day))
    .sort((a, b) => a.day - b.day);
  return candidates[0] ?? null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const limit = Math.min(Number(body.limit ?? 25), 100);
    const db = admin();
    const now = new Date().toISOString();
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const { data: settingsRow } = await db
      .from("bos_tenant_settings")
      .select("settings")
      .eq("tenant_id", tenantId)
      .maybeSingle();
    const aiSales = ((settingsRow?.settings as Record<string, unknown>)?.ai_sales ?? {}) as Record<
      string,
      unknown
    >;
    if (aiSales.auto_engage === false) {
      return new Response(JSON.stringify({ ok: true, processed: 0, skipped: "auto_engage_off" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const sequence = Array.isArray(aiSales.sequence)
      ? (aiSales.sequence as typeof SEQUENCE_DEFAULT)
      : SEQUENCE_DEFAULT;

    const { data: due } = await db
      .from("bos_leads")
      .select("id, score, stage, phone, email, full_name, created_at, meta")
      .eq("tenant_id", tenantId)
      .is("deleted_at", null)
      .not("stage", "in", '("won","lost")')
      .lte("next_follow_up_at", now)
      .order("next_follow_up_at", { ascending: true })
      .limit(limit);

    const processed: string[] = [];

    for (const lead of due ?? []) {
      const meta = (lead.meta ?? {}) as Record<string, unknown>;

      if (lead.score === "cold") {
        // Nurture: enqueue email reactivation recipient on a soft campaign stub activity
        const next = new Date(Date.now() + 15 * 86400000).toISOString();
        await db.from("bos_leads").update({
          next_follow_up_at: next,
          meta: { ...meta, nurture: true },
          updated_at: new Date().toISOString(),
        }).eq("id", lead.id);
        await db.from("bos_activities").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          lead_id: lead.id,
          activity_type: "ai_nurture",
          subject: "Cold lead long-term nurture",
          body: "Follow-up +15d; consider email reactivation campaign",
          due_at: next,
        });
        await db.from("bos_outbound_events").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          lead_id: lead.id,
          channel: "email",
          event_type: "nurture_queued",
          payload: { reason: "cold" },
        });
        processed.push(lead.id);
        continue;
      }

      const step = pickStep(sequence, lead.created_at as string, meta);
      if (step) {
        const text =
          step.type === "offer"
            ? `Hi ${lead.full_name || "there"}, DG.YARD special follow-up offer — reply YES for details.`
            : step.type === "product_details"
            ? `Hi ${lead.full_name || "there"}, sharing product details for your enquiry. Reply with site size for a quote.`
            : `Hi ${lead.full_name || "there"}, just checking in from DG.YARD. Still interested?`;

        await db.from("bos_outbound_events").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          lead_id: lead.id,
          channel: step.channel,
          event_type: "followup_queued",
          payload: { step, preview: text.slice(0, 120) },
        });

        if (step.channel === "whatsapp" && lead.phone) {
          let { data: conv } = await db
            .from("bos_conversations")
            .select("id")
            .eq("tenant_id", tenantId)
            .eq("phone", lead.phone)
            .eq("channel", "whatsapp")
            .is("deleted_at", null)
            .maybeSingle();
          if (!conv) {
            const id = crypto.randomUUID();
            const { data: created } = await db.from("bos_conversations").insert({
              id,
              tenant_id: tenantId,
              channel: "whatsapp",
              phone: lead.phone,
              lead_id: lead.id,
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
              status: "queued",
              meta: { followup_day: step.day, type: step.type },
            });
          }
        }

        await db.from("bos_activities").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          lead_id: lead.id,
          activity_type: `followup.${step.channel}`,
          subject: `AI follow-up day ${step.day} · ${step.type}`,
          body: text,
          completed_at: new Date().toISOString(),
          meta: { step },
        });

        const done = Array.isArray(meta.sequence_done) ? [...(meta.sequence_done as number[])] : [];
        done.push(step.day);
        const nextStep = sequence.find((s) => s.day > step.day);
        const nextAt = nextStep
          ? new Date(Date.now() + (nextStep.day - step.day) * 86400000).toISOString()
          : new Date(Date.now() + 7 * 86400000).toISOString();

        await db.from("bos_leads").update({
          next_follow_up_at: nextAt,
          meta: { ...meta, sequence_done: done, last_followup_channel: step.channel },
          updated_at: new Date().toISOString(),
        }).eq("id", lead.id);

        processed.push(lead.id);
        continue;
      }

      // Fallback: re-orchestrate
      const orchUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-sales-orchestrate`;
      const res = await fetch(orchUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({
          lead_id: lead.id,
          tenant_id: tenantId,
          skip_qualify: true,
        }),
      });
      if (res.ok) processed.push(lead.id);
    }

    return new Response(
      JSON.stringify({ ok: true, processed: processed.length, lead_ids: processed }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
