// Chunk KB + OpenAI embeddings + optional Qdrant upsert. Local keyword RAG without Qdrant.
// Body: { document_id?, tenant_id?, reindex_all?: boolean }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { resolveTenantComm } from "../_shared/tenant_comm.ts";

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

function chunkText(text: string, size = 500): string[] {
  const clean = text.replace(/\s+/g, " ").trim();
  if (!clean) return [];
  const chunks: string[] = [];
  for (let i = 0; i < clean.length; i += size) {
    chunks.push(clean.slice(i, i + size));
  }
  return chunks;
}

async function embedTexts(texts: string[], openaiKey: string): Promise<number[][]> {
  const openai = openaiKey || Deno.env.get("OPENAI_API_KEY") || "";
  if (!openai || texts.length === 0) {
    return texts.map(() => []);
  }
  try {
    const res = await fetch("https://api.openai.com/v1/embeddings", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openai}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "text-embedding-3-small",
        input: texts,
      }),
    });
    if (!res.ok) return texts.map(() => []);
    const data = await res.json();
    const out: number[][] = texts.map(() => []);
    for (const row of data.data ?? []) {
      out[row.index] = row.embedding as number[];
    }
    return out;
  } catch (_) {
    return texts.map(() => []);
  }
}

async function upsertQdrant(
  points: Array<{ id: string; vector: number[]; payload: Record<string, unknown> }>,
) {
  const qUrl = Deno.env.get("QDRANT_URL") ?? "";
  const qKey = Deno.env.get("QDRANT_API_KEY") ?? "";
  const collection = Deno.env.get("QDRANT_COLLECTION") ?? "bos_kb";
  if (!qUrl || points.length === 0) return { upserted: 0 };

  const dim = points[0]?.vector?.length || 0;
  if (dim > 0) {
    await fetch(`${qUrl.replace(/\/$/, "")}/collections/${collection}`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        ...(qKey ? { "api-key": qKey } : {}),
      },
      body: JSON.stringify({ vectors: { size: dim, distance: "Cosine" } }),
    }).catch(() => {});
  }

  const res = await fetch(`${qUrl.replace(/\/$/, "")}/collections/${collection}/points?wait=true`, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      ...(qKey ? { "api-key": qKey } : {}),
    },
    body: JSON.stringify({
      points: points.map((p) => ({
        id: p.id,
        vector: p.vector.length ? p.vector : Array.from({ length: 8 }, () => 0),
        payload: p.payload,
      })),
    }),
  });
  return { upserted: res.ok ? points.length : 0, status: res.status };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const documentId = body.document_id as string | undefined;
    const reindexAll = Boolean(body.reindex_all);

    const db = admin();
    const comm = await resolveTenantComm(db, tenantId);
    let query = db
      .from("bos_kb_documents")
      .select("*")
      .eq("tenant_id", tenantId)
      .is("deleted_at", null);

    if (documentId) query = query.eq("id", documentId);
    else if (!reindexAll) throw new Error("document_id or reindex_all required");

    const { data: docs } = await query;
    let totalChunks = 0;
    let embedded = 0;

    for (const doc of docs ?? []) {
      await db.from("bos_kb_documents").update({ reindex_status: "indexing" }).eq("id", doc.id);
      await db.from("bos_kb_chunks").delete().eq("document_id", doc.id);

      const parts = chunkText(`${doc.title}\n${doc.body ?? ""}`);
      const vectors = await embedTexts(parts, comm.openaiApiKey);
      const pointIds: string[] = [];
      const qPoints: Array<{ id: string; vector: number[]; payload: Record<string, unknown> }> = [];

      for (let i = 0; i < parts.length; i++) {
        const chunkId = crypto.randomUUID();
        pointIds.push(chunkId);
        const vec = vectors[i] ?? [];
        const status = vec.length > 0
          ? "embedded"
          : (Deno.env.get("QDRANT_URL") ? "queued" : "local_only");
        if (vec.length > 0) embedded++;

        await db.from("bos_kb_chunks").insert({
          id: chunkId,
          tenant_id: tenantId,
          document_id: doc.id,
          chunk_index: i,
          content: parts[i],
          qdrant_point_id: chunkId,
          embedding_status: status,
          embedding: vec.length ? vec : null,
        });

        qPoints.push({
          id: chunkId,
          vector: vec,
          payload: {
            tenant_id: tenantId,
            document_id: doc.id,
            collection: doc.collection,
            title: doc.title,
            text: parts[i],
          },
        });
      }

      const q = await upsertQdrant(qPoints);
      totalChunks += parts.length;

      await db.from("bos_kb_documents").update({
        reindex_status: "ready",
        last_reindexed_at: new Date().toISOString(),
        chunk_count: parts.length,
        qdrant_point_ids: pointIds,
        meta: { ...(doc.meta ?? {}), qdrant: q, embedded_chunks: embedded },
      }).eq("id", doc.id);
    }

    return new Response(
      JSON.stringify({ documents: (docs ?? []).length, chunks: totalChunks, embedded }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
