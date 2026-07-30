/// Product pricing: MRP anchor, online (customer), dealer (B2B).
abstract final class ShopPricing {
  ShopPricing._();

  /// Percent discount from MRP when [price] is below [mrp]; null if not calculable.
  static double? discountPercentFromMrp(double? mrp, double? price) {
    if (mrp == null || price == null || mrp <= 0 || price <= 0) return null;
    if (price >= mrp) return 0;
    return ((mrp - price) / mrp) * 100;
  }

  static String? discountLabel(double? mrp, double? price, String channel) {
    final pct = discountPercentFromMrp(mrp, price);
    if (pct == null) return null;
    if (pct <= 0) return '$channel: same as MRP';
    return '$channel: ${pct.toStringAsFixed(1)}% off MRP';
  }

  /// Customer-facing price (online); falls back to legacy selling/base.
  static double customerPrice({
    double? onlinePrice,
    double? sellingPrice,
    double? basePrice,
  }) {
    if (onlinePrice != null && onlinePrice > 0) return onlinePrice;
    if (sellingPrice != null && sellingPrice > 0) return sellingPrice;
    return basePrice ?? 0;
  }
}
