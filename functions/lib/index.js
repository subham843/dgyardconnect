"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.payCancellationCompensation = exports.resolveJobDispute = exports.otpFailuresCleanup = exports.warrantyClaimDeadlineCheck = exports.aggregateDailyFinancialReport = exports.dealerApprovalAutoRelease = exports.jobExpirationCheck = exports.technicianRejectionCooldownReset = exports.requestMoreBids = exports.jobNotificationBatchEscalation = exports.adminApproveEscrow = exports.onWarrantyServiceJobCompleted = exports.onJobDisputeCreated = exports.warrantyUnlock = exports.adminBackfillServiceRecordWarranty = exports.getServiceRecordVerification = exports.onDealerConfirm = exports.lockJobPayment = exports.createRazorpayOrder = exports.respondToWarrantyClaim = exports.onJobRejected = exports.onJobUpdated = exports.ensureUserCode = exports.onUserApprovalChanged = exports.onChatMessageCreated = exports.warrantyClaimReminder = exports.onWarrantyClaimCreated = exports.onJobCreated = exports.adminResetUserJobLimitUsage = exports.adminSetUserJobLimitOverride = exports.adminSetJobLimitConfig = exports.acceptJobWithLimit = exports.createJobWithLimit = exports.previewTechnicianAcceptLimit = exports.previewDealerJobLimit = exports.onUserMarketplaceSellerSuspended = exports.marketplaceSellerRespondToOrderRequest = exports.marketplaceRazorpayWebhook = exports.marketplaceVerifyRazorpayPayment = exports.marketplaceCreateRazorpayCheckout = exports.marketplacePlaceCodOrder = exports.marketplaceCheckCodEligibility = exports.getDealerCountInArea = exports.getTechnicianCountInArea = exports.validateSettlementAccount = exports.onSettlementAccountCreated = exports.kycLivenessVerify = exports.kycPanVerify = exports.kycAadhaarVerifyOtp = exports.kycAadhaarGenerateOtp = void 0;
exports.sendAdminPush = exports.setAppRuntimeConfig = exports.setAppUpdateConfig = exports.initMaskedCall = exports.twimlMaskedCall = exports.requestWithdrawal = exports.submitCustomerRating = exports.verifyOtp = exports.sendOtp = exports.removeTechnicianStrike = exports.addTechnicianStrike = exports.resolveFraudAlert = exports.reactivateUser = exports.suspendUser = exports.applyTechnicianPenalty = exports.applyDealerPenalty = exports.recordJobCancellation = exports.recordCustomerFeedback = exports.recalculateTechnicianLevel = exports.adjustTrustScore = exports.onRatingSubmitted = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const crypto = require("crypto");
const reputation_1 = require("./reputation");
const config_1 = require("./config");
const jobMatching_1 = require("./jobMatching");
const strikes_1 = require("./strikes");
const audit_1 = require("./audit");
var kyc_1 = require("./kyc");
Object.defineProperty(exports, "kycAadhaarGenerateOtp", { enumerable: true, get: function () { return kyc_1.kycAadhaarGenerateOtp; } });
Object.defineProperty(exports, "kycAadhaarVerifyOtp", { enumerable: true, get: function () { return kyc_1.kycAadhaarVerifyOtp; } });
Object.defineProperty(exports, "kycPanVerify", { enumerable: true, get: function () { return kyc_1.kycPanVerify; } });
Object.defineProperty(exports, "kycLivenessVerify", { enumerable: true, get: function () { return kyc_1.kycLivenessVerify; } });
var settlement_1 = require("./settlement");
Object.defineProperty(exports, "onSettlementAccountCreated", { enumerable: true, get: function () { return settlement_1.onSettlementAccountCreated; } });
Object.defineProperty(exports, "validateSettlementAccount", { enumerable: true, get: function () { return settlement_1.validateSettlementAccount; } });
var areaCount_1 = require("./areaCount");
Object.defineProperty(exports, "getTechnicianCountInArea", { enumerable: true, get: function () { return areaCount_1.getTechnicianCountInArea; } });
Object.defineProperty(exports, "getDealerCountInArea", { enumerable: true, get: function () { return areaCount_1.getDealerCountInArea; } });
var marketplacePayments_1 = require("./marketplacePayments");
Object.defineProperty(exports, "marketplaceCheckCodEligibility", { enumerable: true, get: function () { return marketplacePayments_1.marketplaceCheckCodEligibility; } });
Object.defineProperty(exports, "marketplacePlaceCodOrder", { enumerable: true, get: function () { return marketplacePayments_1.marketplacePlaceCodOrder; } });
Object.defineProperty(exports, "marketplaceCreateRazorpayCheckout", { enumerable: true, get: function () { return marketplacePayments_1.marketplaceCreateRazorpayCheckout; } });
Object.defineProperty(exports, "marketplaceVerifyRazorpayPayment", { enumerable: true, get: function () { return marketplacePayments_1.marketplaceVerifyRazorpayPayment; } });
Object.defineProperty(exports, "marketplaceRazorpayWebhook", { enumerable: true, get: function () { return marketplacePayments_1.marketplaceRazorpayWebhook; } });
Object.defineProperty(exports, "marketplaceSellerRespondToOrderRequest", { enumerable: true, get: function () { return marketplacePayments_1.marketplaceSellerRespondToOrderRequest; } });
var marketplaceTriggers_1 = require("./marketplaceTriggers");
Object.defineProperty(exports, "onUserMarketplaceSellerSuspended", { enumerable: true, get: function () { return marketplaceTriggers_1.onUserMarketplaceSellerSuspended; } });
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
function toNumber(v, fallback = 0) {
    if (typeof v === "number" && !Number.isNaN(v))
        return v;
    if (typeof v === "string") {
        const n = parseFloat(v);
        if (!Number.isNaN(n))
            return n;
    }
    return fallback;
}
async function getJobLimitConfig() {
    var _a;
    const snap = await db.collection("config").doc("job_limit_config").get();
    const d = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
    return {
        defaultDealerPostFreeLimit: Math.max(0, Math.floor(toNumber(d.defaultDealerPostFreeLimit, 10))),
        defaultTechnicianAcceptFreeLimit: Math.max(0, Math.floor(toNumber(d.defaultTechnicianAcceptFreeLimit, 15))),
        technicianAcceptanceChargeType: d.technicianAcceptanceChargeType || "fixed",
        technicianAcceptanceChargeValue: Math.max(0, toNumber(d.technicianAcceptanceChargeValue, 0)),
    };
}
async function getPlatformChargeConfig() {
    var _a;
    const snap = await db.collection("platform_charge_config").limit(1).get();
    if (snap.empty)
        return { type: "percent", value: 0 };
    const d = (_a = snap.docs[0].data()) !== null && _a !== void 0 ? _a : {};
    const type = d.type === "fixed" ? "fixed" : "percent";
    const value = Math.max(0, toNumber(d.value, 0));
    return { type, value };
}
function computeCharge(amount, cfg) {
    if (amount <= 0)
        return 0;
    const raw = cfg.type === "percent" ? (amount * cfg.value) / 100 : cfg.value;
    return Math.max(0, Math.round(raw * 100) / 100);
}
function assertAuthed(context) {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    return context.auth.uid;
}
async function assertRole(uid, role) {
    var _a;
    const snap = await db.collection("users").doc(uid).get();
    const r = ((_a = snap.data()) === null || _a === void 0 ? void 0 : _a.role) || "";
    if (r !== role)
        throw new functions.https.HttpsError("permission-denied", "Not allowed");
    return snap;
}
function getUserFreeLimit(userData, role, cfg) {
    var _a;
    const overrides = (_a = userData.jobLimitOverrides) !== null && _a !== void 0 ? _a : {};
    if (role === "dealer") {
        const o = overrides.dealerPostFreeLimit;
        if (o != null)
            return Math.max(0, Math.floor(toNumber(o, cfg.defaultDealerPostFreeLimit)));
        return cfg.defaultDealerPostFreeLimit;
    }
    const o = overrides.technicianAcceptFreeLimit;
    if (o != null)
        return Math.max(0, Math.floor(toNumber(o, cfg.defaultTechnicianAcceptFreeLimit)));
    return cfg.defaultTechnicianAcceptFreeLimit;
}
function getUsedCount(userData, role) {
    var _a;
    const usage = (_a = userData.jobLimitUsage) !== null && _a !== void 0 ? _a : {};
    const v = role === "dealer" ? usage.dealerPosted : usage.technicianAccepted;
    return Math.max(0, Math.floor(toNumber(v, 0)));
}
function usagePatch(role, usedNext) {
    return role === "dealer"
        ? { "jobLimitUsage.dealerPosted": usedNext, "jobLimitUsage.dealerUpdatedAt": admin.firestore.FieldValue.serverTimestamp() }
        : { "jobLimitUsage.technicianAccepted": usedNext, "jobLimitUsage.technicianUpdatedAt": admin.firestore.FieldValue.serverTimestamp() };
}
exports.previewDealerJobLimit = functions.https.onCall(async (data, context) => {
    var _a;
    const uid = assertAuthed(context);
    await assertRole(uid, "dealer");
    const amount = toNumber(data === null || data === void 0 ? void 0 : data.amount, 0);
    const cfg = await getJobLimitConfig();
    const platformCfg = await getPlatformChargeConfig();
    const userSnap = await db.collection("users").doc(uid).get();
    const userData = (_a = userSnap.data()) !== null && _a !== void 0 ? _a : {};
    const limit = getUserFreeLimit(userData, "dealer", cfg);
    const used = getUsedCount(userData, "dealer");
    const remaining = Math.max(0, limit - used);
    const chargeApplies = used >= limit;
    const platformChargeAmount = chargeApplies ? computeCharge(amount, platformCfg) : 0;
    return { ok: true, limit, used, remaining, chargeApplies, platformChargeType: platformCfg.type, platformChargeValue: platformCfg.value, platformChargeAmount };
});
exports.previewTechnicianAcceptLimit = functions.https.onCall(async (_data, context) => {
    var _a;
    const uid = assertAuthed(context);
    await assertRole(uid, "technician");
    const cfg = await getJobLimitConfig();
    const userSnap = await db.collection("users").doc(uid).get();
    const userData = (_a = userSnap.data()) !== null && _a !== void 0 ? _a : {};
    const limit = getUserFreeLimit(userData, "technician", cfg);
    const used = getUsedCount(userData, "technician");
    const remaining = Math.max(0, limit - used);
    const chargeApplies = used >= limit;
    const fee = chargeApplies ? computeCharge(1, { type: cfg.technicianAcceptanceChargeType, value: cfg.technicianAcceptanceChargeValue }) : 0;
    return { ok: true, limit, used, remaining, chargeApplies, acceptanceFeeType: cfg.technicianAcceptanceChargeType, acceptanceFeeValue: cfg.technicianAcceptanceChargeValue, acceptanceFeeAmount: fee };
});
exports.createJobWithLimit = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    const dealerId = assertAuthed(context);
    await assertRole(dealerId, "dealer");
    const job = (_a = data === null || data === void 0 ? void 0 : data.job) !== null && _a !== void 0 ? _a : null;
    if (!job)
        throw new functions.https.HttpsError("invalid-argument", "job required");
    const amount = toNumber((_c = (_b = job.dealerRate) !== null && _b !== void 0 ? _b : job.fixedRate) !== null && _c !== void 0 ? _c : 0, 0);
    const cfg = await getJobLimitConfig();
    const platformCfg = await getPlatformChargeConfig();
    // Callable payload must be JSON-serializable. Normalize coordinates into GeoPoints server-side.
    const jobLatRaw = job.jobLat;
    const jobLngRaw = job.jobLng;
    const pickupLatRaw = job.pickupLat;
    const pickupLngRaw = job.pickupLng;
    const jobLat = typeof jobLatRaw === "number" ? jobLatRaw : (typeof jobLatRaw === "string" ? parseFloat(jobLatRaw) : NaN);
    const jobLng = typeof jobLngRaw === "number" ? jobLngRaw : (typeof jobLngRaw === "string" ? parseFloat(jobLngRaw) : NaN);
    const pickupLat = typeof pickupLatRaw === "number" ? pickupLatRaw : (typeof pickupLatRaw === "string" ? parseFloat(pickupLatRaw) : NaN);
    const pickupLng = typeof pickupLngRaw === "number" ? pickupLngRaw : (typeof pickupLngRaw === "string" ? parseFloat(pickupLngRaw) : NaN);
    if (!Number.isNaN(jobLat) && !Number.isNaN(jobLng)) {
        job.location = new admin.firestore.GeoPoint(jobLat, jobLng);
    }
    if (!Number.isNaN(pickupLat) && !Number.isNaN(pickupLng)) {
        job.pickupLocation = new admin.firestore.GeoPoint(pickupLat, pickupLng);
    }
    const res = await db.runTransaction(async (tx) => {
        var _a;
        const userRef = db.collection("users").doc(dealerId);
        const userSnap = await tx.get(userRef);
        const userData = (_a = userSnap.data()) !== null && _a !== void 0 ? _a : {};
        const limit = getUserFreeLimit(userData, "dealer", cfg);
        const used = getUsedCount(userData, "dealer");
        const chargeApplies = used >= limit;
        const platformChargeAmount = chargeApplies ? computeCharge(amount, platformCfg) : 0;
        const usedNext = used + 1;
        tx.set(userRef, usagePatch("dealer", usedNext), { merge: true });
        const jobRef = db.collection("jobs").doc();
        tx.set(jobRef, Object.assign(Object.assign({}, job), { dealerId, jobCode: shortCode("DGY", jobRef.id), status: job.status || "posted", platformChargeAmount, platformChargeMeta: {
                applied: chargeApplies,
                type: platformCfg.type,
                value: platformCfg.value,
                computedOn: admin.firestore.FieldValue.serverTimestamp(),
            }, createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp() }), { merge: false });
        return { jobId: jobRef.id, limit, used: usedNext, remaining: Math.max(0, limit - usedNext), chargeApplies, platformChargeAmount, platformChargeType: platformCfg.type, platformChargeValue: platformCfg.value };
    });
    return Object.assign({ ok: true }, res);
});
exports.acceptJobWithLimit = functions.https.onCall(async (data, context) => {
    const technicianId = assertAuthed(context);
    await assertRole(technicianId, "technician");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    if (!jobId)
        throw new functions.https.HttpsError("invalid-argument", "jobId required");
    const agreedAmount = toNumber(data === null || data === void 0 ? void 0 : data.agreedAmount, 0);
    if (agreedAmount <= 0)
        throw new functions.https.HttpsError("invalid-argument", "agreedAmount must be > 0");
    const cfg = await getJobLimitConfig();
    const platformCfg = await getPlatformChargeConfig();
    const out = await db.runTransaction(async (tx) => {
        var _a, _b, _c;
        const jobRef = db.collection("jobs").doc(jobId);
        const jobSnap = await tx.get(jobRef);
        if (!jobSnap.exists)
            throw new functions.https.HttpsError("not-found", "Job not found");
        const job = (_a = jobSnap.data()) !== null && _a !== void 0 ? _a : {};
        if (job.technicianId)
            throw new functions.https.HttpsError("failed-precondition", "Job already assigned");
        const status = job.status || "posted";
        if (status !== "posted")
            throw new functions.https.HttpsError("failed-precondition", "Job not available");
        const userRef = db.collection("users").doc(technicianId);
        const userSnap = await tx.get(userRef);
        const userData = (_b = userSnap.data()) !== null && _b !== void 0 ? _b : {};
        const limit = getUserFreeLimit(userData, "technician", cfg);
        const used = getUsedCount(userData, "technician");
        const chargeApplies = used >= limit;
        const acceptanceFeeAmount = chargeApplies
            ? computeCharge(1, { type: cfg.technicianAcceptanceChargeType, value: cfg.technicianAcceptanceChargeValue })
            : 0;
        const usedNext = used + 1;
        tx.set(userRef, usagePatch("technician", usedNext), { merge: true });
        if (acceptanceFeeAmount > 0) {
            const walletRef = db.collection("wallets").doc(technicianId);
            const walletSnap = await tx.get(walletRef);
            const wallet = (_c = walletSnap.data()) !== null && _c !== void 0 ? _c : {};
            const available = toNumber(wallet.availableBalance, 0);
            if (available < acceptanceFeeAmount) {
                throw new functions.https.HttpsError("failed-precondition", "Insufficient wallet balance for acceptance fee");
            }
            tx.set(walletRef, { availableBalance: available - acceptanceFeeAmount }, { merge: true });
            const feeRef = db.collection("technician_acceptance_fees").doc();
            tx.set(feeRef, {
                technicianId,
                jobId,
                feeAmount: acceptanceFeeAmount,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: false });
        }
        // Apply platform charge on the job (commission) only when dealer free limit is exhausted (already computed on create),
        // but ensure it exists (legacy jobs may not).
        const platformChargeAmount = toNumber(job.platformChargeAmount, 0);
        const fallbackPlatformCharge = platformChargeAmount > 0 ? platformChargeAmount : computeCharge(agreedAmount, platformCfg);
        tx.update(jobRef, {
            technicianId,
            status: "payment_pending",
            agreedAmount,
            technicianPayoutAmount: agreedAmount,
            offeredToTechnicianIds: admin.firestore.FieldValue.arrayUnion(technicianId),
            // If job doesn't have a computed platform charge (legacy), compute now.
            platformChargeAmount: platformChargeAmount > 0 ? platformChargeAmount : fallbackPlatformCharge,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { limit, used: usedNext, remaining: Math.max(0, limit - usedNext), chargeApplies, acceptanceFeeAmount };
    });
    return Object.assign({ ok: true }, out);
});
exports.adminSetJobLimitConfig = functions.https.onCall(async (data, context) => {
    const uid = assertAuthed(context);
    await assertRole(uid, "superadmin");
    const cfg = {
        defaultDealerPostFreeLimit: Math.max(0, Math.floor(toNumber(data === null || data === void 0 ? void 0 : data.defaultDealerPostFreeLimit, 10))),
        defaultTechnicianAcceptFreeLimit: Math.max(0, Math.floor(toNumber(data === null || data === void 0 ? void 0 : data.defaultTechnicianAcceptFreeLimit, 15))),
        technicianAcceptanceChargeType: (data === null || data === void 0 ? void 0 : data.technicianAcceptanceChargeType) || "fixed",
        technicianAcceptanceChargeValue: Math.max(0, toNumber(data === null || data === void 0 ? void 0 : data.technicianAcceptanceChargeValue, 0)),
    };
    await db.collection("config").doc("job_limit_config").set(cfg, { merge: true });
    return { ok: true };
});
exports.adminSetUserJobLimitOverride = functions.https.onCall(async (data, context) => {
    const uid = assertAuthed(context);
    await assertRole(uid, "superadmin");
    const userId = data === null || data === void 0 ? void 0 : data.userId;
    const dealerPostFreeLimit = data === null || data === void 0 ? void 0 : data.dealerPostFreeLimit;
    const technicianAcceptFreeLimit = data === null || data === void 0 ? void 0 : data.technicianAcceptFreeLimit;
    if (!userId)
        throw new functions.https.HttpsError("invalid-argument", "userId required");
    const patch = {};
    if (dealerPostFreeLimit != null)
        patch["jobLimitOverrides.dealerPostFreeLimit"] = Math.max(0, Math.floor(toNumber(dealerPostFreeLimit, 0)));
    if (technicianAcceptFreeLimit != null)
        patch["jobLimitOverrides.technicianAcceptFreeLimit"] = Math.max(0, Math.floor(toNumber(technicianAcceptFreeLimit, 0)));
    patch["jobLimitOverrides.updatedAt"] = admin.firestore.FieldValue.serverTimestamp();
    await db.collection("users").doc(userId).set(patch, { merge: true });
    return { ok: true };
});
exports.adminResetUserJobLimitUsage = functions.https.onCall(async (data, context) => {
    const uid = assertAuthed(context);
    await assertRole(uid, "superadmin");
    const userId = data === null || data === void 0 ? void 0 : data.userId;
    const target = (data === null || data === void 0 ? void 0 : data.target) || "both"; // dealer | technician | both
    if (!userId)
        throw new functions.https.HttpsError("invalid-argument", "userId required");
    const patch = { "jobLimitUsage.resetAt": admin.firestore.FieldValue.serverTimestamp() };
    if (target === "dealer" || target === "both")
        patch["jobLimitUsage.dealerPosted"] = 0;
    if (target === "technician" || target === "both")
        patch["jobLimitUsage.technicianAccepted"] = 0;
    await db.collection("users").doc(userId).set(patch, { merge: true });
    return { ok: true };
});
async function ensureFraudAlert(params) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const type = params.type;
    const userId = (_a = params.userId) !== null && _a !== void 0 ? _a : null;
    const windowStart = (_b = params.windowStart) !== null && _b !== void 0 ? _b : null;
    let q = db
        .collection("fraud_alerts")
        .where("type", "==", type);
    if (userId)
        q = q.where("userId", "==", userId);
    if (windowStart)
        q = q.where("windowStart", "==", windowStart);
    const existing = await q.limit(1).get();
    if (!existing.empty)
        return;
    await db.collection("fraud_alerts").add({
        type,
        status: (_c = params.status) !== null && _c !== void 0 ? _c : "open",
        riskScore: (_d = params.riskScore) !== null && _d !== void 0 ? _d : 60,
        jobId: (_e = params.jobId) !== null && _e !== void 0 ? _e : null,
        userId,
        dealerId: (_f = params.dealerId) !== null && _f !== void 0 ? _f : null,
        technicianId: (_g = params.technicianId) !== null && _g !== void 0 ? _g : null,
        reason: params.reason,
        signals: (_h = params.signals) !== null && _h !== void 0 ? _h : {},
        windowStart,
        windowEnd: (_j = params.windowEnd) !== null && _j !== void 0 ? _j : null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
async function countTrustEvents(params) {
    const snap = await db
        .collection("trust_score_history")
        .where("userId", "==", params.userId)
        .where("reason", "==", params.reason)
        .where("eventType", "==", params.eventType)
        .where("createdAt", ">", admin.firestore.Timestamp.fromDate(params.since))
        .get();
    return snap.size;
}
function randomToken() {
    return crypto.randomBytes(24).toString("hex");
}
function shortCode(prefix, seedId) {
    var _a;
    const d = new Date();
    const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    const dd = String(d.getUTCDate()).padStart(2, "0");
    const mmm = (_a = months[d.getUTCMonth()]) !== null && _a !== void 0 ? _a : "UNK";
    const yy = String(d.getUTCFullYear()).slice(-2);
    const token = (seedId || "").slice(-4).toUpperCase().padEnd(4, "X");
    return `${prefix}-${dd}${mmm}${yy}-${token}`;
}
/** Apply trust score delta, update user.reputationLevel, and append to trust_score_history. */
async function updateTrustScore(userId, role, delta, reason, eventType, jobId, adminId) {
    var _a, _b;
    const userRef = db.collection("users").doc(userId);
    const snap = await userRef.get();
    const data = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
    const current = (_b = data.trustScore) !== null && _b !== void 0 ? _b : reputation_1.DEFAULT_TRUST_SCORE;
    const newScore = (0, reputation_1.applyTrustScoreDelta)(current, delta);
    const reputationLevel = (0, reputation_1.getReputationLevel)(newScore);
    const update = { trustScore: newScore, reputationLevel };
    if (role === "technician" && data.manual_level_override !== true) {
        update.technicianLevel = (0, reputation_1.getTechnicianLevelFromTrustScore)(newScore);
    }
    await userRef.set(update, { merge: true });
    await db.collection("trust_score_history").add({
        userId,
        role,
        delta,
        reason,
        eventType,
        jobId: jobId !== null && jobId !== void 0 ? jobId : null,
        adminId: adminId !== null && adminId !== void 0 ? adminId : null,
        previousScore: current,
        newScore,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    functions.logger.info("Trust score updated", { userId, role, delta, reason, newScore });
}
function getJobNotificationContent(type) {
    switch (type) {
        case "job_no_longer_available":
            return { title: "Job no longer available", body: "This job has been assigned to another technician." };
        case "job_expired":
            return { title: "Job expired", body: "No technician accepted in time. You can repost the job." };
        case "job_request":
            return { title: "New job request", body: "You have a new job. Tap to accept or reject." };
        case "technician_accepted":
            return { title: "Technician accepted", body: "A technician accepted your job. Tap to view and respond." };
        case "technician_bid":
            return { title: "Technician bid", body: "You have a new bid. Tap to accept, counter, or reject." };
        case "technician_rejected_offer":
            return {
                title: "Technician rejected your offer",
                body: "Search for other technician for your job. Next technician has been notified.",
            };
        case "dealer_counter":
            return { title: "Dealer counter offer", body: "Dealer sent a counter offer. Tap to respond." };
        case "dealer_accept_bid":
            return { title: "Bid accepted", body: "Your bid was accepted. Tap to view job." };
        case "payment_ready":
            return { title: "Proceed to payment", body: "Rate agreed. Tap to complete payment." };
        case "payment_received":
            return { title: "Payment received", body: "Your job is started now. Tap to view." };
        case "material_list":
            return { title: "Material list updated", body: "Technician provided material list. Tap to review." };
        case "proof_uploaded":
            return { title: "Proof uploaded", body: "Technician uploaded a proof photo. Tap to view." };
        case "job_pending_confirm":
            return { title: "Job complete – confirm", body: "Technician completed the job. Tap to confirm." };
        case "job_completed":
            return { title: "Job completed", body: "Job has been completed. Tap to view and rate." };
        case "material_return_request":
            return { title: "Material return requested", body: "Technician requested material return. Set handover location." };
        case "material_return_location_set":
            return { title: "Handover location set", body: "Material handover location is set. Navigate to complete return." };
        case "warranty_claim":
            return { title: "Warranty claim", body: "A dealer raised a warranty claim – visit required. Respond within 24 hours." };
        default:
            return { title: "Job update", body: "You have a job update. Tap to view." };
    }
}
/** Send FCM for warranty claim to technician (payload includes claimId for app navigation). */
async function sendWarrantyClaimToTechnician(fcmToken, claimId, jobId) {
    if (!fcmToken)
        return false;
    try {
        const { title, body } = getJobNotificationContent("warranty_claim");
        await messaging.send({
            token: fcmToken,
            data: { claimId, jobId, type: "warranty_claim", target: "technician", title, body },
            android: { priority: "high" },
            apns: { payload: { aps: { "content-available": 1 } } },
        });
        return true;
    }
    catch (e) {
        functions.logger.warn("FCM warranty claim send failed", { claimId, error: e });
        return false;
    }
}
function getJobRequestBody(job) {
    const materialOpt = job.materialOption;
    if (!materialOpt || materialOpt === "no_pickup") {
        return "You have a new job. Tap to accept or reject.";
    }
    if (materialOpt === "pickup") {
        const addr = job.pickupAddress || "";
        const list = job.pickupMaterialList || [];
        const items = list.map((i) => { var _a; return `${i.itemName || "Item"} x${(_a = i.qty) !== null && _a !== void 0 ? _a : 1}`; }).join(", ");
        const parts = addr.split(",").map((s) => s.trim()).filter((s) => s.length > 0);
        const area = parts.length > 2 ? parts.slice(-2).join(", ") : addr;
        return `Pickup: ${area}. Items: ${items || "—"}. Tap to accept or reject.`;
    }
    if (materialOpt === "material_by_technician") {
        return "Technician arranges materials. Tap to accept or reject.";
    }
    return "You have a new job. Tap to accept or reject.";
}
async function sendFcmToTechnician(fcmToken, jobId, type = "job_request", job) {
    if (!fcmToken)
        return false;
    try {
        let title;
        let body;
        if (type === "job_request" && job) {
            title = "New job request";
            body = getJobRequestBody(job);
        }
        else {
            const content = getJobNotificationContent(type);
            title = content.title;
            body = content.body;
        }
        await messaging.send({
            token: fcmToken,
            notification: { title, body },
            data: { jobId, type, target: "technician", title, body },
            android: { priority: "high" },
            apns: { payload: { aps: { "content-available": 1, alert: { title, body } } } },
        });
        return true;
    }
    catch (e) {
        functions.logger.warn("FCM send failed", { jobId, type, error: e });
        return false;
    }
}
async function sendFcmToDealer(fcmToken, jobId, type) {
    if (!fcmToken)
        return false;
    try {
        const { title, body } = getJobNotificationContent(type);
        await messaging.send({
            token: fcmToken,
            data: { jobId, type, target: "dealer", title, body },
            android: { priority: "high" },
            apns: { payload: { aps: { "content-available": 1 } } },
        });
        return true;
    }
    catch (e) {
        functions.logger.warn("FCM to dealer failed", { jobId, type, error: e });
        return false;
    }
}
/** Send a notification message (title + body) to a user's device. Used for approval/rejection alerts. */
async function sendFcmNotification(fcmToken, title, body, data) {
    if (!fcmToken)
        return false;
    try {
        await messaging.send({
            token: fcmToken,
            notification: { title, body },
            data: data !== null && data !== void 0 ? data : {},
            android: { priority: "high" },
            apns: { payload: { aps: { alert: { title, body }, sound: "default" } } },
        });
        return true;
    }
    catch (e) {
        functions.logger.warn("FCM notification send failed", { title, error: e });
        return false;
    }
}
/** Send chat message notification to recipient. Uses notification payload so it shows when app is closed. */
async function sendChatMessageNotification(recipientUid, jobId, messagePreview, senderRole) {
    const userSnap = await db.collection("users").doc(recipientUid).get();
    if (!userSnap.exists)
        return false;
    const userData = userSnap.data();
    const tokens = getAllFcmTokens(userData !== null && userData !== void 0 ? userData : {});
    if (tokens.length === 0)
        return false;
    const title = senderRole === "dealer" ? "New message from dealer" : "New message from technician";
    const body = messagePreview.length > 80 ? messagePreview.substring(0, 77) + "..." : messagePreview;
    const target = senderRole === "dealer" ? "technician" : "dealer";
    for (const token of tokens) {
        try {
            await messaging.send({
                token,
                notification: { title, body },
                data: {
                    jobId,
                    type: "chat_message",
                    target,
                    title,
                    body,
                },
                android: { priority: "high" },
                apns: { payload: { aps: { alert: { title, body }, sound: "default" } } },
            });
            return true;
        }
        catch (e) {
            functions.logger.warn("Chat FCM failed", { jobId, error: e });
        }
    }
    return false;
}
/** Collect all FCM tokens for a user (fcmTokens array + fcmToken fallback). */
function getAllFcmTokens(data) {
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
/** Duplicate job check: same dealer, same sector/subsector, similar location, within 15 min. */
async function detectDuplicateJob(db, newJob, jobId) {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const dealerId = newJob.dealerId;
    const sectorId = newJob.sectorId;
    const subOptionId = newJob.subOptionId || newJob.sectorSubOptionId || "";
    if (!dealerId || !subOptionId)
        return false;
    const jobLat = (_a = newJob.jobLat) !== null && _a !== void 0 ? _a : (_b = newJob.location) === null || _b === void 0 ? void 0 : _b.latitude;
    const jobLng = (_c = newJob.jobLng) !== null && _c !== void 0 ? _c : (_d = newJob.location) === null || _d === void 0 ? void 0 : _d.longitude;
    const cutoff = new Date();
    cutoff.setMinutes(cutoff.getMinutes() - 15);
    const recentSnap = await db
        .collection("jobs")
        .where("dealerId", "==", dealerId)
        .where("createdAt", ">", admin.firestore.Timestamp.fromDate(cutoff))
        .limit(20)
        .get();
    for (const doc of recentSnap.docs) {
        if (doc.id === jobId)
            continue;
        const d = doc.data();
        const otherSub = d.subOptionId || d.sectorSubOptionId || "";
        if (otherSub !== subOptionId)
            continue;
        if (d.sectorId !== sectorId)
            continue;
        if (jobLat != null && jobLng != null) {
            const otherLat = (_e = d.jobLat) !== null && _e !== void 0 ? _e : (_f = d.location) === null || _f === void 0 ? void 0 : _f.latitude;
            const otherLng = (_g = d.jobLng) !== null && _g !== void 0 ? _g : (_h = d.location) === null || _h === void 0 ? void 0 : _h.longitude;
            if (otherLat != null && otherLng != null) {
                const km = (0, jobMatching_1.haversineKm)(jobLat, jobLng, otherLat, otherLng);
                if (km < 0.5)
                    return true;
            }
        }
        else
            return true;
    }
    return false;
}
exports.onJobCreated = functions.firestore
    .document("jobs/{jobId}")
    .onCreate(async (snap, context) => {
    var _a;
    const job = snap.data();
    if (!job)
        return;
    const jobId = context.params.jobId;
    const isDuplicate = await detectDuplicateJob(db, job, jobId);
    if (isDuplicate) {
        await snap.ref.update({ duplicateJobFlag: true });
        functions.logger.info("Duplicate job flagged", { jobId });
        // Create a fraud alert entry for admin review queue (idempotent by jobId+type).
        try {
            const dealerId = job.dealerId || null;
            const sectorId = job.sectorId || null;
            const subOptionId = job.subOptionId || job.sectorSubOptionId || null;
            const existing = await db
                .collection("fraud_alerts")
                .where("type", "==", "duplicate_job")
                .where("jobId", "==", jobId)
                .limit(1)
                .get();
            if (existing.empty) {
                await db.collection("fraud_alerts").add({
                    type: "duplicate_job",
                    status: "open",
                    riskScore: 65,
                    jobId,
                    userId: dealerId,
                    dealerId,
                    sectorId,
                    subOptionId,
                    reason: "Similar job posted by same dealer within 15 minutes in nearby location.",
                    signals: {
                        windowMinutes: 15,
                        distanceKmThreshold: 0.5,
                    },
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        }
        catch (e) {
            functions.logger.warn("Failed to create fraud alert (duplicate_job)", {
                jobId,
                error: e,
            });
        }
    }
    const rollIds = await (0, jobMatching_1.getEligibleTechnicianIds)(db, job, []);
    const batchSize = (0, jobMatching_1.getBatchSize)(job);
    const firstBatch = rollIds.slice(0, batchSize);
    const now = admin.firestore.FieldValue.serverTimestamp();
    await snap.ref.update(Object.assign({ rollTechnicianIds: rollIds, offeredToTechnicianIds: [], notificationRound: 1, lastNotifiedTechnicianIds: firstBatch, lastNotificationBatchAt: now, techniciansNotifiedCount: firstBatch.length, techniciansRejectedCount: 0, bidsReceivedCount: 0, bidRound: 1 }, (isDuplicate ? { duplicateJobFlag: true } : {})));
    const jobWithRoll = Object.assign(Object.assign({}, job), { rollTechnicianIds: rollIds, offeredToTechnicianIds: [] });
    for (const techId of firstBatch) {
        const userSnap = await db.collection("users").doc(techId).get();
        const tokens = getAllFcmTokens((_a = userSnap.data()) !== null && _a !== void 0 ? _a : {});
        for (const token of tokens) {
            await sendFcmToTechnician(token, jobId, "job_request", jobWithRoll);
        }
    }
    functions.logger.info("Job created, smart match FCM sent", {
        jobId,
        rollCount: rollIds.length,
        batchSize: firstBatch.length,
        biddingEnabled: job.biddingEnabled,
    });
});
/** When a warranty claim is created, notify the assigned technician. */
exports.onWarrantyClaimCreated = functions.firestore
    .document("warranty_claims/{claimId}")
    .onCreate(async (snap, context) => {
    var _a;
    const claim = snap.data();
    const claimId = context.params.claimId;
    const technicianId = claim === null || claim === void 0 ? void 0 : claim.technicianId;
    const jobId = claim === null || claim === void 0 ? void 0 : claim.jobId;
    if (!technicianId || !jobId)
        return;
    // Strict admin-controlled escrow: lock escrow immediately on claim creation.
    await lockEscrowForJob({
        jobId,
        reason: "warranty_claim_created",
        claimId,
    });
    await snap.ref.set({
        escrowStatus: "locked_due_to_claim",
        adminApprovalStatus: "pending",
        lockedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await notifyAdmins({
        title: "New warranty claim",
        body: "A warranty claim was raised. Escrow locked. Admin action required.",
        data: { jobId, claimId, type: "admin_new_warranty_claim", target: "admin" },
    });
    const techSnap = await db.collection("users").doc(technicianId).get();
    const tokens = getAllFcmTokens((_a = techSnap.data()) !== null && _a !== void 0 ? _a : {});
    for (const token of tokens) {
        await sendWarrantyClaimToTechnician(token, claimId, jobId);
    }
    functions.logger.info("Warranty claim notification sent to technician", { claimId, technicianId });
});
/** Scheduled: every 60 min – remind technician about pending warranty claim until they respond. */
exports.warrantyClaimReminder = functions.pubsub
    .schedule("every 60 minutes")
    .timeZone("UTC")
    .onRun(async () => {
    var _a;
    const now = admin.firestore.Timestamp.now();
    const claimsSnap = await db
        .collection("warranty_claims")
        .where("claimStatus", "==", "pending")
        .get();
    for (const doc of claimsSnap.docs) {
        const claim = doc.data();
        const deadline = claim.claimResponseDeadline;
        if (deadline && deadline.toMillis() <= now.toMillis())
            continue; // deadline handler will take over
        const lastRemindedAt = claim.lastRemindedAt;
        // Throttle reminders: at most once per 2 hours per claim.
        if (lastRemindedAt && now.toMillis() - lastRemindedAt.toMillis() < 2 * 60 * 60 * 1000)
            continue;
        const technicianId = claim.technicianId;
        const jobId = claim.jobId;
        if (!technicianId || !jobId)
            continue;
        const techSnap = await db.collection("users").doc(technicianId).get();
        const tokens = getAllFcmTokens((_a = techSnap.data()) !== null && _a !== void 0 ? _a : {});
        for (const token of tokens) {
            await sendFcmNotification(token, "Warranty claim pending", "Please accept or reject the warranty claim. Action required.", { jobId, claimId: doc.id, type: "warranty_claim_reminder", target: "technician" });
        }
        await doc.ref.set({ lastRemindedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    }
});
/** When a new chat message is sent, notify the recipient (dealer or technician). */
exports.onChatMessageCreated = functions.firestore
    .document("job_chats/{jobId}/messages/{messageId}")
    .onCreate(async (snap, context) => {
    const msg = snap.data();
    if (!msg)
        return;
    const jobId = context.params.jobId;
    const senderId = msg.senderId;
    const text = msg.text || "";
    if (!senderId || !text.trim())
        return;
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        return;
    const job = jobSnap.data();
    const dealerId = job.dealerId;
    const technicianId = job.technicianId;
    let recipientUid;
    let senderRole;
    if (senderId === dealerId) {
        recipientUid = technicianId;
        senderRole = "dealer";
    }
    else if (senderId === technicianId) {
        recipientUid = dealerId;
        senderRole = "technician";
    }
    else {
        return;
    }
    if (!recipientUid)
        return;
    await sendChatMessageNotification(recipientUid, jobId, text, senderRole);
    functions.logger.info("Chat message notification sent", { jobId, recipientUid, senderRole });
});
/** When Super Admin approves or rejects a dealer/technician, send FCM notification to that user. */
exports.onUserApprovalChanged = functions.firestore
    .document("users/{userId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const userId = context.params.userId;
    const approvedBefore = before === null || before === void 0 ? void 0 : before.approved;
    const approvedAfter = after === null || after === void 0 ? void 0 : after.approved;
    if (approvedBefore === approvedAfter)
        return;
    const role = after === null || after === void 0 ? void 0 : after.role;
    if (role !== "dealer" && role !== "technician")
        return;
    const tokens = getAllFcmTokens(after !== null && after !== void 0 ? after : {});
    if (tokens.length === 0) {
        functions.logger.info("User approval changed but no FCM token", { userId, role });
        return;
    }
    const roleLabel = role === "dealer" ? "Dealer" : "Technician";
    const [title, body, data] = approvedAfter === true
        ? [
            "Profile approved",
            role === "technician"
                ? "Your profile has been approved. You can now go online and accept jobs."
                : "Your profile has been approved. You can now access all features.",
            { type: "approval", approved: "true" },
        ]
        : [
            "Registration not approved",
            "Your registration was not approved. Please contact support for more information.",
            { type: "approval", approved: "false" },
        ];
    for (const token of tokens) {
        await sendFcmNotification(token, title, body, data);
    }
    // When approved: also send SMS and Email if configured
    if (approvedAfter === true) {
        const config = (0, config_1.getExternalConfig)();
        const userData = after !== null && after !== void 0 ? after : {};
        const profile = userData.profile;
        const phone = (profile === null || profile === void 0 ? void 0 : profile.phone) || userData.phone || "";
        const email = userData.email || "";
        if (config.twilio && phone) {
            try {
                const twilio = require("twilio");
                const client = twilio(config.twilio.accountSid, config.twilio.authToken);
                const smsBody = "Your DG Yard Connect profile has been approved. You can now go online and use the app.";
                await client.messages.create({
                    body: smsBody,
                    from: config.twilio.phoneNumber,
                    to: phone.startsWith("+") ? phone : `+91${phone}`,
                });
                functions.logger.info("Approval SMS sent", { userId });
            }
            catch (e) {
                functions.logger.warn("Approval SMS failed", { userId, error: e });
            }
        }
        if (config.sendgrid && email) {
            try {
                const sgMail = require("@sendgrid/mail");
                sgMail.setApiKey(config.sendgrid.apiKey);
                const emailBody = "Your DG Yard Connect profile has been approved. You can now go online and use all features.";
                await sgMail.send({
                    to: email,
                    from: config.sendgrid.fromEmail,
                    subject: "DG Yard Connect – Profile approved",
                    text: emailBody,
                });
                functions.logger.info("Approval email sent", { userId });
            }
            catch (e) {
                functions.logger.warn("Approval email failed", { userId, error: e });
            }
        }
    }
    functions.logger.info(approvedAfter ? "Approval notification sent" : "Rejection notification sent", { userId, role: roleLabel, tokenCount: tokens.length });
});
/** Ensure every user doc has a short readable userCode for admin/UI (backfills legacy users). */
exports.ensureUserCode = functions.firestore
    .document("users/{userId}")
    .onWrite(async (change, context) => {
    var _a, _b;
    if (!change.after.exists)
        return;
    const after = (_a = change.after.data()) !== null && _a !== void 0 ? _a : {};
    if ((_b = after.userCode) === null || _b === void 0 ? void 0 : _b.trim())
        return;
    const userId = context.params.userId;
    await change.after.ref.set({ userCode: shortCode("DGYU", userId) }, { merge: true });
});
/** On job update: send FCM to dealer or technician based on what changed. */
exports.onJobUpdated = functions.firestore
    .document("jobs/{jobId}")
    .onUpdate(async (change, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y, _z, _0, _1, _2, _3, _4;
    const before = change.before.data();
    const after = change.after.data();
    const jobId = context.params.jobId;
    const dealerId = after === null || after === void 0 ? void 0 : after.dealerId;
    const technicianId = after === null || after === void 0 ? void 0 : after.technicianId;
    if (!dealerId)
        return;
    const statusBefore = before === null || before === void 0 ? void 0 : before.status;
    const statusAfter = after === null || after === void 0 ? void 0 : after.status;
    // Job cancelled or reassigned: return technician to online
    if (statusAfter === "cancelled") {
        const techId = ((_a = after === null || after === void 0 ? void 0 : after.technicianId) !== null && _a !== void 0 ? _a : before === null || before === void 0 ? void 0 : before.technicianId);
        if (techId) {
            await db.collection("users").doc(techId).set({ availabilityStatus: "online", online: true }, { merge: true });
            functions.logger.info("Technician set to online after job cancelled", { jobId, techId });
        }
        return;
    }
    const techIdBefore = before === null || before === void 0 ? void 0 : before.technicianId;
    const techIdAfter = after === null || after === void 0 ? void 0 : after.technicianId;
    const lastBidBefore = before === null || before === void 0 ? void 0 : before.lastTechnicianBidAmount;
    const lastBidAfter = after === null || after === void 0 ? void 0 : after.lastTechnicianBidAmount;
    const dealerCounterBefore = before === null || before === void 0 ? void 0 : before.dealerCounterAmount;
    const dealerCounterAfter = after === null || after === void 0 ? void 0 : after.dealerCounterAmount;
    const proofPhotosBefore = (_c = (_b = before === null || before === void 0 ? void 0 : before.proofPhotos) === null || _b === void 0 ? void 0 : _b.length) !== null && _c !== void 0 ? _c : 0;
    const proofPhotosAfter = (_e = (_d = after === null || after === void 0 ? void 0 : after.proofPhotos) === null || _d === void 0 ? void 0 : _d.length) !== null && _e !== void 0 ? _e : 0;
    const materialListBefore = (_j = (_g = (_f = before === null || before === void 0 ? void 0 : before.materialList) === null || _f === void 0 ? void 0 : _f.length) !== null && _g !== void 0 ? _g : (_h = before === null || before === void 0 ? void 0 : before.technicianMaterialList) === null || _h === void 0 ? void 0 : _h.length) !== null && _j !== void 0 ? _j : 0;
    const materialListAfter = (_o = (_l = (_k = after === null || after === void 0 ? void 0 : after.materialList) === null || _k === void 0 ? void 0 : _k.length) !== null && _l !== void 0 ? _l : (_m = after === null || after === void 0 ? void 0 : after.technicianMaterialList) === null || _m === void 0 ? void 0 : _m.length) !== null && _o !== void 0 ? _o : 0;
    const offeredBefore = (_q = (_p = before === null || before === void 0 ? void 0 : before.offeredToTechnicianIds) === null || _p === void 0 ? void 0 : _p.length) !== null && _q !== void 0 ? _q : 0;
    const offeredAfter = (_s = (_r = after === null || after === void 0 ? void 0 : after.offeredToTechnicianIds) === null || _r === void 0 ? void 0 : _r.length) !== null && _s !== void 0 ? _s : 0;
    const dealerSnap = await db.collection("users").doc(dealerId).get();
    const dealerTokens = getAllFcmTokens((_t = dealerSnap.data()) !== null && _t !== void 0 ? _t : {});
    // Technician accepted – going to bid (status posted → bidding): notify dealer only
    if (statusBefore === "posted" && statusAfter === "bidding" && technicianId) {
        for (const token of dealerTokens) {
            await sendFcmToDealer(token, jobId, "technician_accepted");
        }
        functions.logger.info("Dealer notified: technician accepted (bidding)", { jobId });
        return;
    }
    // Technician accepted fixed rate (status posted → payment_pending): set technician busy, notify dealer; notify other techs "job no longer available"
    if (statusBefore === "posted" && statusAfter === "payment_pending" && technicianId) {
        await db.collection("users").doc(technicianId).set({ availabilityStatus: "busy", online: true }, { merge: true });
        for (const token of dealerTokens) {
            await sendFcmToDealer(token, jobId, "technician_accepted");
        }
        const lastNotified = (_u = after === null || after === void 0 ? void 0 : after.lastNotifiedTechnicianIds) !== null && _u !== void 0 ? _u : [];
        const offered = (_v = after === null || after === void 0 ? void 0 : after.offeredToTechnicianIds) !== null && _v !== void 0 ? _v : [];
        const toNotifyNoLonger = [...new Set([...offered, ...lastNotified])].filter((id) => id !== technicianId);
        for (const techId of toNotifyNoLonger) {
            const techSnap = await db.collection("users").doc(techId).get();
            const tokens = getAllFcmTokens((_w = techSnap.data()) !== null && _w !== void 0 ? _w : {});
            for (const token of tokens) {
                await sendFcmToTechnician(token, jobId, "job_no_longer_available");
            }
        }
        functions.logger.info("Technician set to busy; dealer and other techs notified", { jobId, count: toNotifyNoLonger.length });
        return;
    }
    // Technician submitted bid – send to dealer; increment bidsReceivedCount
    if (lastBidAfter != null && lastBidAfter !== lastBidBefore) {
        await change.after.ref.update({
            bidsReceivedCount: admin.firestore.FieldValue.increment(1),
        });
        let techTokensToExclude = [];
        if (technicianId) {
            const techSnap = await db.collection("users").doc(technicianId).get();
            techTokensToExclude = getAllFcmTokens((_x = techSnap.data()) !== null && _x !== void 0 ? _x : {});
        }
        const dealerTokensToUse = dealerTokens.filter((t) => !techTokensToExclude.includes(t));
        for (const token of dealerTokensToUse) {
            await sendFcmToDealer(token, jobId, "technician_bid");
        }
        functions.logger.info("Dealer notified: technician bid", {
            jobId,
            dealerTokenCount: dealerTokensToUse.length,
            excluded: dealerTokens.length - dealerTokensToUse.length,
        });
        return;
    }
    // Dealer counter offer
    if (dealerCounterAfter != null && dealerCounterAfter !== dealerCounterBefore && technicianId) {
        const techSnap = await db.collection("users").doc(technicianId).get();
        const techTokens = getAllFcmTokens((_y = techSnap.data()) !== null && _y !== void 0 ? _y : {});
        for (const token of techTokens) {
            await sendFcmToTechnician(token, jobId, "dealer_counter");
        }
        functions.logger.info("Technician notified: dealer counter", { jobId });
        return;
    }
    // Dealer accepted bid or tech accepted rate → payment_pending: set technician to busy
    if (statusAfter === "payment_pending" && statusBefore !== "payment_pending") {
        if (technicianId) {
            await db.collection("users").doc(technicianId).set({ availabilityStatus: "busy", online: true }, { merge: true });
            const techSnap = await db.collection("users").doc(technicianId).get();
            const techTokens = getAllFcmTokens((_z = techSnap.data()) !== null && _z !== void 0 ? _z : {});
            for (const token of techTokens) {
                await sendFcmToTechnician(token, jobId, "dealer_accept_bid");
            }
        }
        for (const token of dealerTokens) {
            await sendFcmToDealer(token, jobId, "payment_ready");
        }
        functions.logger.info("Bid agreed: technician set to busy, notifications sent", { jobId });
        return;
    }
    // Technician rejected OR dealer rejected bid: offered grew and/or technicianId removed → notify next technician
    // (technician reject: offered grows, status→posted; dealer reject: offered grows, technicianId removed)
    const offeredGrew = offeredAfter > offeredBefore;
    const techRemoved = !!techIdBefore && !techIdAfter;
    const statusIsPosted = statusAfter === "posted";
    if ((offeredGrew && statusIsPosted) || techRemoved) {
        const lastRejectedBy = after === null || after === void 0 ? void 0 : after.lastRejectedBy;
        if (techRemoved && techIdBefore) {
            await db.collection("users").doc(techIdBefore).set({ availabilityStatus: "online", online: true }, { merge: true });
        }
        if (offeredGrew) {
            await change.after.ref.update({
                techniciansRejectedCount: admin.firestore.FieldValue.increment(1),
            });
            if (techIdBefore && lastRejectedBy === "technician") {
                const techRef = db.collection("users").doc(techIdBefore);
                await techRef.update({
                    rejectionCountLastHour: admin.firestore.FieldValue.increment(1),
                });
            }
        }
        if (techIdBefore && offeredGrew && lastRejectedBy !== "dealer") {
            for (const token of dealerTokens) {
                await sendFcmToDealer(token, jobId, "technician_rejected_offer");
            }
            functions.logger.info("Dealer notified: technician rejected offer", { jobId });
        }
        const job = change.after.data();
        const rollIds = (_0 = job.rollTechnicianIds) !== null && _0 !== void 0 ? _0 : [];
        const offered = (_1 = job.offeredToTechnicianIds) !== null && _1 !== void 0 ? _1 : [];
        const bidRound = (_2 = job.bidRound) !== null && _2 !== void 0 ? _2 : 1;
        const biddingEnabled = job.biddingEnabled === true;
        const maxBiddingReached = biddingEnabled && bidRound >= 3;
        if (maxBiddingReached) {
            await change.after.ref.update({ biddingMaxReached: true });
            functions.logger.info("Maximum bidding rounds reached for job", { jobId, bidRound });
            return;
        }
        const nextId = rollIds.find((id) => !offered.includes(id));
        if (nextId) {
            const userSnap = await db.collection("users").doc(nextId).get();
            const tokens = getAllFcmTokens((_3 = userSnap.data()) !== null && _3 !== void 0 ? _3 : {});
            for (const token of tokens) {
                await sendFcmToTechnician(token, jobId, "job_request", job);
            }
            functions.logger.info("Next technician notified after reject", { jobId, nextId, tokenCount: tokens.length });
        }
        else {
            functions.logger.warn("No next technician to notify", { jobId, rollCount: rollIds.length, offeredCount: offered.length });
        }
        return;
    }
    // Material list updated (technician provided material)
    if (materialListAfter > materialListBefore && (after === null || after === void 0 ? void 0 : after.materialOption) === "material_by_technician") {
        for (const token of dealerTokens) {
            await sendFcmToDealer(token, jobId, "material_list");
        }
        functions.logger.info("Dealer notified: material list", { jobId });
        return;
    }
    // Proof photos uploaded (pickup, before, after, etc.)
    if (proofPhotosAfter > proofPhotosBefore) {
        for (const token of dealerTokens) {
            await sendFcmToDealer(token, jobId, "proof_uploaded");
        }
        functions.logger.info("Dealer notified: proof uploaded", { jobId });
        return;
    }
    // Job ready for dealer confirm (status → pending_dealer_confirm): set 30-min approval deadline and payment status
    if (statusAfter === "pending_dealer_confirm" && statusBefore !== "pending_dealer_confirm") {
        const deadline = new Date();
        deadline.setMinutes(deadline.getMinutes() + 30);
        await change.after.ref.update({
            dealerApprovalDeadline: admin.firestore.Timestamp.fromDate(deadline),
            paymentStatus: "approval_pending",
        });
        for (const token of dealerTokens) {
            await sendFcmToDealer(token, jobId, "job_pending_confirm");
        }
        functions.logger.info("Dealer notified: job pending confirm, 30-min deadline set", { jobId });
    }
    // Material return requested – notify dealer to set handover location
    const materialReturnBefore = before === null || before === void 0 ? void 0 : before.materialReturnRequested;
    const materialReturnAfter = after === null || after === void 0 ? void 0 : after.materialReturnRequested;
    if (materialReturnAfter === true && materialReturnBefore !== true) {
        for (const token of dealerTokens) {
            await sendFcmToDealer(token, jobId, "material_return_request");
        }
        functions.logger.info("Dealer notified: material return requested", { jobId });
    }
    // Material handover location set – notify technician
    const handoverBefore = before === null || before === void 0 ? void 0 : before.materialHandoverLocation;
    const handoverAfter = after === null || after === void 0 ? void 0 : after.materialHandoverLocation;
    if (handoverAfter && !handoverBefore && technicianId) {
        const techSnap = await db.collection("users").doc(technicianId).get();
        const techTokens = getAllFcmTokens((_4 = techSnap.data()) !== null && _4 !== void 0 ? _4 : {});
        for (const token of techTokens) {
            await sendFcmToTechnician(token, jobId, "material_return_location_set");
        }
        functions.logger.info("Technician notified: handover location set", { jobId });
    }
});
exports.onJobRejected = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    if (!jobId)
        throw new functions.https.HttpsError("invalid-argument", "jobId required");
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    const technicianId = (_b = (_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid) !== null && _b !== void 0 ? _b : data === null || data === void 0 ? void 0 : data.technicianId;
    if (!technicianId)
        throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
    await jobSnap.ref.update({
        offeredToTechnicianIds: admin.firestore.FieldValue.arrayUnion(technicianId),
        technicianId: admin.firestore.FieldValue.delete(),
        techniciansRejectedCount: admin.firestore.FieldValue.increment(1),
    });
    const techRef = db.collection("users").doc(technicianId);
    await techRef.update({
        rejectionCountLastHour: admin.firestore.FieldValue.increment(1),
    });
    const rollIds = (_c = job.rollTechnicianIds) !== null && _c !== void 0 ? _c : [];
    const offered = [...((_d = job.offeredToTechnicianIds) !== null && _d !== void 0 ? _d : []), technicianId];
    const nextId = rollIds.find((id) => !offered.includes(id));
    if (nextId) {
        const userSnap = await db.collection("users").doc(nextId).get();
        const tokens = getAllFcmTokens((_e = userSnap.data()) !== null && _e !== void 0 ? _e : {});
        for (const token of tokens) {
            await sendFcmToTechnician(token, jobId, "job_request", job);
        }
        functions.logger.info("Next technician notified", { jobId, nextId, tokenCount: tokens.length });
    }
    return { ok: true };
});
/** Callable: technician responds to warranty claim (accept visit or reject with reason). */
exports.respondToWarrantyClaim = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const uid = context.auth.uid;
    const claimId = data === null || data === void 0 ? void 0 : data.claimId;
    const accept = (data === null || data === void 0 ? void 0 : data.accept) === true;
    const rejectionReason = (_a = data === null || data === void 0 ? void 0 : data.rejectionReason) === null || _a === void 0 ? void 0 : _a.trim();
    if (!claimId)
        throw new functions.https.HttpsError("invalid-argument", "claimId required");
    if (!accept && !rejectionReason) {
        throw new functions.https.HttpsError("invalid-argument", "Rejection reason required when rejecting");
    }
    const claimSnap = await db.collection("warranty_claims").doc(claimId).get();
    if (!claimSnap.exists)
        throw new functions.https.HttpsError("not-found", "Claim not found");
    const claim = claimSnap.data();
    const technicianId = claim.technicianId;
    if (technicianId !== uid) {
        throw new functions.https.HttpsError("permission-denied", "Not the assigned technician");
    }
    const status = claim.claimStatus;
    if (status !== "pending") {
        throw new functions.https.HttpsError("failed-precondition", "Claim is no longer pending");
    }
    const jobId = claim.jobId;
    const dealerId = claim.dealerId;
    if (accept) {
        await claimSnap.ref.update({
            claimStatus: "technician_accepted",
            technicianResponseStatus: "accepted",
        });
        const dealerSnap = await db.collection("users").doc(dealerId).get();
        const dealerTokens = getAllFcmTokens((_b = dealerSnap.data()) !== null && _b !== void 0 ? _b : {});
        for (const token of dealerTokens) {
            await sendFcmNotification(token, "Technician accepted warranty visit", "The technician has accepted the warranty claim and will visit the site.", { jobId, type: "warranty_technician_accepted", target: "dealer" });
        }
    }
    else {
        await claimSnap.ref.update({
            // Strict admin-controlled escrow: rejection always goes to admin review (no auto settlement).
            claimStatus: "under_review",
            technicianResponseStatus: "rejected",
            rejectionReason: rejectionReason || "",
            escrowStatus: "under_admin_review",
            adminApprovalStatus: "pending",
        });
        await db.collection("jobs").doc(jobId).set({
            warrantyStatus: "claim_open",
            escrowStatus: "under_admin_review",
            escrowLockedAt: admin.firestore.FieldValue.serverTimestamp(),
            escrowLockReason: "warranty_claim_rejected_by_technician",
        }, { merge: true });
        await notifyAdmins({
            title: "Warranty claim under review",
            body: "Technician rejected the claim. Escrow remains locked until admin decides.",
            data: { jobId, claimId, type: "admin_warranty_claim_under_review", target: "admin" },
        });
        await addTechnicianStrikeAndApply(technicianId, "warranty_claim_failure", 1, jobId);
        const dealerSnap = await db.collection("users").doc(dealerId).get();
        const dealerTokens = getAllFcmTokens((_c = dealerSnap.data()) !== null && _c !== void 0 ? _c : {});
        for (const token of dealerTokens) {
            await sendFcmNotification(token, "Technician rejected warranty claim", "The claim is now under admin review. Escrow remains locked until admin decides.", { jobId, claimId, type: "warranty_claim_under_review", target: "dealer" });
        }
    }
    functions.logger.info("Warranty claim response", { claimId, accept });
    return { ok: true };
});
/** Callable: create Razorpay order for job payment. Returns orderId, keyId, amountInPaise for client checkout. */
exports.createRazorpayOrder = functions.https.onCall(async (data, context) => {
    var _a, _b;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const dealerId = context.auth.uid;
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    if (!jobId)
        throw new functions.https.HttpsError("invalid-argument", "jobId required");
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    if (job.dealerId !== dealerId)
        throw new functions.https.HttpsError("permission-denied", "Not the job dealer");
    if (job.status !== "payment_pending")
        throw new functions.https.HttpsError("failed-precondition", "Job is not awaiting payment");
    const amount = (_b = (_a = job.technicianPayoutAmount) !== null && _a !== void 0 ? _a : job.agreedAmount) !== null && _b !== void 0 ? _b : 0;
    if (amount <= 0)
        throw new functions.https.HttpsError("invalid-argument", "Invalid amount");
    const razorpayConfig = (0, config_1.getExternalConfig)().razorpay;
    if (!razorpayConfig) {
        throw new functions.https.HttpsError("failed-precondition", "Razorpay is not configured");
    }
    const Razorpay = require("razorpay");
    const instance = new Razorpay({ key_id: razorpayConfig.keyId, key_secret: razorpayConfig.keySecret });
    const amountInPaise = Math.round(amount * 100);
    /** Razorpay notes: all values must be strings; keep short for dashboard / compliance visibility. */
    const titleRaw = typeof job.title === "string" ? job.title.trim() : "";
    const jobTypeId = typeof job.jobTypeId === "string" ? job.jobTypeId.trim() : "";
    const sectorId = typeof job.sectorId === "string" ? job.sectorId.trim() : "";
    const serviceType = titleRaw.length > 0
        ? titleRaw.slice(0, 200)
        : jobTypeId.length > 0
            ? `jobType:${jobTypeId}`.slice(0, 200)
            : "on_site_field_service";
    const amountReason = "ON_SITE_JOB_ESCROW";
    const notes = {
        jobId,
        dealerId,
        amountReason,
        serviceType,
        paymentContext: "on_site_service_marketplace",
    };
    if (sectorId.length > 0) {
        notes.sectorId = sectorId.slice(0, 64);
    }
    const order = await instance.orders.create({
        amount: amountInPaise,
        currency: "INR",
        receipt: `job_${jobId}`.slice(0, 40),
        notes,
    });
    return {
        orderId: order.id,
        keyId: razorpayConfig.keyId,
        amountInPaise,
        amount,
    };
});
/** Callable: dealer locks payment for job. If Razorpay payment details provided, verifies then credits; else credits without gateway (legacy). */
exports.lockJobPayment = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const dealerId = context.auth.uid;
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    if (!jobId)
        throw new functions.https.HttpsError("invalid-argument", "jobId required");
    const razorpayOrderId = data === null || data === void 0 ? void 0 : data.razorpay_order_id;
    const razorpayPaymentId = data === null || data === void 0 ? void 0 : data.razorpay_payment_id;
    const razorpaySignature = data === null || data === void 0 ? void 0 : data.razorpay_signature;
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    if (job.dealerId !== dealerId)
        throw new functions.https.HttpsError("permission-denied", "Not the job dealer");
    if (job.status !== "payment_pending")
        throw new functions.https.HttpsError("failed-precondition", "Job is not awaiting payment");
    const amount = (_b = (_a = job.technicianPayoutAmount) !== null && _a !== void 0 ? _a : job.agreedAmount) !== null && _b !== void 0 ? _b : 0;
    if (amount <= 0)
        throw new functions.https.HttpsError("invalid-argument", "Invalid amount");
    const razorpayConfig = (0, config_1.getExternalConfig)().razorpay;
    if (razorpayOrderId && razorpayPaymentId && razorpaySignature) {
        if (!razorpayConfig)
            throw new functions.https.HttpsError("failed-precondition", "Razorpay is not configured");
        const expectedSignature = crypto
            .createHmac("sha256", razorpayConfig.keySecret)
            .update(`${razorpayOrderId}|${razorpayPaymentId}`)
            .digest("hex");
        if (expectedSignature !== razorpaySignature) {
            throw new functions.https.HttpsError("invalid-argument", "Invalid payment signature");
        }
    }
    const walletRef = db.collection("wallets").doc(dealerId);
    await walletRef.set({
        balance: admin.firestore.FieldValue.increment(amount),
        locks: admin.firestore.FieldValue.arrayUnion({
            jobId,
            amount,
        }),
    }, { merge: true });
    await jobSnap.ref.update({ status: "in_progress", paymentStatus: "payment_escrowed" });
    if (razorpayPaymentId && razorpayOrderId) {
        const dealerUserSnap = await db.collection("users").doc(dealerId).get();
        const dealerData = (_c = dealerUserSnap.data()) !== null && _c !== void 0 ? _c : {};
        const dealerProfile = (_d = dealerData.profile) !== null && _d !== void 0 ? _d : {};
        const dealerName = dealerProfile.name || dealerData.name || "Dealer";
        let serviceSector = "";
        let serviceType = job.title || "";
        const sectorId = job.sectorId;
        const jobTypeId = job.jobTypeId;
        if (sectorId) {
            const sectorSnap = await db.collection("sectors").doc(sectorId).get();
            serviceSector = ((_e = sectorSnap.data()) === null || _e === void 0 ? void 0 : _e.name) || sectorId;
        }
        if (jobTypeId && !serviceType) {
            const typeSnap = await db.collection("job_types").doc(jobTypeId).get();
            serviceType = ((_f = typeSnap.data()) === null || _f === void 0 ? void 0 : _f.name) || jobTypeId;
        }
        const feePercent = (_g = razorpayConfig.feePercent) !== null && _g !== void 0 ? _g : 0;
        const razorpayFee = Math.round(amount * feePercent * 100) / 100;
        await db.collection("dealer_payment_receipts").add({
            jobId,
            dealerId,
            dealerName,
            serviceSector,
            serviceType,
            paymentAmount: amount,
            razorpayFee,
            paymentDate: admin.firestore.FieldValue.serverTimestamp(),
            paymentMethod: "razorpay",
            razorpayPaymentId,
            razorpayOrderId,
            paymentStatus: "successful",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    const technicianId = job.technicianId;
    const dealerUserSnap = await db.collection("users").doc(dealerId).get();
    const dealerTokens = getAllFcmTokens((_h = dealerUserSnap.data()) !== null && _h !== void 0 ? _h : {});
    if (technicianId) {
        const techSnap = await db.collection("users").doc(technicianId).get();
        const techTokens = getAllFcmTokens((_j = techSnap.data()) !== null && _j !== void 0 ? _j : {});
        for (const token of techTokens) {
            await sendFcmToTechnician(token, jobId, "payment_received");
        }
    }
    for (const token of dealerTokens) {
        await sendFcmToDealer(token, jobId, "payment_received");
    }
    functions.logger.info("Payment locked, job auto-started", { jobId, dealerId, amount });
    return { ok: true };
});
exports.onDealerConfirm = functions.firestore
    .document("jobs/{jobId}")
    .onUpdate(async (change, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p, _q, _r, _s, _t, _u, _v, _w, _x, _y, _z, _0, _1, _2, _3;
    const after = change.after.data();
    const before = change.before.data();
    if ((after === null || after === void 0 ? void 0 : after.status) !== "completed" || (before === null || before === void 0 ? void 0 : before.status) === "completed")
        return;
    const jobId = context.params.jobId;
    const dealerId = after === null || after === void 0 ? void 0 : after.dealerId;
    const technicianId = after === null || after === void 0 ? void 0 : after.technicianId;
    const payout = (_b = (_a = after === null || after === void 0 ? void 0 : after.technicianPayoutAmount) !== null && _a !== void 0 ? _a : after === null || after === void 0 ? void 0 : after.agreedAmount) !== null && _b !== void 0 ? _b : 0;
    // Strict policy: default warranty period is 20 days (can be overridden per job),
    // but never allow non-positive values to create 0-day warranties.
    const rawWarrantyDays = (_d = (_c = after === null || after === void 0 ? void 0 : after.warrantyPeriodDays) !== null && _c !== void 0 ? _c : after === null || after === void 0 ? void 0 : after.warrantyPeriod) !== null && _d !== void 0 ? _d : 20;
    const warrantyDays = Number.isFinite(rawWarrantyDays) && rawWarrantyDays > 0
        ? Math.floor(rawWarrantyDays)
        : 20;
    if (!dealerId || !technicianId) {
        functions.logger.warn("Job completed but missing dealerId or technicianId", {
            jobId,
        });
        return;
    }
    const materialReturnCompleted = (after === null || after === void 0 ? void 0 : after.materialReturnCompleted) === true;
    const lockAmount = payout;
    const totalTravelKm = (_e = after === null || after === void 0 ? void 0 : after.totalTravelKm) !== null && _e !== void 0 ? _e : 0;
    let travelExpenseAmount = 0;
    let warrantyEndDate = null;
    let heldPart = 0;
    if (totalTravelKm > 15) {
        const configSnap = await db.collection("travel_expense_config").limit(1).get();
        const perKmAfter15 = configSnap.empty
            ? 0
            : (_f = configSnap.docs[0].data().perKmAfter15) !== null && _f !== void 0 ? _f : 0;
        travelExpenseAmount = (totalTravelKm - 15) * perKmAfter15;
        if (travelExpenseAmount < 0)
            travelExpenseAmount = 0;
    }
    const dealerWalletRef = db.collection("wallets").doc(dealerId);
    const dealerSnap = await dealerWalletRef.get();
    const dealerData = (_g = dealerSnap.data()) !== null && _g !== void 0 ? _g : {};
    const locks = (_h = dealerData.locks) !== null && _h !== void 0 ? _h : [];
    const matchingLock = locks.find((l) => l.jobId === jobId);
    const amountToRelease = (_j = matchingLock === null || matchingLock === void 0 ? void 0 : matchingLock.amount) !== null && _j !== void 0 ? _j : lockAmount;
    const newLocks = locks.filter((l) => l.jobId !== jobId);
    const currentBalance = (_k = dealerData.balance) !== null && _k !== void 0 ? _k : 0;
    if (materialReturnCompleted) {
        // Material return: refund dealer, no technician payout
        await dealerWalletRef.set({
            balance: currentBalance + amountToRelease,
            locks: newLocks,
        }, { merge: true });
    }
    else {
        // Normal completion: deduct from dealer, pay technician
        const totalDeduction = amountToRelease + travelExpenseAmount;
        await dealerWalletRef.set({
            balance: Math.max(0, currentBalance - totalDeduction),
            locks: newLocks,
        }, { merge: true });
        warrantyEndDate = new Date();
        warrantyEndDate.setDate(warrantyEndDate.getDate() + warrantyDays);
        heldPart = payout * 0.2;
        const techWalletRef = db.collection("wallets").doc(technicianId);
        const availablePart = payout * 0.8;
        await techWalletRef.set({
            availableBalance: admin.firestore.FieldValue.increment(availablePart + travelExpenseAmount),
            heldBalance: admin.firestore.FieldValue.increment(heldPart),
            holds: admin.firestore.FieldValue.arrayUnion({
                jobId,
                amount: heldPart,
                warrantyEndDate: admin.firestore.Timestamp.fromDate(warrantyEndDate),
            }),
        }, { merge: true });
    }
    await db.collection("users").doc(dealerId).set({ totalJobsCompleted: admin.firestore.FieldValue.increment(1) }, { merge: true });
    await db.collection("users").doc(technicianId).set({ totalJobsCompleted: admin.firestore.FieldValue.increment(1) }, { merge: true });
    const customerRatingToken = randomToken();
    const customerChatToken = randomToken();
    const jobUpdate = {
        customerRatingToken,
        customerChatToken,
        paymentStatus: materialReturnCompleted ? "payment_released" : "payment_released",
    };
    if (travelExpenseAmount > 0)
        jobUpdate.travelExpenseAmount = travelExpenseAmount;
    jobUpdate.completedAt = admin.firestore.FieldValue.serverTimestamp();
    if (!materialReturnCompleted && warrantyEndDate) {
        jobUpdate.warrantyStartDate = admin.firestore.FieldValue.serverTimestamp();
        jobUpdate.warrantyEndDate = admin.firestore.Timestamp.fromDate(warrantyEndDate);
        jobUpdate.warrantyStatus = "active";
        jobUpdate.holdPaymentAmount = heldPart;
        // Escrow starts held and cannot be auto-released by scheduler.
        jobUpdate.escrowStatus = "held";
        jobUpdate.adminApprovalStatus = "pending";
    }
    await change.after.ref.update(jobUpdate);
    const baseUrl = (_m = (_l = (0, config_1.getExternalConfig)().app) === null || _l === void 0 ? void 0 : _l.baseUrl) !== null && _m !== void 0 ? _m : "https://yourapp.web.app";
    await sendJobCompleteNotifications(jobId, customerRatingToken, baseUrl);
    const dealerUserSnap = await db.collection("users").doc(dealerId).get();
    const techSnap = await db.collection("users").doc(technicianId).get();
    const dealerUserData = (_o = dealerUserSnap.data()) !== null && _o !== void 0 ? _o : {};
    const techData = (_p = techSnap.data()) !== null && _p !== void 0 ? _p : {};
    const dealerOverride = dealerUserData.adminOverrideLevel;
    const techOverride = techData.adminOverrideLevel;
    const dealerJobs = (_q = dealerUserData.totalJobsCompleted) !== null && _q !== void 0 ? _q : 0;
    const dealerRating = (_r = dealerUserData.avgRating) !== null && _r !== void 0 ? _r : 0;
    if (!dealerOverride) {
        const level = (0, reputation_1.computeDealerLevel)(dealerJobs, dealerRating);
        await db.collection("users").doc(dealerId).set({ dealerLevel: level }, { merge: true });
        await updateTrustScore(dealerId, "dealer", 1, "successful_job_completion", "job_completed", jobId);
    }
    if (!techOverride) {
        await updateTrustScore(technicianId, "technician", 2, "successful_job_completion", "job_completed", jobId);
    }
    // Queue rotation + auto return to online: technician who completed moves to end of queue and becomes available again
    await db.collection("users").doc(technicianId).set({
        lastJobCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        availabilityStatus: "online",
        online: true,
    }, { merge: true });
    // Create Service Completion Record (dealer + technician proof)
    const dealerProfile = (_s = dealerUserData.profile) !== null && _s !== void 0 ? _s : {};
    const techProfile = (_t = techData.profile) !== null && _t !== void 0 ? _t : {};
    const dealerName = dealerProfile.name || dealerUserData.name || "Dealer";
    const technicianName = techProfile.name || techData.name || "Technician";
    let serviceSector = "";
    let serviceSubSector = "";
    let serviceType = "";
    const sectorId = after === null || after === void 0 ? void 0 : after.sectorId;
    const subOptionId = after === null || after === void 0 ? void 0 : after.subOptionId;
    const jobTypeId = after === null || after === void 0 ? void 0 : after.jobTypeId;
    if (sectorId) {
        const sectorSnap = await db.collection("sectors").doc(sectorId).get();
        serviceSector = ((_u = sectorSnap.data()) === null || _u === void 0 ? void 0 : _u.name) || sectorId;
    }
    if (subOptionId) {
        const subSnap = await db.collection("sector_sub_options").doc(subOptionId).get();
        serviceSubSector = ((_v = subSnap.data()) === null || _v === void 0 ? void 0 : _v.name) || subOptionId;
    }
    if (jobTypeId) {
        const typeSnap = await db.collection("job_types").doc(jobTypeId).get();
        serviceType = ((_w = typeSnap.data()) === null || _w === void 0 ? void 0 : _w.name) || (after === null || after === void 0 ? void 0 : after.title) || jobTypeId;
    }
    const serviceLocation = (after === null || after === void 0 ? void 0 : after.address) || "";
    const serviceDate = (after === null || after === void 0 ? void 0 : after.createdAt) || admin.firestore.Timestamp.now();
    const completionDate = admin.firestore.Timestamp.now();
    const recordStatus = materialReturnCompleted ? "active" : "warranty_active";
    const releasedAmount = materialReturnCompleted ? 0 : payout * 0.8;
    const holdAmount = materialReturnCompleted ? 0 : heldPart;
    const warrantyStart = materialReturnCompleted ? null : admin.firestore.FieldValue.serverTimestamp();
    const warrantyEnd = materialReturnCompleted ? null : (warrantyEndDate ? admin.firestore.Timestamp.fromDate(warrantyEndDate) : null);
    const warrantyDaysVal = materialReturnCompleted ? 0 : warrantyDays;
    const recordRef = db.collection("service_completion_records").doc();
    await recordRef.set({
        recordCode: shortCode("DGYR", recordRef.id),
        jobId,
        jobCode: (after === null || after === void 0 ? void 0 : after.jobCode) || null,
        dealerId,
        dealerName,
        technicianId,
        technicianName,
        serviceSector,
        serviceSubSector,
        serviceType,
        serviceLocation,
        serviceDate,
        completionDate,
        customerOtpVerified: true,
        dealerApprovalStatus: "approved",
        warrantyStartDate: warrantyStart,
        warrantyEndDate: warrantyEnd,
        warrantyDurationDays: warrantyDaysVal,
        technicianPaymentReleased: releasedAmount,
        holdPaymentAmount: holdAmount,
        recordStatus,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: false });
    functions.logger.info("Service completion record created", { recordId: recordRef.id, jobId });
    // Service Evidence Locker: tamper-proof evidence record for the completed job (not editable after)
    const proofPhotos = (_x = after === null || after === void 0 ? void 0 : after.proofPhotos) !== null && _x !== void 0 ? _x : [];
    const materialList = ((_y = after === null || after === void 0 ? void 0 : after.materialList) !== null && _y !== void 0 ? _y : after === null || after === void 0 ? void 0 : after.technicianMaterialList);
    await db.collection("job_evidence").doc(jobId).set({
        jobId,
        dealerId,
        technicianId,
        beforeWorkPhotos: proofPhotos.filter((p) => p.type === "before" || p.purpose === "before"),
        afterWorkPhotos: proofPhotos.filter((p) => p.type === "after" || p.purpose === "after"),
        pickupPhotos: proofPhotos.filter((p) => p.type === "pickup" || p.purpose === "pickup"),
        materialReturnPhotos: proofPhotos.filter((p) => p.type === "material_return" || p.purpose === "material_return"),
        materialList: materialList !== null && materialList !== void 0 ? materialList : [],
        jobStartTimestamp: (_z = after === null || after === void 0 ? void 0 : after.updatedAt) !== null && _z !== void 0 ? _z : null,
        jobCompletionTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        locked: true,
    }, { merge: false });
    if (!materialReturnCompleted) {
        const platformCommission = (_0 = after === null || after === void 0 ? void 0 : after.platformChargeAmount) !== null && _0 !== void 0 ? _0 : 0;
        let gstAmount = 0;
        let gstRate = 0;
        const gstSnap = await db.collection("config").doc("billing_gst").get();
        const gstData = gstSnap.data();
        const gstEnabled = (gstData === null || gstData === void 0 ? void 0 : gstData.gstEnabled) === true;
        if (gstEnabled && platformCommission > 0) {
            gstRate = (_1 = gstData === null || gstData === void 0 ? void 0 : gstData.gstRate) !== null && _1 !== void 0 ? _1 : 0.18;
            gstAmount = Math.round(platformCommission * gstRate * 100) / 100;
        }
        const totalPlatformCharge = platformCommission + gstAmount;
        await db.collection("platform_invoices").add({
            jobId,
            dealerId,
            dealerName,
            serviceAmount: payout,
            platformCommission,
            gstAmount,
            totalPlatformCharge,
            invoiceDate: admin.firestore.FieldValue.serverTimestamp(),
            invoiceStatus: "issued",
            razorpayPaymentId: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await db.collection("technician_payment_receipts").add({
            jobId,
            technicianId,
            technicianName,
            totalJobAmount: payout,
            technicianPaidAmount: releasedAmount,
            holdAmount: heldPart,
            transferId: null,
            transferDate: admin.firestore.FieldValue.serverTimestamp(),
            paymentStatus: "credited",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    // Notify dealer and technician via FCM (all devices)
    const dealerTokens = getAllFcmTokens((_2 = dealerUserSnap.data()) !== null && _2 !== void 0 ? _2 : {});
    const techTokens = getAllFcmTokens((_3 = techSnap.data()) !== null && _3 !== void 0 ? _3 : {});
    for (const token of dealerTokens) {
        await sendFcmToDealer(token, jobId, "job_completed");
    }
    for (const token of techTokens) {
        await sendFcmToTechnician(token, jobId, "job_completed");
    }
    functions.logger.info("Job completed: wallet and levels updated", {
        jobId,
        dealerId,
        technicianId,
        payout,
    });
});
/** Callable (public): get service completion record verification data for QR scan page.
 *  No auth required – used by /verify?recordId=xxx. Ensure this function allows unauthenticated
 *  invocations in GCP (Cloud Functions → getServiceRecordVerification → Permissions → Add principal “allUsers” as Invoker) if needed. */
exports.getServiceRecordVerification = functions.https.onCall(async (data, context) => {
    var _a;
    const recordId = data === null || data === void 0 ? void 0 : data.recordId;
    if (!recordId || typeof recordId !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "recordId required");
    }
    const doc = await db.collection("service_completion_records").doc(recordId).get();
    if (!doc.exists) {
        throw new functions.https.HttpsError("not-found", "Record not found");
    }
    const d = doc.data();
    const completionDate = d.completionDate;
    return {
        recordId: doc.id,
        jobId: d.jobId,
        completionStatus: (_a = d.dealerApprovalStatus) !== null && _a !== void 0 ? _a : "approved",
        recordStatus: d.recordStatus,
        warrantyStatus: d.recordStatus === "warranty_active" ? "Warranty active" : d.recordStatus === "warranty_expired" ? "Warranty expired" : "Active",
        completionDate: completionDate ? completionDate.toDate().toISOString() : null,
        serviceType: d.serviceType,
        dealerName: d.dealerName,
        technicianName: d.technicianName,
    };
});
/** Admin callable: backfill invalid warranty fields for service completion records. */
exports.adminBackfillServiceRecordWarranty = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const adminSnap = await db.collection("users").doc(context.auth.uid).get();
    const role = (_a = adminSnap.data()) === null || _a === void 0 ? void 0 : _a.role;
    if (role !== "superadmin")
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const limit = Math.max(1, Math.min(1000, Number((_b = data === null || data === void 0 ? void 0 : data.limit) !== null && _b !== void 0 ? _b : 300)));
    const dryRun = (data === null || data === void 0 ? void 0 : data.dryRun) === true;
    const defaultDays = 20;
    const snap = await db.collection("service_completion_records")
        .orderBy("createdAt", "desc")
        .limit(limit)
        .get();
    let scanned = 0;
    let fixed = 0;
    const touchedIds = [];
    const batch = db.batch();
    for (const doc of snap.docs) {
        scanned += 1;
        const d = doc.data();
        const status = (_c = d.recordStatus) !== null && _c !== void 0 ? _c : "";
        if (status !== "warranty_active")
            continue;
        const startTs = d.warrantyStartDate;
        const endTs = d.warrantyEndDate;
        const completionTs = d.completionDate;
        const createdTs = d.createdAt;
        const duration = Number((_d = d.warrantyDurationDays) !== null && _d !== void 0 ? _d : 0);
        const startDate = (_g = (_f = (_e = startTs === null || startTs === void 0 ? void 0 : startTs.toDate()) !== null && _e !== void 0 ? _e : completionTs === null || completionTs === void 0 ? void 0 : completionTs.toDate()) !== null && _f !== void 0 ? _f : createdTs === null || createdTs === void 0 ? void 0 : createdTs.toDate()) !== null && _g !== void 0 ? _g : null;
        const endDate = (_h = endTs === null || endTs === void 0 ? void 0 : endTs.toDate()) !== null && _h !== void 0 ? _h : null;
        const needsDurationFix = !Number.isFinite(duration) || duration <= 0;
        const needsEndFix = !startDate || !endDate || endDate.getTime() <= startDate.getTime();
        if (!needsDurationFix && !needsEndFix)
            continue;
        if (!startDate)
            continue;
        const days = needsDurationFix ? defaultDays : Math.max(1, Math.floor(duration));
        const fixedEnd = new Date(startDate);
        fixedEnd.setDate(fixedEnd.getDate() + days);
        fixed += 1;
        touchedIds.push(doc.id);
        if (!dryRun) {
            batch.update(doc.ref, {
                warrantyDurationDays: days,
                warrantyStartDate: startTs !== null && startTs !== void 0 ? startTs : admin.firestore.Timestamp.fromDate(startDate),
                warrantyEndDate: admin.firestore.Timestamp.fromDate(fixedEnd),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    }
    if (!dryRun && fixed > 0) {
        await batch.commit();
    }
    return { ok: true, dryRun, scanned, fixed, touchedIds };
});
/** Scheduled: daily warranty escrow review queue (STRICT: no auto release). */
exports.warrantyUnlock = functions.pubsub
    .schedule("0 2 * * *")
    .timeZone("UTC")
    .onRun(async () => {
    var _a;
    // STRICT RULE: Never move money automatically.
    // This job only moves eligible jobs into admin review queue after warranty end.
    const now = admin.firestore.Timestamp.now();
    const jobsSnap = await db
        .collection("jobs")
        .where("warrantyEndDate", "<=", now)
        .limit(300)
        .get();
    for (const jobDoc of jobsSnap.docs) {
        const jobId = jobDoc.id;
        const job = jobDoc.data();
        const escrowStatus = (_a = job.escrowStatus) !== null && _a !== void 0 ? _a : "held";
        // If claim/dispute exists, keep locked (admin will decide via those flows).
        const claimExists = await db
            .collection("warranty_claims")
            .where("jobId", "==", jobId)
            .limit(1)
            .get();
        const disputeExists = await db
            .collection("job_disputes")
            .where("jobId", "==", jobId)
            .where("status", "==", "open")
            .limit(1)
            .get();
        if (!claimExists.empty || !disputeExists.empty) {
            await jobDoc.ref.set({
                escrowStatus: "locked_due_to_claim",
                escrowLockReason: "claim_or_dispute_exists",
            }, { merge: true });
            continue;
        }
        // Warranty ended with no claim/dispute: send to admin queue for approval.
        if (escrowStatus === "held") {
            await jobDoc.ref.set({
                escrowStatus: "under_admin_review",
                escrowLockedAt: admin.firestore.FieldValue.serverTimestamp(),
                escrowLockReason: "warranty_period_ended",
            }, { merge: true });
            await notifyAdmins({
                title: "Warranty period ended",
                body: "Warranty period ended with no claim/dispute. Escrow ready for admin approval.",
                data: { jobId, type: "admin_warranty_period_ended", target: "admin" },
            });
        }
    }
});
/** Trigger: when any job dispute is created, lock escrow and notify admins. */
exports.onJobDisputeCreated = functions.firestore
    .document("job_disputes/{disputeId}")
    .onCreate(async (snap, context) => {
    const dispute = snap.data();
    const disputeId = context.params.disputeId;
    const jobId = dispute === null || dispute === void 0 ? void 0 : dispute.jobId;
    if (!jobId)
        return;
    await lockEscrowForJob({
        jobId,
        reason: "job_dispute_created",
        disputeId,
    });
    await notifyAdmins({
        title: "Dispute raised",
        body: "A dispute was raised. Escrow locked. Admin action required.",
        data: { jobId, disputeId, type: "admin_new_dispute", target: "admin" },
    });
});
/** Trigger: when a warranty service job completes, do NOT release escrow; move to admin review. */
exports.onWarrantyServiceJobCompleted = functions.firestore
    .document("jobs/{jobId}")
    .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    if (!after)
        return;
    const warrantyServiceJobId = context.params.jobId;
    const jobType = after.jobType;
    if (jobType !== "warranty_service")
        return;
    if (after.status !== "completed" || (before === null || before === void 0 ? void 0 : before.status) === "completed")
        return;
    const claimId = after.claimId;
    const parentJobId = after.parentJobId;
    if (!claimId || !parentJobId)
        return;
    await db.collection("warranty_claims").doc(claimId).set({
        claimStatus: "awaiting_admin_approval",
        escrowStatus: "under_admin_review",
        adminApprovalStatus: "pending",
    }, { merge: true });
    await db.collection("jobs").doc(parentJobId).set({
        escrowStatus: "under_admin_review",
        escrowLockedAt: admin.firestore.FieldValue.serverTimestamp(),
        escrowLockReason: "warranty_service_completed",
    }, { merge: true });
    await notifyAdmins({
        title: "Warranty service completed",
        body: "Warranty service job completed. Escrow still locked; admin approval required to settle.",
        data: {
            jobId: parentJobId,
            claimId,
            warrantyServiceJobId,
            type: "admin_warranty_service_completed",
            target: "admin",
        },
    });
});
/** Callable (admin-only): approve/settle escrow. All money movements MUST go through this function. */
exports.adminApproveEscrow = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const adminUid = context.auth.uid;
    const adminSnap = await db.collection("users").doc(adminUid).get();
    const role = (_a = adminSnap.data()) === null || _a === void 0 ? void 0 : _a.role;
    if (role !== "superadmin")
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    const claimId = data === null || data === void 0 ? void 0 : data.claimId;
    const decision = data === null || data === void 0 ? void 0 : data.decision; // release_full_to_tech | partial_deduction | transfer_to_dealer | assign_to_new_tech | keep_platform
    const amount = (_b = data === null || data === void 0 ? void 0 : data.amount) !== null && _b !== void 0 ? _b : null; // for partial_deduction (absolute)
    const percent = (_c = data === null || data === void 0 ? void 0 : data.percent) !== null && _c !== void 0 ? _c : null; // for partial_deduction (0-100)
    const newTechnicianId = data === null || data === void 0 ? void 0 : data.newTechnicianId;
    const reason = (_d = data === null || data === void 0 ? void 0 : data.reason) !== null && _d !== void 0 ? _d : "";
    if (!jobId || !decision)
        throw new functions.https.HttpsError("invalid-argument", "jobId and decision required");
    if (decision === "assign_to_new_tech" && !newTechnicianId) {
        throw new functions.https.HttpsError("invalid-argument", "newTechnicianId required");
    }
    const jobRef = db.collection("jobs").doc(jobId);
    const jobSnap = await jobRef.get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    const holdAmount = (_e = job.holdPaymentAmount) !== null && _e !== void 0 ? _e : 0;
    const techId = job.technicianId;
    const dealerId = job.dealerId;
    if (!techId || !dealerId)
        throw new functions.https.HttpsError("failed-precondition", "Missing dealerId/technicianId");
    if (!holdAmount || holdAmount <= 0)
        throw new functions.https.HttpsError("failed-precondition", "No hold amount to settle");
    let techPayout = 0;
    let dealerPayout = 0;
    let platformKeep = 0;
    let newTechPayout = 0;
    let escrowResultStatus = "closed";
    if (decision === "release_full_to_tech") {
        techPayout = holdAmount;
        escrowResultStatus = "approved_release";
    }
    else if (decision === "transfer_to_dealer") {
        dealerPayout = holdAmount;
        escrowResultStatus = "transferred_to_dealer";
    }
    else if (decision === "keep_platform") {
        platformKeep = holdAmount;
        escrowResultStatus = "closed";
    }
    else if (decision === "assign_to_new_tech") {
        newTechPayout = holdAmount;
        escrowResultStatus = "reassigned";
    }
    else if (decision === "partial_deduction") {
        const partial = amount != null
            ? Math.max(0, Math.min(holdAmount, amount))
            : percent != null
                ? Math.max(0, Math.min(holdAmount, (holdAmount * Math.max(0, Math.min(100, percent))) / 100))
                : null;
        if (partial == null)
            throw new functions.https.HttpsError("invalid-argument", "amount or percent required for partial_deduction");
        // Convention: partial released to technician, remainder to dealer.
        techPayout = partial;
        dealerPayout = Math.max(0, holdAmount - partial);
        escrowResultStatus = "partially_released";
    }
    else {
        throw new functions.https.HttpsError("invalid-argument", "Invalid decision");
    }
    const techWalletRef = db.collection("wallets").doc(techId);
    const dealerWalletRef = db.collection("wallets").doc(dealerId);
    const platformEscrowRef = db.collection("platform_escrow").doc("main");
    const newTechWalletRef = newTechnicianId ? db.collection("wallets").doc(newTechnicianId) : null;
    await db.runTransaction(async (tx) => {
        var _a, _b, _c, _d, _e;
        const jobSnapT = await tx.get(jobRef);
        const jobT = (_a = jobSnapT.data()) !== null && _a !== void 0 ? _a : {};
        const currentEscrowStatus = (_b = jobT.escrowStatus) !== null && _b !== void 0 ? _b : "held";
        if (currentEscrowStatus === "closed") {
            throw new functions.https.HttpsError("failed-precondition", "Escrow already closed");
        }
        const techWalletSnap = await tx.get(techWalletRef);
        const techWallet = (_c = techWalletSnap.data()) !== null && _c !== void 0 ? _c : {};
        const holds = (_d = techWallet.holds) !== null && _d !== void 0 ? _d : [];
        const matching = holds.find((h) => h.jobId === jobId);
        if (!matching || ((_e = matching.amount) !== null && _e !== void 0 ? _e : 0) <= 0) {
            throw new functions.https.HttpsError("failed-precondition", "Hold entry not found in technician wallet");
        }
        const newHolds = holds.filter((h) => h.jobId !== jobId);
        tx.set(techWalletRef, Object.assign({ heldBalance: admin.firestore.FieldValue.increment(-holdAmount), holds: newHolds }, (techPayout > 0 ? { availableBalance: admin.firestore.FieldValue.increment(techPayout) } : {})), { merge: true });
        if (dealerPayout > 0) {
            tx.set(dealerWalletRef, { balance: admin.firestore.FieldValue.increment(dealerPayout) }, { merge: true });
        }
        if (platformKeep > 0) {
            tx.set(platformEscrowRef, { balance: admin.firestore.FieldValue.increment(platformKeep) }, { merge: true });
        }
        if (newTechPayout > 0 && newTechWalletRef) {
            tx.set(newTechWalletRef, { availableBalance: admin.firestore.FieldValue.increment(newTechPayout) }, { merge: true });
        }
        tx.set(jobRef, {
            escrowStatus: "closed",
            escrowSettlementStatus: escrowResultStatus,
            adminApprovalStatus: "approved",
            adminApprovedAmount: techPayout,
            adminDecisionReason: reason,
            releasedAt: admin.firestore.FieldValue.serverTimestamp(),
            escrowDecision: decision,
            escrowDecisionBy: adminUid,
        }, { merge: true });
        if (claimId) {
            const claimRef = db.collection("warranty_claims").doc(claimId);
            tx.set(claimRef, {
                escrowStatus: "closed",
                escrowSettlementStatus: escrowResultStatus,
                adminApprovalStatus: "approved",
                adminApprovedAmount: techPayout,
                adminDecisionReason: reason,
                releasedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        const escTxRef = db.collection("escrow_transactions").doc();
        tx.set(escTxRef, {
            jobId,
            claimId: claimId !== null && claimId !== void 0 ? claimId : null,
            holdAmount,
            techPayout,
            dealerPayout,
            platformKeep,
            newTechPayout,
            decision,
            newTechnicianId: newTechnicianId !== null && newTechnicianId !== void 0 ? newTechnicianId : null,
            reason,
            actorId: adminUid,
            actorRole: "superadmin",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    return { ok: true };
});
async function lockEscrowForJob(args) {
    const { jobId, reason, claimId, disputeId } = args;
    await db.collection("jobs").doc(jobId).set(Object.assign(Object.assign({ escrowStatus: "locked_due_to_claim", escrowLockedAt: admin.firestore.FieldValue.serverTimestamp(), escrowLockReason: reason }, (claimId ? { escrowLockedByClaimId: claimId } : {})), (disputeId ? { escrowLockedByDisputeId: disputeId } : {})), { merge: true });
}
async function notifyAdmins(args) {
    var _a;
    const adminsSnap = await db.collection("users").where("role", "==", "superadmin").get();
    for (const doc of adminsSnap.docs) {
        const tokens = getAllFcmTokens((_a = doc.data()) !== null && _a !== void 0 ? _a : {});
        for (const token of tokens) {
            await sendFcmNotification(token, args.title, args.body, args.data);
        }
    }
}
/** Scheduled: every 1 min – send next batch of job notifications (60s after previous batch if no accept). */
exports.jobNotificationBatchEscalation = functions.pubsub
    .schedule("every 1 minutes")
    .timeZone("UTC")
    .onRun(async () => {
    var _a, _b, _c, _d;
    const now = new Date();
    const cutoff = new Date(now.getTime() - 60 * 1000);
    const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);
    const jobsSnap = await db
        .collection("jobs")
        .where("status", "==", "posted")
        .where("lastNotificationBatchAt", "<", cutoffTs)
        .limit(30)
        .get();
    for (const jobDoc of jobsSnap.docs) {
        const job = jobDoc.data();
        const jobId = jobDoc.id;
        if (job.technicianId)
            continue;
        const rollIds = (_a = job.rollTechnicianIds) !== null && _a !== void 0 ? _a : [];
        const offered = (_b = job.offeredToTechnicianIds) !== null && _b !== void 0 ? _b : [];
        const lastNotified = (_c = job.lastNotifiedTechnicianIds) !== null && _c !== void 0 ? _c : [];
        const biddingEnabled = job.biddingEnabled === true;
        const batchSize = biddingEnabled ? 10 : 5;
        const newOffered = [...new Set([...offered, ...lastNotified])];
        const nextBatch = rollIds.filter((id) => !newOffered.includes(id)).slice(0, batchSize);
        if (nextBatch.length === 0) {
            continue;
        }
        // Queue skip rule: technicians who did not respond within window are marked (temporarily deprioritized for next job)
        for (const techId of lastNotified) {
            await db.collection("users").doc(techId).set({ lastNotificationIgnoredAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        }
        await jobDoc.ref.update({
            offeredToTechnicianIds: newOffered,
            lastNotifiedTechnicianIds: nextBatch,
            lastNotificationBatchAt: admin.firestore.FieldValue.serverTimestamp(),
            notificationRound: admin.firestore.FieldValue.increment(1),
            techniciansNotifiedCount: admin.firestore.FieldValue.increment(nextBatch.length),
        });
        const jobWithRoll = Object.assign(Object.assign({}, job), { rollTechnicianIds: rollIds, offeredToTechnicianIds: newOffered });
        for (const techId of nextBatch) {
            const userSnap = await db.collection("users").doc(techId).get();
            const tokens = getAllFcmTokens((_d = userSnap.data()) !== null && _d !== void 0 ? _d : {});
            for (const token of tokens) {
                await sendFcmToTechnician(token, jobId, "job_request", jobWithRoll);
            }
        }
        functions.logger.info("Job notification next batch sent", { jobId, batchSize: nextBatch.length, round: job.notificationRound + 1 });
    }
});
/** Callable: dealer requests more bids (next round, max 3). Sends job to next 10 technicians. */
exports.requestMoreBids = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    if (!jobId)
        throw new functions.https.HttpsError("invalid-argument", "jobId required");
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    const dealerId = job.dealerId;
    if (dealerId !== context.auth.uid)
        throw new functions.https.HttpsError("permission-denied", "Only the job dealer can request more bids");
    if (job.status !== "posted")
        throw new functions.https.HttpsError("failed-precondition", "Job is not in posted status");
    if (job.biddingEnabled !== true)
        throw new functions.https.HttpsError("failed-precondition", "Job is not in bidding mode");
    const bidRound = (_a = job.bidRound) !== null && _a !== void 0 ? _a : 1;
    if (bidRound >= 3)
        throw new functions.https.HttpsError("failed-precondition", "Maximum 3 bid rounds allowed");
    const rollIds = (_b = job.rollTechnicianIds) !== null && _b !== void 0 ? _b : [];
    const offered = (_c = job.offeredToTechnicianIds) !== null && _c !== void 0 ? _c : [];
    const nextBatch = rollIds.filter((id) => !offered.includes(id)).slice(0, 10);
    if (nextBatch.length === 0) {
        throw new functions.https.HttpsError("failed-precondition", "No more technicians available to notify");
    }
    const newOffered = [...offered, ...nextBatch];
    await jobSnap.ref.update({
        offeredToTechnicianIds: newOffered,
        lastNotifiedTechnicianIds: nextBatch,
        lastNotificationBatchAt: admin.firestore.FieldValue.serverTimestamp(),
        bidRound: bidRound + 1,
        techniciansNotifiedCount: admin.firestore.FieldValue.increment(nextBatch.length),
        technicianId: admin.firestore.FieldValue.delete(),
    });
    const jobWithRoll = Object.assign(Object.assign({}, job), { rollTechnicianIds: rollIds, offeredToTechnicianIds: newOffered });
    for (const techId of nextBatch) {
        const userSnap = await db.collection("users").doc(techId).get();
        const tokens = getAllFcmTokens((_d = userSnap.data()) !== null && _d !== void 0 ? _d : {});
        for (const token of tokens) {
            await sendFcmToTechnician(token, jobId, "job_request", jobWithRoll);
        }
    }
    functions.logger.info("Dealer requested more bids", { jobId, bidRound: bidRound + 1, notified: nextBatch.length });
    return { ok: true, bidRound: bidRound + 1, notifiedCount: nextBatch.length };
});
/** Scheduled: every hour – reset technician rejection cooldown counter. */
exports.technicianRejectionCooldownReset = functions.pubsub
    .schedule("0 * * * *")
    .timeZone("UTC")
    .onRun(async () => {
    const techsSnap = await db.collection("users").where("role", "==", "technician").get();
    const batch = db.batch();
    for (const doc of techsSnap.docs) {
        batch.update(doc.ref, { rejectionCountLastHour: 0 });
    }
    await batch.commit();
    functions.logger.info("Technician rejection cooldown reset", { count: techsSnap.size });
});
/** Scheduled: every 15 min – expire old posted jobs (no accept/bid in 24h); close bidding jobs after 3 rounds with no selection. */
exports.jobExpirationCheck = functions.pubsub
    .schedule("every 15 minutes")
    .timeZone("UTC")
    .onRun(async () => {
    var _a, _b;
    const now = new Date();
    const expiryCutoff = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const expiryTs = admin.firestore.Timestamp.fromDate(expiryCutoff);
    const postedSnap = await db
        .collection("jobs")
        .where("status", "==", "posted")
        .where("createdAt", "<", expiryTs)
        .limit(50)
        .get();
    for (const jobDoc of postedSnap.docs) {
        const jobId = jobDoc.id;
        const job = jobDoc.data();
        const dealerId = job.dealerId;
        await jobDoc.ref.update({ status: "expired" });
        if (dealerId) {
            const dealerSnap = await db.collection("users").doc(dealerId).get();
            const tokens = getAllFcmTokens((_a = dealerSnap.data()) !== null && _a !== void 0 ? _a : {});
            for (const token of tokens) {
                await sendFcmToDealer(token, jobId, "job_expired");
            }
        }
        functions.logger.info("Job expired (24h no accept)", { jobId });
    }
    const bidRound3Snap = await db
        .collection("jobs")
        .where("status", "==", "posted")
        .where("bidRound", ">=", 3)
        .limit(30)
        .get();
    for (const jobDoc of bidRound3Snap.docs) {
        const jobId = jobDoc.id;
        const job = jobDoc.data();
        if (job.technicianId)
            continue;
        const dealerId = job.dealerId;
        await jobDoc.ref.update({ status: "closed" });
        if (dealerId) {
            const dealerSnap = await db.collection("users").doc(dealerId).get();
            const tokens = getAllFcmTokens((_b = dealerSnap.data()) !== null && _b !== void 0 ? _b : {});
            for (const token of tokens) {
                await sendFcmToDealer(token, jobId, "job_expired");
            }
        }
        functions.logger.info("Job closed (3 bid rounds, no selection)", { jobId });
    }
});
/** Scheduled: every 5 min – auto-approve jobs where dealer did not respond within 30 min (no open dispute). */
exports.dealerApprovalAutoRelease = functions.pubsub
    .schedule("every 5 minutes")
    .timeZone("UTC")
    .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const jobsSnap = await db
        .collection("jobs")
        .where("status", "==", "pending_dealer_confirm")
        .where("dealerApprovalDeadline", "<=", now)
        .limit(50)
        .get();
    for (const jobDoc of jobsSnap.docs) {
        const jobId = jobDoc.id;
        const disputeSnap = await db
            .collection("job_disputes")
            .where("jobId", "==", jobId)
            .where("status", "==", "open")
            .limit(1)
            .get();
        if (!disputeSnap.empty)
            continue;
        await jobDoc.ref.update({
            status: "completed",
            autoApprovedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        functions.logger.info("Job auto-approved (30 min dealer approval window)", { jobId });
    }
});
/** Scheduled: daily aggregation of financial metrics into platform_financial_reports (runs at 03:00 UTC for previous day). */
exports.aggregateDailyFinancialReport = functions.pubsub
    .schedule("0 3 * * *")
    .timeZone("UTC")
    .onRun(async () => {
    var _a, _b, _c, _d, _e;
    const now = new Date();
    const yesterday = new Date(now);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    const dateStr = yesterday.toISOString().slice(0, 10);
    const startOfDay = admin.firestore.Timestamp.fromDate(new Date(Date.UTC(yesterday.getUTCFullYear(), yesterday.getUTCMonth(), yesterday.getUTCDate(), 0, 0, 0)));
    const endOfDay = admin.firestore.Timestamp.fromDate(new Date(Date.UTC(yesterday.getUTCFullYear(), yesterday.getUTCMonth(), yesterday.getUTCDate() + 1, 0, 0, 0)));
    let totalPaymentsReceived = 0;
    let platformCommission = 0;
    let razorpayFees = 0;
    let technicianPayout = 0;
    let operationalExpenses = 0;
    const receiptsSnap = await db.collection("dealer_payment_receipts")
        .where("paymentDate", ">=", startOfDay)
        .where("paymentDate", "<", endOfDay)
        .get();
    for (const d of receiptsSnap.docs) {
        const data = d.data();
        totalPaymentsReceived += (_a = data.paymentAmount) !== null && _a !== void 0 ? _a : 0;
        razorpayFees += (_b = data.razorpayFee) !== null && _b !== void 0 ? _b : 0;
    }
    const invoicesSnap = await db.collection("platform_invoices")
        .where("invoiceDate", ">=", startOfDay)
        .where("invoiceDate", "<", endOfDay)
        .get();
    for (const d of invoicesSnap.docs) {
        platformCommission += (_c = d.data().totalPlatformCharge) !== null && _c !== void 0 ? _c : 0;
    }
    const techReceiptsSnap = await db.collection("technician_payment_receipts")
        .where("transferDate", ">=", startOfDay)
        .where("transferDate", "<", endOfDay)
        .get();
    for (const d of techReceiptsSnap.docs) {
        technicianPayout += (_d = d.data().technicianPaidAmount) !== null && _d !== void 0 ? _d : 0;
    }
    const expensesSnap = await db.collection("platform_expenses")
        .where("expenseDate", ">=", startOfDay)
        .where("expenseDate", "<", endOfDay)
        .get();
    for (const d of expensesSnap.docs) {
        operationalExpenses += (_e = d.data().expenseAmount) !== null && _e !== void 0 ? _e : 0;
    }
    const netProfit = platformCommission - razorpayFees - operationalExpenses;
    await db.collection("platform_financial_reports").doc(dateStr).set({
        date: dateStr,
        totalPaymentsReceived,
        platformCommission,
        razorpayFees,
        technicianPayout,
        operationalExpenses,
        netProfit,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    functions.logger.info("Daily financial report aggregated", { dateStr, netProfit });
});
/** Scheduled: every 30 min – mark warranty claims past 24h response deadline as technician_failed and notify dealer. */
exports.warrantyClaimDeadlineCheck = functions.pubsub
    .schedule("every 30 minutes")
    .timeZone("UTC")
    .onRun(async () => {
    var _a;
    const now = admin.firestore.Timestamp.now();
    const claimsSnap = await db
        .collection("warranty_claims")
        .where("claimStatus", "==", "pending")
        .get();
    for (const doc of claimsSnap.docs) {
        const claim = doc.data();
        const deadline = claim.claimResponseDeadline;
        if (!deadline || deadline.toMillis() > now.toMillis())
            continue;
        await doc.ref.update({
            // Strict admin-controlled escrow: SLA miss escalates to admin review (no auto settlement).
            claimStatus: "under_review",
            technicianResponseStatus: "no_response",
            escrowStatus: "under_admin_review",
            adminApprovalStatus: "pending",
        });
        const jobId = claim.jobId;
        const dealerId = claim.dealerId;
        const technicianId = claim.technicianId;
        if (technicianId) {
            await updateTrustScore(technicianId, "technician", -8, "warranty_claim_failure", "warranty_claim", jobId);
            // Smart fraud signal: repeated warranty failures (SLA miss) in last 30 days.
            try {
                const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
                const failures = await countTrustEvents({
                    userId: technicianId,
                    reason: "warranty_claim_failure",
                    eventType: "warranty_claim",
                    since,
                });
                if (failures >= 2) {
                    const windowStart = admin.firestore.Timestamp.fromDate(since);
                    const windowEnd = admin.firestore.Timestamp.now();
                    await ensureFraudAlert({
                        type: "warranty_abuse",
                        userId: technicianId,
                        technicianId,
                        jobId,
                        riskScore: Math.min(95, 60 + failures * 10),
                        reason: "Repeated warranty claim response failures in last 30 days.",
                        signals: { failuresLast30Days: failures, threshold: 2 },
                        windowStart,
                        windowEnd,
                    });
                }
            }
            catch (e) {
                functions.logger.warn("Failed to evaluate warranty_abuse fraud signal", {
                    jobId,
                    technicianId,
                    error: e,
                });
            }
        }
        const dealerSnap = await db.collection("users").doc(dealerId).get();
        const dealerTokens = getAllFcmTokens((_a = dealerSnap.data()) !== null && _a !== void 0 ? _a : {});
        for (const token of dealerTokens) {
            await sendFcmNotification(token, "Warranty claim – no technician response", "The claim is now under admin review. Escrow remains locked until admin decides.", { jobId, claimId: doc.id, type: "warranty_claim_under_review", target: "dealer" });
        }
        await db.collection("jobs").doc(jobId).set({
            warrantyStatus: "claim_open",
            escrowStatus: "under_admin_review",
            escrowLockedAt: admin.firestore.FieldValue.serverTimestamp(),
            escrowLockReason: "warranty_claim_no_response_deadline",
        }, { merge: true });
        await notifyAdmins({
            title: "Warranty claim SLA breach",
            body: "Technician did not respond. Claim moved to admin review. Escrow locked.",
            data: { jobId, claimId: doc.id, type: "admin_warranty_claim_under_review", target: "admin" },
        });
        functions.logger.info("Warranty claim moved to under_review (deadline)", { claimId: doc.id });
    }
});
/** Scheduled: daily cleanup for otp_failures (keep last 30 days). */
exports.otpFailuresCleanup = functions.pubsub
    .schedule("0 4 * * *")
    .timeZone("UTC")
    .onRun(async () => {
    const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const cutoffTs = admin.firestore.Timestamp.fromDate(cutoff);
    const snap = await db
        .collection("otp_failures")
        .where("createdAt", "<", cutoffTs)
        .limit(500)
        .get();
    if (snap.empty)
        return;
    const batch = db.batch();
    for (const d of snap.docs)
        batch.delete(d.ref);
    await batch.commit();
    functions.logger.info("otp_failures cleanup", { deleted: snap.size });
});
/** Callable: admin resolves a job dispute. approved_tech → complete job (payment released); refund_dealer → refund dealer. Optionally set disputeSeverity: low | medium | high for trust score deduction. */
exports.resolveJobDispute = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const disputeId = data === null || data === void 0 ? void 0 : data.disputeId;
    const resolution = data === null || data === void 0 ? void 0 : data.resolution; // approved_tech | refund_dealer | partial
    const adminNotes = data === null || data === void 0 ? void 0 : data.adminNotes;
    const disputeSeverity = (data === null || data === void 0 ? void 0 : data.disputeSeverity) || "medium"; // low | medium | high
    if (!disputeId || !resolution)
        throw new functions.https.HttpsError("invalid-argument", "disputeId and resolution required");
    const adminSnap = await db.collection("users").doc(context.auth.uid).get();
    const role = (_a = adminSnap.data()) === null || _a === void 0 ? void 0 : _a.role;
    if (role !== "superadmin")
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const disputeSnap = await db.collection("job_disputes").doc(disputeId).get();
    if (!disputeSnap.exists)
        throw new functions.https.HttpsError("not-found", "Dispute not found");
    const dispute = disputeSnap.data();
    if (dispute.status !== "open")
        throw new functions.https.HttpsError("failed-precondition", "Dispute already resolved");
    const jobId = dispute.jobId;
    const dealerId = dispute.dealerId;
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    if (job.status !== "pending_dealer_confirm") {
        throw new functions.https.HttpsError("failed-precondition", "Job status is not pending_dealer_confirm");
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    const deduction = (_b = reputation_1.DISPUTE_SEVERITY_DEDUCTION[disputeSeverity]) !== null && _b !== void 0 ? _b : -5;
    await disputeSnap.ref.update({
        status: resolution,
        adminNotes: adminNotes !== null && adminNotes !== void 0 ? adminNotes : null,
        disputeSeverity: disputeSeverity,
        resolvedAt: now,
        resolvedBy: context.auth.uid,
    });
    if (resolution === "approved_tech") {
        await jobSnap.ref.update({ status: "completed", autoApprovedAt: now });
        await updateTrustScore(dealerId, "dealer", deduction, "dispute_resolved_invalid_complaint", "dispute_resolved", jobId, context.auth.uid);
        await (0, audit_1.writeAuditLog)(db, {
            adminId: context.auth.uid,
            actionType: "dispute_resolved",
            targetUserId: dealerId,
            targetJobId: jobId,
            targetDisputeId: disputeId,
            details: { resolution },
        });
        functions.logger.info("Dispute resolved: approve technician", { disputeId, jobId });
    }
    else if (resolution === "refund_dealer") {
        const dealerWalletRef = db.collection("wallets").doc(dealerId);
        const walletSnap = await dealerWalletRef.get();
        const walletData = (_c = walletSnap.data()) !== null && _c !== void 0 ? _c : {};
        const locks = (_d = walletData.locks) !== null && _d !== void 0 ? _d : [];
        const match = locks.find((l) => l.jobId === jobId);
        const amount = (_e = match === null || match === void 0 ? void 0 : match.amount) !== null && _e !== void 0 ? _e : ((_g = (_f = job.technicianPayoutAmount) !== null && _f !== void 0 ? _f : job.agreedAmount) !== null && _g !== void 0 ? _g : 0);
        const newLocks = locks.filter((l) => l.jobId !== jobId);
        const balance = (_h = walletData.balance) !== null && _h !== void 0 ? _h : 0;
        await dealerWalletRef.set({
            balance: balance + amount,
            locks: newLocks,
        }, { merge: true });
        await jobSnap.ref.update({
            status: "cancelled",
            disputeResolvedRefund: true,
        });
        const techId = job.technicianId;
        if (techId) {
            await updateTrustScore(techId, "technician", deduction, "dispute_resolved_technician_fault", "dispute_resolved", jobId, context.auth.uid);
            await addTechnicianStrikeAndApply(techId, "dispute_loss", 1, jobId, context.auth.uid);
        }
        await (0, audit_1.writeAuditLog)(db, {
            adminId: context.auth.uid,
            actionType: "dispute_resolved",
            targetUserId: dealerId,
            targetJobId: jobId,
            targetDisputeId: disputeId,
            details: { resolution, disputeSeverity, amount },
        });
        functions.logger.info("Dispute resolved: refund dealer", { disputeId, jobId, amount });
    }
    else {
        await (0, audit_1.writeAuditLog)(db, {
            adminId: context.auth.uid,
            actionType: "dispute_resolved",
            targetUserId: dealerId,
            targetJobId: jobId,
            targetDisputeId: disputeId,
            details: { resolution },
        });
    }
    return { ok: true };
});
/** Callable: admin pays cancellation compensation to technician (travel or pickup). Use when dealer cancels after tech traveled or after material pickup. */
exports.payCancellationCompensation = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    const type = data === null || data === void 0 ? void 0 : data.type; // travel | pickup
    const amount = data === null || data === void 0 ? void 0 : data.amount;
    if (!jobId || !type || amount == null || amount <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "jobId, type (travel|pickup), and positive amount required");
    }
    if (type !== "travel" && type !== "pickup") {
        throw new functions.https.HttpsError("invalid-argument", "type must be travel or pickup");
    }
    const adminSnap = await db.collection("users").doc(context.auth.uid).get();
    if (((_a = adminSnap.data()) === null || _a === void 0 ? void 0 : _a.role) !== "superadmin") {
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    }
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    const technicianId = job.technicianId;
    if (!technicianId)
        throw new functions.https.HttpsError("failed-precondition", "Job has no technician");
    const walletRef = db.collection("wallets").doc(technicianId);
    await walletRef.set({ availableBalance: admin.firestore.FieldValue.increment(amount) }, { merge: true });
    await db.collection("cancellation_compensations").add({
        jobId,
        technicianId,
        type,
        amount,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        paidBy: context.auth.uid,
    });
    functions.logger.info("Cancellation compensation paid", { jobId, technicianId, type, amount });
    return { ok: true };
});
/** Callable: submit rating after job completed. Writes to job and updates ratee avgRating + level/trustScore. */
exports.onRatingSubmitted = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    const raterRole = data === null || data === void 0 ? void 0 : data.raterRole;
    const rating = data === null || data === void 0 ? void 0 : data.rating;
    const review = data === null || data === void 0 ? void 0 : data.review;
    if (!jobId || !raterRole || rating == null || rating < 1 || rating > 5) {
        throw new functions.https.HttpsError("invalid-argument", "jobId, raterRole, rating (1-5) required");
    }
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    const uid = context.auth.uid;
    let rateeId;
    const updates = {};
    if (raterRole === "dealer") {
        if (job.dealerId !== uid)
            throw new functions.https.HttpsError("permission-denied", "Not the dealer");
        rateeId = job.technicianId;
        if (!rateeId)
            throw new functions.https.HttpsError("failed-precondition", "No technician");
        updates.dealerRatingToTechnician = rating;
        if (review != null)
            updates.dealerReviewToTechnician = review;
    }
    else if (raterRole === "technician") {
        if (job.technicianId !== uid)
            throw new functions.https.HttpsError("permission-denied", "Not the technician");
        rateeId = job.dealerId;
        if (!rateeId)
            throw new functions.https.HttpsError("failed-precondition", "No dealer");
        updates.technicianRatingToDealer = rating;
        if (review != null)
            updates.technicianReviewToDealer = review;
    }
    else {
        throw new functions.https.HttpsError("invalid-argument", "raterRole must be dealer or technician");
    }
    await jobSnap.ref.update(updates);
    const rateeSnap = await db.collection("users").doc(rateeId).get();
    const rateeData = (_a = rateeSnap.data()) !== null && _a !== void 0 ? _a : {};
    const currentAvg = (_b = rateeData.avgRating) !== null && _b !== void 0 ? _b : 0;
    const totalReviews = (_c = rateeData.totalReviews) !== null && _c !== void 0 ? _c : 0;
    const newTotal = totalReviews + 1;
    const newAvg = (currentAvg * totalReviews + rating) / newTotal;
    await db.collection("users").doc(rateeId).set({ avgRating: newAvg, totalReviews: newTotal }, { merge: true });
    const role = rateeData.role;
    const jobs = (_d = rateeData.totalJobsCompleted) !== null && _d !== void 0 ? _d : 0;
    const override = rateeData.adminOverrideLevel;
    if (!override) {
        const levelUpdate = {};
        if (role === "dealer")
            levelUpdate.dealerLevel = (0, reputation_1.computeDealerLevel)(jobs, newAvg);
        await db.collection("users").doc(rateeId).set(levelUpdate, { merge: true });
        let ratingDelta = 0;
        if (newAvg >= 4.5)
            ratingDelta = 2;
        else if (newAvg >= 4)
            ratingDelta = 1;
        else if (newAvg < 3)
            ratingDelta = -2;
        if (ratingDelta !== 0) {
            await updateTrustScore(rateeId, role, ratingDelta, "rating_submitted", "rating", jobId);
        }
    }
    return { ok: true };
});
/** Callable: admin manually adjust user trust score. */
exports.adjustTrustScore = functions.https.onCall(async (data, context) => {
    var _a, _b;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const uid = data === null || data === void 0 ? void 0 : data.uid;
    const delta = data === null || data === void 0 ? void 0 : data.delta;
    const reason = (data === null || data === void 0 ? void 0 : data.reason) || "admin_adjustment";
    if (!uid || delta == null || typeof delta !== "number") {
        throw new functions.https.HttpsError("invalid-argument", "uid and delta (number) required");
    }
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    if (((_a = callerSnap.data()) === null || _a === void 0 ? void 0 : _a.role) !== "superadmin") {
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    }
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists)
        throw new functions.https.HttpsError("not-found", "User not found");
    const role = (_b = userSnap.data()) === null || _b === void 0 ? void 0 : _b.role;
    if (role !== "dealer" && role !== "technician") {
        throw new functions.https.HttpsError("invalid-argument", "User must be dealer or technician");
    }
    await updateTrustScore(uid, role, delta, reason, "admin_adjustment", undefined, context.auth.uid);
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "trust_score_adjusted",
        targetUserId: uid,
        details: { delta, reason },
    });
    return { ok: true };
});
/** Callable: recalculate technician level from current trust score (admin only). Use when removing manual override. */
exports.recalculateTechnicianLevel = functions.https.onCall(async (data, context) => {
    var _a, _b;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const uid = data === null || data === void 0 ? void 0 : data.uid;
    if (!uid)
        throw new functions.https.HttpsError("invalid-argument", "uid required");
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    if (((_a = callerSnap.data()) === null || _a === void 0 ? void 0 : _a.role) !== "superadmin") {
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    }
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists)
        throw new functions.https.HttpsError("not-found", "User not found");
    const d = userSnap.data();
    if (d.role !== "technician") {
        throw new functions.https.HttpsError("failed-precondition", "User is not a technician");
    }
    const trustScore = (_b = d.trustScore) !== null && _b !== void 0 ? _b : reputation_1.DEFAULT_TRUST_SCORE;
    const level = (0, reputation_1.getTechnicianLevelFromTrustScore)(trustScore);
    await db.collection("users").doc(uid).set({ technicianLevel: level, manual_level_override: false, adminOverrideLevel: null }, { merge: true });
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "technician_level_changed",
        targetUserId: uid,
        details: { technicianLevel: level, reason: "recalculate_from_trust" },
    });
    functions.logger.info("Technician level recalculated from trust score", { uid, trustScore, level });
    return { ok: true, technicianLevel: level };
});
/** Callable: record customer feedback (positive/negative). Dealer or system calls after verification; affects technician trust. */
exports.recordCustomerFeedback = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    const positive = data === null || data === void 0 ? void 0 : data.positive;
    if (!jobId || typeof positive !== "boolean") {
        throw new functions.https.HttpsError("invalid-argument", "jobId and positive (boolean) required");
    }
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    const dealerId = job.dealerId;
    const technicianId = job.technicianId;
    if (context.auth.uid !== dealerId)
        throw new functions.https.HttpsError("permission-denied", "Only job dealer can submit customer feedback");
    if (!technicianId)
        throw new functions.https.HttpsError("failed-precondition", "Job has no technician");
    const delta = positive ? 1 : -1;
    await updateTrustScore(technicianId, "technician", delta, "customer_feedback", "customer_feedback", jobId);
    return { ok: true };
});
/** Callable: record job cancellation for trust score. Call when job is cancelled by dealer or technician after acceptance. */
exports.recordJobCancellation = functions.https.onCall(async (data, context) => {
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    const cancelledBy = data === null || data === void 0 ? void 0 : data.cancelledBy; // 'dealer' | 'technician'
    if (!jobId || !cancelledBy)
        throw new functions.https.HttpsError("invalid-argument", "jobId and cancelledBy required");
    if (cancelledBy !== "dealer" && cancelledBy !== "technician") {
        throw new functions.https.HttpsError("invalid-argument", "cancelledBy must be dealer or technician");
    }
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    if (job.status !== "cancelled") {
        throw new functions.https.HttpsError("failed-precondition", "Job status must be cancelled");
    }
    if (cancelledBy === "dealer") {
        const dealerId = job.dealerId;
        if (context.auth.uid !== dealerId)
            throw new functions.https.HttpsError("permission-denied", "Only dealer can record dealer cancellation");
        await updateTrustScore(dealerId, "dealer", -2, "job_cancelled_by_dealer", "job_cancelled", jobId);
        // Smart fraud signal: repeated dealer cancellations (last 7 days).
        try {
            const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
            const cancels = await countTrustEvents({
                userId: dealerId,
                reason: "job_cancelled_by_dealer",
                eventType: "job_cancelled",
                since,
            });
            if (cancels >= 3) {
                const windowStart = admin.firestore.Timestamp.fromDate(since);
                const windowEnd = admin.firestore.Timestamp.now();
                await ensureFraudAlert({
                    type: "repeat_cancellation",
                    userId: dealerId,
                    dealerId,
                    jobId,
                    riskScore: Math.min(90, 55 + cancels * 10),
                    reason: "High cancellation rate by dealer in last 7 days.",
                    signals: { cancelsLast7Days: cancels, threshold: 3, cancelledBy: "dealer" },
                    windowStart,
                    windowEnd,
                });
            }
        }
        catch (e) {
            functions.logger.warn("Failed to evaluate repeat_cancellation (dealer)", { jobId, error: e });
        }
    }
    else {
        const technicianId = job.technicianId;
        if (!technicianId || context.auth.uid !== technicianId)
            throw new functions.https.HttpsError("permission-denied", "Only technician can record technician cancellation");
        await updateTrustScore(technicianId, "technician", -3, "job_cancelled_after_acceptance", "job_cancelled", jobId);
        await addTechnicianStrikeAndApply(technicianId, "job_cancellation_after_acceptance", 1, jobId);
        // Smart fraud signal: repeated technician cancellations after acceptance (last 7 days).
        try {
            const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
            const cancels = await countTrustEvents({
                userId: technicianId,
                reason: "job_cancelled_after_acceptance",
                eventType: "job_cancelled",
                since,
            });
            if (cancels >= 3) {
                const windowStart = admin.firestore.Timestamp.fromDate(since);
                const windowEnd = admin.firestore.Timestamp.now();
                await ensureFraudAlert({
                    type: "repeat_cancellation",
                    userId: technicianId,
                    technicianId,
                    jobId,
                    riskScore: Math.min(92, 58 + cancels * 10),
                    reason: "High cancellation rate by technician after acceptance in last 7 days.",
                    signals: { cancelsLast7Days: cancels, threshold: 3, cancelledBy: "technician" },
                    windowStart,
                    windowEnd,
                });
            }
        }
        catch (e) {
            functions.logger.warn("Failed to evaluate repeat_cancellation (technician)", { jobId, error: e });
        }
    }
    return { ok: true };
});
/** Callable: apply penalty points to dealer (admin or system). */
exports.applyDealerPenalty = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    const uid = data === null || data === void 0 ? void 0 : data.uid;
    const points = data === null || data === void 0 ? void 0 : data.points;
    if (!uid || points == null || points < 0) {
        throw new functions.https.HttpsError("invalid-argument", "uid and points required");
    }
    const caller = (_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid;
    const callerSnap = caller ? await db.collection("users").doc(caller).get() : null;
    const isAdmin = ((_b = callerSnap === null || callerSnap === void 0 ? void 0 : callerSnap.data()) === null || _b === void 0 ? void 0 : _b.role) === "superadmin";
    if (!isAdmin)
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const userRef = db.collection("users").doc(uid);
    await userRef.set({
        dealerPenaltyPoints: admin.firestore.FieldValue.increment(points),
    }, { merge: true });
    const snap = await userRef.get();
    const total = (_d = (_c = snap.data()) === null || _c === void 0 ? void 0 : _c.dealerPenaltyPoints) !== null && _d !== void 0 ? _d : 0;
    await userRef.set({ accountStatus: (0, reputation_1.accountStatusFromPoints)(total) }, { merge: true });
    return { ok: true, total };
});
/** Callable: apply penalty points to technician (admin or system). */
exports.applyTechnicianPenalty = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    const uid = data === null || data === void 0 ? void 0 : data.uid;
    const points = data === null || data === void 0 ? void 0 : data.points;
    if (!uid || points == null || points < 0) {
        throw new functions.https.HttpsError("invalid-argument", "uid and points required");
    }
    const caller = (_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid;
    const callerSnap = caller ? await db.collection("users").doc(caller).get() : null;
    const isAdmin = ((_b = callerSnap === null || callerSnap === void 0 ? void 0 : callerSnap.data()) === null || _b === void 0 ? void 0 : _b.role) === "superadmin";
    if (!isAdmin)
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const userRef = db.collection("users").doc(uid);
    await userRef.set({
        technicianPenaltyPoints: admin.firestore.FieldValue.increment(points),
    }, { merge: true });
    const snap = await userRef.get();
    const total = (_d = (_c = snap.data()) === null || _c === void 0 ? void 0 : _c.technicianPenaltyPoints) !== null && _d !== void 0 ? _d : 0;
    await userRef.set({ accountStatus: (0, reputation_1.accountStatusFromPoints)(total) }, { merge: true });
    return { ok: true, total };
});
/** Callable: superadmin suspend a user (dealer/technician). */
exports.suspendUser = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const uid = data === null || data === void 0 ? void 0 : data.uid;
    const days = (_a = data === null || data === void 0 ? void 0 : data.days) !== null && _a !== void 0 ? _a : 7;
    const reason = (_b = data === null || data === void 0 ? void 0 : data.reason) !== null && _b !== void 0 ? _b : "suspended_by_admin";
    if (!uid || days <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "uid and positive days required");
    }
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    const isAdmin = ((_c = callerSnap.data()) === null || _c === void 0 ? void 0 : _c.role) === "superadmin";
    if (!isAdmin)
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const until = new Date();
    until.setDate(until.getDate() + Math.min(90, Math.floor(days)));
    await db.collection("users").doc(uid).set({
        accountStatus: "suspended",
        job_block_until: admin.firestore.Timestamp.fromDate(until),
        online: false,
        availabilityStatus: "offline",
    }, { merge: true });
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "user_suspended",
        targetUserId: uid,
        details: { days, reason, job_block_until: until.toISOString() },
    });
    return { ok: true, suspendedUntil: until.toISOString() };
});
/** Callable: superadmin reactivate a user (clears suspension/block). */
exports.reactivateUser = functions.https.onCall(async (data, context) => {
    var _a, _b;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const uid = data === null || data === void 0 ? void 0 : data.uid;
    const reason = (_a = data === null || data === void 0 ? void 0 : data.reason) !== null && _a !== void 0 ? _a : "reactivated_by_admin";
    if (!uid)
        throw new functions.https.HttpsError("invalid-argument", "uid required");
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    const isAdmin = ((_b = callerSnap.data()) === null || _b === void 0 ? void 0 : _b.role) === "superadmin";
    if (!isAdmin)
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    await db.collection("users").doc(uid).set({
        accountStatus: "active",
        job_block_until: admin.firestore.FieldValue.delete(),
        availabilityStatus: "offline",
        online: false,
    }, { merge: true });
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "user_reactivated",
        targetUserId: uid,
        details: { reason },
    });
    return { ok: true };
});
/** Callable: resolve a fraud alert and write audit log. */
exports.resolveFraudAlert = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const alertId = data === null || data === void 0 ? void 0 : data.alertId;
    const note = (_a = data === null || data === void 0 ? void 0 : data.note) !== null && _a !== void 0 ? _a : "";
    if (!alertId)
        throw new functions.https.HttpsError("invalid-argument", "alertId required");
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    const isAdmin = ((_b = callerSnap.data()) === null || _b === void 0 ? void 0 : _b.role) === "superadmin";
    if (!isAdmin)
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const ref = db.collection("fraud_alerts").doc(alertId);
    const snap = await ref.get();
    if (!snap.exists)
        throw new functions.https.HttpsError("not-found", "Alert not found");
    const d = (_c = snap.data()) !== null && _c !== void 0 ? _c : {};
    const userId = d.userId || d.dealerId || d.technicianId || undefined;
    const jobId = d.jobId || undefined;
    await ref.set({
        status: "resolved",
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        resolvedBy: context.auth.uid,
        resolveNote: note || null,
    }, { merge: true });
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "fraud_flag_removed",
        targetUserId: userId,
        targetJobId: jobId,
        details: { alertId, note },
    });
    return { ok: true };
});
/** Add a strike for a technician and apply block/suspension. Used by callables and by dispute/cancellation flows. */
async function addTechnicianStrikeAndApply(technicianId, strikeReason, strikeLevel, jobId, issuedByAdminId) {
    const now = new Date();
    const strikeRef = await db.collection("technician_strikes").add({
        technician_id: technicianId,
        strike_reason: strikeReason,
        strike_level: strikeLevel,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        issued_by_admin_id: issuedByAdminId !== null && issuedByAdminId !== void 0 ? issuedByAdminId : null,
        job_id: jobId !== null && jobId !== void 0 ? jobId : null,
        removed: false,
    });
    const snapshot = await db
        .collection("technician_strikes")
        .where("technician_id", "==", technicianId)
        .where("removed", "==", false)
        .get();
    const totalStrikes = snapshot.size;
    const userRef = db.collection("users").doc(technicianId);
    if (totalStrikes >= strikes_1.STRIKE_LEVEL_3) {
        const blockUntil = new Date(now);
        blockUntil.setDate(blockUntil.getDate() + strikes_1.JOB_BLOCK_DAYS_LEVEL_3);
        await userRef.set({ job_block_until: admin.firestore.Timestamp.fromDate(blockUntil), accountStatus: "suspended" }, { merge: true });
    }
    else if (totalStrikes >= strikes_1.STRIKE_LEVEL_2) {
        const blockUntil = new Date(now);
        blockUntil.setHours(blockUntil.getHours() + strikes_1.JOB_BLOCK_HOURS_LEVEL_2);
        await userRef.set({ job_block_until: admin.firestore.Timestamp.fromDate(blockUntil) }, { merge: true });
    }
    return { strikeId: strikeRef.id, totalStrikes };
}
/** Callable: admin (or system) add a strike to a technician. */
exports.addTechnicianStrike = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const technicianId = data === null || data === void 0 ? void 0 : data.technicianId;
    const reason = data === null || data === void 0 ? void 0 : data.reason;
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    if (!technicianId || !reason)
        throw new functions.https.HttpsError("invalid-argument", "technicianId and reason required");
    const validReasons = Object.keys(strikes_1.STRIKE_REASONS);
    if (!validReasons.includes(reason)) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid reason. Use: " + validReasons.join(", "));
    }
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    const isAdmin = ((_a = callerSnap.data()) === null || _a === void 0 ? void 0 : _a.role) === "superadmin";
    if (!isAdmin)
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const userSnap = await db.collection("users").doc(technicianId).get();
    if (!userSnap.exists || ((_b = userSnap.data()) === null || _b === void 0 ? void 0 : _b.role) !== "technician") {
        throw new functions.https.HttpsError("failed-precondition", "Technician not found");
    }
    const level = (_c = data === null || data === void 0 ? void 0 : data.strikeLevel) !== null && _c !== void 0 ? _c : 1;
    const { strikeId, totalStrikes } = await addTechnicianStrikeAndApply(technicianId, reason, level, jobId, context.auth.uid);
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "strike_added",
        targetUserId: technicianId,
        targetJobId: jobId !== null && jobId !== void 0 ? jobId : undefined,
        details: { strikeId, reason, strikeLevel: level, totalStrikes },
    });
    return { ok: true, strikeId, totalStrikes };
});
/** Callable: admin remove a strike (mark as removed and optionally clear block). */
exports.removeTechnicianStrike = functions.https.onCall(async (data, context) => {
    var _a, _b;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const strikeId = data === null || data === void 0 ? void 0 : data.strikeId;
    if (!strikeId)
        throw new functions.https.HttpsError("invalid-argument", "strikeId required");
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    if (((_a = callerSnap.data()) === null || _a === void 0 ? void 0 : _a.role) !== "superadmin") {
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    }
    const strikeSnap = await db.collection("technician_strikes").doc(strikeId).get();
    if (!strikeSnap.exists)
        throw new functions.https.HttpsError("not-found", "Strike not found");
    const technicianId = (_b = strikeSnap.data()) === null || _b === void 0 ? void 0 : _b.technician_id;
    await strikeSnap.ref.update({ removed: true });
    const snapshot = await db
        .collection("technician_strikes")
        .where("technician_id", "==", technicianId)
        .where("removed", "==", false)
        .get();
    const totalStrikes = snapshot.size;
    const userRef = db.collection("users").doc(technicianId);
    if (totalStrikes < strikes_1.STRIKE_LEVEL_2) {
        await userRef.update({
            job_block_until: admin.firestore.FieldValue.delete(),
            accountStatus: "active",
        });
    }
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "strike_removed",
        targetUserId: technicianId,
        details: { strikeId, totalStrikesAfter: totalStrikes },
    });
    return { ok: true, totalStrikes };
});
/** Callable: request OTP for job step. Stores in Firestore; sends SMS via Twilio if configured.
 * When Twilio is NOT configured: sends OTP to technician via FCM so they can use it (dev/testing). */
exports.sendOtp = functions.https.onCall(async (data, context) => {
    var _a, _b;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    const purpose = data === null || data === void 0 ? void 0 : data.purpose;
    if (!jobId || !purpose)
        throw new functions.https.HttpsError("invalid-argument", "jobId and purpose required");
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date();
    expiresAt.setMinutes(expiresAt.getMinutes() + 10);
    await db.collection("otps").doc(`${jobId}_${purpose}`).set({
        code,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const twilioConfig = (0, config_1.getExternalConfig)().twilio;
    let smsSent = false;
    if (twilioConfig) {
        const jobSnap = await db.collection("jobs").doc(jobId).get();
        const job = jobSnap.data();
        let phone;
        if (purpose === "material_return_confirm") {
            const dealerId = job === null || job === void 0 ? void 0 : job.dealerId;
            if (dealerId) {
                const dealerSnap = await db.collection("users").doc(dealerId).get();
                const dealerData = dealerSnap.data();
                phone = ((_a = dealerData === null || dealerData === void 0 ? void 0 : dealerData.profile) === null || _a === void 0 ? void 0 : _a.phone) || (dealerData === null || dealerData === void 0 ? void 0 : dealerData.phone);
            }
        }
        else {
            phone =
                purpose === "pickup"
                    ? (job === null || job === void 0 ? void 0 : job.pickupContactPhone) || (job === null || job === void 0 ? void 0 : job.siteContactPhone)
                    : (job === null || job === void 0 ? void 0 : job.siteContactPhone) || (job === null || job === void 0 ? void 0 : job.pickupContactPhone);
        }
        if (phone) {
            try {
                const twilio = require("twilio");
                const client = twilio(twilioConfig.accountSid, twilioConfig.authToken);
                await client.messages.create({
                    body: `Your OTP for DG Yard Connect (${purpose}) is ${code}. Valid for 10 minutes.`,
                    from: twilioConfig.phoneNumber,
                    to: phone.startsWith("+") ? phone : `+91${phone}`,
                });
                smsSent = true;
            }
            catch (e) {
                functions.logger.warn("Twilio SMS failed", e);
            }
        }
    }
    // When Twilio not configured or SMS failed: send OTP to technician via FCM so they can use it
    if (!smsSent) {
        const technicianId = context.auth.uid;
        const techSnap = await db.collection("users").doc(technicianId).get();
        const tokens = getAllFcmTokens((_b = techSnap.data()) !== null && _b !== void 0 ? _b : {});
        const otpMessage = `OTP for ${purpose}: ${code}. Valid 10 min.`;
        for (const token of tokens) {
            try {
                await messaging.send({
                    token,
                    notification: { title: "DG Yard Connect – OTP", body: otpMessage },
                    data: { jobId, purpose, type: "otp" },
                    android: { priority: "high" },
                    apns: { payload: { aps: { alert: { title: "OTP", body: otpMessage }, sound: "default" } } },
                });
                functions.logger.info("OTP sent via FCM to technician (Twilio not configured or failed)", { jobId, purpose });
                break;
            }
            catch (e) {
                functions.logger.warn("FCM OTP to technician failed", e);
            }
        }
        // Return OTP in response when SMS not sent (for in-app display – e.g. testing, or when FCM fails)
        return { sent: true, devOtp: code };
    }
    return { sent: true };
});
/** Callable: verify OTP for job step; returns success. */
exports.verifyOtp = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    const purpose = data === null || data === void 0 ? void 0 : data.purpose;
    const code = data === null || data === void 0 ? void 0 : data.code;
    if (!jobId || !purpose || !code) {
        throw new functions.https.HttpsError("invalid-argument", "jobId, purpose, code required");
    }
    const otpRef = db.collection("otps").doc(`${jobId}_${purpose}`);
    const otpSnap = await otpRef.get();
    if (!otpSnap.exists)
        throw new functions.https.HttpsError("not-found", "OTP not found");
    const otp = otpSnap.data();
    const stored = otp.code;
    const expires = (_c = (_b = (_a = otp.expiresAt) === null || _a === void 0 ? void 0 : _a.toMillis) === null || _b === void 0 ? void 0 : _b.call(_a)) !== null && _c !== void 0 ? _c : 0;
    const actorId = context.auth.uid;
    async function recordOtpFailure(failure) {
        var _a;
        try {
            const userSnap = await db.collection("users").doc(actorId).get();
            const role = ((_a = userSnap.data()) === null || _a === void 0 ? void 0 : _a.role) || "";
            // Only technicians can attempt job-completion related OTP verification.
            if (role !== "technician")
                return;
            await db.collection("otp_failures").add({
                userId: actorId,
                jobId,
                purpose,
                failure,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
            const failuresSnap = await db
                .collection("otp_failures")
                .where("userId", "==", actorId)
                .where("createdAt", ">", admin.firestore.Timestamp.fromDate(since))
                .get();
            const failures = failuresSnap.size;
            if (failures >= 3) {
                await ensureFraudAlert({
                    type: "fake_completion",
                    userId: actorId,
                    technicianId: actorId,
                    jobId,
                    riskScore: Math.min(95, 60 + failures * 10),
                    reason: "Repeated OTP verification failures in a short time window.",
                    signals: { failuresLast24h: failures, threshold: 3, purpose },
                    windowStart: admin.firestore.Timestamp.fromDate(since),
                    windowEnd: admin.firestore.Timestamp.now(),
                });
            }
        }
        catch (e) {
            functions.logger.warn("OTP failure tracking failed", { jobId, purpose, error: e });
        }
    }
    if (Date.now() > expires) {
        await recordOtpFailure("expired");
        throw new functions.https.HttpsError("failed-precondition", "OTP expired");
    }
    if (stored !== code) {
        await recordOtpFailure("invalid_code");
        throw new functions.https.HttpsError("invalid-argument", "Invalid code");
    }
    await otpRef.delete();
    if (purpose === "pickup") {
        const jobRef = db.collection("jobs").doc(jobId);
        await jobRef.update({
            pickupConfirmed: true,
            pickupConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
            executionPhase: "going_to_job",
        });
        const jobSnap = await jobRef.get();
        const job = jobSnap.data();
        const dealerId = job === null || job === void 0 ? void 0 : job.dealerId;
        if (dealerId) {
            const dealerSnap = await db.collection("users").doc(dealerId).get();
            const tokens = getAllFcmTokens((_d = dealerSnap.data()) !== null && _d !== void 0 ? _d : {});
            for (const t of tokens) {
                await sendFcmNotification(t, "Pickup confirmed", "Technician confirmed material pickup. Tap to view details.", {
                    jobId,
                    type: "pickup_confirmed",
                    target: "dealer",
                });
            }
        }
    }
    if (purpose === "material_return_confirm") {
        await db.collection("jobs").doc(jobId).update({
            status: "completed",
            materialReturnCompleted: true,
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    return { verified: true };
});
/** Callable: customer submits rating via link (unauthenticated; token required). */
exports.submitCustomerRating = functions.https.onCall(async (data, context) => {
    var _a;
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    const token = data === null || data === void 0 ? void 0 : data.token;
    const dealerRating = data === null || data === void 0 ? void 0 : data.dealerRating;
    const technicianRating = data === null || data === void 0 ? void 0 : data.technicianRating;
    const dealerReview = data === null || data === void 0 ? void 0 : data.dealerReview;
    const technicianReview = data === null || data === void 0 ? void 0 : data.technicianReview;
    if (!jobId || !token)
        throw new functions.https.HttpsError("invalid-argument", "jobId and token required");
    if ((dealerRating == null || dealerRating < 1) && (technicianRating == null || technicianRating < 1)) {
        throw new functions.https.HttpsError("invalid-argument", "At least one rating (dealer or technician) required");
    }
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const storedToken = (_a = jobSnap.data()) === null || _a === void 0 ? void 0 : _a.customerRatingToken;
    if (!storedToken || storedToken !== token) {
        throw new functions.https.HttpsError("permission-denied", "Invalid or expired link");
    }
    const updates = {};
    if (dealerRating != null && dealerRating >= 1)
        updates.customerRatingToDealer = dealerRating;
    if (dealerReview != null && dealerReview.trim())
        updates.customerReviewToDealer = dealerReview.trim();
    if (technicianRating != null && technicianRating >= 1)
        updates.customerRatingToTechnician = technicianRating;
    if (technicianReview != null && technicianReview.trim())
        updates.customerReviewToTechnician = technicianReview.trim();
    await jobSnap.ref.update(updates);
    functions.logger.info("Customer rating submitted", { jobId });
    return { ok: true };
});
/** Send SMS, Email, WhatsApp on job complete via Twilio and SendGrid when configured. */
async function sendJobCompleteNotifications(jobId, customerRatingToken, baseUrl) {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j;
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    const job = jobSnap.data() || {};
    // If anyone has already rated, don't send rating link
    const customerRated = job.customerRatingToDealer != null || job.customerRatingToTechnician != null;
    const dealerRated = job.dealerRatingToTechnician != null;
    const technicianRated = job.technicianRatingToDealer != null;
    const anyRated = customerRated || dealerRated || technicianRated;
    const ratingLink = !anyRated && customerRatingToken && baseUrl
        ? `${baseUrl.replace(/\/$/, "")}/customer/rate?jobId=${jobId}&token=${customerRatingToken}`
        : "";
    const message = ratingLink
        ? `Job completed. Rate your experience: ${ratingLink}`
        : "Job completed.";
    const dealerId = job.dealerId;
    const technicianId = job.technicianId;
    const siteContactPhone = job.siteContactPhone || "";
    const twilioConfig = (0, config_1.getExternalConfig)().twilio;
    const sendgridConfig = (0, config_1.getExternalConfig)().sendgrid;
    if (sendgridConfig && (dealerId || technicianId)) {
        try {
            const sgMail = require("@sendgrid/mail");
            sgMail.setApiKey(sendgridConfig.apiKey);
            const to = [];
            if (dealerId) {
                const d = await db.collection("users").doc(dealerId).get();
                const email = ((_a = d.data()) === null || _a === void 0 ? void 0 : _a.email) || ((_c = (_b = d.data()) === null || _b === void 0 ? void 0 : _b.profile) === null || _c === void 0 ? void 0 : _c.email);
                if (email)
                    to.push({ email });
            }
            if (technicianId) {
                const t = await db.collection("users").doc(technicianId).get();
                const email = ((_d = t.data()) === null || _d === void 0 ? void 0 : _d.email) || ((_f = (_e = t.data()) === null || _e === void 0 ? void 0 : _e.profile) === null || _f === void 0 ? void 0 : _f.email);
                if (email && !to.some((x) => x.email === email))
                    to.push({ email });
            }
            if (to.length > 0) {
                await sgMail.send({
                    to: to.map((x) => x.email),
                    from: sendgridConfig.fromEmail,
                    subject: "DG Yard Connect – Job completed",
                    text: message,
                });
            }
        }
        catch (e) {
            functions.logger.warn("SendGrid email failed", e);
        }
    }
    if (twilioConfig) {
        const twilio = require("twilio");
        const client = twilio(twilioConfig.accountSid, twilioConfig.authToken);
        const toSms = [dealerId, technicianId].filter((id) => Boolean(id));
        for (const uid of toSms) {
            const u = await db.collection("users").doc(uid).get();
            const phone = ((_h = (_g = u.data()) === null || _g === void 0 ? void 0 : _g.profile) === null || _h === void 0 ? void 0 : _h.phone) || ((_j = u.data()) === null || _j === void 0 ? void 0 : _j.phone);
            if (phone) {
                try {
                    await client.messages.create({
                        body: message,
                        from: twilioConfig.phoneNumber,
                        to: phone.startsWith("+") ? phone : `+91${phone}`,
                    });
                }
                catch (_) { }
            }
        }
        if (siteContactPhone) {
            try {
                await client.messages.create({
                    body: message,
                    from: twilioConfig.phoneNumber,
                    to: siteContactPhone.startsWith("+") ? siteContactPhone : `+91${siteContactPhone}`,
                });
            }
            catch (_) { }
            if (twilioConfig.whatsappNumber) {
                try {
                    const waTo = siteContactPhone.startsWith("+") ? siteContactPhone : `+91${siteContactPhone}`;
                    await client.messages.create({
                        body: message,
                        from: `whatsapp:${twilioConfig.whatsappNumber}`,
                        to: `whatsapp:${waTo}`,
                    });
                }
                catch (_) { }
            }
        }
    }
    if (ratingLink)
        functions.logger.info("Job complete notifications. Customer rating link:", { ratingLink });
}
/** HTTP: TwiML for masked call – when customer answers, dial technician so both are connected. */
/** Callable: technician requests withdrawal. Validates amount <= availableBalance; when Razorpay Payouts is configured, creates payout and deducts. */
exports.requestWithdrawal = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const uid = context.auth.uid;
    const userSnap = await db.collection("users").doc(uid).get();
    const role = (_a = userSnap.data()) === null || _a === void 0 ? void 0 : _a.role;
    if (role !== "technician")
        throw new functions.https.HttpsError("permission-denied", "Technicians only");
    const amount = typeof (data === null || data === void 0 ? void 0 : data.amount) === "number" ? data.amount : parseFloat(data === null || data === void 0 ? void 0 : data.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
        throw new functions.https.HttpsError("invalid-argument", "Valid amount required");
    }
    const walletSnap = await db.collection("wallets").doc(uid).get();
    const wallet = (_b = walletSnap.data()) !== null && _b !== void 0 ? _b : {};
    const available = (_c = wallet.availableBalance) !== null && _c !== void 0 ? _c : 0;
    if (amount > available) {
        throw new functions.https.HttpsError("invalid-argument", "Amount exceeds available balance");
    }
    const razorpayConfig = (0, config_1.getExternalConfig)().razorpay;
    if (!razorpayConfig) {
        return { ok: false, reason: "payout_not_configured", message: "Withdrawal will be available when Razorpay payout is configured." };
    }
    const settlementSnap = await db.collection("users").doc(uid).collection("settlement_accounts").get();
    const userPrimaryId = (_d = userSnap.data()) === null || _d === void 0 ? void 0 : _d.primarySettlementAccountId;
    const payoutCapable = (d) => (d.data().status === "verified" || d.data().status === "created") && !!d.data().razorpayFundAccountId;
    const primaryAccount = userPrimaryId
        ? settlementSnap.docs.find((d) => d.id === userPrimaryId)
        : settlementSnap.docs.find((d) => d.data().isPrimary === true);
    const fallbackAccount = settlementSnap.docs.find((d) => payoutCapable(d));
    const accountToUse = primaryAccount && payoutCapable(primaryAccount) ? primaryAccount : fallbackAccount;
    if (!accountToUse) {
        return {
            ok: false,
            reason: "no_settlement_account",
            message: "Add a bank account or UPI in Settlement Account and set one as primary for withdrawals.",
        };
    }
    const fundAccountId = accountToUse.data().razorpayFundAccountId;
    if (!fundAccountId) {
        return {
            ok: false,
            reason: "account_not_verified",
            message: "Your primary payout account is not payout-ready. Please verify bank/UPI account or set a payout-capable primary account.",
        };
    }
    const xAccountNumber = razorpayConfig.xAccountNumber;
    if (!xAccountNumber) {
        return { ok: false, reason: "payout_not_configured", message: "Withdrawal will be available when RazorpayX account is configured (razorpay.x_account_number)." };
    }
    const amountPaise = Math.round(amount * 100);
    const refId = `wd_${uid}_${Date.now()}`;
    const auth = Buffer.from(`${razorpayConfig.keyId}:${razorpayConfig.keySecret}`).toString("base64");
    let payoutId;
    try {
        const payoutRes = await fetch("https://api.razorpay.com/v1/payouts", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Basic ${auth}`,
                "X-Payout-Idempotency": refId,
            },
            body: JSON.stringify({
                account_number: xAccountNumber,
                fund_account: { id: fundAccountId },
                amount: amountPaise,
                currency: "INR",
                mode: "NEFT",
                purpose: "payout",
                reference_id: refId,
                narration: `D.G.Yard Connect withdrawal`,
            }),
        });
        const payoutJson = (await payoutRes.json());
        if (!payoutRes.ok || !payoutJson.id) {
            const errMsg = ((_e = payoutJson.error) === null || _e === void 0 ? void 0 : _e.description) || payoutRes.statusText || "Payout failed";
            functions.logger.warn("Razorpay payout failed", { status: payoutRes.status, body: payoutJson });
            return { ok: false, reason: "payout_failed", message: errMsg };
        }
        payoutId = payoutJson.id;
    }
    catch (e) {
        functions.logger.error("Razorpay payout error", e);
        return { ok: false, reason: "payout_failed", message: e.message };
    }
    const techData = (_f = userSnap.data()) !== null && _f !== void 0 ? _f : {};
    const techProfile = (_g = techData.profile) !== null && _g !== void 0 ? _g : {};
    const technicianName = techProfile.name || techData.name || "Technician";
    const payoutRef = db.collection("technician_payouts").doc();
    await db.runTransaction(async (tx) => {
        const walletRef = db.collection("wallets").doc(uid);
        tx.update(walletRef, { availableBalance: admin.firestore.FieldValue.increment(-amount) });
        tx.set(payoutRef, {
            technicianId: uid,
            technicianName,
            amount,
            transferId: payoutId,
            payoutDate: admin.firestore.FieldValue.serverTimestamp(),
            status: "created",
            referenceId: refId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    functions.logger.info("Withdrawal completed", { uid, amount, payoutId });
    return { ok: true, transferId: payoutId };
});
exports.twimlMaskedCall = functions.https.onRequest((req, res) => {
    const to = req.query.to;
    if (!to) {
        res.status(400).send("Missing to");
        return;
    }
    const phone = to.startsWith("+") ? to : `+91${to}`;
    res.type("text/xml").send(`<?xml version="1.0" encoding="UTF-8"?><Response><Say>Connecting you to the technician.</Say><Dial><Number>${phone}</Number></Dial></Response>`);
});
/** Callable: initiate masked call (Twilio). Customer or dealer is called; when they answer, technician is dialed. */
exports.initMaskedCall = functions.https.onCall(async (data, context) => {
    var _a, _b, _c, _d, _e, _f, _g;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const jobId = data === null || data === void 0 ? void 0 : data.jobId;
    if (!jobId)
        throw new functions.https.HttpsError("invalid-argument", "jobId required");
    const target = (data === null || data === void 0 ? void 0 : data.target) || "customer";
    const jobSnap = await db.collection("jobs").doc(jobId).get();
    if (!jobSnap.exists)
        throw new functions.https.HttpsError("not-found", "Job not found");
    const job = jobSnap.data();
    let calleePhone;
    let calleeLabel;
    if (target === "dealer") {
        const dealerId = job.dealerId;
        if (!dealerId) {
            throw new functions.https.HttpsError("failed-precondition", "No dealer for this job");
        }
        const dealerSnap = await db.collection("users").doc(dealerId).get();
        const dealerData = dealerSnap.data();
        const dealerPhone = ((_a = dealerData === null || dealerData === void 0 ? void 0 : dealerData.profile) === null || _a === void 0 ? void 0 : _a.phone) || (dealerData === null || dealerData === void 0 ? void 0 : dealerData.phone) || "";
        if (!dealerPhone || !String(dealerPhone).trim()) {
            throw new functions.https.HttpsError("failed-precondition", "No dealer phone for this job");
        }
        calleePhone = String(dealerPhone).startsWith("+") ? String(dealerPhone) : `+91${String(dealerPhone)}`;
        calleeLabel = "Dealer";
    }
    else {
        const siteContactPhone = job.siteContactPhone || "";
        if (!siteContactPhone.trim()) {
            throw new functions.https.HttpsError("failed-precondition", "No site contact phone for this job");
        }
        calleePhone = siteContactPhone.startsWith("+") ? siteContactPhone : `+91${siteContactPhone}`;
        calleeLabel = "Customer";
    }
    const twilioConfig = (0, config_1.getExternalConfig)().twilio;
    if (!twilioConfig) {
        return { ok: true, message: "Masked call will be available when Twilio is configured." };
    }
    const technicianId = job.technicianId;
    let technicianPhone = null;
    if (technicianId) {
        const techSnap = await db.collection("users").doc(technicianId).get();
        technicianPhone = ((_c = (_b = techSnap.data()) === null || _b === void 0 ? void 0 : _b.profile) === null || _c === void 0 ? void 0 : _c.phone) || ((_d = techSnap.data()) === null || _d === void 0 ? void 0 : _d.phone) || null;
    }
    if (!technicianPhone) {
        const callerSnap = await db.collection("users").doc(context.auth.uid).get();
        technicianPhone = ((_f = (_e = callerSnap.data()) === null || _e === void 0 ? void 0 : _e.profile) === null || _f === void 0 ? void 0 : _f.phone) || ((_g = callerSnap.data()) === null || _g === void 0 ? void 0 : _g.phone) || null;
    }
    if (!technicianPhone) {
        throw new functions.https.HttpsError("failed-precondition", "No technician/caller phone to connect");
    }
    const twilio = require("twilio");
    const client = twilio(twilioConfig.accountSid, twilioConfig.authToken);
    const baseUrl = twilioConfig.twimlBaseUrl ||
        `https://us-central1-${process.env.GCLOUD_PROJECT || "dg-yard-8c195"}.cloudfunctions.net`;
    const twimlUrl = `${baseUrl.replace(/\/$/, "")}/twimlMaskedCall?to=${encodeURIComponent(technicianPhone)}`;
    await client.calls.create({
        to: calleePhone,
        from: twilioConfig.phoneNumber,
        url: twimlUrl,
    });
    functions.logger.info("Masked call initiated", { jobId, calleePhone, target });
    return { ok: true, message: `Call initiated. ${calleeLabel} will receive a call from the platform number.` };
});
/**
 * Callable (superadmin): publish app update config to Firebase Remote Config.
 *
 * The admin app calls this. Client apps only READ Remote Config.
 */
exports.setAppUpdateConfig = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    const role = ((_a = callerSnap.data()) === null || _a === void 0 ? void 0 : _a.role) || "";
    if (role !== "superadmin")
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    let latest = ((_b = data === null || data === void 0 ? void 0 : data.app_latest_version) === null || _b === void 0 ? void 0 : _b.trim()) || "";
    let min = ((_c = data === null || data === void 0 ? void 0 : data.app_min_supported_version) === null || _c === void 0 ? void 0 : _c.trim()) || "";
    const source = ((data === null || data === void 0 ? void 0 : data.app_update_source) || "playstore").trim().toLowerCase();
    const title = ((data === null || data === void 0 ? void 0 : data.app_update_title) || "").trim();
    const message = ((data === null || data === void 0 ? void 0 : data.app_update_message) || "").trim();
    const changelog = ((data === null || data === void 0 ? void 0 : data.app_update_changelog) || "").trim();
    const updateUrl = ((data === null || data === void 0 ? void 0 : data.app_update_url) || "").trim();
    const apkUrl = ((data === null || data === void 0 ? void 0 : data.app_update_apk_url) || "").trim();
    if (source !== "apk" && source !== "playstore") {
        throw new functions.https.HttpsError("invalid-argument", "Invalid source");
    }
    if (source === "apk" && !apkUrl)
        throw new functions.https.HttpsError("invalid-argument", "APK URL required");
    if (source === "playstore" && !updateUrl)
        throw new functions.https.HttpsError("invalid-argument", "Update URL required");
    // Auto-extract version from URL if admin didn't provide it.
    const tryExtractVersion = (rawUrl) => {
        if (!rawUrl)
            return null;
        try {
            const u = new URL(rawUrl);
            const qp = (u.searchParams.get("version") || u.searchParams.get("v") || "").trim();
            if (qp) {
                const m = /v?(\d+\.\d+\.\d+)/.exec(qp);
                if (m === null || m === void 0 ? void 0 : m[1])
                    return m[1];
            }
        }
        catch (_) { }
        const decoded = decodeURIComponent(rawUrl);
        const m3 = /(?:^|[^0-9])v?(\d+\.\d+\.\d+)(?:[^0-9]|$)/.exec(decoded);
        if (m3 === null || m3 === void 0 ? void 0 : m3[1])
            return m3[1];
        const m2 = /(?:^|[^0-9])v?(\d+\.\d+)(?:[^0-9]|$)/.exec(decoded);
        if (m2 === null || m2 === void 0 ? void 0 : m2[1])
            return `${m2[1]}.0`;
        return null;
    };
    if (!latest) {
        latest = tryExtractVersion(source === "apk" ? apkUrl : updateUrl) || "";
    }
    if (!min) {
        // Default: optional update (min = latest). Admin can set min lower/higher if needed.
        min = latest;
    }
    if (!latest || !min) {
        throw new functions.https.HttpsError("invalid-argument", "Version missing. Provide app_latest_version/app_min_supported_version or include version in the URL (e.g. ?version=1.2.3 or filename v1.2.3.apk).");
    }
    // Update Remote Config template.
    const rc = admin.remoteConfig();
    const template = await rc.getTemplate();
    const setParam = (key, value) => {
        template.parameters[key] = {
            defaultValue: { value: value !== null && value !== void 0 ? value : "" },
        };
    };
    setParam("app_latest_version", latest);
    setParam("app_min_supported_version", min);
    setParam("app_update_source", source);
    setParam("app_update_title", title);
    setParam("app_update_message", message);
    setParam("app_update_changelog", changelog);
    setParam("app_update_url", updateUrl);
    setParam("app_update_apk_url", apkUrl);
    // Unique ID per publish to prevent repeated prompts for same release.
    setParam("app_update_release_id", String(Date.now()));
    await rc.publishTemplate(template);
    // Save a copy to Firestore for admin UI + history.
    await db.collection("config").doc("app_update").set({
        latestVersion: latest,
        minSupportedVersion: min,
        source,
        title,
        message,
        changelog,
        updateUrl,
        apkUrl,
        updatedBy: context.auth.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "app_update_configured",
        details: { latest, minSupported: min, source },
    });
    return { ok: true };
});
/**
 * Callable (superadmin): publish runtime UI/text/flags to Firebase Remote Config.
 *
 * Keys:
 * - ui_primary_color_hex
 * - app_texts_json
 * - feature_flags_json
 */
exports.setAppRuntimeConfig = functions.https.onCall(async (data, context) => {
    var _a;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    const role = ((_a = callerSnap.data()) === null || _a === void 0 ? void 0 : _a.role) || "";
    if (role !== "superadmin")
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const primary = ((data === null || data === void 0 ? void 0 : data.ui_primary_color_hex) || "").trim();
    const textsJson = ((data === null || data === void 0 ? void 0 : data.app_texts_json) || "{}").trim() || "{}";
    const flagsJson = ((data === null || data === void 0 ? void 0 : data.feature_flags_json) || "{}").trim() || "{}";
    // Basic validation (avoid publishing broken JSON).
    try {
        JSON.parse(textsJson);
    }
    catch (_) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid app_texts_json");
    }
    try {
        JSON.parse(flagsJson);
    }
    catch (_) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid feature_flags_json");
    }
    if (primary && !/^#?[0-9a-fA-F]{6,8}$/.test(primary)) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid ui_primary_color_hex");
    }
    const rc = admin.remoteConfig();
    const template = await rc.getTemplate();
    const setParam = (key, value) => {
        template.parameters[key] = {
            defaultValue: { value: value !== null && value !== void 0 ? value : "" },
        };
    };
    setParam("ui_primary_color_hex", primary);
    setParam("app_texts_json", textsJson);
    setParam("feature_flags_json", flagsJson);
    await rc.publishTemplate(template);
    await db.collection("config").doc("app_runtime").set({
        uiPrimaryColorHex: primary,
        appTextsJson: textsJson,
        featureFlagsJson: flagsJson,
        updatedBy: context.auth.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "app_runtime_configured",
        details: { primarySet: !!primary },
    });
    return { ok: true };
});
/**
 * Callable (superadmin): send a push notification with deep-link payload.
 *
 * Payload keys supported by app:
 * - type or screen: job | chat | offer | general | ...
 * - job_id (or jobId)
 * - target: dealer | technician (optional)
 */
exports.sendAdminPush = functions.https.onCall(async (data, context) => {
    var _a, _b, _c;
    if (!context.auth)
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    const callerSnap = await db.collection("users").doc(context.auth.uid).get();
    const role = ((_a = callerSnap.data()) === null || _a === void 0 ? void 0 : _a.role) || "";
    if (role !== "superadmin")
        throw new functions.https.HttpsError("permission-denied", "Admin only");
    const audience = ((data === null || data === void 0 ? void 0 : data.audience) || "uid").trim().toLowerCase();
    const uid = ((_b = data === null || data === void 0 ? void 0 : data.uid) === null || _b === void 0 ? void 0 : _b.trim()) || "";
    const title = ((data === null || data === void 0 ? void 0 : data.title) || "Notification").trim();
    const body = ((data === null || data === void 0 ? void 0 : data.body) || "").trim();
    const type = ((data === null || data === void 0 ? void 0 : data.type) || (data === null || data === void 0 ? void 0 : data.screen) || "general").trim().toLowerCase();
    const jobId = ((data === null || data === void 0 ? void 0 : data.job_id) || (data === null || data === void 0 ? void 0 : data.jobId) || "").trim();
    const target = ((data === null || data === void 0 ? void 0 : data.target) || "").trim().toLowerCase();
    const imageUrl = ((data === null || data === void 0 ? void 0 : data.image_url) || (data === null || data === void 0 ? void 0 : data.imageUrl) || "").trim();
    const resolvedImageUrl = imageUrl || (await resolveBrandKitImageUrl());
    let tokens = [];
    if (audience === "uid") {
        if (!uid)
            throw new functions.https.HttpsError("invalid-argument", "uid required for audience=uid");
        const userSnap = await db.collection("users").doc(uid).get();
        if (!userSnap.exists)
            throw new functions.https.HttpsError("not-found", "User not found");
        tokens = getAllFcmTokens((_c = userSnap.data()) !== null && _c !== void 0 ? _c : {});
    }
    else if (audience === "dealer" || audience === "technician" || audience === "all") {
        tokens = await collectTokensForAudience(audience);
    }
    else {
        throw new functions.https.HttpsError("invalid-argument", "Invalid audience");
    }
    tokens = Array.from(new Set(tokens)).filter((t) => typeof t === "string" && t.length > 0);
    if (tokens.length === 0)
        throw new functions.https.HttpsError("failed-precondition", "No FCM tokens found for audience");
    const payload = {
        title,
        body,
        type,
        screen: type, // alias for clients that use "screen"
    };
    if (jobId) {
        payload.job_id = jobId;
        payload.jobId = jobId;
    }
    if (target === "dealer" || target === "technician") {
        payload.target = target;
    }
    if (resolvedImageUrl) {
        payload.image_url = resolvedImageUrl;
        payload.imageUrl = resolvedImageUrl;
    }
    let sent = 0;
    const chunks = [];
    for (let i = 0; i < tokens.length; i += 500)
        chunks.push(tokens.slice(i, i + 500));
    for (const batch of chunks) {
        try {
            const res = await messaging.sendEachForMulticast({
                tokens: batch,
                notification: { title, body },
                data: payload,
                android: {
                    priority: "high",
                    notification: resolvedImageUrl ? { imageUrl: resolvedImageUrl } : undefined,
                },
                apns: {
                    payload: { aps: { alert: { title, body }, sound: "default" } },
                    fcmOptions: resolvedImageUrl ? { imageUrl: resolvedImageUrl } : undefined,
                },
            });
            sent += res.successCount || 0;
        }
        catch (e) {
            functions.logger.warn("Admin multicast push failed", { audience, error: e });
        }
    }
    await (0, audit_1.writeAuditLog)(db, {
        adminId: context.auth.uid,
        actionType: "admin_push_sent",
        targetUserId: audience === "uid" ? uid : undefined,
        details: { kind: "admin_push", audience, uid, type, jobId, target, sent, tokenCount: tokens.length },
    });
    return { ok: true, sent, tokenCount: tokens.length };
});
async function resolveBrandKitImageUrl() {
    try {
        const snap = await db.collection("config").doc("brand_kit").get();
        const d = snap.data();
        const urlCandidates = [
            (d === null || d === void 0 ? void 0 : d.animatedAppIconUrl) || "",
            (d === null || d === void 0 ? void 0 : d.appIcon512Url) || "",
            (d === null || d === void 0 ? void 0 : d.logoColorUrl) || "",
            (d === null || d === void 0 ? void 0 : d.logoWhiteUrl) || "",
            (d === null || d === void 0 ? void 0 : d.appIconUrl) || "",
        ].map((s) => (typeof s === "string" ? s.trim() : "")).filter((s) => s.length > 0);
        const first = urlCandidates[0] || "";
        if (!first)
            return "";
        if (!/^https?:\/\//i.test(first))
            return "";
        return first;
    }
    catch (_) {
        return "";
    }
}
async function collectTokensForAudience(audience) {
    var _a, _b;
    let q = db.collection("users");
    if (audience === "dealer" || audience === "technician") {
        q = q.where("role", "==", audience);
    }
    const tokens = [];
    let last = null;
    for (;;) {
        let page = q.orderBy(admin.firestore.FieldPath.documentId()).limit(500);
        if (last)
            page = page.startAfter(last);
        const snap = await page.get();
        if (snap.empty)
            break;
        for (const doc of snap.docs) {
            tokens.push(...getAllFcmTokens((_a = doc.data()) !== null && _a !== void 0 ? _a : {}));
        }
        last = (_b = snap.docs[snap.docs.length - 1]) !== null && _b !== void 0 ? _b : null;
        if (snap.size < 500)
            break;
    }
    return tokens;
}
//# sourceMappingURL=index.js.map