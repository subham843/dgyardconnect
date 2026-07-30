// Guest (anonymous) storefront cart.
// Lives entirely on the public web side — no Firebase Auth required to add
// items. Persisted to local storage so the cart survives reloads. Checkout /
// Buy Now then routes the visitor to login to complete the order.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/public_store_models.dart';

class PublicCartLine {
  PublicCartLine({
    required this.id,
    required this.name,
    required this.slug,
    this.brandName,
    this.imageUrl,
    this.price,
    this.mrp,
    this.qty = 1,
  });

  final String id;
  final String name;
  final String slug;
  final String? brandName;
  final String? imageUrl;
  final double? price;
  final double? mrp;
  int qty;

  double get lineTotal => (price ?? 0) * qty;

  double get lineSavings {
    if (mrp == null || price == null || mrp! <= price!) return 0;
    return (mrp! - price!) * qty;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'brand': brandName,
        'image': imageUrl,
        'price': price,
        'mrp': mrp,
        'qty': qty,
      };

  factory PublicCartLine.fromProduct(PublicProduct p, int qty) {
    return PublicCartLine(
      id: p.id,
      name: p.name,
      slug: p.slug,
      brandName: p.brandName,
      imageUrl: p.imageUrl ?? p.thumbnailUrl,
      price: p.price,
      mrp: p.mrp,
      qty: qty,
    );
  }

  factory PublicCartLine.fromJson(Map<String, dynamic> m) {
    double? d(dynamic v) => v == null ? null : (v as num).toDouble();
    return PublicCartLine(
      id: m['id'].toString(),
      name: (m['name'] ?? '').toString(),
      slug: (m['slug'] ?? '').toString(),
      brandName: m['brand'] as String?,
      imageUrl: m['image'] as String?,
      price: d(m['price']),
      mrp: d(m['mrp']),
      qty: (m['qty'] as num?)?.toInt() ?? 1,
    );
  }
}

class PublicCart extends ChangeNotifier {
  PublicCart._() {
    _load();
  }

  static final PublicCart instance = PublicCart._();
  static const _storageKey = 'public_store_cart_v1';

  final Map<String, PublicCartLine> _lines = {};

  List<PublicCartLine> get lines => _lines.values.toList(growable: false);
  bool get isEmpty => _lines.isEmpty;
  int get itemCount => _lines.values.fold(0, (a, l) => a + l.qty);
  int get lineCount => _lines.length;
  double get subtotal => _lines.values.fold(0.0, (a, l) => a + l.lineTotal);
  double get totalSavings => _lines.values.fold(0.0, (a, l) => a + l.lineSavings);

  bool contains(String productId) => _lines.containsKey(productId);

  void addProduct(PublicProduct product, {int qty = 1}) {
    final existing = _lines[product.id];
    if (existing != null) {
      existing.qty += qty;
    } else {
      _lines[product.id] = PublicCartLine.fromProduct(product, qty);
    }
    _persist();
    notifyListeners();
  }

  void setQty(String id, int qty) {
    final line = _lines[id];
    if (line == null) return;
    if (qty <= 0) {
      _lines.remove(id);
    } else {
      line.qty = qty;
    }
    _persist();
    notifyListeners();
  }

  void increment(String id) {
    final line = _lines[id];
    if (line == null) return;
    line.qty += 1;
    _persist();
    notifyListeners();
  }

  void decrement(String id) {
    final line = _lines[id];
    if (line == null) return;
    setQty(id, line.qty - 1);
  }

  void remove(String id) {
    if (_lines.remove(id) != null) {
      _persist();
      notifyListeners();
    }
  }

  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    _persist();
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _lines.clear();
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final line = PublicCartLine.fromJson(entry);
          _lines[line.id] = line;
        }
      }
      notifyListeners();
    } catch (_) {
      // Corrupt / unavailable storage — start with an empty cart.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(lines.map((l) => l.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort persistence.
    }
  }
}
