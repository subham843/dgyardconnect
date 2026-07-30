// Meta WhatsApp Cloud API webhook + inbound message ingest for AI Business OS.
// Secrets: WHATSAPP_VERIFY_TOKEN, WHATSAPP_APP_SECRET (optional), SUPABASE_SERVICE_ROLE_KEY
// Query: ?tenant_id=<uuid> (defaults to DG.YARD tenant)

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

  const url = new URL(req.url);
  const tenantId = url.searchParams.get("tenant_id") || DEFAULT_TENANT;

  // Meta webhook verification
  if (req.method === "GET") {
    const mode = url.searchParams.get("hub.mode");
    const token = url.searchParams.get("hub.verify_token");
    const challenge = url.searchParams.get("hub.challenge");
    const expected = Deno.env.get("WHATSAPP_VERIFY_TOKEN") ?? "dgyard-bos-wa";
    if (mode === "subscribe" && token === expected && challenge) {
      return new Response(challenge, { headers: corsHeaders });
    }
    return new Response("Forbidden", { status: 403, headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const db = admin();
    const entries = payload?.entry ?? [];
    let ingested = 0;

    for (const entry of entries) {
      for (const change of entry?.changes ?? []) {
        const value = change?.value;
        const messages = value?.messages ?? [];
        for (const msg of messages) {
          const phone = msg.from as string | undefined;
          const body = msg.text?.body as string | undefined;
          const externalId = msg.id as string | undefined;
          if (!phone || !body) continue;

          // Opt-out keyword
          if (/^(stop|unsubscribe|opt.?out)$/i.test(body.trim())) {
            await db.from("bos_opt_outs").upsert({
              tenant_id: tenantId,
              phone,
              channel: "whatsapp",
              reason: "user_stop",
            }, { onConflict: "tenant_id,phone,channel" });
          }

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
              external_id: phone,
              last_message_at: new Date().toISOString(),
              unread_count: 1,
              ai_enabled: true,
            }).select("id").single();
            conv = created;
          } else {
            await db.from("bos_conversations").update({
              last_message_at: new Date().toISOString(),
              unread_count: 1,
            }).eq("id", conv.id);
          }

          if (!conv?.id) continue;

          await db.from("bos_messages").insert({
            id: crypto.randomUUID(),
            tenant_id: tenantId,
            conversation_id: conv.id,
            direction: "inbound",
            body,
            status: "received",
            external_id: externalId ?? null,
            meta: { raw_type: msg.type ?? "text" },
          });

          // Link / create lead + trigger AI sales orchestrate (async fire-and-forget)
          let leadId: string | null = null;
          const { data: existingLead } = await db
            .from("bos_leads")
            .select("id")
            .eq("tenant_id", tenantId)
            .eq("phone", phone)
            .is("deleted_at", null)
            .order("created_at", { ascending: false })
            .limit(1)
            .maybeSingle();
          if (existingLead?.id) {
            leadId = existingLead.id;
          } else {
            leadId = crypto.randomUUID();
            await db.from("bos_leads").insert({
              id: leadId,
              tenant_id: tenantId,
              source: "whatsapp",
              stage: "new",
              phone,
              full_name: phone,
              requirements: body.slice(0, 500),
            });
          }
          await db.from("bos_conversations").update({ lead_id: leadId }).eq("id", conv.id);

          const orchUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-sales-orchestrate`;
          const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
          fetch(orchUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${key}`,
            },
            body: JSON.stringify({ lead_id: leadId, tenant_id: tenantId }),
          }).catch(() => {});

          // Also draft AI reply for open conversation
          const replyUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-ai-reply`;
          fetch(replyUrl, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${key}`,
            },
            body: JSON.stringify({ conversation_id: conv.id, tenant_id: tenantId }),
          }).catch(() => {});

          ingested++;
        }
      }
    }

    // Facebook / Instagram Messenger-style ingest (Meta secrets optional; stub payload OK)
    // payload: { social: { channel: "facebook"|"instagram", sender_id, text, name? } }
    if (payload?.social?.text && payload?.social?.sender_id) {
      const socialChannel = ["facebook", "instagram"].includes(payload.social.channel)
        ? String(payload.social.channel)
        : "facebook";
      const senderId = String(payload.social.sender_id);
      const text = String(payload.social.text);
      const externalId = `${socialChannel}:${senderId}`;
      let { data: conv } = await db
        .from("bos_conversations")
        .select("id,lead_id")
        .eq("tenant_id", tenantId)
        .eq("channel", socialChannel)
        .eq("external_id", externalId)
        .is("deleted_at", null)
        .maybeSingle();
      if (!conv) {
        const id = crypto.randomUUID();
        const { data: created } = await db.from("bos_conversations").insert({
          id,
          tenant_id: tenantId,
          channel: socialChannel,
          external_id: externalId,
          status: "open",
          last_message_at: new Date().toISOString(),
          unread_count: 1,
          ai_enabled: true,
          meta: { name: payload.social.name ?? null },
        }).select("id,lead_id").single();
        conv = created;
      }
      if (conv?.id) {
        await db.from("bos_messages").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          conversation_id: conv.id,
          direction: "inbound",
          body: text,
          status: "received",
          meta: { social: true },
        });
        let leadId = conv.lead_id as string | null;
        if (!leadId) {
          leadId = crypto.randomUUID();
          await db.from("bos_leads").insert({
            id: leadId,
            tenant_id: tenantId,
            source: socialChannel === "instagram" ? "facebook" : "facebook",
            stage: "new",
            full_name: payload.social.name || `${socialChannel} ${senderId.slice(0, 8)}`,
            requirements: text.slice(0, 500),
            meta: { social_channel: socialChannel, sender_id: senderId },
          });
          await db.from("bos_conversations").update({ lead_id: leadId }).eq("id", conv.id);
        }
        const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
        const replyUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/bos-ai-reply`;
        fetch(replyUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${key}`,
          },
          body: JSON.stringify({
            conversation_id: conv.id,
            tenant_id: tenantId,
            inbound_text: text,
          }),
        }).catch(() => {});
        ingested++;
      }
    }

    // Manual test ingest (admin / n8n)
    if (payload?.test_phone && payload?.test_body) {
      const phone = String(payload.test_phone);
      const body = String(payload.test_body);
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
          last_message_at: new Date().toISOString(),
        }).select("id").single();
        conv = created;
      }
      if (conv?.id) {
        await db.from("bos_messages").insert({
          id: crypto.randomUUID(),
          tenant_id: tenantId,
          conversation_id: conv.id,
          direction: "inbound",
          body,
          status: "received",
        });
        ingested++;
      }
    }

    return new Response(JSON.stringify({ ok: true, ingested }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
