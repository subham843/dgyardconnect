// Omnichannel AI reply: intent detection + CRM update + optional Meta WA send.
// Body: { conversation_id, tenant_id?, inbound_text? }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { recordUsage, resolveTenantComm } from "../_shared/tenant_comm.ts";
import { assertUsageLimit } from "../_shared/plan_limits.ts";

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

type Intent =
  | "interested"
  | "price_enquiry"
  | "not_interested"
  | "need_info"
  | "ready_to_buy"
  | "support"
  | "appointment";

function detectIntent(text: string): Intent {
  const t = text.toLowerCase();
  if (/(ready to buy|book now|confirm order|deal final|le lo|le leta|purchase|buy now)/.test(t)) {
    return "ready_to_buy";
  }
  if (/(price|kitna|kitne|cost|quote|budget|rate|pricing)/.test(t)) return "price_enquiry";
  if (/(not interested|no thanks|mat bhejo|stop|unsubscribe|nahi chahiye)/.test(t)) {
    return "not_interested";
  }
  if (/(appoint|visit|survey|site visit|kal aao|schedule|meeting)/.test(t)) return "appointment";
  if (/(support|complaint|ticket|issue|problem|help me|service)/.test(t)) return "support";
  if (/(interested|haan|yes|ok|batao|details|info|more info|aur batao)/.test(t)) {
    return "interested";
  }
  return "need_info";
}

function intentToScore(intent: Intent): string {
  if (intent === "ready_to_buy" || intent === "appointment") return "hot";
  if (intent === "price_enquiry" || intent === "interested") return "warm";
  if (intent === "not_interested") return "cold";
  return "warm";
}

function recommendation(intent: Intent): string {
  switch (intent) {
    case "ready_to_buy":
      return "Handover to sales — prepare quotation";
    case "appointment":
      return "Confirm site survey slot with sales";
    case "price_enquiry":
      return "Share ballpark + collect site details";
    case "interested":
      return "Continue nurture + product details";
    case "support":
      return "Route to tickets / service desk";
    case "not_interested":
      return "Opt-out friendly close + long nurture";
    default:
      return "Ask clarifying questions; continue AI follow-up";
  }
}

async function draftReply(
  userText: string,
  kbSnippets: string[],
  leadCtx: string,
  channel: string,
  intent: Intent,
  agentName: string,
  language: string,
  tone: string,
  openaiKey = "",
): Promise<string> {
  const context = kbSnippets.slice(0, 5).join("\n---\n");
  const openai = openaiKey || Deno.env.get("OPENAI_API_KEY") || "";
  const prompt =
    `You are ${agentName} (${channel}). Language preference: ${language}. Tone: ${tone}. ` +
    `Hindi/English/Hinglish OK. Be concise.\n` +
    `Detected intent: ${intent}\n` +
    `Lead context: ${leadCtx || "(none)"}\n` +
    `KB:\n${context || "(no KB)"}\n\nCustomer: ${userText}\nReply:`;

  if (openai) {
    try {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openai}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [
            {
              role: "system",
              content:
                `You are ${agentName}. Reply in 2-4 short sentences. Match customer language. Tone: ${tone}. Ask one clarifying question if needed. Do not invent prices.`,
            },
            { role: "user", content: prompt },
          ],
          temperature: 0.4,
        }),
      });
      if (res.ok) {
        const data = await res.json();
        const text = data.choices?.[0]?.message?.content?.trim();
        if (text) return text;
      }
    } catch (_) { /* fallback */ }
  }

  const tips: Record<Intent, string> = {
    ready_to_buy: `Great — ${agentName} will connect sales. Site address aur preferred time share karein.`,
    price_enquiry: "Price site size pe depend karta hai. Camera/node count aur location bataiye — ballpark quote denge.",
    not_interested: "Samajh gaya. Agar baad mein help chahiye ho to message kar dena. Dhanyavaad!",
    need_info: `Main ${agentName} hoon. Hum CCTV, networking, software aur websites mein help karte hain. Requirement short mein bataiye?`,
    interested: "Bahut accha! Apni requirement (cameras/network/software) aur location share karein.",
    support: "Support ke liye issue briefly likhiye — ticket create karke team follow-up karegi.",
    appointment: "Site survey book kar sakte hain. Preferred date/time aur address bhej dijiye.",
  };
  return tips[intent] + (kbSnippets[0] ? `\n\nTip: ${kbSnippets[0].slice(0, 140)}…` : "");
}

async function sendWhatsApp(
  phone: string,
  text: string,
  token: string,
  phoneId: string,
): Promise<{ sent: boolean; meta?: unknown }> {
  if (!token || !phoneId || !phone) return { sent: false };

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

function cosine(a: number[], b: number[]): number {
  if (!a.length || !b.length || a.length !== b.length) return 0;
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (!na || !nb) return 0;
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

async function embedQuery(text: string, openaiKey = ""): Promise<number[]> {
  const openai = openaiKey || Deno.env.get("OPENAI_API_KEY") || "";
  if (!openai) return [];
  try {
    const res = await fetch("https://api.openai.com/v1/embeddings", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openai}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ model: "text-embedding-3-small", input: text }),
    });
    if (!res.ok) return [];
    const data = await res.json();
    return (data.data?.[0]?.embedding as number[]) ?? [];
  } catch (_) {
    return [];
  }
}

type Citation = {
  document_id: string | null;
  title: string;
  excerpt: string;
  score: number;
};

async function retrieveKbSnippets(
  db: ReturnType<typeof admin>,
  tenantId: string,
  query: string,
  openaiKey = "",
): Promise<{ snippets: string[]; citations: Citation[] }> {
  const { data: chunks } = await db
    .from("bos_kb_chunks")
    .select("content, embedding, document_id")
    .eq("tenant_id", tenantId)
    .limit(80);

  if (chunks && chunks.length > 0) {
    const qVec = await embedQuery(query.slice(0, 1000), openaiKey);
    const scored = chunks.map((c) => {
      const emb = Array.isArray(c.embedding) ? (c.embedding as number[]) : [];
      let score = 0;
      if (qVec.length && emb.length) score = cosine(qVec, emb);
      else {
        const t = (c.content as string).toLowerCase();
        const words = query.toLowerCase().split(/\W+/).filter((w) => w.length > 3);
        score = words.reduce((s, w) => s + (t.includes(w) ? 1 : 0), 0) / Math.max(words.length, 1);
      }
      return {
        content: c.content as string,
        score,
        document_id: (c.document_id as string) || null,
      };
    });
    scored.sort((a, b) => b.score - a.score);
    const top = scored.filter((s) => s.score > 0).slice(0, 5);
    if (top.length) {
      const docIds = [...new Set(top.map((t) => t.document_id).filter(Boolean))] as string[];
      const titleMap: Record<string, string> = {};
      if (docIds.length) {
        const { data: docs } = await db
          .from("bos_kb_documents")
          .select("id,title")
          .in("id", docIds);
        for (const d of docs ?? []) titleMap[d.id as string] = d.title as string;
      }
      const citations: Citation[] = top.map((t) => ({
        document_id: t.document_id,
        title: (t.document_id && titleMap[t.document_id]) || "Knowledge base",
        excerpt: t.content.slice(0, 180),
        score: Math.round(t.score * 1000) / 1000,
      }));
      return {
        snippets: top.map((t) => t.content.slice(0, 280)),
        citations,
      };
    }
  }

  const { data: docs } = await db
    .from("bos_kb_documents")
    .select("id,title,body")
    .eq("tenant_id", tenantId)
    .eq("is_active", true)
    .is("deleted_at", null)
    .limit(8);
  const citations: Citation[] = (docs ?? []).slice(0, 5).map((d) => ({
    document_id: d.id as string,
    title: (d.title as string) || "Document",
    excerpt: String(d.body ?? "").slice(0, 180),
    score: 0.1,
  }));
  return {
    snippets: (docs ?? []).map((d) => `${d.title}: ${(d.body ?? "").slice(0, 280)}`),
    citations,
  };
}

function nextFollowUpIso(sequence: typeof SEQUENCE_DEFAULT, score: string): string | null {
  if (score === "hot") return null;
  const step = sequence.find((s) => s.day > 0) ?? sequence[1] ?? { day: 3 };
  return new Date(Date.now() + step.day * 86400000).toISOString();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const conversationId = body.conversation_id as string;
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    if (!conversationId) throw new Error("conversation_id required");

    const db = admin();
    await assertUsageLimit(db, tenantId, "ai_messages", 1);
    await assertUsageLimit(db, tenantId, "api_calls", 1);

    const { data: conv } = await db
      .from("bos_conversations")
      .select("*")
      .eq("id", conversationId)
      .single();
    if (!conv) throw new Error("conversation not found");

    const channel = (conv.channel as string) || "whatsapp";

    const { data: lastMsgs } = await db
      .from("bos_messages")
      .select("body,direction")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: false })
      .limit(8);

    const lastInbound =
      (body.inbound_text as string) ||
      (lastMsgs ?? []).find((m) => m.direction === "inbound")?.body ||
      "";

    let leadCtx = "";
    let leadId = conv.lead_id as string | null;
    if (leadId) {
      const { data: lead } = await db.from("bos_leads").select("*").eq("id", leadId).maybeSingle();
      if (lead) {
        leadCtx = JSON.stringify({
          name: lead.full_name,
          company: lead.company_name,
          requirements: lead.requirements,
          score: lead.score,
          summary: lead.ai_summary,
        });
      }
    }

    const { data: settingsRow } = await db
      .from("bos_tenant_settings")
      .select("settings")
      .eq("tenant_id", tenantId)
      .maybeSingle();
    const aiSales = ((settingsRow?.settings as Record<string, unknown>)?.ai_sales ?? {}) as Record<
      string,
      unknown
    >;
    const aiAgent = ((settingsRow?.settings as Record<string, unknown>)?.ai_agent ?? {}) as Record<
      string,
      unknown
    >;
    const sequence = Array.isArray(aiSales.sequence)
      ? (aiSales.sequence as typeof SEQUENCE_DEFAULT)
      : SEQUENCE_DEFAULT;

    const comm = await resolveTenantComm(db, tenantId);
    const { snippets, citations } = await retrieveKbSnippets(
      db,
      tenantId,
      lastInbound || "Hello",
      comm.openaiApiKey,
    );
    const intent = detectIntent(lastInbound || "Hello");
    const score = intentToScore(intent);
    const agentName = String(aiAgent.name || "DG.YARD Sales Agent");
    const reply = await draftReply(
      lastInbound || "Hello",
      snippets,
      leadCtx,
      channel,
      intent,
      agentName,
      String(aiAgent.language || "hinglish"),
      String(aiAgent.tone || "friendly"),
      comm.openaiApiKey,
    );

    let send: { sent: boolean; meta?: unknown } = { sent: false };
    if (channel === "whatsapp") {
      send = await sendWhatsApp(
        conv.phone ?? "",
        reply,
        comm.whatsappToken,
        comm.whatsappPhoneNumberId,
      );
    }

    const msgStatus =
      channel === "whatsapp"
        ? (send.sent
          ? "sent"
          : (!comm.whatsappToken || !comm.whatsappPhoneNumberId)
          ? "queued"
          : "failed")
        : "sent_sim";

    await db.from("bos_messages").insert({
      id: crypto.randomUUID(),
      tenant_id: tenantId,
      conversation_id: conversationId,
      direction: "outbound",
      body: reply,
      status: msgStatus,
      meta: {
        ai: true,
        intent,
        channel,
        meta_send: send.meta ?? null,
        citations,
      },
    });

    await recordUsage(db, tenantId, "ai_messages", 1, { channel, intent });
    await recordUsage(db, tenantId, "api_calls", 1, { fn: "bos-ai-reply" });

    await db.from("bos_conversations").update({
      last_message_at: new Date().toISOString(),
      unread_count: 0,
      meta: { ...(conv.meta ?? {}), last_intent: intent, last_citations: citations },
    }).eq("id", conversationId);

    if (leadId && lastInbound) {
      const { data: lead } = await db.from("bos_leads").select("meta,score").eq("id", leadId).maybeSingle();
      const summary =
        `${channel} chat · intent=${intent}: "${lastInbound.slice(0, 140)}". AI replied.`;
      const meta = {
        ...(lead?.meta ?? {}),
        intent,
        requirement: lastInbound.slice(0, 240),
        ai_recommendation: recommendation(intent),
        last_channel: channel,
        handover_ready:
          intent === "ready_to_buy" || score === "hot"
            ? true
            : (lead?.meta as Record<string, unknown>)?.handover_ready,
      };
      const follow = nextFollowUpIso(sequence, score);
      await db.from("bos_leads").update({
        score,
        ai_summary: summary,
        next_follow_up_at: follow,
        meta,
        stage: score === "hot" ? "qualified" : intent === "not_interested" ? "lost" : "contacted",
        updated_at: new Date().toISOString(),
      }).eq("id", leadId);

      await db.from("bos_activities").insert({
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        lead_id: leadId,
        activity_type: `ai_${channel}`,
        subject: `AI reply · ${intent} · ${score}`,
        body: `In: ${lastInbound.slice(0, 200)}\nOut: ${reply.slice(0, 200)}`,
        completed_at: new Date().toISOString(),
        meta: { intent, channel },
      });

      if (meta.handover_ready) {
        await db.from("bos_activities").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          lead_id: leadId,
          activity_type: "ai.handover_ready",
          subject: "AI handover ready",
          body: recommendation(intent),
          completed_at: new Date().toISOString(),
        });
      }
    }

    return new Response(
      JSON.stringify({
        reply,
        sent: send.sent,
        intent,
        score,
        lead_id: leadId,
        channel,
        status: msgStatus,
        citations,
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
