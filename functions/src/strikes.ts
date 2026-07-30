/**
 * Technician strike and penalty system.
 * Strike 1 → warning; Strike 2 → 24h job block; Strike 3 → 7 day suspension from jobs.
 */

export const STRIKE_REASONS = {
  job_cancellation_after_acceptance: "Repeated job cancellations after acceptance",
  no_show: "No-show at job location",
  dispute_loss: "Repeated dispute losses",
  warranty_claim_failure: "Repeated warranty claim failures",
  fake_completion_attempt: "Fake job completion attempts",
} as const;

export type StrikeReason = keyof typeof STRIKE_REASONS;

export const STRIKE_LEVEL_1 = 1; // warning notification
export const STRIKE_LEVEL_2 = 2; // 24 hour job acceptance block
export const STRIKE_LEVEL_3 = 3; // 7 day suspension from receiving jobs

export const JOB_BLOCK_HOURS_LEVEL_2 = 24;
export const JOB_BLOCK_DAYS_LEVEL_3 = 7;
