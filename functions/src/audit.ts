/**
 * System audit logging for admin actions. Super admin only read.
 */

import * as admin from "firebase-admin";

export type AuditActionType =
  | "trust_score_adjusted"
  | "dispute_resolved"
  | "technician_level_changed"
  | "refund_issued"
  | "user_suspended"
  | "user_reactivated"
  | "strike_added"
  | "strike_removed"
  | "fraud_flag_removed"
  | "reliability_score_adjusted"
  | "app_update_configured"
  | "app_runtime_configured"
  | "admin_push_sent";

export async function writeAuditLog(
  db: admin.firestore.Firestore,
  params: {
    adminId: string;
    actionType: AuditActionType;
    targetUserId?: string;
    targetJobId?: string;
    targetDisputeId?: string;
    details?: Record<string, unknown>;
  }
): Promise<void> {
  await db.collection("audit_logs").add({
    adminId: params.adminId,
    actionType: params.actionType,
    targetUserId: params.targetUserId ?? null,
    targetJobId: params.targetJobId ?? null,
    targetDisputeId: params.targetDisputeId ?? null,
    details: params.details ?? {},
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}
