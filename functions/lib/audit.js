"use strict";
/**
 * System audit logging for admin actions. Super admin only read.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.writeAuditLog = writeAuditLog;
const admin = require("firebase-admin");
async function writeAuditLog(db, params) {
    var _a, _b, _c, _d;
    await db.collection("audit_logs").add({
        adminId: params.adminId,
        actionType: params.actionType,
        targetUserId: (_a = params.targetUserId) !== null && _a !== void 0 ? _a : null,
        targetJobId: (_b = params.targetJobId) !== null && _b !== void 0 ? _b : null,
        targetDisputeId: (_c = params.targetDisputeId) !== null && _c !== void 0 ? _c : null,
        details: (_d = params.details) !== null && _d !== void 0 ? _d : {},
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
}
//# sourceMappingURL=audit.js.map