import 'package:cloud_firestore/cloud_firestore.dart';

import 'marketplace_price_tier.dart';

class MarketplaceCartItem {
  const MarketplaceCartItem({
    required this.id,
    required this.catalogProductId,
    required this.quantity,
    required this.titleSnapshot,
    required this.pricePaiseSnapshot,
    required this.moq,
    this.priceTiers = const [],
  });

  final String id;
  final String catalogProductId;
  final int quantity;
  final String titleSnapshot;
  /// Unit price at [quantity] when [priceTiers] is empty; otherwise kept in sync for display.
  final int pricePaiseSnapshot;
  final int moq;
  final List<MarketplacePriceTier> priceTiers;

  int unitPaiseForQuantity(int qty) {
    if (priceTiers.isEmpty) return pricePaiseSnapshot;
    return MarketplacePriceTier.pricePaiseForQuantity(priceTiers, qty);
  }

  int lineSubtotalPaise() => unitPaiseForQuantity(quantity) * quantity;

  static MarketplaceCartItem? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final tiers = MarketplacePriceTier.listFromFirestore(data['price_tiers_snapshot']);
    return MarketplaceCartItem(
      id: doc.id,
      catalogProductId: (data['catalog_product_id'] as String?) ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      titleSnapshot: (data['title_snapshot'] as String?) ?? '',
      pricePaiseSnapshot: (data['price_paise_snapshot'] as num?)?.toInt() ?? 0,
      moq: (data['moq'] as num?)?.toInt() ?? 1,
      priceTiers: tiers,
    );
  }

  Map<String, dynamic> toWriteMap() {
    return {
      'catalog_product_id': catalogProductId,
      'quantity': quantity,
      'title_snapshot': titleSnapshot,
      'price_paise_snapshot': pricePaiseSnapshot,
      'moq': moq,
      'price_tiers_snapshot': MarketplacePriceTier.listToFirestore(priceTiers),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
