"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DISPUTE_SEVERITY_DEDUCTION = exports.DEFAULT_TRUST_SCORE = void 0;
exports.getReputationLevel = getReputationLevel;
exports.applyTrustScoreDelta = applyTrustScoreDelta;
exports.getTechnicianLevelFromTrustScore = getTechnicianLevelFromTrustScore;
exports.computeTechnicianLevel = computeTechnicianLevel;
exports.computeDealerLevel = computeDealerLevel;
exports.computeTrustScore = computeTrustScore;
exports.accountStatusFromPoints = accountStatusFromPoints;
/** Default trust score for new users (0–100 scale). */
exports.DEFAULT_TRUST_SCORE = 70;
function getReputationLevel(score) {
    if (score >= 90)
        return "elite";
    if (score >= 75)
        return "trusted";
    if (score >= 60)
        return "standard";
    if (score >= 40)
        return "risky";
    return "restricted";
}
/** Apply a delta to current trust score; returns clamped 0–100. */
function applyTrustScoreDelta(current, delta) {
    return Math.max(0, Math.min(100, Math.round(current + delta)));
}
function getTechnicianLevelFromTrustScore(score) {
    if (score >= 85)
        return "elite";
    if (score >= 70)
        return "gold";
    if (score >= 50)
        return "silver";
    return "bronze";
}
/** @deprecated Use getTechnicianLevelFromTrustScore(trustScore) for technicians. Kept for any legacy reads. */
function computeTechnicianLevel(totalJobsCompleted, avgRating) {
    if (totalJobsCompleted >= 500 && avgRating >= 4.7)
        return "elite";
    if (totalJobsCompleted >= 200 && avgRating >= 4.5)
        return "gold";
    if (totalJobsCompleted >= 50 && avgRating >= 4)
        return "silver";
    return "bronze";
}
/** Dealer: basic < trusted < premium < enterprise */
function computeDealerLevel(totalJobsCompleted, avgRating) {
    if (totalJobsCompleted >= 500 && avgRating >= 4.5)
        return "enterprise";
    if (totalJobsCompleted >= 100 && avgRating >= 4)
        return "premium";
    if (totalJobsCompleted >= 20)
        return "trusted";
    return "basic";
}
/** Trust score 0–100: rating contribution + completion contribution - penalty (legacy formula; new users use DEFAULT_TRUST_SCORE + deltas). */
function computeTrustScore(avgRating, totalJobsCompleted, penaltyPoints) {
    const ratingPart = Math.min(50, avgRating * 10);
    const jobPart = Math.min(40, Math.log(totalJobsCompleted + 1) * 8);
    const penaltyDeduction = Math.min(90, penaltyPoints * 3);
    return Math.max(0, Math.min(100, Math.round(ratingPart + jobPart - penaltyDeduction)));
}
/** accountStatus from penalty points */
function accountStatusFromPoints(points) {
    if (points >= 20)
        return "suspended";
    if (points >= 10)
        return "temporarily_blocked";
    if (points >= 5)
        return "warning";
    return "active";
}
/** Dispute severity trust score deduction (admin sets on resolve). */
exports.DISPUTE_SEVERITY_DEDUCTION = {
    low: -2,
    medium: -5,
    high: -10,
};
//# sourceMappingURL=reputation.js.map