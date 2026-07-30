// AI campaign message copy. Body: { name?, brief, channel?, tone?, tenant_id? }

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

function localCopy(name: string, brief: string, channel: string, tone: string) {
  const hi = "Hi {{name}},";
  if (channel === "sms") {
    return `${hi} DG.YARD: ${brief.slice(0, 100)}. Reply YES for details.`;
  }
  if (channel === "email") {
    return `${hi}\n\n${brief}\n\nWe can help with CCTV, networking, and software.\nReply with your site details for a free survey.\n\n— DG.YARD (${tone})`;
  }
  return `${hi} ${brief.slice(0, 180)} — DG.YARD. Reply with your requirement.`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const name = (body.name as string) || "Campaign";
    const brief = (body.brief as string) || "Follow up on enquiry";
    const channel = (body.channel as string) || "whatsapp";
    const tone = (body.tone as string) || "friendly";

    const db = admin();
    const { data: docs } = await db
      .from("bos_kb_documents")
      .select("title,body")
      .eq("tenant_id", tenantId)
      .eq("is_active", true)
      .is("deleted_at", null)
      .limit(4);
    const kb = (docs ?? []).map((d) => `${d.title}: ${(d.body ?? "").slice(0, 120)}`).join("\n");

    const openai = Deno.env.get("OPENAI_API_KEY") ?? "";
    let message = localCopy(name, brief, channel, tone);

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
                  `Write a short ${channel} marketing message for DG.YARD. Use {{name}} placeholder. Hindi/English/Hinglish OK. Tone: ${tone}. No invented prices.`,
              },
              {
                role: "user",
                content: `Campaign: ${name}\nBrief: ${brief}\nKB:\n${kb || "(none)"}`,
              },
            ],
            temperature: 0.5,
          }),
        });
        if (res.ok) {
          const data = await res.json();
          const text = data.choices?.[0]?.message?.content?.trim();
          if (text) message = text;
        }
      } catch (_) { /* local */ }
    }

    return new Response(JSON.stringify({ message, channel, name }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
