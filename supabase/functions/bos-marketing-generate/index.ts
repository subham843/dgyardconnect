// Generate digital marketing copy from brief (+ optional KB).
// Body: { campaign_id?, name, brief, channel?, tone?, tenant_id? }

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

function localCopy(name: string, brief: string, tone: string, channel: string) {
  return {
    headline: `${name} | Trusted CCTV & Tech by DG.YARD`,
    primary_text:
      `${brief.trim() || "Secure your premises with DG.YARD."} ` +
      `Get expert ${channel === "ads" ? "installation" : "consultation"} with transparent pricing.`,
    cta: "Book free survey",
    hashtags: ["#DGYARD", "#CCTV", "#Networking", "#SmartSecurity"],
    variations: [
      `Need reliable CCTV? ${name} — call DG.YARD today.`,
      `From cameras to cloud apps — ${name} with DG.YARD.`,
    ],
    tone,
  };
}

async function llmCopy(name: string, brief: string, tone: string, channel: string, kb: string) {
  const openai = Deno.env.get("OPENAI_API_KEY") ?? "";
  if (!openai) return localCopy(name, brief, tone, channel);
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
            content: "Return JSON only: headline, primary_text, cta, hashtags[], variations[]. India B2B security/tech tone.",
          },
          {
            role: "user",
            content: `Campaign: ${name}\nChannel: ${channel}\nTone: ${tone}\nBrief: ${brief}\nKB:\n${kb}`,
          },
        ],
        temperature: 0.5,
      }),
    });
    if (!res.ok) return localCopy(name, brief, tone, channel);
    const data = await res.json();
    const text = data.choices?.[0]?.message?.content ?? "";
    return { ...JSON.parse(text.replace(/```json|```/g, "").trim()), tone };
  } catch {
    return localCopy(name, brief, tone, channel);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const name = (body.name as string) || "DG.YARD campaign";
    const brief = (body.brief as string) || "";
    const channel = (body.channel as string) || "content";
    const tone = (body.tone as string) || "professional";
    const campaignId = body.campaign_id as string | undefined;

    const db = admin();
    const { data: docs } = await db
      .from("bos_kb_documents")
      .select("title,body")
      .eq("tenant_id", tenantId)
      .eq("is_active", true)
      .is("deleted_at", null)
      .limit(4);
    const kb = (docs ?? []).map((d) => `${d.title}: ${(d.body ?? "").slice(0, 120)}`).join("\n");

    const content = await llmCopy(name, brief, tone, channel, kb);

    let id = campaignId;
    if (id) {
      await db.from("bos_marketing_campaigns").update({
        generated_content: content,
        status: "draft",
        brief,
        channel,
        tone,
        name,
      }).eq("id", id);
    } else {
      id = crypto.randomUUID();
      await db.from("bos_marketing_campaigns").insert({
        id,
        tenant_id: tenantId,
        name,
        brief,
        channel,
        tone,
        status: "draft",
        generated_content: content,
      });
    }

    return new Response(JSON.stringify({ id, content }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
