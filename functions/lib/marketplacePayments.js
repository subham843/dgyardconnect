"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.marketplaceRazorpayWebhook = exports.marketplaceVerifyRazorpayPayment = exports.marketplaceCreateRazorpayCheckout = exports.marketplacePlaceCodOrder = exports.marketplaceCheckCodEligibility = exports.marketplaceSellerRespondToOrderRequest = void 0;
/**
 * Marketplace checkout: server-authoritative cart totals, Razorpay orders, COD eligibility, webhook.
 *
 * Config (existing): razorpay.key_id, razorpay.key_secret
 * Add: razorpay.webhook_secret — Razorpay Dashboard → Webhooks → signing secret
 * Firestore: config/marketplace_rules — optional COD gates (see readMarketplaceRules)
 */
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const crypto = require("crypto");
const config_1 = require("./config");
/** Lazy: Firebase CLI loads this module before `index.ts` runs `initializeApp()`. */
function getDb() {
    return admin.firestore();
}
function getMessaging() {
    return admin.messaging();
}
function getAllFcmTokensForUser(data) {
    const arr = data.fcmTokens;
    const tokens = Array.isArray(arr)
        ? arr.filter((t) => typeof t === "string" && t.length > 0)
        : [];
    const single = data.fcmToken;
    if (typeof single === "string" && single.length > 0 && !tokens.includes(single)) {
        tokens.push(single);
    }
    return tokens;
}
async function notifySellerNewOrderRequest(sellerUid, requestId, titleSnapshot) {
    var _a;
    const userSnap = await getDb().collection("users").doc(sellerUid).get();
    if (!userSnap.exists)
        return;
    const tokens = getAllFcmTokensForUser((_a = userSnap.data()) !== null && _a !== void 0 ? _a : {});
    if (tokens.length === 0)
        return;
    const title = "New marketplace order";
    const line = titleSnapshot.length > 72 ? `${titleSnapshot.slice(0, 69)}…` : titleSnapshot;
    const body = line.length > 0 ? line : "You have a new order line to fulfil.";
    const dataPayload = {
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
                android: { priority: "high" },
                apns: { payload: { aps: { alert: { title, body }, sound: "default" } } },
            });
        }
        catch (e) {
            functions.logger.warn("marketplace seller FCM failed", { sellerUid, error: e });
        }
    }
}
function assertAuthed(context) {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    return context.auth.uid;
}
async function readMarketplaceRules() {
    var _a;
    const snap = await getDb().collection("config").doc("marketplace_rules").get();
    const d = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
    const blocked = d.cod_blocked_pincodes;
    const pinSet = new Set();
    if (Array.isArray(blocked)) {
        for (const p of blocked) {
            if (typeof p === "string" && p.trim())
                pinSet.add(p.trim());
        }
    }
    return {
        codEnabled: d.cod_enabled !== false,
        codMaxAmountPaise: Math.max(0, Math.floor(Number(d.cod_max_amount_paise) || 5000000)),
        codBlockedPincodes: pinSet,
        codMinTrustScore: Math.max(0, Number(d.cod_min_trust_score) || 0),
    };
}
async function loadCartLines(uid) {
    var _a, _b;
    const col = getDb()
        .collection("users")
        .doc(uid)
        .collection("marketplace_cart")
        .doc("data")
        .collection("items");
    const snap = await col.get();
    const lines = [];
    for (const doc of snap.docs) {
        const m = doc.data();
        lines.push({
            id: doc.id,
            catalogProductId: String((_a = m.catalog_product_id) !== null && _a !== void 0 ? _a : ""),
            quantity: Math.max(1, Math.floor(Number(m.quantity) || 1)),
            titleSnapshot: String((_b = m.title_snapshot) !== null && _b !== void 0 ? _b : ""),
            pricePaiseSnapshot: Math.max(0, Math.floor(Number(m.price_paise_snapshot) || 0)),
            moq: Math.max(1, Math.floor(Number(m.moq) || 1)),
        });
    }
    return lines.filter((l) => l.catalogProductId.length > 0);
}
async function buildOrderFromCart(uid, lines) {
    var _a, _b;
    if (lines.length === 0)
        throw new functions.https.HttpsError("failed-precondition", "Cart is empty");
    let totalPaise = 0;
    const resolvedLines = [];
    for (const line of lines) {
        const catRef = getDb().collection("marketplace_catalog").doc(line.catalogProductId);
        const catSnap = await catRef.get();
        if (!catSnap.exists) {
            throw new functions.https.HttpsError("failed-precondition", `Product unavailable: ${line.catalogProductId}`);
        }
        const c = catSnap.data();
        if (c.listing_status !== "live") {
            throw new functions.https.HttpsError("failed-precondition", `Product not for sale: ${line.catalogProductId}`);
        }
        const unit = Math.max(0, Math.floor(Number(c.price_paise) || 0));
        const qty = Math.max(line.moq, line.quantity);
        const lineTotal = unit * qty;
        totalPaise += lineTotal;
        resolvedLines.push({
            catalogProductId: line.catalogProductId,
            title: String((_b = (_a = c.title) !== null && _a !== void 0 ? _a : line.titleSnapshot) !== null && _b !== void 0 ? _b : "Item"),
            quantity: qty,
            unitPricePaise: unit,
            lineTotalPaise: lineTotal,
        });
    }
    if (totalPaise <= 0)
        throw new functions.https.HttpsError("failed-precondition", "Invalid total");
    return { totalPaise, resolvedLines };
}
async function clearCart(uid, lineIds) {
    const batch = getDb().batch();
    const base = getDb().collection("users").doc(uid).collection("marketplace_cart").doc("data").collection("items");
    for (const id of lineIds) {
        batch.delete(base.doc(id));
    }
    batch.set(getDb().collection("users").doc(uid).collection("marketplace_cart").doc("data"), { updated_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    await batch.commit();
}
async function sellerUidForCatalogProduct(catalogProductId) {
    const q = await getDb()
        .collection("marketplace_listings")
        .where("catalog_product_id", "==", catalogProductId)
        .limit(1)
        .get();
    if (q.empty)
        return null;
    const u = q.docs[0].data().seller_uid;
    return typeof u === "string" && u.length > 0 ? u : null;
}
/** Idempotent: one doc per order line for seller queue (buyer identity not stored here). */
async function ensureSellerOrderRequestsForOrder(orderRef) {
    var _a, _b, _c;
    const orderId = orderRef.id;
    const linesSnap = await orderRef.collection("lines").get();
    for (const lineDoc of linesSnap.docs) {
        const d = lineDoc.data();
        const catId = String((_a = d.catalog_product_id) !== null && _a !== void 0 ? _a : "");
        if (!catId)
            continue;
        const reqRef = getDb().collection("marketplace_seller_order_requests").doc(`${orderId}_${lineDoc.id}`);
        const existing = await reqRef.get();
        if (existing.exists)
            continue;
        const sellerUid = await sellerUidForCatalogProduct(catId);
        if (!sellerUid) {
            functions.logger.warn("marketplace: no seller mapping for catalog line", { orderId, catalogProductId: catId });
            continue;
        }
        await reqRef.set({
            order_id: orderId,
            line_id: lineDoc.id,
            catalog_product_id: catId,
            title_snapshot: String((_b = d.title_snapshot) !== null && _b !== void 0 ? _b : ""),
            quantity: Math.max(1, Math.floor(Number(d.quantity) || 1)),
            unit_price_paise: Math.max(0, Math.floor(Number(d.unit_price_paise) || 0)),
            line_total_paise: Math.max(0, Math.floor(Number(d.line_total_paise) || 0)),
            seller_uid: sellerUid,
            status: "open",
            created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        await notifySellerNewOrderRequest(sellerUid, reqRef.id, String((_c = d.title_snapshot) !== null && _c !== void 0 ? _c : ""));
    }
}
/** Callable: seller accepts or rejects a line-item request (server-enforced ownership). */
exports.marketplaceSellerRespondToOrderRequest = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    const uid = assertAuthed(context);
    const requestId = String((_a = data === null || data === void 0 ? void 0 : data.requestId) !== null && _a !== void 0 ? _a : "").trim();
    const action = String((_b = data === null || data === void 0 ? void 0 : data.action) !== null && _b !== void 0 ? _b : "").trim().toLowerCase();
    if (!requestId || (action !== "accept" && action !== "reject")) {
        throw new functions.https.HttpsError("invalid-argument", "requestId and action accept|reject required");
    }
    const ref = getDb().collection("marketplace_seller_order_requests").doc(requestId);
    const snap = await ref.get();
    if (!snap.exists) {
        throw new functions.https.HttpsError("not-found", "Request not found");
    }
    const d = snap.data();
    if (d.seller_uid !== uid) {
        throw new functions.https.HttpsError("permission-denied", "Not your request");
    }
    const cur = String((_c = d.status) !== null && _c !== void 0 ? _c : "");
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
exports.marketplaceCheckCodEligibility = functions.https.onCall(async (data, context) => {
    var _a, _b;
    const uid = assertAuthed(context);
    const totalPaise = Math.max(0, Math.floor(Number(data === null || data === void 0 ? void 0 : data.totalPaise) || 0));
    const pincode = typeof (data === null || data === void 0 ? void 0 : data.pincode) === "string" ? data.pincode.trim() : "";
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
    const trust = Number((_b = (_a = userSnap.data()) === null || _a === void 0 ? void 0 : _a.trustScore) !== null && _b !== void 0 ? _b : 0);
    if (trust < rules.codMinTrustScore) {
        return { eligible: false, reason: "trust_too_low" };
    }
    return { eligible: true };
});
/** Callable: place COD order after eligibility (re-checked server-side). */
exports.marketplacePlaceCodOrder = functions.https.onCall(async (data, context) => {
    var _a, _b;
    const uid = assertAuthed(context);
    const pincode = typeof (data === null || data === void 0 ? void 0 : data.pincode) === "string" ? data.pincode.trim() : "";
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
    const trust = Number((_b = (_a = userSnap.data()) === null || _a === void 0 ? void 0 : _a.trustScore) !== null && _b !== void 0 ? _b : 0);
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
    await clearCart(uid, rawLines.map((l) => l.id));
    await ensureSellerOrderRequestsForOrder(orderRef);
    return { marketplaceOrderId: orderRef.id, totalPaise };
});
/** Callable: create Firestore marketplace order + Razorpay order from cart. */
exports.marketplaceCreateRazorpayCheckout = functions.https.onCall(async (data, context) => {
    const uid = assertAuthed(context);
    const razorpayConfig = (0, config_1.getExternalConfig)().razorpay;
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
    await clearCart(uid, rawLines.map((l) => l.id));
    return {
        marketplaceOrderId: orderRef.id,
        razorpayOrderId: rpOrder.id,
        keyId: razorpayConfig.keyId,
        amountPaise: totalPaise,
    };
});
/** Callable: verify client payment success (HMAC) and mark order paid. Webhook is a backup. */
exports.marketplaceVerifyRazorpayPayment = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    const uid = assertAuthed(context);
    const marketplaceOrderId = String((_a = data === null || data === void 0 ? void 0 : data.marketplaceOrderId) !== null && _a !== void 0 ? _a : "").trim();
    const razorpayOrderId = String((_b = data === null || data === void 0 ? void 0 : data.razorpay_order_id) !== null && _b !== void 0 ? _b : "").trim();
    const razorpayPaymentId = String((_c = data === null || data === void 0 ? void 0 : data.razorpay_payment_id) !== null && _c !== void 0 ? _c : "").trim();
    const razorpaySignature = String((_d = data === null || data === void 0 ? void 0 : data.razorpay_signature) !== null && _d !== void 0 ? _d : "").trim();
    if (!marketplaceOrderId || !razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
        throw new functions.https.HttpsError("invalid-argument", "Missing payment fields");
    }
    const razorpayConfig = (0, config_1.getExternalConfig)().razorpay;
    if (!razorpayConfig) {
        throw new functions.https.HttpsError("failed-precondition", "Razorpay is not configured");
    }
    const orderRef = getDb().collection("marketplace_orders").doc(marketplaceOrderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists)
        throw new functions.https.HttpsError("not-found", "Order not found");
    const order = orderSnap.data();
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
    const cur = order.status;
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
function verifyWebhookSignature(rawBody, signatureHeader, secret) {
    if (!signatureHeader)
        return false;
    const expected = crypto.createHmac("sha256", secret).update(rawBody).digest("hex");
    try {
        const a = Buffer.from(expected, "hex");
        const b = Buffer.from(signatureHeader.trim(), "hex");
        if (a.length !== b.length || a.length === 0)
            return false;
        return crypto.timingSafeEqual(a, b);
    }
    catch (_a) {
        return false;
    }
}
/** HTTPS: Razorpay payment events — configure URL in Razorpay Dashboard. */
exports.marketplaceRazorpayWebhook = functions.https.onRequest(async (req, res) => {
    var _a;
    if (req.method !== "POST") {
        res.status(405).send("Method not allowed");
        return;
    }
    const razorpayConfig = (0, config_1.getExternalConfig)().razorpay;
    const secret = razorpayConfig === null || razorpayConfig === void 0 ? void 0 : razorpayConfig.webhookSecret;
    if (!razorpayConfig || !secret) {
        functions.logger.warn("marketplaceRazorpayWebhook: webhook secret not configured");
        res.status(503).send("Webhook not configured");
        return;
    }
    const rawBody = req.rawBody;
    if (!rawBody) {
        res.status(400).send("Missing raw body");
        return;
    }
    const sig = req.get("x-razorpay-signature");
    if (!verifyWebhookSignature(rawBody, sig, secret)) {
        res.status(400).send("Invalid signature");
        return;
    }
    let payload;
    try {
        payload = JSON.parse(rawBody.toString("utf8"));
    }
    catch (_b) {
        res.status(400).send("Invalid JSON");
        return;
    }
    const event = payload.event;
    const paymentPayload = payload.payload;
    const paymentEntity = (_a = paymentPayload === null || paymentPayload === void 0 ? void 0 : paymentPayload.payment) === null || _a === void 0 ? void 0 : _a.entity;
    if (event === "payment.captured" && paymentEntity) {
        const orderId = paymentEntity.order_id;
        const paymentId = paymentEntity.id;
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
//# sourceMappingURL=marketplacePayments.js.map