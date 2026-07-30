/// Validation rules for Shop ERP admin forms (ERP / inventory standards).
abstract final class ShopErpValidation {
  static String? requiredText(String? value, {String label = 'Field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? sku(String? value) {
    final err = requiredText(value, label: 'SKU');
    if (err != null) return err;
    if (!RegExp(r'^[A-Za-z0-9._\-]+$').hasMatch(value!.trim())) {
      return 'SKU may only contain letters, numbers, . _ -';
    }
    return null;
  }

  static String? gstPercentage(double? value) {
    if (value == null) return null;
    if (value < 0 || value > 100) return 'GST must be between 0 and 100';
    return null;
  }

  /// Optional; Indian HSN/SAC is typically 4–8 digits.
  static String? hsnCode(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^\d{4,8}$').hasMatch(value.trim())) {
      return 'HSN must be 4–8 digits';
    }
    return null;
  }

  static String? positiveInt(int? value, {String label = 'Quantity'}) {
    if (value == null || value <= 0) return '$label must be greater than 0';
    return null;
  }

  static String? nonNegativeAmount(double? value, {String label = 'Amount'}) {
    if (value == null || value < 0) return '$label cannot be negative';
    return null;
  }

  static String? purchaseInvoiceNo(String? value) {
    return requiredText(value, label: 'Purchase invoice number');
  }

  static String? supplierCode(String? value) {
    final err = requiredText(value, label: 'Supplier code');
    if (err != null) return err;
    if (value!.trim().length > 32) return 'Code max 32 characters';
    return null;
  }

  static String? customerCode(String? value) {
    final err = requiredText(value, label: 'Customer code');
    if (err != null) return err;
    if (value!.trim().length > 32) return 'Code max 32 characters';
    return null;
  }

  static String? serialListMatchesQty(List<String> serials, int quantity, {bool required = false}) {
    final cleaned = serials.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (cleaned.isEmpty) return required ? 'At least one serial number is required' : null;
    if (cleaned.length != quantity) {
      return 'Serial count (${cleaned.length}) must match quantity ($quantity)';
    }
    if (cleaned.toSet().length != cleaned.length) return 'Duplicate serial numbers in list';
    return null;
  }

  static String? urlSlug(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value.trim())) {
      return 'URL slug: lowercase letters, numbers, hyphens only';
    }
    return null;
  }

  static String? inventoryReceiptLine({
    required String? productId,
    required int? quantity,
    required double? purchaseRate,
    required List<String> serials,
    required bool trackSerial,
  }) {
    if (productId == null || productId.isEmpty) return 'Select a product (stock is added to existing SKU only)';
    final qErr = positiveInt(quantity);
    if (qErr != null) return qErr;
    final pErr = nonNegativeAmount(purchaseRate, label: 'Purchase rate');
    if (pErr != null) return pErr;
    return serialListMatchesQty(serials, quantity!, required: trackSerial);
  }
}
