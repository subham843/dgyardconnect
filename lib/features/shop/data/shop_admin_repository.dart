import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_repository_base.dart';

class ShopAdminDashboardData {
  const ShopAdminDashboardData({
    required this.categories,
    required this.subCategories,
    required this.products,
    required this.activeProducts,
    required this.brands,
    required this.orders,
    required this.pendingOrders,
    required this.totalRevenue,
    required this.activeCarts,
    required this.cartLineItems,
    required this.lowStockCount,
    required this.orderStatusCounts,
    required this.recentCategories,
    required this.recentProducts,
    required this.recentOrders,
    required this.recentCarts,
    required this.lowStockProducts,
  });

  final int categories;
  final int subCategories;
  final int products;
  final int activeProducts;
  final int brands;
  final int orders;
  final int pendingOrders;
  final double totalRevenue;
  final int activeCarts;
  final int cartLineItems;
  final int lowStockCount;
  final Map<String, int> orderStatusCounts;
  final List<Map<String, dynamic>> recentCategories;
  final List<Map<String, dynamic>> recentProducts;
  final List<Map<String, dynamic>> recentOrders;
  final List<ShopAdminCartRow> recentCarts;
  final List<Map<String, dynamic>> lowStockProducts;
}

class ShopAdminCartRow {
  const ShopAdminCartRow({
    required this.cartId,
    required this.firebaseUid,
    required this.itemCount,
    required this.totalQty,
    this.updatedAt,
  });

  final String cartId;
  final String firebaseUid;
  final int itemCount;
  final int totalQty;
  final DateTime? updatedAt;
}

class ShopAdminRepository {
  static const _empty = ShopAdminDashboardData(
    categories: 0,
    subCategories: 0,
    products: 0,
    activeProducts: 0,
    brands: 0,
    orders: 0,
    pendingOrders: 0,
    totalRevenue: 0,
    activeCarts: 0,
    cartLineItems: 0,
    lowStockCount: 0,
    orderStatusCounts: {},
    recentCategories: [],
    recentProducts: [],
    recentOrders: [],
    recentCarts: [],
    lowStockProducts: [],
  );

  Future<ShopAdminDashboardData> loadDashboard() async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return _empty;

    final results = await Future.wait<dynamic>([
      _count(c, 'categories'),
      _count(c, 'sub_categories'),
      _count(c, 'products'),
      _countActiveProducts(c),
      _count(c, 'brands'),
      c.from('shop_orders').select('id, status, total_amount, created_at').order('created_at', ascending: false).limit(400),
      c
          .from('shop_carts')
          .select('id, firebase_uid, updated_at, shop_cart_items(qty)')
          .eq('is_active', true)
          .order('updated_at', ascending: false)
          .limit(20),
      c.from('categories').select('id, name, slug, created_at').order('created_at', ascending: false).limit(5),
      c
          .from('products')
          .select('id, name, sku, base_price, is_active, created_at')
          .order('created_at', ascending: false)
          .limit(5),
      c
          .from('inventory')
          .select('qty_on_hand, products(id, name, sku)')
          .lt('qty_on_hand', 5)
          .order('qty_on_hand')
          .limit(8),
    ]);

    final catCount = results[0] as int;
    final subCount = results[1] as int;
    final productCount = results[2] as int;
    final activeProductCount = results[3] as int;
    final brandCount = results[4] as int;
    final orderRows = results[5] as List;
    final cartRows = results[6] as List;
    final recentCatRows = results[7] as List;
    final recentProdRows = results[8] as List;
    final lowStockRows = results[9] as List;

    var revenue = 0.0;
    var pending = 0;
    final statusCounts = <String, int>{};
    for (final raw in orderRows) {
      final o = SupabaseRepositoryBase.rowToMap(raw as Map<String, dynamic>);
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      final status = o['status'] as String? ?? '';
      revenue += amount;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      if (status == 'pending_payment' || status == 'draft' || status == 'processing') {
        pending++;
      }
    }

    final lowStock = <Map<String, dynamic>>[];
    for (final raw in lowStockRows) {
      final row = SupabaseRepositoryBase.rowToMap(raw as Map<String, dynamic>);
      final prod = row['products'];
      Map<String, dynamic>? p;
      if (prod is Map) {
        p = SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(prod));
      }
      if (p == null) continue;
      lowStock.add({
        'id': p['id'],
        'name': p['name'],
        'sku': p['sku'],
        'qty': (row['qty_on_hand'] as num?)?.toInt() ?? 0,
      });
    }

    var lineItems = 0;
    final carts = <ShopAdminCartRow>[];
    for (final raw in cartRows) {
      final row = SupabaseRepositoryBase.rowToMap(raw as Map<String, dynamic>);
      final items = SupabaseRepositoryBase.embeddedRows(row['shop_cart_items']);
      var qtySum = 0;
      for (final it in items) {
        final m = SupabaseRepositoryBase.rowToMap(it);
        qtySum += (m['qty'] as num?)?.toInt() ?? 0;
      }
      lineItems += items.length;
      carts.add(
        ShopAdminCartRow(
          cartId: row['id'] as String,
          firebaseUid: row['firebase_uid'] as String? ?? '',
          itemCount: items.length,
          totalQty: qtySum,
          updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at'].toString()) : null,
        ),
      );
    }

    final recentOrders = orderRows.take(8).map((raw) {
      final o = SupabaseRepositoryBase.rowToMap(raw as Map<String, dynamic>);
      return {
        'id': o['id'],
        'status': o['status'],
        'total_amount': o['total_amount'],
        'created_at': o['created_at']?.toString(),
      };
    }).toList();

    return ShopAdminDashboardData(
      categories: catCount,
      subCategories: subCount,
      products: productCount,
      activeProducts: activeProductCount,
      brands: brandCount,
      orders: orderRows.length,
      pendingOrders: pending,
      totalRevenue: revenue,
      activeCarts: carts.length,
      cartLineItems: lineItems,
      lowStockCount: lowStock.length,
      orderStatusCounts: statusCounts,
      recentCategories: recentCatRows.map((e) => SupabaseRepositoryBase.rowToMap(e as Map<String, dynamic>)).toList(),
      recentProducts: recentProdRows.map((e) => SupabaseRepositoryBase.rowToMap(e as Map<String, dynamic>)).toList(),
      recentOrders: recentOrders,
      recentCarts: carts.take(6).toList(),
      lowStockProducts: lowStock.take(5).toList(),
    );
  }

  static Future<int> _count(SupabaseClient c, String table) async {
    final res = await c.from(table).select('id').count(CountOption.exact);
    return res.count;
  }

  static Future<int> _countActiveProducts(SupabaseClient c) async {
    final res = await c.from('products').select('id').eq('is_active', true).count(CountOption.exact);
    return res.count;
  }
}
