/// Quantity break pricing (B2B). [maxQty] null means no upper limit (open-ended band).
class MarketplacePriceTier {
  const MarketplacePriceTier({
    required this.minQty,
    this.maxQty,
    required this.pricePaise,
  });

  final int minQty;
  final int? maxQty;
  final int pricePaise;

  Map<String, dynamic> toFirestoreMap() => {
        'min_qty': minQty,
        if (maxQty != null) 'max_qty': maxQty,
        'price_paise': pricePaise,
      };

  static MarketplacePriceTier? fromDynamic(dynamic e) {
    if (e is! Map) return null;
    final min = (e['min_qty'] as num?)?.toInt();
    final price = (e['price_paise'] as num?)?.toInt();
    if (min == null || min < 1 || price == null || price < 0) return null;
    final hasMax = e.containsKey('max_qty') && e['max_qty'] != null;
    final max = hasMax ? (e['max_qty'] as num?)?.toInt() : null;
    if (max != null && max < min) return null;
    return MarketplacePriceTier(minQty: min, maxQty: max, pricePaise: price);
  }

  static List<MarketplacePriceTier> listFromFirestore(dynamic v) {
    if (v is! List) return const [];
    final out = v.map(fromDynamic).whereType<MarketplacePriceTier>().toList();
    out.sort((a, b) => a.minQty.compareTo(b.minQty));
    return out;
  }

  static List<Map<String, dynamic>> listToFirestore(List<MarketplacePriceTier> tiers) =>
      tiers.map((e) => e.toFirestoreMap()).toList(growable: false);

  /// Unit price (paise) for [quantity] using the first matching tier; fallback last tier or 0.
  static int pricePaiseForQuantity(List<MarketplacePriceTier> tiers, int quantity) {
    if (tiers.isEmpty || quantity < 1) return 0;
    final q = quantity;
    for (final t in tiers) {
      if (q < t.minQty) continue;
      if (t.maxQty == null || q <= t.maxQty!) {
        return t.pricePaise;
      }
    }
    return tiers.last.pricePaise;
  }

  /// Display line e.g. "1–5 pcs"
  String quantityLabel() {
    if (maxQty == null) return '$minQty+ pcs';
    return '$minQty–$maxQty pcs';
  }
}
