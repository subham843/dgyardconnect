import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/marketplace_cart_repository.dart';
import '../domain/marketplace_cart_item.dart';
import '../domain/marketplace_catalog_product.dart';
import '../domain/marketplace_price_tier.dart';

/// Session cart synced to `users/{uid}/marketplace_cart/data/items/*`.
class MarketplaceCartController extends ChangeNotifier {
  MarketplaceCartController({
    MarketplaceCartRepository? cartRepository,
  }) : _repo = cartRepository ?? MarketplaceCartRepository();

  final MarketplaceCartRepository _repo;
  StreamSubscription<List<MarketplaceCartItem>>? _sub;
  String? _uid;
  List<MarketplaceCartItem> _items = const [];
  bool _ready = false;

  List<MarketplaceCartItem> get items => _items;
  bool get isReady => _ready;

  int get totalPaise {
    var t = 0;
    for (final i in _items) {
      t += i.lineSubtotalPaise();
    }
    return t;
  }

  int get itemCount {
    var n = 0;
    for (final i in _items) {
      n += i.quantity;
    }
    return n;
  }

  void attachToAuth() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      final next = user?.uid;
      if (next == _uid) return;
      _uid = next;
      _sub?.cancel();
      _items = const [];
      _ready = next == null;
      notifyListeners();
      if (next == null) return;
      _sub = _repo.watchCart(next).listen((list) {
        _items = list;
        _ready = true;
        notifyListeners();
      });
    });
  }

  Future<void> addCatalogProduct(MarketplaceCatalogProduct product, {int quantity = 1}) async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (product.sellerUid.isNotEmpty && product.sellerUid == uid) {
      return;
    }
    final qty = quantity < product.moq ? product.moq : quantity;
    final id = product.id;
    MarketplaceCartItem? existing;
    for (final e in _items) {
      if (e.catalogProductId == id) {
        existing = e;
        break;
      }
    }
    final tiers = product.offerActive ? product.effectivePriceTiers() : product.priceTiers;
    if (existing != null) {
      final newQty = existing.quantity + qty;
      final tierList = existing.priceTiers.isNotEmpty ? existing.priceTiers : tiers;
      final unit = tierList.isEmpty
          ? existing.pricePaiseSnapshot
          : MarketplacePriceTier.pricePaiseForQuantity(tierList, newQty);
      await _repo.upsertItem(
        uid: uid,
        item: MarketplaceCartItem(
          id: existing.id,
          catalogProductId: id,
          quantity: newQty,
          titleSnapshot: product.title,
          pricePaiseSnapshot: unit,
          moq: product.moq,
          priceTiers: tierList,
        ),
      );
      return;
    }
    final unit = tiers.isEmpty ? product.effectiveUnitPaiseForQuantity(qty) : MarketplacePriceTier.pricePaiseForQuantity(tiers, qty);
    final item = MarketplaceCartItem(
      id: id,
      catalogProductId: id,
      quantity: qty,
      titleSnapshot: product.title,
      pricePaiseSnapshot: unit,
      moq: product.moq,
      priceTiers: tiers,
    );
    await _repo.upsertItem(uid: uid, item: item);
  }

  Future<void> setQuantity(String itemDocId, int quantity) async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    MarketplaceCartItem? found;
    for (final e in _items) {
      if (e.id == itemDocId) {
        found = e;
        break;
      }
    }
    if (found == null) return;
    final unit = found.priceTiers.isEmpty
        ? found.pricePaiseSnapshot
        : MarketplacePriceTier.pricePaiseForQuantity(found.priceTiers, quantity);
    await _repo.setQuantity(
      uid: uid,
      itemDocId: itemDocId,
      quantity: quantity,
      pricePaiseSnapshot: unit,
    );
  }

  Future<void> removeLine(String itemDocId) async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _repo.removeItem(uid: uid, itemDocId: itemDocId);
  }

  Future<void> clear() async {
    final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _repo.clearCart(uid);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
