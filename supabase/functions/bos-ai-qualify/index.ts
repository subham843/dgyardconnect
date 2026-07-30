// AI Business OS — lead qualification stub.
// Secrets (optional): OPENAI_API_KEY, GEMINI_API_KEY
// Without keys: heuristic score from requirements length / keywords.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type Body = {
  lead_id?: string;
  full_name?: string;
  email?: string;
  phone?: string;
  company_name?: string;
  requirements?: string;
};

function heuristicQualify(b: Body): { score: string; summary: string; questions: string[] } {
  const req = (b.requirements ?? "").toLowerCase();
  let points = 0;
  if ((b.phone ?? "").length >= 8) points += 1;
  if ((b.email ?? "").includes("@")) points += 1;
  if ((b.company_name ?? "").length > 2) points += 1;
  if (req.length > 40) points += 1;
  if (/(cctv|camera|nvr|network|website|app|marketing)/.test(req)) points += 2;
  if (/(urgent|asap|budget|quote)/.test(req)) points += 1;

  let score = "cold";
  if (points >= 5) score = "hot";
  else if (points >= 3) score = "warm";

  const summary =
    `Heuristic qualification for ${b.full_name ?? "lead"} at ${b.company_name ?? "unknown company"}. ` +
    `Signals: contact completeness + requirement keywords (score points=${points}). ` +
    (Deno.env.get("OPENAI_API_KEY") || Deno.env.get("GEMINI_API_KEY")
      ? "LLM keys present but heuristic used as fallback path."
      : "No LLM keys configured — using local heuristic.");

  const questions = [
    "What is the site address and approximate camera count?",
    "Is this for a new install or an upgrade?",
    "What decision timeline and budget range do you have?",
  ];

  return { score, summary, questions };
}

async function llmQualify(b: Body): Promise<{ score: string; summary: string; questions: string[] } | null> {
  const openai = Deno.env.get("OPENAI_API_KEY") ?? "";
  const gemini = Deno.env.get("GEMINI_API_KEY") ?? "";
  const prompt =
    `Qualify this B2B lead for DG.YARD (CCTV, networking, software, websites, marketing). ` +
    `Return JSON only: {"score":"hot|warm|cold","summary":"...","questions":["..."]}.\n` +
    `Lead: ${JSON.stringify(b)}`;

  try {
    if (openai) {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openai}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages: [
            { role: "system", content: "You are a sales qualification assistant. Reply with JSON only." },
            { role: "user", content: prompt },
          ],
          temperature: 0.2,
        }),
      });
      if (res.ok) {
        const data = await res.json();
        const text = data.choices?.[0]?.message?.content ?? "";
        const json = JSON.parse(text.replace(/```json|```/g, "").trim());
        return {
          score: json.score ?? "warm",
          summary: json.summary ?? "",
          questions: Array.isArray(json.questions) ? json.questions : [],
        };
      }
    }
    if (gemini) {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${gemini}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
          }),
        },
      );
      if (res.ok) {
        const data = await res.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
        const json = JSON.parse(text.replace(/```json|```/g, "").trim());
        return {
          score: json.score ?? "warm",
          summary: json.summary ?? "",
          questions: Array.isArray(json.questions) ? json.questions : [],
        };
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as Body;
    const llm = await llmQualify(body);
    const result = llm ?? heuristicQualify(body);

    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (url && key && body.lead_id) {
      const admin = createClient(url, key);
      await admin.from("bos_leads").update({
        score: result.score,
        ai_summary: result.summary,
        ai_next_questions: result.questions,
        stage: "qualified",
      }).eq("id", body.lead_id);
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
