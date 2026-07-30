// AI Sales orchestrate: qualify lead → WA and/or voice queue → handover flag.
// Body: { lead_id, tenant_id?, skip_qualify?: boolean }
// Reuses bos_* only. Providers optional (WHATSAPP_*, VOICE_PROVIDER).

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

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function defaultAiSales() {
  return {
    auto_engage: true,
    channel: "both", // whatsapp | voice | both
    working_hours: { start: 9, end: 20, tz: "Asia/Kolkata" },
    follow_up_days: [1, 3, 7, 15],
    hot_handover: true,
    voice_provider: Deno.env.get("VOICE_PROVIDER") || "stub",
  };
}

function inWorkingHours(cfg: { start: number; end: number }): boolean {
  // Approximate IST offset +5:30 without full tz lib
  const now = new Date();
  const istHour = (now.getUTCHours() + 5 + (now.getUTCMinutes() + 30 >= 60 ? 1 : 0)) % 24;
  const start = cfg.start ?? 9;
  const end = cfg.end ?? 20;
  return istHour >= start && istHour < end;
}

function heuristicQualify(lead: Record<string, unknown>) {
  const req = String(lead.requirements ?? "").toLowerCase();
  let points = 0;
  if (String(lead.phone ?? "").length >= 8) points += 1;
  if (String(lead.email ?? "").includes("@")) points += 1;
  if (String(lead.company_name ?? "").length > 2) points += 1;
  if (req.length > 40) points += 1;
  if (/(cctv|camera|nvr|network|website|app|marketing)/.test(req)) points += 2;
  if (/(urgent|asap|budget|quote)/.test(req)) points += 1;
  let score = "cold";
  if (points >= 5) score = "hot";
  else if (points >= 3) score = "warm";
  const summary =
    `AI sales qualify for ${lead.full_name ?? "lead"} (${lead.company_name ?? "—"}). ` +
    `Requirement signals score=${points}.`;
  const questions = [
    "Kitne cameras / nodes chahiye?",
    "Site location aur timeline?",
    "Budget range kya hai?",
  ];
  const recommendation = score === "hot"
    ? "Send quotation / assign sales agent"
    : score === "warm"
    ? "AI follow-up WhatsApp + call"
    : "Nurture campaign";
  return { score, summary, questions, recommendation };
}

async function sendWhatsApp(phone: string, text: string) {
  const token = Deno.env.get("WHATSAPP_TOKEN") ?? "";
  const phoneId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID") ?? "";
  if (!token || !phoneId || !phone) return { sent: false as const };
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
  return { sent: res.ok as boolean, meta: await res.json().catch(() => ({})) };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json();
    const leadId = body.lead_id as string;
    if (!leadId) throw new Error("lead_id required");
    const db = admin();

    const { data: lead } = await db.from("bos_leads").select("*").eq("id", leadId).maybeSingle();
    if (!lead) throw new Error("lead not found");
    const tenantId = (body.tenant_id as string) || lead.tenant_id || DEFAULT_TENANT;

    const { data: settingsRow } = await db
      .from("bos_tenant_settings")
      .select("settings")
      .eq("tenant_id", tenantId)
      .maybeSingle();
    const settings = (settingsRow?.settings ?? {}) as Record<string, unknown>;
    const aiSales = {
      ...defaultAiSales(),
      ...((settings.ai_sales as Record<string, unknown>) ?? {}),
    };

    const actions: string[] = [];
    let score = lead.score as string | null;
    let summary = lead.ai_summary as string | null;
    let questions = lead.ai_next_questions as unknown[];
    let recommendation = (lead.meta as Record<string, unknown>)?.ai_recommendation as string | undefined;

    if (!body.skip_qualify) {
      const q = heuristicQualify(lead);
      score = q.score;
      summary = q.summary;
      questions = q.questions;
      recommendation = q.recommendation;
      await db.from("bos_leads").update({
        score: q.score,
        ai_summary: q.summary,
        ai_next_questions: q.questions,
        stage: lead.stage === "new" || lead.stage === "contacted" ? "qualified" : lead.stage,
        meta: {
          ...(lead.meta ?? {}),
          ai_recommendation: q.recommendation,
          intent: String(lead.requirements ?? "").slice(0, 120) || null,
        },
        updated_at: new Date().toISOString(),
      }).eq("id", leadId);
      actions.push("qualified");
      await db.from("bos_activities").insert({
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        lead_id: leadId,
        activity_type: "ai_qualify",
        subject: `AI qualify · ${q.score}`,
        body: q.summary,
        completed_at: new Date().toISOString(),
      });
      await db.from("bos_audit_log").insert({
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        action: "ai.qualify",
        entity_type: "bos_leads",
        entity_id: leadId,
        meta: { score: q.score },
      });
    }

    if (!aiSales.auto_engage) {
      return json(200, { ok: true, actions: [...actions, "auto_engage_off"], score, summary });
    }

    const hours = (aiSales.working_hours as { start: number; end: number }) || { start: 9, end: 20 };
    if (!inWorkingHours(hours)) {
      const followDays = (aiSales.follow_up_days as number[]) || [1];
      const next = new Date(Date.now() + (followDays[0] || 1) * 86400000);
      await db.from("bos_leads").update({
        next_follow_up_at: next.toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", leadId);
      actions.push("outside_hours_scheduled");
      return json(200, { ok: true, actions, next_follow_up_at: next.toISOString(), score });
    }

    const phone = String(lead.phone ?? "").trim();
    if (phone) {
      const { data: opt } = await db
        .from("bos_opt_outs")
        .select("id")
        .eq("tenant_id", tenantId)
        .eq("phone", phone)
        .eq("channel", "whatsapp")
        .maybeSingle();
      if (opt) {
        actions.push("opted_out");
      } else {
        const channel = String(aiSales.channel || "both");
        const firstName = String(lead.full_name ?? "ji").split(" ")[0];
        const reqHint = String(lead.requirements ?? "enquiry").slice(0, 80);
        const opener =
          `Namaste ${firstName} ji, aapne ${reqHint || "hamari services"} ke liye enquiry ki thi. ` +
          `Aapko kitne cameras / nodes ki requirement hai? Budget aur location bhi bata dein.`;

        if (channel === "whatsapp" || channel === "both") {
          let { data: conv } = await db
            .from("bos_conversations")
            .select("id")
            .eq("tenant_id", tenantId)
            .eq("phone", phone)
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
              lead_id: leadId,
              last_message_at: new Date().toISOString(),
              ai_enabled: true,
            }).select("id").single();
            conv = created;
          } else {
            await db.from("bos_conversations").update({
              lead_id: leadId,
              last_message_at: new Date().toISOString(),
            }).eq("id", conv.id);
          }
          if (conv?.id) {
            const send = await sendWhatsApp(phone, opener);
            await db.from("bos_messages").insert({
              id: crypto.randomUUID(),
              tenant_id: tenantId,
              conversation_id: conv.id,
              direction: "outbound",
              body: opener,
              status: send.sent ? "sent" : "queued",
              meta: { ai: true, orchestrate: true, meta_send: send.meta ?? null },
            });
            await db.from("bos_activities").insert({
              id: crypto.randomUUID(),
              tenant_id: tenantId,
              lead_id: leadId,
              activity_type: "ai_whatsapp",
              subject: "AI WhatsApp first touch",
              body: opener,
              completed_at: new Date().toISOString(),
            });
            actions.push(send.sent ? "whatsapp_sent" : "whatsapp_queued");
          }
        }

        if (channel === "voice" || channel === "both") {
          const script =
            `Hi ${firstName}, this is DG.YARD calling about your enquiry` +
            (reqHint ? ` regarding ${reqHint}` : "") +
            `. Do you have two minutes?`;
          const provider = String(aiSales.voice_provider || "stub");
          const callId = crypto.randomUUID();
          const when = new Date().toISOString();
          await db.from("bos_voice_calls").insert({
            id: callId,
            tenant_id: tenantId,
            lead_id: leadId,
            phone,
            direction: "outbound",
            status: "queued",
            provider: provider === "exotel" ? "exotel" : "stub",
            script,
            scheduled_at: when,
            meta: {
              source: "orchestrate",
              voice_provider: provider,
              note: provider === "stub"
                ? "Simulated dial — set VOICE_PROVIDER=exotel + secrets for live"
                : "Exotel/Twilio dial pending adapter",
            },
          });
          await db.from("bos_activities").insert({
            id: crypto.randomUUID(),
            tenant_id: tenantId,
            lead_id: leadId,
            activity_type: "voice_queued",
            subject: "AI call queued",
            body: script,
            due_at: when,
          });
          actions.push("voice_queued");
        }
      }
    } else {
      actions.push("no_phone");
    }

    // Follow-up cadence day 1
    const followDays = (aiSales.follow_up_days as number[]) || [1, 3, 7, 15];
    const nextFollow = new Date(Date.now() + (followDays[0] || 1) * 86400000).toISOString();

    const meta: Record<string, unknown> = {
      ...(lead.meta ?? {}),
      ai_recommendation: recommendation ?? null,
      intent: ((lead.meta as Record<string, unknown>)?.intent as string | undefined) ||
        String(lead.requirements ?? "").slice(0, 120) ||
        null,
    };

    if (aiSales.hot_handover !== false && score === "hot") {
      (meta as Record<string, unknown>).handover_ready = true;
      await db.from("bos_activities").insert({
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        lead_id: leadId,
        activity_type: "ai_handover",
        subject: "Handover ready",
        body: recommendation || "Hot lead — assign sales agent",
        completed_at: new Date().toISOString(),
      });
      await db.from("bos_audit_log").insert({
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        action: "ai.handover",
        entity_type: "bos_leads",
        entity_id: leadId,
        meta: { score },
      });
      actions.push("handover_ready");
    }

    await db.from("bos_leads").update({
      next_follow_up_at: score === "hot" ? null : nextFollow,
      meta,
      updated_at: new Date().toISOString(),
    }).eq("id", leadId);

    await db.from("bos_audit_log").insert({
      id: crypto.randomUUID(),
      tenant_id: tenantId,
      action: "ai.orchestrate",
      entity_type: "bos_leads",
      entity_id: leadId,
      meta: { actions },
    });

    return json(200, {
      ok: true,
      actions,
      score,
      summary,
      recommendation,
      next_follow_up_at: score === "hot" ? null : nextFollow,
    });
  } catch (e) {
    return json(400, { error: String(e) });
  }
});
