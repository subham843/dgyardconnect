"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserMarketplaceSellerSuspended = void 0;
/**
 * Marketplace Firestore triggers: e.g. delist live catalog when seller is suspended.
 */
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
function getDb() {
    return admin.firestore();
}
exports.onUserMarketplaceSellerSuspended = functions.firestore
    .document("users/{userId}")
    .onUpdate(async (change, context) => {
    var _a, _b;
    const before = (_a = change.before.data()) === null || _a === void 0 ? void 0 : _a.marketplace_seller_status;
    const after = (_b = change.after.data()) === null || _b === void 0 ? void 0 : _b.marketplace_seller_status;
    if (after !== "suspended" || before === "suspended")
        return;
    const userId = context.params.userId;
    const listings = await getDb()
        .collection("marketplace_listings")
        .where("seller_uid", "==", userId)
        .where("status", "==", "published")
        .get();
    if (listings.empty) {
        functions.logger.info("marketplace: seller suspended, no published listings", { userId });
        return;
    }
    let batch = getDb().batch();
    let n = 0;
    for (const doc of listings.docs) {
        const catId = doc.data().catalog_product_id;
        if (!catId)
            continue;
        batch.update(getDb().collection("marketplace_catalog").doc(catId), {
            listing_status: "offline",
            delisted_reason: "seller_suspended",
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        n++;
        if (n >= 400) {
            await batch.commit();
            batch = getDb().batch();
            n = 0;
        }
    }
    if (n > 0)
        await batch.commit();
    functions.logger.info("marketplace: delisted catalog for suspended seller", {
        userId,
        count: listings.docs.length,
    });
});
//# sourceMappingURL=marketplaceTriggers.js.map