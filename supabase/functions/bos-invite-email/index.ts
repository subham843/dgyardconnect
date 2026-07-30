// Send tenant invite email via Resend (tenant secrets or global env). Stub logs if no key.
// Body: { invite_id, tenant_id?, accept_base_url? }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { resolveTenantComm } from "../_shared/tenant_comm.ts";
import { assertUsageLimit } from "../_shared/plan_limits.ts";
import { recordUsage } from "../_shared/tenant_comm.ts";

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
    const inviteId = body.invite_id as string;
    const tenantId = (body.tenant_id as string) || DEFAULT_TENANT;
    if (!inviteId) throw new Error("invite_id required");

    const db = admin();
    await assertUsageLimit(db, tenantId, "api_calls", 1);

    const { data: invite } = await db
      .from("bos_tenant_invites")
      .select("*")
      .eq("id", inviteId)
      .maybeSingle();
    if (!invite) throw new Error("invite not found");

    const { data: tenant } = await db.from("bos_tenants").select("name").eq("id", tenantId).maybeSingle();
    const base = (body.accept_base_url as string) || "https://app.dgyard.com";
    const link = `${base.replace(/\/$/, "")}/admin/ai-os/accept-invite?token=${invite.token}`;

    const comm = await resolveTenantComm(db, tenantId);
    const subject = `You're invited to ${tenant?.name ?? "AI Business OS"}`;
    const text =
      `Hi,\n\nYou've been invited as ${invite.role} to ${tenant?.name ?? "a workspace"}.\n\n` +
      `Accept here:\n${link}\n\nIf you did not expect this, ignore this email.`;

    let sent = false;
    let sim = true;
    let meta: unknown = { provider: "stub" };

    if (comm.emailProvider !== "stub" && comm.emailApiKey) {
      if (comm.emailProvider === "resend" || comm.emailApiKey.startsWith("re_")) {
        const res = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${comm.emailApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: comm.emailFrom || "noreply@dgyard.com",
            to: [invite.email],
            subject,
            text,
          }),
        });
        meta = await res.json().catch(() => ({}));
        sent = res.ok;
        sim = false;
      }
    }

    await db.from("bos_tenant_invites").update({
      meta: {
        ...(invite.meta ?? {}),
        email_sent: sent,
        email_sim: sim,
        email_meta: meta,
        accept_link: link,
      },
    }).eq("id", inviteId);

    await recordUsage(db, tenantId, "api_calls", 1, { fn: "bos-invite-email", sent, sim });

    return new Response(JSON.stringify({ ok: true, sent, sim, link, to: invite.email }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
