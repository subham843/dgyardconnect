import 'package:firebase_auth/firebase_auth.dart';

import '../../web_public/state/public_cart.dart';
import '../domain/shop_order.dart';
import 'shop_cart_repository.dart';
import 'shop_order_repository.dart';

/// Merges guest [PublicCart] lines into Supabase cart and places an order.
class PublicCartCheckoutService {
  PublicCartCheckoutService({
    ShopCartRepository? cartRepo,
    ShopOrderRepository? orderRepo,
  })  : _cart = cartRepo ?? ShopCartRepository(),
        _orders = orderRepo ?? ShopOrderRepository();

  final ShopCartRepository _cart;
  final ShopOrderRepository _orders;

  Future<String?> checkoutFromPublicCart({
    Map<String, dynamic>? shippingAddress,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final lines = PublicCart.instance.lines;
    if (lines.isEmpty) return null;

    for (final line in lines) {
      await _cart.addToCart(line.id, qty: line.qty);
    }

    final orderId = await _orders.createOrderFromCart(shippingAddress: shippingAddress);
    if (orderId != null) {
      PublicCart.instance.clear();
    }
    return orderId;
  }

  Future<void> reorderLines(List<ShopOrderLineItem> lines) async {
    for (final line in lines) {
      await _cart.addToCart(line.productId, qty: line.qty);
    }
  }
}
