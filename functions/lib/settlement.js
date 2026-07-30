"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateSettlementAccount = exports.onSettlementAccountCreated = void 0;
/**
 * Settlement Account validation via Razorpay.
 * Creates contact, fund account (bank/UPI), and validates bank accounts via RazorpayX Lite (₹1 transfer).
 *
 * Setup:
 * 1. firebase functions:config:set razorpay.key_id "rzp_xxx" razorpay.key_secret "xxx"
 * 2. For bank validation: Create RazorpayX Lite account at https://x.razorpay.com
 *    Add balance, get Customer Identifier from: My Account & Settings → Banking → Customer Identifier
 * 3. firebase functions:config:set razorpay.x_lite_customer_id "YOUR_CUSTOMER_ID"
 *    (Test and Live mode have different Customer Identifiers)
 */
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const config_1 = require("./config");
function getDb() {
    return admin.firestore();
}
const RAZORPAY_BASE = "https://api.razorpay.com/v1";
async function razorpayFetch(keyId, keySecret, path, options = {}) {
    const auth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");
    const res = await fetch(`${RAZORPAY_BASE}${path}`, {
        method: options.method || "GET",
        headers: {
            Authorization: `Basic ${auth}`,
            "Content-Type": "application/json",
        },
        body: options.body ? JSON.stringify(options.body) : undefined,
    });
    const text = await res.text();
    if (!res.ok) {
        throw new Error(`Razorpay API ${res.status}: ${text}`);
    }
    return text ? JSON.parse(text) : {};
}
/** Firestore trigger: when a new settlement account is added, validate via Razorpay. */
exports.onSettlementAccountCreated = functions.firestore
    .document("users/{uid}/settlement_accounts/{accountId}")
    .onCreate(async (snap, context) => {
    var _a;
    const uid = context.params.uid;
    const accountId = context.params.accountId;
    const data = snap.data();
    if ((data === null || data === void 0 ? void 0 : data.status) === "verified")
        return;
    const razorpayConfig = (0, config_1.getExternalConfig)().razorpay;
    if (!razorpayConfig) {
        functions.logger.info("Razorpay not configured, skipping settlement validation", { uid, accountId });
        return;
    }
    try {
        const userSnap = await getDb().collection("users").doc(uid).get();
        const userData = userSnap.data() || {};
        const profile = userData.profile || {};
        const name = profile.name || userData.name || "User";
        const email = profile.email || userData.email || `${uid}@dgyardconnect.local`;
        const phone = profile.phone || userData.phone || "+919999999999";
        let contactId = userData.razorpayContactId || null;
        if (!contactId) {
            const contactRes = (await razorpayFetch(razorpayConfig.keyId, razorpayConfig.keySecret, "/contacts", {
                method: "POST",
                body: { name, email, contact: phone, type: "customer" },
            }));
            contactId = contactRes.id || null;
            if (contactId) {
                await getDb().collection("users").doc(uid).set({ razorpayContactId: contactId }, { merge: true });
            }
        }
        if (!contactId) {
            await snap.ref.update({ status: "failed", error: "Failed to create contact" });
            return;
        }
        const type = data === null || data === void 0 ? void 0 : data.type;
        let fundAccountId = null;
        let bankName = "";
        if (type === "bank_account") {
            const bankRes = (await razorpayFetch(razorpayConfig.keyId, razorpayConfig.keySecret, "/fund_accounts", {
                method: "POST",
                body: {
                    contact_id: contactId,
                    account_type: "bank_account",
                    bank_account: {
                        name: (data === null || data === void 0 ? void 0 : data.accountHolderName) || name,
                        ifsc: (data === null || data === void 0 ? void 0 : data.ifsc) || "",
                        account_number: (data === null || data === void 0 ? void 0 : data.accountNumber) || "",
                    },
                },
            }));
            fundAccountId = bankRes.id || null;
            bankName = ((_a = bankRes.bank_account) === null || _a === void 0 ? void 0 : _a.bank_name) || "";
        }
        else if (type === "vpa") {
            const vpaRes = (await razorpayFetch(razorpayConfig.keyId, razorpayConfig.keySecret, "/fund_accounts", {
                method: "POST",
                body: {
                    contact_id: contactId,
                    account_type: "vpa",
                    vpa: { address: (data === null || data === void 0 ? void 0 : data.vpa) || "" },
                },
            }));
            fundAccountId = vpaRes.id || null;
        }
        else if (type === "card") {
            // Card is kept for checkout preference/reference only.
            // Payout fund_account is not created for card records.
            fundAccountId = null;
        }
        if (!fundAccountId && type !== "card") {
            await snap.ref.update({ status: "failed", error: "Failed to create fund account" });
            return;
        }
        let finalStatus;
        let validationId = null;
        if (type === "vpa") {
            finalStatus = "verified";
        }
        else if (type === "card") {
            finalStatus = "created";
        }
        else if (type === "bank_account" && razorpayConfig.xLiteCustomerId) {
            try {
                const validationRes = (await razorpayFetch(razorpayConfig.keyId, razorpayConfig.keySecret, "/fund_accounts/validations", {
                    method: "POST",
                    body: {
                        account_number: razorpayConfig.xLiteCustomerId,
                        fund_account: { id: fundAccountId },
                        amount: 100,
                        currency: "INR",
                        notes: { uid, accountId },
                    },
                }));
                validationId = validationRes.id || null;
                const vStatus = validationRes.status || "created";
                finalStatus = vStatus === "completed" ? "verified" : vStatus === "failed" ? "failed" : "pending";
            }
            catch (e) {
                functions.logger.warn("Bank account validation failed", { accountId, error: e });
                finalStatus = "created";
            }
        }
        else {
            finalStatus = "created";
        }
        await snap.ref.update(Object.assign(Object.assign({ razorpayFundAccountId: fundAccountId !== null && fundAccountId !== void 0 ? fundAccountId : admin.firestore.FieldValue.delete(), razorpayContactId: contactId, bankName: bankName || admin.firestore.FieldValue.delete(), status: finalStatus }, (validationId && { razorpayValidationId: validationId })), { validatedAt: admin.firestore.FieldValue.serverTimestamp() }));
        functions.logger.info("Settlement account processed", { uid, accountId, status: finalStatus });
    }
    catch (e) {
        functions.logger.error("Settlement validation error", { uid, accountId, error: e });
        await snap.ref.update({ status: "failed", error: String(e) });
    }
});
/** Callable: validate a settlement account (manual trigger). */
exports.validateSettlementAccount = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    }
    const uid = context.auth.uid;
    const accountId = data === null || data === void 0 ? void 0 : data.accountId;
    if (!accountId) {
        throw new functions.https.HttpsError("invalid-argument", "accountId required");
    }
    const razorpayConfig = (0, config_1.getExternalConfig)().razorpay;
    if (!razorpayConfig) {
        throw new functions.https.HttpsError("failed-precondition", "Razorpay is not configured. Set razorpay.key_id and razorpay.key_secret.");
    }
    const accountRef = getDb().collection("users").doc(uid).collection("settlement_accounts").doc(accountId);
    const accountSnap = await accountRef.get();
    if (!accountSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Settlement account not found");
    }
    const accountData = accountSnap.data();
    const type = accountData.type;
    const status = accountData.status;
    if (status === "verified") {
        return { ok: true, status: "verified", message: "Already verified" };
    }
    // If pending with validation ID, fetch status from Razorpay
    const existingValidationId = accountData.razorpayValidationId;
    if (status === "pending" && existingValidationId && razorpayConfig) {
        try {
            const validationRes = (await razorpayFetch(razorpayConfig.keyId, razorpayConfig.keySecret, `/fund_accounts/validations/${existingValidationId}`, { method: "GET" }));
            const vStatus = validationRes.status || "created";
            const newStatus = vStatus === "completed" ? "verified" : vStatus === "failed" ? "failed" : "pending";
            if (newStatus !== status) {
                await accountRef.update({
                    status: newStatus,
                    validatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            return {
                ok: true,
                status: newStatus,
                message: newStatus === "verified"
                    ? "Account verified successfully"
                    : newStatus === "failed"
                        ? "Validation failed"
                        : "Validation still in progress. Try again in a minute.",
            };
        }
        catch (e) {
            functions.logger.warn("Fetch validation status failed", { accountId, error: e });
        }
    }
    const userSnap = await getDb().collection("users").doc(uid).get();
    const userData = userSnap.data() || {};
    const profile = userData.profile || {};
    const name = profile.name || userData.name || "User";
    const email = profile.email || userData.email || `${uid}@dgyardconnect.local`;
    const phone = profile.phone || userData.phone || "+919999999999";
    let contactId = userData.razorpayContactId || null;
    if (!contactId) {
        const contactRes = (await razorpayFetch(razorpayConfig.keyId, razorpayConfig.keySecret, "/contacts", {
            method: "POST",
            body: {
                name,
                email,
                contact: phone,
                type: "customer",
            },
        }));
        contactId = contactRes.id || null;
        if (contactId) {
            await getDb().collection("users").doc(uid).set({ razorpayContactId: contactId }, { merge: true });
        }
    }
    if (!contactId) {
        throw new functions.https.HttpsError("internal", "Failed to create Razorpay contact");
    }
    let fundAccountId = null;
    let bankName = "";
    if (type === "bank_account") {
        const bankRes = (await razorpayFetch(razorpayConfig.keyId, razorpayConfig.keySecret, "/fund_accounts", {
            method: "POST",
            body: {
                contact_id: contactId,
                account_type: "bank_account",
                bank_account: {
                    name: accountData.accountHolderName || name,
                    ifsc: accountData.ifsc || "",
                    account_number: accountData.accountNumber || "",
                },
            },
        }));
        fundAccountId = bankRes.id || null;
        bankName = ((_a = bankRes.bank_account) === null || _a === void 0 ? void 0 : _a.bank_name) || "";
    }
    else if (type === "vpa") {
        const vpaRes = (await razorpayFetch(razorpayConfig.keyId, razorpayConfig.keySecret, "/fund_accounts", {
            method: "POST",
            body: {
                contact_id: contactId,
                account_type: "vpa",
                vpa: {
                    address: accountData.vpa || "",
                },
            },
        }));
        fundAccountId = vpaRes.id || null;
    }
    else if (type === "card") {
        fundAccountId = null;
    }
    if (!fundAccountId && type !== "card") {
        throw new functions.https.HttpsError("internal", "Failed to create fund account");
    }
    let finalStatus;
    let newValidationId = null;
    if (type === "vpa") {
        finalStatus = "verified";
    }
    else if (type === "card") {
        finalStatus = "created";
    }
    else if (type === "bank_account" && razorpayConfig.xLiteCustomerId) {
        try {
            const validationRes = (await razorpayFetch(razorpayConfig.keyId, razorpayConfig.keySecret, "/fund_accounts/validations", {
                method: "POST",
                body: {
                    account_number: razorpayConfig.xLiteCustomerId,
                    fund_account: { id: fundAccountId },
                    amount: 100,
                    currency: "INR",
                    notes: { uid, accountId },
                },
            }));
            newValidationId = validationRes.id || null;
            const vStatus = validationRes.status || "created";
            finalStatus = vStatus === "completed" ? "verified" : vStatus === "failed" ? "failed" : "pending";
        }
        catch (e) {
            functions.logger.warn("Bank account validation failed", { accountId, error: e });
            finalStatus = "created";
        }
    }
    else {
        finalStatus = "created";
    }
    const updateData = {
        razorpayFundAccountId: fundAccountId !== null && fundAccountId !== void 0 ? fundAccountId : admin.firestore.FieldValue.delete(),
        razorpayContactId: contactId,
        bankName: bankName || admin.firestore.FieldValue.delete(),
        status: finalStatus,
        validatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (newValidationId)
        updateData.razorpayValidationId = newValidationId;
    await accountRef.update(updateData);
    const message = finalStatus === "verified"
        ? "Account verified successfully"
        : finalStatus === "pending"
            ? "Validation in progress (₹1 transferred). Will update when bank confirms."
            : "Account added";
    return {
        ok: true,
        status: finalStatus,
        fundAccountId,
        message,
    };
});
//# sourceMappingURL=settlement.js.map