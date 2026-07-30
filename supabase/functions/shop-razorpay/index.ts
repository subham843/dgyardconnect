// Shop checkout: create Razorpay order + verify payment for shop_orders.
// Secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET
// Auto: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
// Auth: Bearer = Supabase JWT from exchange-firebase-token (sub = firebase_uid)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function decodeJwtSub(authHeader: string | null): string | null {
  if (!authHeader?.startsWith("Bearer ")) return null;
  const token = authHeader.slice(7);
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
    const sub = payload.sub ?? payload.user_id;
    return typeof sub === "string" && sub.length > 0 ? sub : null;
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

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!url || !key) throw new Error("Supabase admin not configured");
  return createClient(url, key);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const firebaseUid = decodeJwtSub(req.headers.get("Authorization"));
    if (!firebaseUid) return json(401, { error: "Sign in required" });

    const keyId = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
    if (!keyId || !keySecret) {
      return json(503, { error: "Razorpay is not configured" });
    }

    const body = await req.json();
    const action = String(body?.action ?? "").trim();
    const shopOrderId = String(body?.shopOrderId ?? "").trim();
    if (!shopOrderId) return json(400, { error: "shopOrderId required" });

    const admin = adminClient();
    const { data: order, error: orderErr } = await admin
      .from("shop_orders")
      .select("id, firebase_uid, status, total_amount, payment_ref")
      .eq("id", shopOrderId)
      .maybeSingle();

    if (orderErr || !order) return json(404, { error: "Order not found" });
    if (order.firebase_uid !== firebaseUid) {
      return json(403, { error: "Not your order" });
    }

    if (action === "create") {
      if (order.status !== "pending_payment" && order.status !== "draft") {
        return json(400, { error: "Order is not awaiting payment" });
      }
      const amountInr = Number(order.total_amount ?? 0);
      if (!(amountInr > 0)) return json(400, { error: "Invalid order amount" });
      const amountPaise = Math.round(amountInr * 100);

      const auth = btoa(`${keyId}:${keySecret}`);
      const rpRes = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: {
          Authorization: `Basic ${auth}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          amount: amountPaise,
          currency: "INR",
          receipt: `shop_${shopOrderId}`.slice(0, 40),
          notes: {
            shop_order_id: shopOrderId,
            buyer_uid: firebaseUid,
            paymentContext: "dgyard_shop",
          },
        }),
      });
      const rpJson = await rpRes.json();
      if (!rpRes.ok) {
        return json(502, { error: rpJson?.error?.description ?? "Razorpay order failed" });
      }

      await admin
        .from("shop_orders")
        .update({ payment_ref: rpJson.id })
        .eq("id", shopOrderId);

      return json(200, {
        shopOrderId,
        razorpayOrderId: rpJson.id,
        keyId,
        amountPaise,
        amountInr,
      });
    }

    if (action === "verify") {
      const razorpayOrderId = String(body?.razorpay_order_id ?? "").trim();
      const razorpayPaymentId = String(body?.razorpay_payment_id ?? "").trim();
      const razorpaySignature = String(body?.razorpay_signature ?? "").trim();
      if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
        return json(400, { error: "Missing payment fields" });
      }
      if (order.payment_ref && order.payment_ref !== razorpayOrderId) {
        return json(400, { error: "Order mismatch" });
      }

      const expected = await hmacSha256Hex(
        keySecret,
        `${razorpayOrderId}|${razorpayPaymentId}`,
      );
      if (expected !== razorpaySignature) {
        return json(400, { error: "Invalid payment signature" });
      }

      if (order.status === "paid" || order.status === "processing" || order.status === "shipped" || order.status === "delivered") {
        return json(200, { ok: true, shopOrderId, alreadyConfirmed: true });
      }

      const { error: updErr } = await admin
        .from("shop_orders")
        .update({
          status: "paid",
          payment_ref: `${razorpayOrderId}|${razorpayPaymentId}`,
        })
        .eq("id", shopOrderId);

      if (updErr) return json(500, { error: updErr.message });
      return json(200, { ok: true, shopOrderId });
    }

    return json(400, { error: "Unknown action" });
  } catch (e) {
    return json(500, { error: e instanceof Error ? e.message : "Server error" });
  }
});
