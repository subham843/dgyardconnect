/**
 * Marketplace checkout: server-authoritative cart totals, Razorpay orders, COD eligibility, webhook.
 *
 * Config (existing): razorpay.key_id, razorpay.key_secret
 * Add: razorpay.webhook_secret — Razorpay Dashboard → Webhooks → signing secret
 * Firestore: config/marketplace_rules — optional COD gates (see readMarketplaceRules)
 */
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { getExternalConfig } from "./config";

/** Lazy: Firebase CLI loads this module before `index.ts` runs `initializeApp()`. */
function getDb(): admin.firestore.Firestore {
  return admin.firestore();
}
function getMessaging(): admin.messaging.Messaging {
  return admin.messaging();
}

function getAllFcmTokensForUser(data: Record<string, unknown>): string[] {
  const arr = data.fcmTokens as string[] | undefined;
  const tokens = Array.isArray(arr)
    ? arr.filter((t): t is string => typeof t === "string" && t.length > 0)
    : [];
  const single = data.fcmToken as string | undefined;
  if (typeof single === "string" && single.length > 0 && !tokens.includes(single)) {
    tokens.push(single);
  }
  return tokens;
}

async function notifySellerNewOrderRequest(
  sellerUid: string,
  requestId: string,
  titleSnapshot: string
): Promise<void> {
  const userSnap = await getDb().collection("users").doc(sellerUid).get();
  if (!userSnap.exists) return;
  const tokens = getAllFcmTokensForUser(userSnap.data() ?? {});
  if (tokens.length === 0) return;
  const title = "New marketplace order";
  const line = titleSnapshot.length > 72 ? `${titleSnapshot.slice(0, 69)}…` : titleSnapshot;
  const body = line.length > 0 ? line : "You have a new order line to fulfil.";
  const dataPayload: Record<string, string> = {
    type: "mp_seller_order_request",
    requestId,
    target: "marketplace",
    title,
    body,
  };
  for (const token of tokens) {
    try {
      await getMessaging().send({
        token,
        notification: { title, body },
        data: dataPayload,
        android: { priority: "high" as const },
        apns: { payload: { aps: { alert: { title, body }, sound: "default" } } },
      });
    } catch (e) {
      functions.logger.warn("marketplace seller FCM failed", { sellerUid, error: e });
    }
  }
}

type CartLine = {
  id: string;
  catalogProductId: string;
  quantity: number;
  titleSnapshot: string;
  pricePaiseSnapshot: number;
  moq: number;
};

type MarketplaceRules = {
  codEnabled: boolean;
  codMaxAmountPaise: number;
  codBlockedPincodes: Set<string>;
  codMinTrustScore: number;
};

function assertAuthed(context: functions.https.CallableContext): string {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  return context.auth.uid;
}

async function readMarketplaceRules(): Promise<MarketplaceRules> {
  const snap = await getDb().collection("config").doc("marketplace_rules").get();
  const d = snap.data() ?? {};
  const blocked = d.cod_blocked_pincodes;
  const pinSet = new Set<string>();
  if (Array.isArray(blocked)) {
    for (const p of blocked) {
      if (typeof p === "string" && p.trim()) pinSet.add(p.trim());
    }
  }
  return {
    codEnabled: d.cod_enabled !== false,
    codMaxAmountPaise: Math.max(0, Math.floor(Number(d.cod_max_amount_paise) || 5000000)),
    codBlockedPincodes: pinSet,
    codMinTrustScore: Math.max(0, Number(d.cod_min_trust_score) || 0),
  };
}

async function loadCartLines(uid: string): Promise<CartLine[]> {
  const col = getDb()
    .collection("users")
    .doc(uid)
    .collection("marketplace_cart")
    .doc("data")
    .collection("items");
  const snap = await col.get();
  const lines: CartLine[] = [];
  for (const doc of snap.docs) {
    const m = doc.data();
    lines.push({
      id: doc.id,
      catalogProductId: String(m.catalog_product_id ?? ""),
      quantity: Math.max(1, Math.floor(Number(m.quantity) || 1)),
      titleSnapshot: String(m.title_snapshot ?? ""),
      pricePaiseSnapshot: Math.max(0, Math.floor(Number(m.price_paise_snapshot) || 0)),
      moq: Math.max(1, Math.floor(Number(m.moq) || 1)),
    });
  }
  return lines.filter((l) => l.catalogProductId.length > 0);
}

async function buildOrderFromCart(uid: string, lines: CartLine[]) {
  if (lines.length === 0) throw new functions.https.HttpsError("failed-precondition", "Cart is empty");

  let totalPaise = 0;
  const resolvedLines: {
    catalogProductId: string;
    title: string;
    quantity: number;
    unitPricePaise: number;
    lineTotalPaise: number;
  }[] = [];

  for (const line of lines) {
    const catRef = getDb().collection("marketplace_catalog").doc(line.catalogProductId);
    const catSnap = await catRef.get();
    if (!catSnap.exists) {
      throw new functions.https.HttpsError("failed-precondition", `Product unavailable: ${line.catalogProductId}`);
    }
    const c = catSnap.data()!;
    if (c.listing_status !== "live") {
      throw new functions.https.HttpsError("failed-precondition", `Product not for sale: ${line.catalogProductId}`);
    }
    const unit = Math.max(0, Math.floor(Number(c.price_paise) || 0));
    const qty = Math.max(line.moq, line.quantity);
    const lineTotal = unit * qty;
    totalPaise += lineTotal;
    resolvedLines.push({
      catalogProductId: line.catalogProductId,
      title: String(c.title ?? line.titleSnapshot ?? "Item"),
      quantity: qty,
      unitPricePaise: unit,
      lineTotalPaise: lineTotal,
    });
  }

  if (totalPaise <= 0) throw new functions.https.HttpsError("failed-precondition", "Invalid total");

  return { totalPaise, resolvedLines };
}

async function clearCart(uid: string, lineIds: string[]) {
  const batch = getDb().batch();
  const base = getDb().collection("users").doc(uid).collection("marketplace_cart").doc("data").collection("items");
  for (const id of lineIds) {
    batch.delete(base.doc(id));
  }
  batch.set(
    getDb().collection("users").doc(uid).collection("marketplace_cart").doc("data"),
    { updated_at: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
  await batch.commit();
}

async function sellerUidForCatalogProduct(catalogProductId: string): Promise<string | null> {
  const q = await getDb()
    .collection("marketplace_listings")
    .where("catalog_product_id", "==", catalogProductId)
    .limit(1)
    .get();
  if (q.empty) return null;
  const u = q.docs[0].data().seller_uid;
  return typeof u === "string" && u.length > 0 ? u : null;
}

/** Idempotent: one doc per order line for seller queue (buyer identity not stored here). */
async function ensureSellerOrderRequestsForOrder(orderRef: admin.firestore.DocumentReference): Promise<void> {
  const orderId = orderRef.id;
  const linesSnap = await orderRef.collection("lines").get();
  for (const lineDoc of linesSnap.docs) {
    const d = lineDoc.data();
    const catId = String(d.catalog_product_id ?? "");
    if (!catId) continue;
    const reqRef = getDb().collection("marketplace_seller_order_requests").doc(`${orderId}_${lineDoc.id}`);
    const existing = await reqRef.get();
    if (existing.exists) continue;
    const sellerUid = await sellerUidForCatalogProduct(catId);
    if (!sellerUid) {
      functions.logger.warn("marketplace: no seller mapping for catalog line", { orderId, catalogProductId: catId });
      continue;
    }
    await reqRef.set({
      order_id: orderId,
      line_id: lineDoc.id,
      catalog_product_id: catId,
      title_snapshot: String(d.title_snapshot ?? ""),
      quantity: Math.max(1, Math.floor(Number(d.quantity) || 1)),
      unit_price_paise: Math.max(0, Math.floor(Number(d.unit_price_paise) || 0)),
      line_total_paise: Math.max(0, Math.floor(Number(d.line_total_paise) || 0)),
      seller_uid: sellerUid,
      status: "open",
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    await notifySellerNewOrderRequest(sellerUid, reqRef.id, String(d.title_snapshot ?? ""));
  }
}

/** Callable: seller accepts or rejects a line-item request (server-enforced ownership). */
export const marketplaceSellerRespondToOrderRequest = functions.https.onCall(async (data, context) => {
  const uid = assertAuthed(context);
  const requestId = String(data?.requestId ?? "").trim();
  const action = String(data?.action ?? "").trim().toLowerCase();
  if (!requestId || (action !== "accept" && action !== "reject")) {
    throw new functions.https.HttpsError("invalid-argument", "requestId and action accept|reject required");
  }
  const ref = getDb().collection("marketplace_seller_order_requests").doc(requestId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "Request not found");
  }
  const d = snap.data()!;
  if (d.seller_uid !== uid) {
    throw new functions.https.HttpsError("permission-denied", "Not your request");
  }
  const cur = String(d.status ?? "");
  if (cur !== "open") {
    throw new functions.https.HttpsError("failed-precondition", "Already responded");
  }
  const newStatus = action === "accept" ? "accepted" : "rejected";
  await ref.update({
    status: newStatus,
    responded_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { ok: true, status: newStatus };
});

/** Callable: server validates cart vs live catalog; returns whether COD is allowed and why not. */
export const marketplaceCheckCodEligibility = functions.https.onCall(async (data, context) => {
  const uid = assertAuthed(context);
  const totalPaise = Math.max(0, Math.floor(Number(data?.totalPaise) || 0));
  const pincode = typeof data?.pincode === "string" ? data.pincode.trim() : "";

  const rules = await readMarketplaceRules();
  if (!rules.codEnabled) {
    return { eligible: false, reason: "cod_disabled" };
  }
  if (totalPaise <= 0) {
    return { eligible: false, reason: "invalid_amount" };
  }
  if (totalPaise > rules.codMaxAmountPaise) {
    return { eligible: false, reason: "amount_over_cap" };
  }
  if (pincode && rules.codBlockedPincodes.has(pincode)) {
    return { eligible: false, reason: "pincode_blocked" };
  }

  const userSnap = await getDb().collection("users").doc(uid).get();
  const trust = Number(userSnap.data()?.trustScore ?? 0);
  if (trust < rules.codMinTrustScore) {
    return { eligible: false, reason: "trust_too_low" };
  }

  return { eligible: true };
});

/** Callable: place COD order after eligibility (re-checked server-side). */
export const marketplacePlaceCodOrder = functions.https.onCall(async (data, context) => {
  const uid = assertAuthed(context);
  const pincode = typeof data?.pincode === "string" ? data.pincode.trim() : "";

  const rawLines = await loadCartLines(uid);
  const { totalPaise, resolvedLines } = await buildOrderFromCart(uid, rawLines);

  const rules = await readMarketplaceRules();
  if (!rules.codEnabled) {
    throw new functions.https.HttpsError("failed-precondition", "COD is disabled");
  }
  if (totalPaise > rules.codMaxAmountPaise) {
    throw new functions.https.HttpsError("failed-precondition", "Order amount exceeds COD limit");
  }
  if (pincode && rules.codBlockedPincodes.has(pincode)) {
    throw new functions.https.HttpsError("failed-precondition", "COD not available for this pincode");
  }
  const userSnap = await getDb().collection("users").doc(uid).get();
  const trust = Number(userSnap.data()?.trustScore ?? 0);
  if (trust < rules.codMinTrustScore) {
    throw new functions.https.HttpsError("failed-precondition", "COD not available for this account tier");
  }

  const orderRef = getDb().collection("marketplace_orders").doc();
  const batch = getDb().batch();
  batch.set(orderRef, {
    buyer_uid: uid,
    status: "awaiting_confirmation",
    total_paise: totalPaise,
    payment_method: "cod",
    cod_pincode: pincode || null,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  for (const line of resolvedLines) {
    const lineRef = orderRef.collection("lines").doc();
    batch.set(lineRef, {
      catalog_product_id: line.catalogProductId,
      title_snapshot: line.title,
      quantity: line.quantity,
      unit_price_paise: line.unitPricePaise,
      line_total_paise: line.lineTotalPaise,
    });
  }

  await batch.commit();
  await clearCart(
    uid,
    rawLines.map((l) => l.id)
  );
  await ensureSellerOrderRequestsForOrder(orderRef);

  return { marketplaceOrderId: orderRef.id, totalPaise };
});

/** Callable: create Firestore marketplace order + Razorpay order from cart. */
export const marketplaceCreateRazorpayCheckout = functions.https.onCall(async (data, context) => {
  const uid = assertAuthed(context);
  const razorpayConfig = getExternalConfig().razorpay;
  if (!razorpayConfig) {
    throw new functions.https.HttpsError("failed-precondition", "Razorpay is not configured");
  }

  const rawLines = await loadCartLines(uid);
  const { totalPaise, resolvedLines } = await buildOrderFromCart(uid, rawLines);

  const orderRef = getDb().collection("marketplace_orders").doc();
  const Razorpay = require("razorpay");
  const instance = new Razorpay({ key_id: razorpayConfig.keyId, key_secret: razorpayConfig.keySecret });

  const rpOrder = await instance.orders.create({
    amount: totalPaise,
    currency: "INR",
    receipt: `mp_${orderRef.id}`.slice(0, 40),
    notes: {
      marketplace_order_id: orderRef.id,
      buyer_uid: uid,
      paymentContext: "dgyard_marketplace",
    },
  });

  const batch = getDb().batch();
  batch.set(orderRef, {
    buyer_uid: uid,
    status: "payment_pending",
    total_paise: totalPaise,
    payment_method: "razorpay",
    razorpay_order_id: rpOrder.id,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  for (const line of resolvedLines) {
    const lineRef = orderRef.collection("lines").doc();
    batch.set(lineRef, {
      catalog_product_id: line.catalogProductId,
      title_snapshot: line.title,
      quantity: line.quantity,
      unit_price_paise: line.unitPricePaise,
      line_total_paise: line.lineTotalPaise,
    });
  }

  await batch.commit();
  await clearCart(
    uid,
    rawLines.map((l) => l.id)
  );

  return {
    marketplaceOrderId: orderRef.id,
    razorpayOrderId: rpOrder.id,
    keyId: razorpayConfig.keyId,
    amountPaise: totalPaise,
  };
});

/** Callable: verify client payment success (HMAC) and mark order paid. Webhook is a backup. */
export const marketplaceVerifyRazorpayPayment = functions.https.onCall(async (data, context) => {
  const uid = assertAuthed(context);
  const marketplaceOrderId = String(data?.marketplaceOrderId ?? "").trim();
  const razorpayOrderId = String(data?.razorpay_order_id ?? "").trim();
  const razorpayPaymentId = String(data?.razorpay_payment_id ?? "").trim();
  const razorpaySignature = String(data?.razorpay_signature ?? "").trim();

  if (!marketplaceOrderId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
    throw new functions.https.HttpsError("invalid-argument", "Missing payment fields");
  }

  const razorpayConfig = getExternalConfig().razorpay;
  if (!razorpayConfig) {
    throw new functions.https.HttpsError("failed-precondition", "Razorpay is not configured");
  }

  const orderRef = getDb().collection("marketplace_orders").doc(marketplaceOrderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) throw new functions.https.HttpsError("not-found", "Order not found");
  const order = orderSnap.data()!;
  if (order.buyer_uid !== uid) {
    throw new functions.https.HttpsError("permission-denied", "Not your order");
  }
  if (order.razorpay_order_id !== razorpayOrderId) {
    throw new functions.https.HttpsError("invalid-argument", "Order mismatch");
  }

  const expectedSignature = crypto
    .createHmac("sha256", razorpayConfig.keySecret)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest("hex");
  if (expectedSignature !== razorpaySignature) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid payment signature");
  }

  const cur = order.status as string;
  if (cur === "paid" || cur === "payment_captured") {
    return { ok: true, marketplaceOrderId, alreadyConfirmed: true };
  }

  await orderRef.update({
    status: "paid",
    razorpay_payment_id: razorpayPaymentId,
    payment_verified_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  await ensureSellerOrderRequestsForOrder(orderRef);

  return { ok: true, marketplaceOrderId };
});

function verifyWebhookSignature(rawBody: Buffer, signatureHeader: string | undefined, secret: string): boolean {
  if (!signatureHeader) return false;
  const expected = crypto.createHmac("sha256", secret).update(rawBody).digest("hex");
  try {
    const a = Buffer.from(expected, "hex");
    const b = Buffer.from(signatureHeader.trim(), "hex");
    if (a.length !== b.length || a.length === 0) return false;
    return crypto.timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

/** HTTPS: Razorpay payment events — configure URL in Razorpay Dashboard. */
export const marketplaceRazorpayWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method not allowed");
    return;
  }

  const razorpayConfig = getExternalConfig().razorpay;
  const secret = razorpayConfig?.webhookSecret;
  if (!razorpayConfig || !secret) {
    functions.logger.warn("marketplaceRazorpayWebhook: webhook secret not configured");
    res.status(503).send("Webhook not configured");
    return;
  }

  const rawBody = (req as { rawBody?: Buffer }).rawBody;
  if (!rawBody) {
    res.status(400).send("Missing raw body");
    return;
  }

  const sig = req.get("x-razorpay-signature");
  if (!verifyWebhookSignature(rawBody, sig, secret)) {
    res.status(400).send("Invalid signature");
    return;
  }

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody.toString("utf8")) as Record<string, unknown>;
  } catch {
    res.status(400).send("Invalid JSON");
    return;
  }

  const event = payload.event as string | undefined;
  const paymentPayload = payload.payload as Record<string, unknown> | undefined;
  const paymentEntity = (paymentPayload?.payment as Record<string, unknown> | undefined)?.entity as
    | Record<string, unknown>
    | undefined;

  if (event === "payment.captured" && paymentEntity) {
    const orderId = paymentEntity.order_id as string | undefined;
    const paymentId = paymentEntity.id as string | undefined;
    if (orderId && paymentId) {
      const q = await getDb().collection("marketplace_orders").where("razorpay_order_id", "==", orderId).limit(1).get();
      if (!q.empty) {
        const doc = q.docs[0];
        const d = doc.data();
        if (d.status === "payment_pending") {
          await doc.ref.update({
            status: "paid",
            razorpay_payment_id: paymentId,
            payment_verified_at: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
          await ensureSellerOrderRequestsForOrder(doc.ref);
          functions.logger.info("marketplace webhook: order marked paid", { orderId: doc.id, paymentId });
        }
      }
    }
  }

  res.json({ ok: true });
});
