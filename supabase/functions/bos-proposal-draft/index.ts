// Draft a commercial proposal from deal + KB (+ optional quotation totals).
// Body: { deal_id?, lead_id?, quotation_id?, tenant_id?, title? }

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

function fillTemplate(
  md: string,
  vars: Record<string, string>,
): string {
  let out = md;
  for (const [k, v] of Object.entries(vars)) {
    out = out.replaceAll(`{{${k}}}`, v || "—");
  }
  return out;
}

async function llmPolish(markdown: string): Promise<string> {
  const openai = Deno.env.get("OPENAI_API_KEY") ?? "";
  if (!openai) return markdown;
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
            content: "Polish this B2B proposal markdown. Keep structure. Do not invent prices.",
          },
          { role: "user", content: markdown },
        ],
        temperature: 0.3,
      }),
    });
    if (!res.ok) return markdown;
    const data = await res.json();
    return data.choices?.[0]?.message?.content?.trim() || markdown;
  } catch {
    return markdown;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const dealId = body.deal_id as string | undefined;
    const leadId = body.lead_id as string | undefined;
    const quotationId = body.quotation_id as string | undefined;
    const title = (body.title as string) || "Service proposal";

    const db = admin();

    let contact = "Customer";
    let company = "your organization";
    let summary = "We reviewed your requirements and prepared this proposal.";
    let scope = "- Discovery & solution design\n- Supply / implementation\n- Testing & handover";
    let investment = "Shared separately / as per attached quotation.";

    if (dealId) {
      const { data: deal } = await db.from("bos_deals").select("*").eq("id", dealId).maybeSingle();
      if (deal) {
        summary = `Opportunity: ${deal.title}. Stage: ${deal.stage}.`;
        if (deal.amount_paise) {
          investment = `Indicative value: ₹${(Number(deal.amount_paise) / 100).toLocaleString("en-IN")}`;
        }
        if (deal.contact_id) {
          const { data: c } = await db.from("bos_contacts").select("*").eq("id", deal.contact_id).maybeSingle();
          if (c) contact = c.full_name || c.email || contact;
        }
        if (deal.company_id) {
          const { data: co } = await db.from("bos_companies").select("*").eq("id", deal.company_id).maybeSingle();
          if (co) company = co.name;
        }
      }
    }

    if (leadId) {
      const { data: lead } = await db.from("bos_leads").select("*").eq("id", leadId).maybeSingle();
      if (lead) {
        contact = lead.full_name || contact;
        company = lead.company_name || company;
        if (lead.requirements) summary = lead.requirements;
        if (lead.ai_summary) summary = `${summary}\n\nAI notes: ${lead.ai_summary}`;
      }
    }

    if (quotationId) {
      const { data: q } = await db.from("bos_quotations").select("*").eq("id", quotationId).maybeSingle();
      if (q) {
        investment =
          `Quotation total: ₹${(Number(q.total_paise) / 100).toLocaleString("en-IN")} ` +
          `(subtotal ₹${(Number(q.subtotal_paise) / 100).toLocaleString("en-IN")} + tax ₹${(Number(q.tax_paise) / 100).toLocaleString("en-IN")})`;
        const { data: lines } = await db
          .from("bos_quotation_lines")
          .select("category,description,qty")
          .eq("quotation_id", quotationId)
          .order("sort_order");
        if (lines?.length) {
          scope = lines
            .map((l) => `- ${l.category ?? "Item"}: ${l.description} × ${l.qty}`)
            .join("\n");
        }
      }
    }

    const { data: kb } = await db
      .from("bos_kb_documents")
      .select("title,body,collection")
      .eq("tenant_id", tenantId)
      .eq("is_active", true)
      .is("deleted_at", null)
      .limit(5);

    if (kb?.length) {
      scope += "\n\n### Reference knowledge\n" +
        kb.map((d) => `- **${d.title}** (${d.collection}): ${(d.body ?? "").slice(0, 180)}…`).join("\n");
    }

    const { data: tpl } = await db
      .from("bos_proposal_templates")
      .select("*")
      .eq("tenant_id", tenantId)
      .eq("is_default", true)
      .is("deleted_at", null)
      .maybeSingle();

    const templateMd = tpl?.body_markdown ??
      "# Proposal\n\n{{summary}}\n\n## Scope\n{{scope}}\n\n## Investment\n{{investment}}\n";

    let markdown = fillTemplate(templateMd, {
      company,
      contact,
      summary,
      scope,
      investment,
    });
    markdown = await llmPolish(markdown);

    const id = crypto.randomUUID();
    await db.from("bos_proposals").insert({
      id,
      tenant_id: tenantId,
      title,
      status: "draft",
      body_markdown: markdown,
      deal_id: dealId ?? null,
      lead_id: leadId ?? null,
      quotation_id: quotationId ?? null,
      template_id: tpl?.id ?? null,
      meta: { generated_by: "bos-proposal-draft" },
    });

    return new Response(JSON.stringify({ id, title, body_markdown: markdown }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
