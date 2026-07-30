"use strict";
/**
 * Smart Job Matching + Fair Technician Queue.
 * Eligibility: sector, subsector, skills, online, service radius (10 km max), not busy.
 * Queue order: distance 40%, trust 30%, rating 20%, response 10%; elite boost; rotation (recent completers to end); skip penalty (no-response).
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.haversineKm = haversineKm;
exports.getEligibleTechnicianIds = getEligibleTechnicianIds;
exports.getBatchSize = getBatchSize;
const MAX_SERVICE_RADIUS_KM = 10;
const BATCH_SIZE_FIXED = 5;
const BATCH_SIZE_BIDDING = 10;
const WEIGHT_DISTANCE = 0.4;
const WEIGHT_TRUST = 0.3;
const WEIGHT_RATING = 0.2;
const WEIGHT_RESPONSE = 0.1;
/** Priority boost for elite technicians (highest visibility, priority notifications). */
const ELITE_BOOST = 0.05;
/** Smaller boost for gold technicians (higher visibility). */
const GOLD_BOOST = 0.02;
/** Penalty when technician did not respond to last notification within window. */
const IGNORED_NOTIFICATION_PENALTY = 0.2;
/** After completing a job, technician moves to end of queue for this long (ms). */
const QUEUE_ROTATION_WINDOW_MS = 24 * 60 * 60 * 1000;
/** Window for "no response" penalty (ms). */
const NOTIFICATION_IGNORED_PENALTY_WINDOW_MS = 60 * 60 * 1000;
/** Haversine distance in km between two lat/lng points. */
function haversineKm(lat1, lng1, lat2, lng2) {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((lat1 * Math.PI) / 180) *
            Math.cos((lat2 * Math.PI) / 180) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}
function getJobLatLng(job) {
    if (job.jobLat != null && job.jobLng != null) {
        return { lat: job.jobLat, lng: job.jobLng };
    }
    const gp = job.location;
    if (gp && gp.latitude != null && gp.longitude != null) {
        return { lat: gp.latitude, lng: gp.longitude };
    }
    return null;
}
function getPickupLatLng(job) {
    const gp = job.pickupLocation;
    if (gp && gp.latitude != null && gp.longitude != null) {
        return { lat: gp.latitude, lng: gp.longitude };
    }
    return null;
}
/** Compute distance for ranking: job only, or tech→pickup→job if material pickup. */
function computeDistanceKm(job, techLat, techLng) {
    const jobPoint = getJobLatLng(job);
    if (!jobPoint)
        return 0;
    const hasPickup = job.materialOption === "pickup" && getPickupLatLng(job) != null;
    if (!hasPickup) {
        return haversineKm(techLat, techLng, jobPoint.lat, jobPoint.lng);
    }
    const pickup = getPickupLatLng(job);
    const d1 = haversineKm(techLat, techLng, pickup.lat, pickup.lng);
    const d2 = haversineKm(pickup.lat, pickup.lng, jobPoint.lat, jobPoint.lng);
    return d1 + d2;
}
/** Check if job location is within technician's service radius (max 10 km). */
function isWithinServiceRadius(job, techLat, techLng, radiusKm) {
    const jobPoint = getJobLatLng(job);
    if (!jobPoint)
        return true;
    const capped = Math.min(radiusKm, MAX_SERVICE_RADIUS_KM);
    const d = haversineKm(techLat, techLng, jobPoint.lat, jobPoint.lng);
    return d <= capped;
}
/**
 * Get eligible technician IDs for a job in fair queue order.
 * Eligibility: sector/subsector via skills, online, service area (max 10 km), not busy, not already offered.
 * Queue order: score (distance, trust, rating, response, elite boost, rejection/ignore penalties) then rotation (recent completers to end).
 * Queue resets implicitly: we always build from current DB state (online, busy, service area, trust), so offline/busy/area/trust changes reset order.
 */
async function getEligibleTechnicianIds(db, job, excludeTechnicianIds = []) {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const subsectorId = job.subOptionId || job.sectorSubOptionId || "";
    if (!subsectorId) {
        return [];
    }
    const skillsSnap = await db
        .collection("skills")
        .where("sectorSubOptionId", "==", subsectorId)
        .get();
    const skillIdsForSubsector = skillsSnap.docs.map((d) => d.id);
    if (skillIdsForSubsector.length === 0) {
        return [];
    }
    // Do not filter by online here – include offline technicians so they still get notified
    // (e.g. single technician in area); online ones are preferred via scoring below.
    const techniciansSnap = await db
        .collection("users")
        .where("role", "==", "technician")
        .where("approved", "==", true)
        .get();
    const jobPoint = getJobLatLng(job);
    if (!jobPoint) {
        return [];
    }
    const activeJobSnap = await db
        .collection("jobs")
        .where("status", "in", [
        "posted",
        "bidding",
        "agreed",
        "payment_pending",
        "paid",
        "in_progress",
        "pending_dealer_confirm",
    ])
        .get();
    const busyTechnicianIds = new Set();
    activeJobSnap.docs.forEach((d) => {
        const tid = d.data().technicianId;
        if (tid)
            busyTechnicianIds.add(tid);
    });
    const offeredSet = new Set(excludeTechnicianIds);
    const candidates = [];
    for (const doc of techniciansSnap.docs) {
        const id = doc.id;
        if (busyTechnicianIds.has(id) || offeredSet.has(id))
            continue;
        const data = doc.data();
        const availabilityStatus = data.availabilityStatus;
        if (availabilityStatus === "busy")
            continue;
        const status = data.accountStatus;
        if (status === "suspended" || status === "temporarily_blocked")
            continue;
        const jobBlockUntil = data.job_block_until;
        if (jobBlockUntil && jobBlockUntil.toMillis && jobBlockUntil.toMillis() > Date.now())
            continue;
        const skills = data.skills || [];
        const hasSkillForSubsector = skillIdsForSubsector.some((sid) => skills.includes(sid));
        if (!hasSkillForSubsector)
            continue;
        const serviceArea = data.serviceArea || {};
        const rawLat = serviceArea.latitude;
        const rawLng = serviceArea.longitude;
        const techLat = typeof rawLat === "number" && !Number.isNaN(rawLat)
            ? rawLat
            : (typeof rawLat === "string" ? Number(rawLat) : 0) || 0;
        const techLng = typeof rawLng === "number" && !Number.isNaN(rawLng)
            ? rawLng
            : (typeof rawLng === "string" ? Number(rawLng) : 0) || 0;
        const radiusKm = Math.min((typeof serviceArea.radiusKm === "number" ? serviceArea.radiusKm : Number(serviceArea.radiusKm) || MAX_SERVICE_RADIUS_KM), MAX_SERVICE_RADIUS_KM);
        if (!isWithinServiceRadius(job, techLat, techLng, radiusKm))
            continue;
        const distanceKm = computeDistanceKm(job, techLat, techLng);
        const trustScore = (_a = data.trustScore) !== null && _a !== void 0 ? _a : 70;
        const avgRating = (_b = data.avgRating) !== null && _b !== void 0 ? _b : 0;
        const totalJobsCompleted = (_c = data.totalJobsCompleted) !== null && _c !== void 0 ? _c : 0;
        const rejectionCountLastHour = (_d = data.rejectionCountLastHour) !== null && _d !== void 0 ? _d : 0;
        const lastJobCompletedAt = data.lastJobCompletedAt;
        const lastNotificationIgnoredAt = data.lastNotificationIgnoredAt;
        const reputationLevel = data.reputationLevel;
        const technicianLevel = data.technicianLevel;
        const isOnline = data.online === true;
        candidates.push({
            id,
            trustScore,
            avgRating,
            totalJobsCompleted,
            distanceKm,
            rejectionCountLastHour,
            lastJobCompletedAtMs: (_f = (_e = lastJobCompletedAt === null || lastJobCompletedAt === void 0 ? void 0 : lastJobCompletedAt.toMillis) === null || _e === void 0 ? void 0 : _e.call(lastJobCompletedAt)) !== null && _f !== void 0 ? _f : null,
            lastNotificationIgnoredAtMs: (_h = (_g = lastNotificationIgnoredAt === null || lastNotificationIgnoredAt === void 0 ? void 0 : lastNotificationIgnoredAt.toMillis) === null || _g === void 0 ? void 0 : _g.call(lastNotificationIgnoredAt)) !== null && _h !== void 0 ? _h : null,
            reputationLevel: reputationLevel !== null && reputationLevel !== void 0 ? reputationLevel : null,
            technicianLevel: technicianLevel !== null && technicianLevel !== void 0 ? technicianLevel : null,
            isOnline,
        });
    }
    const maxDistance = Math.max(...candidates.map((c) => c.distanceKm), 1);
    const maxTrust = 100;
    const maxRating = 5;
    const nowMs = Date.now();
    const ONLINE_BOOST = 0.15;
    function score(c) {
        var _a;
        const distNorm = 1 - c.distanceKm / maxDistance;
        const trustNorm = c.trustScore / maxTrust;
        const ratingNorm = c.avgRating / maxRating;
        const responseNorm = Math.min(1, c.totalJobsCompleted / 50);
        const cooldownPenalty = Math.min(0.5, ((_a = c.rejectionCountLastHour) !== null && _a !== void 0 ? _a : 0) * 0.1);
        const levelBoost = c.technicianLevel === "elite" ? ELITE_BOOST
            : c.technicianLevel === "gold" ? GOLD_BOOST
                : 0;
        const onlineBoost = c.isOnline === true ? ONLINE_BOOST : 0;
        const ignoredPenalty = c.lastNotificationIgnoredAtMs != null &&
            nowMs - c.lastNotificationIgnoredAtMs < NOTIFICATION_IGNORED_PENALTY_WINDOW_MS
            ? IGNORED_NOTIFICATION_PENALTY
            : 0;
        return (WEIGHT_DISTANCE * distNorm +
            WEIGHT_TRUST * trustNorm +
            WEIGHT_RATING * ratingNorm +
            WEIGHT_RESPONSE * responseNorm -
            cooldownPenalty +
            levelBoost +
            onlineBoost -
            ignoredPenalty);
    }
    candidates.sort((a, b) => score(b) - score(a));
    // Queue rotation: technicians who recently completed a job move to end of queue (fair distribution).
    const completedRecently = candidates.filter((c) => c.lastJobCompletedAtMs != null &&
        nowMs - c.lastJobCompletedAtMs < QUEUE_ROTATION_WINDOW_MS);
    const rest = candidates.filter((c) => c.lastJobCompletedAtMs == null ||
        nowMs - c.lastJobCompletedAtMs >= QUEUE_ROTATION_WINDOW_MS);
    const ordered = [...rest, ...completedRecently];
    return ordered.map((c) => c.id);
}
function getBatchSize(job) {
    return job.biddingEnabled ? BATCH_SIZE_BIDDING : BATCH_SIZE_FIXED;
}
//# sourceMappingURL=jobMatching.js.map