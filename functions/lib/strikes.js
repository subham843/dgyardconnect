"use strict";
/**
 * Technician strike and penalty system.
 * Strike 1 → warning; Strike 2 → 24h job block; Strike 3 → 7 day suspension from jobs.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.JOB_BLOCK_DAYS_LEVEL_3 = exports.JOB_BLOCK_HOURS_LEVEL_2 = exports.STRIKE_LEVEL_3 = exports.STRIKE_LEVEL_2 = exports.STRIKE_LEVEL_1 = exports.STRIKE_REASONS = void 0;
exports.STRIKE_REASONS = {
    job_cancellation_after_acceptance: "Repeated job cancellations after acceptance",
    no_show: "No-show at job location",
    dispute_loss: "Repeated dispute losses",
    warranty_claim_failure: "Repeated warranty claim failures",
    fake_completion_attempt: "Fake job completion attempts",
};
exports.STRIKE_LEVEL_1 = 1; // warning notification
exports.STRIKE_LEVEL_2 = 2; // 24 hour job acceptance block
exports.STRIKE_LEVEL_3 = 3; // 7 day suspension from receiving jobs
exports.JOB_BLOCK_HOURS_LEVEL_2 = 24;
exports.JOB_BLOCK_DAYS_LEVEL_3 = 7;
//# sourceMappingURL=strikes.js.map