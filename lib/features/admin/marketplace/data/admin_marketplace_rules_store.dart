import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/services/firestore_service.dart';

/// Superadmin read/write for `config/marketplace_rules` (COD, pricing metadata, rollouts).
class AdminMarketplaceRulesStore {
  AdminMarketplaceRulesStore._();

  static DocumentReference<Map<String, dynamic>> get ref => FirestoreService.marketplaceRulesDoc();

  static Future<Map<String, dynamic>> loadOrEmpty() async {
    if (!FirestoreService.isAvailable) return {};
    final snap = await ref.get();
    return snap.data() ?? {};
  }

  static Future<void> merge(Map<String, dynamic> patch) async {
    if (!FirestoreService.isAvailable) return;
    await ref.set({
      ...patch,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
