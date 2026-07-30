import 'package:cloud_firestore/cloud_firestore.dart';

class MarketplaceCategoryNode {
  const MarketplaceCategoryNode({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.active,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool active;

  static MarketplaceCategoryNode? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
    return MarketplaceCategoryNode(
      id: doc.id,
      name: (d['name'] as String?)?.trim() ?? doc.id,
      sortOrder: (d['sort_order'] as num?)?.toInt() ?? 0,
      active: d['active'] != false,
    );
  }
}

class MarketplaceSubcategoryNode {
  const MarketplaceSubcategoryNode({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.active,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool active;

  static MarketplaceSubcategoryNode? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
    return MarketplaceSubcategoryNode(
      id: doc.id,
      name: (d['name'] as String?)?.trim() ?? doc.id,
      sortOrder: (d['sort_order'] as num?)?.toInt() ?? 0,
      active: d['active'] != false,
    );
  }
}

class MarketplaceAttributeDef {
  const MarketplaceAttributeDef({
    required this.id,
    required this.key,
    required this.label,
    required this.values,
    required this.sortOrder,
    required this.required,
    this.freeText = false,
    this.scanQrBarcode = false,
  });

  final String id;
  final String key;
  final String label;
  final List<String> values;
  final int sortOrder;
  final bool required;
  /// When true, seller enters text instead of picking from [values] (includes empty option lists).
  final bool freeText;
  /// When true and [usesTextInput], listing editor shows a scan button to fill the field.
  final bool scanQrBarcode;

  bool get usesTextInput => freeText;

  static MarketplaceAttributeDef? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
    final raw = d['values'];
    final vals = raw is List ? raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList(growable: false) : const <String>[];
    final freeText = d['free_text'] == true || vals.isEmpty;
    return MarketplaceAttributeDef(
      id: doc.id,
      key: (d['key'] as String?)?.trim() ?? doc.id,
      label: (d['label'] as String?)?.trim() ?? doc.id,
      values: vals,
      sortOrder: (d['sort_order'] as num?)?.toInt() ?? 0,
      required: d['required'] != false,
      freeText: freeText,
      scanQrBarcode: d['scan_qr_barcode'] == true,
    );
  }
}

/// Virtual subcategory in seller UI: product does not fit listed subcategories — seller proposes new sub + features.
const String kMarketplaceOtherSubcategoryId = '__other__';

/// Listing uses seller-proposed subcategory name + [SellerProposedFeatureDef] until admin publishes (taxonomy created then).
const String kMarketplaceProposedSubcategoryId = '__proposed__';

/// Feature row proposed by seller under Others (mirrors admin attribute shape; stored on listing only until publish).
class SellerProposedFeatureDef {
  const SellerProposedFeatureDef({
    required this.key,
    required this.label,
    this.values = const [],
    this.freeText = false,
    this.scanQrBarcode = false,
  });

  final String key;
  final String label;
  final List<String> values;
  /// Explicit free-text mode; also implied when [values] is empty.
  final bool freeText;
  /// Seller chose camera scan to fill the text value (QR / barcode → uppercase).
  final bool scanQrBarcode;

  bool get usesTextInput => freeText || values.isEmpty;

  Map<String, dynamic> toFirestoreMap() {
    final m = <String, dynamic>{
      'key': key,
      'label': label,
      'values': values,
    };
    if (usesTextInput) m['free_text'] = true;
    if (scanQrBarcode) m['scan_qr_barcode'] = true;
    return m;
  }

  static SellerProposedFeatureDef? fromDynamic(dynamic e) {
    if (e is! Map) return null;
    final key = '${e['key'] ?? ''}'.trim();
    final label = '${e['label'] ?? ''}'.trim();
    final raw = e['values'];
    final vals = raw is List
        ? raw.map((x) => '$x'.trim()).where((x) => x.isNotEmpty).toList(growable: false)
        : const <String>[];
    final ftFlag = e['free_text'] == true;
    final scan = e['scan_qr_barcode'] == true;
    if (key.isEmpty || label.isEmpty) return null;
    final ft = ftFlag || vals.isEmpty;
    return SellerProposedFeatureDef(key: key, label: label, values: vals, freeText: ft, scanQrBarcode: scan);
  }
}
