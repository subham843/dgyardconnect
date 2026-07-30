// SaaS billing: plans, GST invoices, Razorpay pay→activate, usage, Super Admin MRR.
// Body: { action, tenant_id, ... }
// Secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET (same as shop)
// Auth: Bearer = exchange-firebase-token JWT (sub = firebase_uid)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const DEFAULT_TENANT = "b0000000-0000-4000-8000-000000000001";
const GST_RATE = 18;

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function admin() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase not configured");
  return createClient(url, key);
}

function decodeJwt(authHeader: string | null): { uid: string; appRole?: string; bosTenant?: string; bosRole?: string } | null {
  if (!authHeader?.startsWith("Bearer ")) return null;
  const token = authHeader.slice(7);
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
    const sub = payload.sub ?? payload.user_id;
    if (typeof sub !== "string" || !sub) return null;
    return {
      uid: sub,
      appRole: typeof payload.app_role === "string" ? payload.app_role : undefined,
      bosTenant: typeof payload.bos_tenant_id === "string" ? payload.bos_tenant_id : undefined,
      bosRole: typeof payload.bos_role === "string" ? payload.bos_role : undefined,
    };
  } catch {
    return null;
  }
}

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function gstBreakdown(taxablePaise: number) {
  const rate = GST_RATE;
  const gstTotal = Math.round((taxablePaise * rate) / 100);
  const cgst = Math.floor(gstTotal / 2);
  const sgst = gstTotal - cgst;
  return {
    taxable_paise: taxablePaise,
    cgst_paise: cgst,
    sgst_paise: sgst,
    igst_paise: 0,
    gst_rate_pct: rate,
    amount_paise: taxablePaise + gstTotal,
  };
}

async function assertTenantAccess(
  db: ReturnType<typeof admin>,
  uid: string,
  tenantId: string,
  appRole?: string,
): Promise<void> {
  if (appRole === "superadmin") return;
  const { data } = await db
    .from("bos_tenant_members")
    .select("id, role")
    .eq("tenant_id", tenantId)
    .eq("firebase_uid", uid)
    .eq("is_active", true)
    .is("deleted_at", null)
    .maybeSingle();
  if (!data) throw new Error("Not a tenant member");
}

async function activatePlan(
  db: ReturnType<typeof admin>,
  tenantId: string,
  planId: string,
  razorpayPaymentId?: string,
) {
  const { data: plan } = await db.from("bos_plans").select("*").eq("id", planId).single();
  if (!plan) throw new Error("plan not found");

  await db.from("bos_tenants").update({ plan_id: planId, status: "active" }).eq("id", tenantId);

  const { data: existing } = await db
    .from("bos_subscriptions")
    .select("id")
    .eq("tenant_id", tenantId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  const period = {
    plan_id: planId,
    status: "active",
    current_period_start: new Date().toISOString(),
    current_period_end: new Date(Date.now() + 30 * 86400000).toISOString(),
    ...(razorpayPaymentId
      ? { razorpay_subscription_id: razorpayPaymentId, metadata: { last_payment_id: razorpayPaymentId } }
      : {}),
  };

  if (existing) {
    await db.from("bos_subscriptions").update(period).eq("id", existing.id);
  } else {
    await db.from("bos_subscriptions").insert({ tenant_id: tenantId, ...period });
  }
  return plan;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const auth = decodeJwt(req.headers.get("Authorization"));
    if (!auth) return json(401, { error: "Sign in required" });

    const body = await req.json();
    const action = body.action as string;
    const tenantId = (body.tenant_id as string) || auth.bosTenant || DEFAULT_TENANT;
    const db = admin();

    if (action === "change_plan") {
      await assertTenantAccess(db, auth.uid, tenantId, auth.appRole);
      const planId = body.plan_id as string;
      if (!planId) throw new Error("plan_id required");
      // Manual switch allowed for superadmin; tenants should use create_checkout.
      if (auth.appRole !== "superadmin") {
        throw new Error("Use Pay & upgrade for plan changes");
      }
      const plan = await activatePlan(db, tenantId, planId);
      return json(200, { ok: true, plan: plan.code });
    }

    if (action === "create_invoice") {
      await assertTenantAccess(db, auth.uid, tenantId, auth.appRole);
      const { data: sub } = await db
        .from("bos_subscriptions")
        .select("*, bos_plans(*)")
        .eq("tenant_id", tenantId)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      const taxable = Number(body.amount_paise ?? sub?.bos_plans?.price_monthly_paise ?? 0);
      const gst = gstBreakdown(taxable);
      const id = crypto.randomUUID();
      const invoiceNumber = `INV-${Date.now().toString().slice(-8)}`;
      await db.from("bos_invoices").insert({
        id,
        tenant_id: tenantId,
        subscription_id: sub?.id ?? null,
        ...gst,
        currency: "INR",
        status: body.mark_paid ? "paid" : "open",
        invoice_number: invoiceNumber,
        issued_at: new Date().toISOString(),
        paid_at: body.mark_paid ? new Date().toISOString() : null,
        place_of_supply: body.place_of_supply ?? "IN-JH",
        metadata: { gst_split: "cgst_sgst" },
      });
      return json(200, {
        id,
        invoice_number: invoiceNumber,
        ...gst,
      });
    }

    if (action === "create_checkout") {
      await assertTenantAccess(db, auth.uid, tenantId, auth.appRole);
      const planId = body.plan_id as string;
      if (!planId) throw new Error("plan_id required");
      const { data: plan } = await db.from("bos_plans").select("*").eq("id", planId).single();
      if (!plan) throw new Error("plan not found");

      const keyId = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
      const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
      if (!keyId || !keySecret) {
        return json(503, { error: "Razorpay is not configured" });
      }

      const taxable = Number(plan.price_monthly_paise ?? 0);
      if (!(taxable > 0)) {
        // Free / enterprise negotiated — activate without payment
        await activatePlan(db, tenantId, planId);
        return json(200, { ok: true, free: true, plan: plan.code });
      }

      const gst = gstBreakdown(taxable);
      const { data: sub } = await db
        .from("bos_subscriptions")
        .select("id")
        .eq("tenant_id", tenantId)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      const invoiceId = crypto.randomUUID();
      const invoiceNumber = `INV-${Date.now().toString().slice(-8)}`;

      const authRp = btoa(`${keyId}:${keySecret}`);
      const rpRes = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: {
          Authorization: `Basic ${authRp}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          amount: gst.amount_paise,
          currency: "INR",
          receipt: `bos_${invoiceId}`.slice(0, 40),
          notes: {
            bos_invoice_id: invoiceId,
            bos_tenant_id: tenantId,
            plan_id: planId,
            paymentContext: "dgyard_bos",
          },
        }),
      });
      const rpJson = await rpRes.json();
      if (!rpRes.ok) {
        return json(502, { error: rpJson?.error?.description ?? "Razorpay order failed" });
      }

      await db.from("bos_invoices").insert({
        id: invoiceId,
        tenant_id: tenantId,
        subscription_id: sub?.id ?? null,
        ...gst,
        currency: "INR",
        status: "open",
        invoice_number: invoiceNumber,
        issued_at: new Date().toISOString(),
        place_of_supply: body.place_of_supply ?? "IN-JH",
        razorpay_order_id: rpJson.id,
        metadata: {
          pending_plan_id: planId,
          plan_code: plan.code,
          gst_split: "cgst_sgst",
        },
      });

      return json(200, {
        invoiceId,
        invoice_number: invoiceNumber,
        razorpayOrderId: rpJson.id,
        keyId,
        amountPaise: gst.amount_paise,
        taxablePaise: gst.taxable_paise,
        cgstPaise: gst.cgst_paise,
        sgstPaise: gst.sgst_paise,
        gstRatePct: gst.gst_rate_pct,
        planCode: plan.code,
        planName: plan.name,
      });
    }

    if (action === "verify_payment") {
      await assertTenantAccess(db, auth.uid, tenantId, auth.appRole);
      const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
      if (!keySecret) return json(503, { error: "Razorpay is not configured" });

      const invoiceId = String(body.invoice_id ?? "").trim();
      const razorpayOrderId = String(body.razorpay_order_id ?? "").trim();
      const razorpayPaymentId = String(body.razorpay_payment_id ?? "").trim();
      const razorpaySignature = String(body.razorpay_signature ?? "").trim();
      if (!invoiceId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
        throw new Error("Missing payment fields");
      }

      const { data: inv } = await db
        .from("bos_invoices")
        .select("*")
        .eq("id", invoiceId)
        .eq("tenant_id", tenantId)
        .maybeSingle();
      if (!inv) throw new Error("Invoice not found");
      if (inv.razorpay_order_id && inv.razorpay_order_id !== razorpayOrderId) {
        throw new Error("Order mismatch");
      }

      const expected = await hmacSha256Hex(keySecret, `${razorpayOrderId}|${razorpayPaymentId}`);
      if (expected !== razorpaySignature) throw new Error("Invalid payment signature");

      if (inv.status === "paid") {
        return json(200, { ok: true, alreadyConfirmed: true, invoice_id: invoiceId });
      }

      const planId = (inv.metadata as Record<string, unknown>)?.pending_plan_id as string | undefined;
      await db.from("bos_invoices").update({
        status: "paid",
        paid_at: new Date().toISOString(),
        razorpay_payment_id: razorpayPaymentId,
      }).eq("id", invoiceId);

      let planCode: string | null = null;
      if (planId) {
        const plan = await activatePlan(db, tenantId, planId, razorpayPaymentId);
        planCode = plan.code;
      }

      await db.from("bos_usage_events").insert({
        tenant_id: tenantId,
        metric: "payment_success",
        quantity: 1,
        meta: { invoice_id: invoiceId, payment_id: razorpayPaymentId, plan_id: planId },
      });

      return json(200, { ok: true, invoice_id: invoiceId, plan: planCode });
    }

    if (action === "set_status") {
      if (auth.appRole !== "superadmin") throw new Error("Superadmin only");
      const status = body.status as string;
      if (!["active", "suspended", "trial", "cancelled"].includes(status)) {
        throw new Error("invalid status");
      }
      await db.from("bos_tenants").update({ status }).eq("id", tenantId);
      const subStatus = status === "suspended" || status === "cancelled" ? "suspended" : "active";
      await db.from("bos_subscriptions").update({ status: subStatus }).eq("tenant_id", tenantId);
      return json(200, { ok: true, status });
    }

    if (action === "record_usage") {
      await assertTenantAccess(db, auth.uid, tenantId, auth.appRole);
      const metric = (body.metric as string) || "api_calls";
      const quantity = Number(body.quantity ?? 1);
      await db.from("bos_usage_events").insert({
        tenant_id: tenantId,
        metric,
        quantity,
        meta: body.meta ?? {},
      });
      return json(200, { ok: true });
    }

    if (action === "usage_summary") {
      await assertTenantAccess(db, auth.uid, tenantId, auth.appRole);
      const since = new Date(Date.now() - 30 * 86400000).toISOString();
      const { data: events } = await db
        .from("bos_usage_events")
        .select("metric, quantity")
        .eq("tenant_id", tenantId)
        .gte("occurred_at", since);

      const totals: Record<string, number> = {};
      for (const e of events ?? []) {
        const m = String(e.metric ?? "other");
        totals[m] = (totals[m] ?? 0) + Number(e.quantity ?? 0);
      }

      const { data: tenant } = await db.from("bos_tenants").select("plan_id").eq("id", tenantId).maybeSingle();
      let limits: Record<string, unknown> = {};
      if (tenant?.plan_id) {
        const { data: plan } = await db.from("bos_plans").select("limits, code, name").eq("id", tenant.plan_id).maybeSingle();
        limits = (plan?.limits as Record<string, unknown>) ?? {};
        return json(200, {
          totals,
          limits,
          plan: plan?.code,
          plan_name: plan?.name,
          window_days: 30,
        });
      }
      return json(200, { totals, limits, window_days: 30 });
    }

    if (action === "mrr_overview") {
      if (auth.appRole !== "superadmin") throw new Error("Superadmin only");
      const { data: subs } = await db
        .from("bos_subscriptions")
        .select("id, tenant_id, status, plan_id, bos_plans(code, name, price_monthly_paise), bos_tenants(name, slug, status)")
        .in("status", ["active", "trialing"]);

      let mrrPaise = 0;
      let activeCount = 0;
      let trialingCount = 0;
      const rows: Record<string, unknown>[] = [];
      for (const s of subs ?? []) {
        const plan = s.bos_plans as { code?: string; name?: string; price_monthly_paise?: number } | null;
        const tenant = s.bos_tenants as { name?: string; slug?: string; status?: string } | null;
        const price = Number(plan?.price_monthly_paise ?? 0);
        if (s.status === "active") {
          mrrPaise += price;
          activeCount += 1;
        } else if (s.status === "trialing") {
          trialingCount += 1;
        }
        rows.push({
          tenant_id: s.tenant_id,
          tenant_name: tenant?.name,
          slug: tenant?.slug,
          tenant_status: tenant?.status,
          sub_status: s.status,
          plan: plan?.code,
          price_monthly_paise: price,
        });
      }

      return json(200, {
        mrr_paise: mrrPaise,
        mrr_inr: Math.round(mrrPaise / 100),
        active_subscriptions: activeCount,
        trialing_subscriptions: trialingCount,
        tenants: rows,
      });
    }

    throw new Error("Unknown action");
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
