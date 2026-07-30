// Exchange Firebase ID token for a short-lived Supabase-compatible JWT.
// Set secrets: FIREBASE_PROJECT_ID, JWT_SECRET (Dashboard API JWT Secret; CLI rejects SUPABASE_* names)
// Optional body: bosTenantId — active AI Business OS tenant for JWT claims.

import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_TENANT_ID = "b0000000-0000-4000-8000-000000000001";

async function verifyFirebaseIdToken(idToken: string, projectId: string): Promise<{ uid: string; phone?: string }> {
  const parts = idToken.split(".");
  if (parts.length !== 3) throw new Error("Invalid token format");
  const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
  const iss = payload.iss as string | undefined;
  if (!iss?.includes(projectId)) throw new Error("Invalid issuer");
  const exp = payload.exp as number | undefined;
  if (!exp || exp * 1000 < Date.now()) throw new Error("Token expired");
  const uid = payload.user_id ?? payload.sub;
  if (!uid || typeof uid !== "string") throw new Error("Missing uid");
  return { uid, phone: payload.phone_number };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { idToken, roleMirror, bosTenantId } = body as {
      idToken?: string;
      roleMirror?: string;
      bosTenantId?: string;
    };
    if (!idToken) {
      return new Response(JSON.stringify({ error: "idToken required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
    const jwtSecret =
      Deno.env.get("JWT_SECRET") ?? Deno.env.get("SUPABASE_JWT_SECRET") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!projectId || !jwtSecret) {
      return new Response(JSON.stringify({ error: "Server not configured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { uid, phone } = await verifyFirebaseIdToken(idToken, projectId);
    const appRole = roleMirror === "superadmin" ? "superadmin" : "user";

    let resolvedTenantId: string | null = null;
    let resolvedBosRole: string | null = null;

    if (supabaseUrl && serviceRoleKey) {
      const admin = createClient(supabaseUrl, serviceRoleKey);
      await admin.from("platform_users").upsert(
        {
          firebase_uid: uid,
          phone: phone ?? null,
          role_mirror: appRole,
          last_seen_at: new Date().toISOString(),
        },
        { onConflict: "firebase_uid" },
      );

      // Resolve AI Business OS tenant membership for JWT claims.
      const requested = typeof bosTenantId === "string" && bosTenantId.length > 0
        ? bosTenantId
        : null;

      if (appRole === "superadmin") {
        resolvedTenantId = requested ?? DEFAULT_TENANT_ID;
        resolvedBosRole = "owner";
        // Ensure superadmin membership on active tenant (+ default DG.YARD).
        const tenantIds = new Set<string>([DEFAULT_TENANT_ID, resolvedTenantId]);
        for (const tid of tenantIds) {
          await admin.from("bos_tenant_members").upsert(
            {
              tenant_id: tid,
              firebase_uid: uid,
              role: "owner",
              display_name: phone ?? uid,
              is_active: true,
              deleted_at: null,
            },
            { onConflict: "tenant_id,firebase_uid" },
          );
        }
      } else {
        // Prefer requested tenant membership; fall back to any active membership.
        let membershipQuery = admin
          .from("bos_tenant_members")
          .select("tenant_id, role")
          .eq("firebase_uid", uid)
          .is("deleted_at", null)
          .eq("is_active", true);

        if (requested) {
          membershipQuery = membershipQuery.eq("tenant_id", requested);
        }

        let { data: memberships } = await membershipQuery.limit(5);
        if ((!memberships || memberships.length === 0) && requested) {
          const fallback = await admin
            .from("bos_tenant_members")
            .select("tenant_id, role")
            .eq("firebase_uid", uid)
            .is("deleted_at", null)
            .eq("is_active", true)
            .limit(5);
          memberships = fallback.data;
        }
        const row = memberships?.[0];
        if (row) {
          resolvedTenantId = row.tenant_id as string;
          resolvedBosRole = row.role as string;
        }
      }
    }

    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(jwtSecret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const claims: Record<string, unknown> = {
      sub: uid,
      role: "authenticated",
      app_role: appRole,
      aud: "authenticated",
      iss: "supabase",
      iat: getNumericDate(0),
      exp: getNumericDate(60 * 60),
    };
    if (resolvedTenantId) claims.bos_tenant_id = resolvedTenantId;
    if (resolvedBosRole) claims.bos_role = resolvedBosRole;

    // JWT "role" must be "authenticated" for PostgREST; app_role drives RLS (auth_is_superadmin).
    const accessToken = await create(
      { alg: "HS256", typ: "JWT" },
      claims,
      key,
    );

    return new Response(
      JSON.stringify({
        access_token: accessToken,
        firebase_uid: uid,
        role: appRole,
        bos_tenant_id: resolvedTenantId,
        bos_role: resolvedBosRole,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
