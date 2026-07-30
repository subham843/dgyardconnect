import 'package:firebase_auth/firebase_auth.dart';

import '../domain/shop_order.dart';
import 'shop_catalog_repository.dart';
import 'supabase_repository_base.dart';

class ShopCartRepository {
  final _catalog = ShopCatalogRepository();

  Future<String?> _activeCartId(String uid) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c
        .from('shop_carts')
        .select('id')
        .eq('firebase_uid', uid)
        .eq('is_active', true)
        .maybeSingle();
    if (row != null) return row['id'] as String;
    final created = await c.from('shop_carts').insert({'firebase_uid': uid}).select('id').maybeSingle();
    return created?['id'] as String?;
  }

  Future<List<ShopCartItem>> listCartItems() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final cartId = await _activeCartId(uid);
    if (cartId == null) return [];
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('shop_cart_items').select().eq('cart_id', cartId);
    final items = <ShopCartItem>[];
    for (final raw in rows as List) {
      final row = SupabaseRepositoryBase.rowToMap(raw);
      final product = await _catalog.getProduct(row['product_id'] as String);
      items.add(ShopCartItem(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        qty: (row['qty'] as num?)?.toInt() ?? 1,
        product: product,
      ));
    }
    return items;
  }

  Future<void> addToCart(String productId, {int qty = 1}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final cartId = await _activeCartId(uid);
    if (cartId == null) return;
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('shop_cart_items').upsert({
      'cart_id': cartId,
      'product_id': productId,
      'qty': qty,
    }, onConflict: 'cart_id,product_id');
  }

  Future<void> setQty(String cartItemId, int qty) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    if (qty <= 0) {
      await c.from('shop_cart_items').delete().eq('id', cartItemId);
    } else {
      await c.from('shop_cart_items').update({'qty': qty}).eq('id', cartItemId);
    }
  }

  Future<void> clearCart() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final cartId = await _activeCartId(uid);
    if (cartId == null) return;
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('shop_cart_items').delete().eq('cart_id', cartId);
  }
}
