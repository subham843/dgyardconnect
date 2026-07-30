/**
 * Area count callables: count technicians/dealers in same area for home screen stats.
 * Uses server-side Firestore read (admin) so client rules don't block the query.
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { haversineKm } from "./jobMatching";

const MAX_DISTANCE_KM = 75;

function lat(sa: Record<string, unknown> | null | undefined): number | null {
  if (!sa) return null;
  const v = sa.latitude;
  if (v == null) return null;
  if (typeof v === "number" && !Number.isNaN(v)) return v;
  const n = Number(v);
  return Number.isNaN(n) ? null : n;
}

function lng(sa: Record<string, unknown> | null | undefined): number | null {
  if (!sa) return null;
  const v = sa.longitude;
  if (v == null) return null;
  if (typeof v === "number" && !Number.isNaN(v)) return v;
  const n = Number(v);
  return Number.isNaN(n) ? null : n;
}

function normalizeArea(s: string | null | undefined): string | null {
  if (s == null || String(s).trim() === "") return null;
  const t = String(s).trim().toLowerCase();
  const first = t.split(/[,\-]/)[0]?.trim();
  return (first && first.length > 0) ? first : t;
}

function areaLabelMatches(a: string | null | undefined, b: string | null | undefined): boolean {
  const na = normalizeArea(a);
  const nb = normalizeArea(b);
  if (na == null || nb == null) return false;
  if (na === nb) return true;
  return na.includes(nb) || nb.includes(na);
}

/** Callable: returns count of approved technicians in dealer's area (distance or city match). */
export const getTechnicianCountInArea = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }
  const serviceArea = data?.serviceArea as Record<string, unknown> | null | undefined;
  const db = admin.firestore();
  const dealerLat = lat(serviceArea);
  const dealerLng = lng(serviceArea);
  const dealerCity = serviceArea?.city as string | null | undefined;
  const dealerAddress = serviceArea?.addressLabel as string | null | undefined;
  const dealerLabel = dealerCity ?? dealerAddress;

  const snap = await db.collection("users")
    .where("role", "==", "technician")
    .where("approved", "==", true)
    .limit(500)
    .get();

  let count = 0;
  for (const doc of snap.docs) {
    const sa = doc.data().serviceArea as Record<string, unknown> | null | undefined;
    const techLat = lat(sa);
    const techLng = lng(sa);
    const techCity = sa?.city as string | null | undefined;
    const techAddress = sa?.addressLabel as string | null | undefined;
    const techLabel = techCity ?? techAddress;

    let counted = false;
    if (dealerLat != null && dealerLng != null && techLat != null && techLng != null) {
      const km = haversineKm(dealerLat, dealerLng, techLat, techLng);
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
export const getDealerCountInArea = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required");
  }
  const serviceArea = data?.serviceArea as Record<string, unknown> | null | undefined;
  const db = admin.firestore();
  const techLat = lat(serviceArea);
  const techLng = lng(serviceArea);
  const techCity = serviceArea?.city as string | null | undefined;
  const techAddress = serviceArea?.addressLabel as string | null | undefined;
  const techLabel = techCity ?? techAddress;

  const snap = await db.collection("users")
    .where("role", "==", "dealer")
    .where("approved", "==", true)
    .limit(500)
    .get();

  let count = 0;
  for (const doc of snap.docs) {
    const sa = doc.data().serviceArea as Record<string, unknown> | null | undefined;
    const dealerLat = lat(sa);
    const dealerLng = lng(sa);
    const dealerCity = sa?.city as string | null | undefined;
    const dealerAddress = sa?.addressLabel as string | null | undefined;
    const dealerLabel = dealerCity ?? dealerAddress;

    let counted = false;
    if (techLat != null && techLng != null && dealerLat != null && dealerLng != null) {
      const km = haversineKm(techLat, techLng, dealerLat, dealerLng);
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
