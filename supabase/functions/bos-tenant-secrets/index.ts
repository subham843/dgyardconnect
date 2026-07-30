// Get/set per-tenant API secrets + api_config. Masks secrets on read.
// Body: { action: "get"|"upsert", tenant_id?, api_config?, api_secrets? }

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

function maskSecrets(secrets: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(secrets)) {
    if (v && typeof v === "object" && !Array.isArray(v)) {
      out[k] = maskSecrets(v as Record<string, unknown>);
    } else if (typeof v === "string" && v.length > 0) {
      out[k] = { set: true, hint: v.length > 4 ? `…${v.slice(-4)}` : "••••" };
    } else {
      out[k] = { set: false };
    }
  }
  return out;
}

function deepMerge(
  a: Record<string, unknown>,
  b: Record<string, unknown>,
): Record<string, unknown> {
  const out = { ...a };
  for (const [k, v] of Object.entries(b)) {
    if (v && typeof v === "object" && !Array.isArray(v) && a[k] && typeof a[k] === "object") {
      out[k] = deepMerge(a[k] as Record<string, unknown>, v as Record<string, unknown>);
    } else if (v !== undefined && v !== null && v !== "") {
      out[k] = v;
    }
  }
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const action = (body.action as string) || "get";
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    const db = admin();

    const { data: row } = await db
      .from("bos_tenant_settings")
      .select("api_config, api_secrets, settings, api_keys_placeholder")
      .eq("tenant_id", tenantId)
      .maybeSingle();

    if (action === "get") {
      const secrets = (row?.api_secrets ?? {}) as Record<string, unknown>;
      const legacy = (row?.api_keys_placeholder ?? {}) as Record<string, unknown>;
      return new Response(
        JSON.stringify({
          api_config: row?.api_config ?? {},
          api_secrets_masked: maskSecrets({ ...legacy, ...secrets }),
          ai_agent: ((row?.settings as Record<string, unknown>)?.ai_agent) ?? {},
          ai_sales: ((row?.settings as Record<string, unknown>)?.ai_sales) ?? {},
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (action === "upsert") {
      const existingConfig = (row?.api_config ?? {}) as Record<string, unknown>;
      const existingSecrets = (row?.api_secrets ?? {}) as Record<string, unknown>;
      const nextConfig = body.api_config
        ? deepMerge(existingConfig, body.api_config as Record<string, unknown>)
        : existingConfig;
      const nextSecrets = body.api_secrets
        ? deepMerge(existingSecrets, body.api_secrets as Record<string, unknown>)
        : existingSecrets;

      await db.from("bos_tenant_settings").upsert({
        tenant_id: tenantId,
        api_config: nextConfig,
        api_secrets: nextSecrets,
        updated_at: new Date().toISOString(),
      });

      await db.from("bos_audit_log").insert({
        id: crypto.randomUUID(),
        tenant_id: tenantId,
        action: "tenant.api_config_update",
        entity_type: "bos_tenant_settings",
        entity_id: tenantId,
        meta: {
          config_keys: Object.keys(nextConfig),
          secret_channels: Object.keys(nextSecrets),
        },
      });

      return new Response(
        JSON.stringify({
          ok: true,
          api_config: nextConfig,
          api_secrets_masked: maskSecrets(nextSecrets),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    throw new Error("Unknown action");
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
