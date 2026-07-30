// Generate outbound AI voice follow-up script for a lead.
// Secrets (optional): OPENAI_API_KEY
// Body: { lead_id }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function admin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase not configured");
  return createClient(url, key);
}

function heuristicScript(lead: Record<string, unknown>): string {
  const name = (lead.full_name as string) || "there";
  const company = (lead.company_name as string) || "your business";
  const req = ((lead.requirements as string) || "").trim();
  const summary = ((lead.ai_summary as string) || "").trim();
  const reqBit = req
    ? `You reached out about: ${req.slice(0, 160)}${req.length > 160 ? "…" : ""}. `
    : "";
  const sumBit = summary
    ? `Our notes: ${summary.slice(0, 120)}${summary.length > 120 ? "…" : ""}. `
    : "";
  return (
    `Hi ${name}, this is DG.YARD calling regarding ${company}. ` +
    reqBit +
    sumBit +
    `Do you have two minutes for a quick follow-up on next steps and a site/requirement check?`
  );
}

async function llmScript(lead: Record<string, unknown>): Promise<string | null> {
  const openai = Deno.env.get("OPENAI_API_KEY") ?? "";
  if (!openai) return null;
  const prompt =
    `Write a short outbound phone call script (4-6 spoken sentences) for a DG.YARD sales follow-up. ` +
    `Friendly, Indian B2B tone, CCTV/networking/software services. No markdown. ` +
    `Lead JSON: ${JSON.stringify({
      full_name: lead.full_name,
      company_name: lead.company_name,
      requirements: lead.requirements,
      ai_summary: lead.ai_summary,
      stage: lead.stage,
      score: lead.score,
    })}`;
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
          { role: "system", content: "You write concise phone scripts only." },
          { role: "user", content: prompt },
        ],
        temperature: 0.4,
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const text = (data.choices?.[0]?.message?.content ?? "").trim();
    return text || null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const leadId = body.lead_id as string | undefined;
    if (!leadId) throw new Error("lead_id required");

    const db = admin();
    const { data: lead, error } = await db.from("bos_leads").select("*").eq("id", leadId).single();
    if (error || !lead) throw new Error("lead not found");

    const llm = await llmScript(lead as Record<string, unknown>);
    const script = llm ?? heuristicScript(lead as Record<string, unknown>);

    return new Response(
      JSON.stringify({
        ok: true,
        script,
        source: llm ? "openai" : "heuristic",
        lead_id: leadId,
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
