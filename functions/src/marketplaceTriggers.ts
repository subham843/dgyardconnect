/**
 * Marketplace Firestore triggers: e.g. delist live catalog when seller is suspended.
 */
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

function getDb(): admin.firestore.Firestore {
  return admin.firestore();
}

export const onUserMarketplaceSellerSuspended = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data()?.marketplace_seller_status as string | undefined;
    const after = change.after.data()?.marketplace_seller_status as string | undefined;
    if (after !== "suspended" || before === "suspended") return;

    const userId = context.params.userId as string;
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
      const catId = doc.data().catalog_product_id as string | undefined;
      if (!catId) continue;
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
    if (n > 0) await batch.commit();
    functions.logger.info("marketplace: delisted catalog for suspended seller", {
      userId,
      count: listings.docs.length,
    });
  });
