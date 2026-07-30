// Web / App chatbot ingest. Creates conversation + lead, then bos-ai-reply.
// Body: { tenant_id?, channel?: web|app, visitor_id?, firebase_uid?, phone?, email?, name?, message }

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const channel = ["web", "app"].includes(body.channel) ? String(body.channel) : "web";
    const message = String(body.message ?? "").trim();
    if (!message) throw new Error("message required");

    const visitorId = String(body.visitor_id ?? body.firebase_uid ?? crypto.randomUUID());
    const phone = body.phone ? String(body.phone).trim() : null;
    const email = body.email ? String(body.email).trim().toLowerCase() : null;
    const name = body.name ? String(body.name).trim() : null;

    const db = admin();
    const externalId = `chat:${channel}:${visitorId}`;

    let { data: conv } = await db
      .from("bos_conversations")
      .select("*")
      .eq("tenant_id", tenantId)
      .eq("channel", channel)
      .eq("external_id", externalId)
      .is("deleted_at", null)
      .maybeSingle();

    if (!conv) {
      const id = crypto.randomUUID();
      const { data: created } = await db.from("bos_conversations").insert({
        id,
        tenant_id: tenantId,
        channel,
        external_id: externalId,
        phone,
        status: "open",
        last_message_at: new Date().toISOString(),
        unread_count: 1,
        ai_enabled: true,
        meta: { visitor_id: visitorId, email, name },
      }).select("*").single();
      conv = created;
    } else {
      await db.from("bos_conversations").update({
        last_message_at: new Date().toISOString(),
        unread_count: 1,
        phone: phone ?? conv.phone,
        meta: { ...(conv.meta ?? {}), email: email ?? (conv.meta as Record<string, unknown>)?.email, name: name ?? (conv.meta as Record<string, unknown>)?.name },
      }).eq("id", conv.id);
    }

    if (!conv?.id) throw new Error("conversation create failed");

    await db.from("bos_messages").insert({
      id: crypto.randomUUID(),
      tenant_id: tenantId,
      conversation_id: conv.id,
      direction: "inbound",
      body: message,
      status: "received",
      meta: { channel, visitor_id: visitorId },
    });

    let leadId = conv.lead_id as string | null;
    if (!leadId) {
      if (phone) {
        const { data: existing } = await db
          .from("bos_leads")
          .select("id")
          .eq("tenant_id", tenantId)
          .eq("phone", phone)
          .is("deleted_at", null)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        leadId = existing?.id ?? null;
      }
      if (!leadId && email) {
        const { data: existing } = await db
          .from("bos_leads")
          .select("id")
          .eq("tenant_id", tenantId)
          .eq("email", email)
          .is("deleted_at", null)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();
        leadId = existing?.id ?? null;
      }
      if (!leadId) {
        leadId = crypto.randomUUID();
        await db.from("bos_leads").insert({
          id: leadId,
          tenant_id: tenantId,
          source: channel === "app" ? "api" : "website",
          stage: "new",
          phone,
          email,
          full_name: name || phone || email || `Chat ${visitorId.slice(0, 8)}`,
          requirements: message.slice(0, 500),
          meta: { visitor_id: visitorId, channel },
        });
      }
      await db.from("bos_conversations").update({ lead_id: leadId }).eq("id", conv.id);
    }

    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const replyUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-ai-reply`;
    const replyRes = await fetch(replyUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        conversation_id: conv.id,
        tenant_id: tenantId,
        inbound_text: message,
      }),
    });
    const replyJson = await replyRes.json().catch(() => ({}));

    // Fire orchestrate for new-ish leads (non-blocking)
    const orchUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-sales-orchestrate`;
    fetch(orchUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({ lead_id: leadId, tenant_id: tenantId, skip_qualify: false }),
    }).catch(() => {});

    return new Response(
      JSON.stringify({
        ok: true,
        conversation_id: conv.id,
        lead_id: leadId,
        visitor_id: visitorId,
        channel,
        reply: replyJson.reply ?? null,
        intent: replyJson.intent ?? null,
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
