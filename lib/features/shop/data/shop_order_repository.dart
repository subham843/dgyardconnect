import 'package:firebase_auth/firebase_auth.dart';

import '../domain/shop_order.dart';
import 'shop_cart_repository.dart';
import 'supabase_repository_base.dart';

class ShopOrderRepository {
  final _cart = ShopCartRepository();

  Future<List<ShopOrder>> listMyOrders() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('shop_orders').select().eq('firebase_uid', uid).order('created_at', ascending: false);
    return (rows as List).map((e) => ShopOrder.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<ShopOrder?> getOrder(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c
        .from('shop_orders')
        .select()
        .eq('id', orderId)
        .eq('firebase_uid', uid)
        .maybeSingle();
    if (row == null) return null;
    return ShopOrder.fromRow(SupabaseRepositoryBase.rowToMap(row));
  }

  Future<List<ShopOrderLineItem>> listOrderLines(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final order = await getOrder(orderId);
    if (order == null) return [];
    final rows = await c.from('shop_order_items').select().eq('order_id', orderId);
    return (rows as List)
        .map((e) => ShopOrderLineItem.fromRow(SupabaseRepositoryBase.rowToMap(e)))
        .toList();
  }

  Future<List<ShopOrder>> listAllOrdersAdmin() async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('shop_orders').select().order('created_at', ascending: false).limit(200);
    return (rows as List).map((e) => ShopOrder.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<String?> createOrderFromCart({Map<String, dynamic>? shippingAddress}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final items = await _cart.listCartItems();
    if (items.isEmpty) return null;
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;

    var subtotal = 0.0;
    for (final it in items) {
      subtotal += it.lineTotal;
    }

    final orderRes = await c.from('shop_orders').insert({
      'firebase_uid': uid,
      'status': 'pending_payment',
      'shipping_address': shippingAddress,
      'subtotal': subtotal,
      'total_amount': subtotal,
    }).select('id').maybeSingle();

    final orderId = orderRes?['id'] as String?;
    if (orderId == null) return null;

    for (final it in items) {
      final p = it.product;
      await c.from('shop_order_items').insert({
        'order_id': orderId,
        'product_id': it.productId,
        'product_name': p?.name ?? 'Product',
        'sku': p?.sku ?? '',
        'unit_price': p?.basePrice ?? 0,
        'qty': it.qty,
        'line_total': it.lineTotal,
      });
    }

    await _cart.clearCart();
    return orderId;
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('shop_orders').update({'status': status}).eq('id', orderId);
  }
}
