import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/shop_cart_repository.dart';
import '../domain/shop_order.dart';

class ShopCartController extends ChangeNotifier {
  ShopCartController() : _repo = ShopCartRepository();

  final ShopCartRepository _repo;
  List<ShopCartItem> _items = const [];
  bool _loading = false;

  List<ShopCartItem> get items => _items;
  bool get loading => _loading;
  int get itemCount => _items.fold(0, (s, i) => s + i.qty);
  double get subtotal => _items.fold(0.0, (s, i) => s + i.lineTotal);

  void attachToAuth() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _items = const [];
        notifyListeners();
      } else {
        refresh();
      }
    });
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    _items = await _repo.listCartItems();
    _loading = false;
    notifyListeners();
  }

  Future<void> addProduct(String productId, {int qty = 1}) async {
    await _repo.addToCart(productId, qty: qty);
    await refresh();
  }

  Future<void> setQty(String cartItemId, int qty) async {
    await _repo.setQty(cartItemId, qty);
    await refresh();
  }
}
