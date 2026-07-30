import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/services/firestore_service.dart';

class MarketplaceRfqRepository {
  Future<String> submitRfq({
    required String buyerUid,
    required String title,
    required String notes,
    String? companyGstin,
  }) async {
    if (!FirestoreService.isAvailable) throw StateError('Firestore unavailable');
    final ref = FirestoreService.marketplaceRfqs().doc();
    await ref.set({
      'buyer_uid': buyerUid,
      'title': title,
      'notes': notes,
      'company_gstin': companyGstin,
      'status': 'submitted',
      'created_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBuyerRfqs(String buyerUid) {
    return FirestoreService.marketplaceRfqs()
        .where('buyer_uid', isEqualTo: buyerUid)
        .snapshots();
  }
}
