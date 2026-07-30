/**
 * Smart Job Matching + Fair Technician Queue.
 * Eligibility: sector, subsector, skills, online, service radius (10 km max), not busy.
 * Queue order: distance 40%, trust 30%, rating 20%, response 10%; elite boost; rotation (recent completers to end); skip penalty (no-response).
 */

import * as admin from "firebase-admin";

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
export function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

export type JobForMatching = {
  sectorId?: string;
  subOptionId?: string;
  sectorSubOptionId?: string;
  jobLat?: number;
  jobLng?: number;
  location?: admin.firestore.GeoPoint;
  pickupLocation?: admin.firestore.GeoPoint;
  materialOption?: string;
  biddingEnabled?: boolean;
};

export interface TechnicianForRanking {
  id: string;
  trustScore: number;
  avgRating: number;
  totalJobsCompleted: number;
  distanceKm: number;
  rejectionCountLastHour?: number;
  /** When technician last completed a job (ms). Used to rotate to end of queue. */
  lastJobCompletedAtMs?: number | null;
  /** When technician last ignored a notification (no response in window) (ms). */
  lastNotificationIgnoredAtMs?: number | null;
  /** For queue priority boost (e.g. 'elite'). */
  reputationLevel?: string | null;
  /** Technician level from trust: bronze | silver | gold | elite. Used for visibility/priority. */
  technicianLevel?: string | null;
  /** Prefer online technicians in queue order. */
  isOnline?: boolean;
}

function getJobLatLng(job: JobForMatching): { lat: number; lng: number } | null {
  if (job.jobLat != null && job.jobLng != null) {
    return { lat: job.jobLat, lng: job.jobLng };
  }
  const gp = job.location as admin.firestore.GeoPoint | undefined;
  if (gp && gp.latitude != null && gp.longitude != null) {
    return { lat: gp.latitude, lng: gp.longitude };
  }
  return null;
}

function getPickupLatLng(job: JobForMatching): { lat: number; lng: number } | null {
  const gp = job.pickupLocation as admin.firestore.GeoPoint | undefined;
  if (gp && gp.latitude != null && gp.longitude != null) {
    return { lat: gp.latitude, lng: gp.longitude };
  }
  return null;
}

/** Compute distance for ranking: job only, or tech→pickup→job if material pickup. */
function computeDistanceKm(
  job: JobForMatching,
  techLat: number,
  techLng: number
): number {
  const jobPoint = getJobLatLng(job);
  if (!jobPoint) return 0;

  const hasPickup =
    job.materialOption === "pickup" && getPickupLatLng(job) != null;
  if (!hasPickup) {
    return haversineKm(techLat, techLng, jobPoint.lat, jobPoint.lng);
  }
  const pickup = getPickupLatLng(job)!;
  const d1 = haversineKm(techLat, techLng, pickup.lat, pickup.lng);
  const d2 = haversineKm(pickup.lat, pickup.lng, jobPoint.lat, jobPoint.lng);
  return d1 + d2;
}

/** Check if job location is within technician's service radius (max 10 km). */
function isWithinServiceRadius(
  job: JobForMatching,
  techLat: number,
  techLng: number,
  radiusKm: number
): boolean {
  const jobPoint = getJobLatLng(job);
  if (!jobPoint) return true;
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
export async function getEligibleTechnicianIds(
  db: admin.firestore.Firestore,
  job: JobForMatching,
  excludeTechnicianIds: string[] = []
): Promise<string[]> {
  const subsectorId =
    job.subOptionId || job.sectorSubOptionId || "";
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
  const busyTechnicianIds = new Set<string>();
  activeJobSnap.docs.forEach((d) => {
    const tid = d.data().technicianId as string | undefined;
    if (tid) busyTechnicianIds.add(tid);
  });

  const offeredSet = new Set(excludeTechnicianIds);
  const candidates: TechnicianForRanking[] = [];

  for (const doc of techniciansSnap.docs) {
    const id = doc.id;
    if (busyTechnicianIds.has(id) || offeredSet.has(id)) continue;

    const data = doc.data();
    const availabilityStatus = data.availabilityStatus as string | undefined;
    if (availabilityStatus === "busy") continue;
    const status = data.accountStatus as string | undefined;
    if (status === "suspended" || status === "temporarily_blocked") continue;
    const jobBlockUntil = data.job_block_until as admin.firestore.Timestamp | undefined;
    if (jobBlockUntil && jobBlockUntil.toMillis && jobBlockUntil.toMillis() > Date.now()) continue;

    const skills = (data.skills as string[] | undefined) || [];
    const hasSkillForSubsector = skillIdsForSubsector.some((sid) =>
      skills.includes(sid)
    );
    if (!hasSkillForSubsector) continue;

    const serviceArea = (data.serviceArea as Record<string, unknown>) || {};
    const rawLat = serviceArea.latitude;
    const rawLng = serviceArea.longitude;
    const techLat = typeof rawLat === "number" && !Number.isNaN(rawLat)
      ? rawLat
      : (typeof rawLat === "string" ? Number(rawLat) : 0) || 0;
    const techLng = typeof rawLng === "number" && !Number.isNaN(rawLng)
      ? rawLng
      : (typeof rawLng === "string" ? Number(rawLng) : 0) || 0;
    const radiusKm = Math.min(
      (typeof serviceArea.radiusKm === "number" ? serviceArea.radiusKm : Number(serviceArea.radiusKm) || MAX_SERVICE_RADIUS_KM),
      MAX_SERVICE_RADIUS_KM
    );

    if (!isWithinServiceRadius(job, techLat, techLng, radiusKm)) continue;

    const distanceKm = computeDistanceKm(job, techLat, techLng);
    const trustScore = (data.trustScore as number) ?? 70;
    const avgRating = (data.avgRating as number) ?? 0;
    const totalJobsCompleted = (data.totalJobsCompleted as number) ?? 0;
    const rejectionCountLastHour = (data.rejectionCountLastHour as number) ?? 0;
    const lastJobCompletedAt = data.lastJobCompletedAt as admin.firestore.Timestamp | undefined;
    const lastNotificationIgnoredAt = data.lastNotificationIgnoredAt as admin.firestore.Timestamp | undefined;
    const reputationLevel = data.reputationLevel as string | undefined;
    const technicianLevel = data.technicianLevel as string | undefined;
    const isOnline = data.online === true;

    candidates.push({
      id,
      trustScore,
      avgRating,
      totalJobsCompleted,
      distanceKm,
      rejectionCountLastHour,
      lastJobCompletedAtMs: lastJobCompletedAt?.toMillis?.() ?? null,
      lastNotificationIgnoredAtMs: lastNotificationIgnoredAt?.toMillis?.() ?? null,
      reputationLevel: reputationLevel ?? null,
      technicianLevel: technicianLevel ?? null,
      isOnline,
    });
  }

  const maxDistance = Math.max(
    ...candidates.map((c) => c.distanceKm),
    1
  );
  const maxTrust = 100;
  const maxRating = 5;
  const nowMs = Date.now();

  const ONLINE_BOOST = 0.15;
  function score(c: TechnicianForRanking): number {
    const distNorm = 1 - c.distanceKm / maxDistance;
    const trustNorm = c.trustScore / maxTrust;
    const ratingNorm = c.avgRating / maxRating;
    const responseNorm = Math.min(1, c.totalJobsCompleted / 50);
    const cooldownPenalty = Math.min(0.5, (c.rejectionCountLastHour ?? 0) * 0.1);
    const levelBoost =
      c.technicianLevel === "elite" ? ELITE_BOOST
      : c.technicianLevel === "gold" ? GOLD_BOOST
      : 0;
    const onlineBoost = c.isOnline === true ? ONLINE_BOOST : 0;
    const ignoredPenalty =
      c.lastNotificationIgnoredAtMs != null &&
      nowMs - c.lastNotificationIgnoredAtMs < NOTIFICATION_IGNORED_PENALTY_WINDOW_MS
        ? IGNORED_NOTIFICATION_PENALTY
        : 0;
    return (
      WEIGHT_DISTANCE * distNorm +
      WEIGHT_TRUST * trustNorm +
      WEIGHT_RATING * ratingNorm +
      WEIGHT_RESPONSE * responseNorm -
      cooldownPenalty +
      levelBoost +
      onlineBoost -
      ignoredPenalty
    );
  }

  candidates.sort((a, b) => score(b) - score(a));

  // Queue rotation: technicians who recently completed a job move to end of queue (fair distribution).
  const completedRecently = candidates.filter(
    (c) =>
      c.lastJobCompletedAtMs != null &&
      nowMs - c.lastJobCompletedAtMs < QUEUE_ROTATION_WINDOW_MS
  );
  const rest = candidates.filter(
    (c) =>
      c.lastJobCompletedAtMs == null ||
      nowMs - c.lastJobCompletedAtMs >= QUEUE_ROTATION_WINDOW_MS
  );
  const ordered = [...rest, ...completedRecently];
  return ordered.map((c) => c.id);
}

export function getBatchSize(job: JobForMatching): number {
  return job.biddingEnabled ? BATCH_SIZE_BIDDING : BATCH_SIZE_FIXED;
}
