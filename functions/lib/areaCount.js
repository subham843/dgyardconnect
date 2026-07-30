"use strict";
/**
 * Area count callables: count technicians/dealers in same area for home screen stats.
 * Uses server-side Firestore read (admin) so client rules don't block the query.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDealerCountInArea = exports.getTechnicianCountInArea = void 0;
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const jobMatching_1 = require("./jobMatching");
const MAX_DISTANCE_KM = 75;
function lat(sa) {
    if (!sa)
        return null;
    const v = sa.latitude;
    if (v == null)
        return null;
    if (typeof v === "number" && !Number.isNaN(v))
        return v;
    const n = Number(v);
    return Number.isNaN(n) ? null : n;
}
function lng(sa) {
    if (!sa)
        return null;
    const v = sa.longitude;
    if (v == null)
        return null;
    if (typeof v === "number" && !Number.isNaN(v))
        return v;
    const n = Number(v);
    return Number.isNaN(n) ? null : n;
}
function normalizeArea(s) {
    var _a;
    if (s == null || String(s).trim() === "")
        return null;
    const t = String(s).trim().toLowerCase();
    const first = (_a = t.split(/[,\-]/)[0]) === null || _a === void 0 ? void 0 : _a.trim();
    return (first && first.length > 0) ? first : t;
}
function areaLabelMatches(a, b) {
    const na = normalizeArea(a);
    const nb = normalizeArea(b);
    if (na == null || nb == null)
        return false;
    if (na === nb)
        return true;
    return na.includes(nb) || nb.includes(na);
}
/** Callable: returns count of approved technicians in dealer's area (distance or city match). */
exports.getTechnicianCountInArea = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    }
    const serviceArea = data === null || data === void 0 ? void 0 : data.serviceArea;
    const db = admin.firestore();
    const dealerLat = lat(serviceArea);
    const dealerLng = lng(serviceArea);
    const dealerCity = serviceArea === null || serviceArea === void 0 ? void 0 : serviceArea.city;
    const dealerAddress = serviceArea === null || serviceArea === void 0 ? void 0 : serviceArea.addressLabel;
    const dealerLabel = dealerCity !== null && dealerCity !== void 0 ? dealerCity : dealerAddress;
    const snap = await db.collection("users")
        .where("role", "==", "technician")
        .where("approved", "==", true)
        .limit(500)
        .get();
    let count = 0;
    for (const doc of snap.docs) {
        const sa = doc.data().serviceArea;
        const techLat = lat(sa);
        const techLng = lng(sa);
        const techCity = sa === null || sa === void 0 ? void 0 : sa.city;
        const techAddress = sa === null || sa === void 0 ? void 0 : sa.addressLabel;
        const techLabel = techCity !== null && techCity !== void 0 ? techCity : techAddress;
        let counted = false;
        if (dealerLat != null && dealerLng != null && techLat != null && techLng != null) {
            const km = (0, jobMatching_1.haversineKm)(dealerLat, dealerLng, techLat, techLng);
            if (km <= MAX_DISTANCE_KM) {
                count++;
                counted = true;
            }
        }
        if (!counted && dealerLabel && String(dealerLabel).trim() && techLabel) {
            if (areaLabelMatches(dealerLabel, techLabel)) {
                count++;
            }
        }
    }
    return { count };
});
/** Callable: returns count of approved dealers in technician's area (distance or city match). */
exports.getDealerCountInArea = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Sign in required");
    }
    const serviceArea = data === null || data === void 0 ? void 0 : data.serviceArea;
    const db = admin.firestore();
    const techLat = lat(serviceArea);
    const techLng = lng(serviceArea);
    const techCity = serviceArea === null || serviceArea === void 0 ? void 0 : serviceArea.city;
    const techAddress = serviceArea === null || serviceArea === void 0 ? void 0 : serviceArea.addressLabel;
    const techLabel = techCity !== null && techCity !== void 0 ? techCity : techAddress;
    const snap = await db.collection("users")
        .where("role", "==", "dealer")
        .where("approved", "==", true)
        .limit(500)
        .get();
    let count = 0;
    for (const doc of snap.docs) {
        const sa = doc.data().serviceArea;
        const dealerLat = lat(sa);
        const dealerLng = lng(sa);
        const dealerCity = sa === null || sa === void 0 ? void 0 : sa.city;
        const dealerAddress = sa === null || sa === void 0 ? void 0 : sa.addressLabel;
        const dealerLabel = dealerCity !== null && dealerCity !== void 0 ? dealerCity : dealerAddress;
        let counted = false;
        if (techLat != null && techLng != null && dealerLat != null && dealerLng != null) {
            const km = (0, jobMatching_1.haversineKm)(techLat, techLng, dealerLat, dealerLng);
            if (km <= MAX_DISTANCE_KM) {
                count++;
                counted = true;
            }
        }
        if (!counted && techLabel && String(techLabel).trim() && dealerLabel) {
            if (areaLabelMatches(techLabel, dealerLabel)) {
                count++;
            }
        }
    }
    return { count };
});
//# sourceMappingURL=areaCount.js.map