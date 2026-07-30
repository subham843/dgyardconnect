import '../domain/shop_erp_models.dart';
import 'supabase_repository_base.dart';

/// Inventory, purchase, suppliers, customers, shop quotations, reports.
class ShopErpRepository {
  // --- Suppliers ---
  Future<List<ShopSupplier>> listSuppliers({bool activeOnly = false}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    var q = c.from('suppliers').select();
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('name');
    return (rows as List).map((e) => ShopSupplier.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<String?> createSupplier({
    required String code,
    required String name,
    String? contactName,
    String? email,
    String? phone,
    String? gstin,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c
        .from('suppliers')
        .insert({
          'code': code.trim().toUpperCase(),
          'name': name.trim(),
          if (contactName != null) 'contact_name': contactName.trim(),
          if (email != null) 'email': email.trim(),
          if (phone != null) 'phone': phone.trim(),
          if (gstin != null) 'gstin': gstin.trim(),
        })
        .select('id')
        .maybeSingle();
    return res?['id'] as String?;
  }

  Future<void> deleteSupplier(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) throw StateError('Supabase not ready');
    await c.from('suppliers').delete().eq('id', id);
  }

  // --- Customers ---
  Future<List<ShopCustomer>> listCustomers({bool activeOnly = false}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    var q = c.from('customers').select();
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('name');
    return (rows as List).map((e) => ShopCustomer.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<String?> createCustomer({
    required String code,
    required String name,
    String? email,
    String? phone,
    String? gstin,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c
        .from('customers')
        .insert({
          'code': code.trim().toUpperCase(),
          'name': name.trim(),
          if (email != null) 'email': email.trim(),
          if (phone != null) 'phone': phone.trim(),
          if (gstin != null) 'gstin': gstin.trim(),
        })
        .select('id')
        .maybeSingle();
    return res?['id'] as String?;
  }

  Future<void> deleteCustomer(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) throw StateError('Supabase not ready');
    await c.from('customers').delete().eq('id', id);
  }

  // --- Purchase / inventory receipts ---
  Future<List<InventoryReceipt>> listInventoryReceipts({int limit = 100}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('inventory_receipts')
        .select('*, suppliers(name)')
        .order('purchase_date', ascending: false)
        .limit(limit);
    return (rows as List).map((e) => InventoryReceipt.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<String?> createInventoryReceiptDraft({
    String? supplierId,
    required String purchaseInvoiceNo,
    required DateTime purchaseDate,
    String? remarks,
    String? createdByUid,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c
        .from('inventory_receipts')
        .insert({
          'supplier_id': supplierId,
          'purchase_invoice_no': purchaseInvoiceNo.trim(),
          'purchase_date': purchaseDate.toIso8601String().split('T').first,
          'remarks': remarks?.trim(),
          'status': 'draft',
          'created_by_uid': ?createdByUid,
        })
        .select('id')
        .maybeSingle();
    return res?['id'] as String?;
  }

  Future<String?> addReceiptLine({
    required String receiptId,
    required InventoryReceiptLineInput line,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c
        .from('inventory_receipt_lines')
        .insert({
          'receipt_id': receiptId,
          'product_id': line.productId,
          'quantity': line.quantity,
          'purchase_rate': line.purchaseRate,
          if (line.gstPercentage != null) 'gst_percentage': line.gstPercentage,
          if (line.mrp != null) 'mrp': line.mrp,
          if (line.onlinePrice != null) ...{
            'online_price': line.onlinePrice,
            'selling_price': line.onlinePrice,
          },
          if (line.dealerPrice != null) 'dealer_price': line.dealerPrice,
          if (line.batchNumber != null) 'batch_number': line.batchNumber!.trim(),
          if (line.remarks != null) 'remarks': line.remarks!.trim(),
        })
        .select('id')
        .maybeSingle();
    final lineId = res?['id'] as String?;
    if (lineId != null && line.serialNumbers.isNotEmpty) {
      for (final sn in line.serialNumbers) {
        final t = sn.trim();
        if (t.isEmpty) continue;
        await c.from('inventory_receipt_serials').insert({
          'receipt_line_id': lineId,
          'serial_number': t,
        });
      }
    }
    return lineId;
  }

  Future<void> finalizeReceipt(String receiptId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.rpc('finalize_inventory_receipt', params: {'p_receipt_id': receiptId});
  }

  // --- Reports ---
  Future<List<StockReportRow>> stockReport({int limit = 500}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('v_inventory_stock_report').select().order('product_name').limit(limit);
    return (rows as List).map((e) => StockReportRow.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<List<Map<String, dynamic>>> purchaseRegister({int limit = 200}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('v_purchase_register').select().limit(limit);
    return (rows as List).map((e) => SupabaseRepositoryBase.rowToMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> gstSummary() async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('v_gst_summary').select().order('period_month', ascending: false);
    return (rows as List).map((e) => SupabaseRepositoryBase.rowToMap(e)).toList();
  }

  // --- Shop quotations ---
  Future<List<ShopQuotation>> listShopQuotations({int limit = 100}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('shop_quotations')
        .select('*, customers(name)')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((e) => ShopQuotation.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<String?> createShopQuotation({
    required String firebaseUid,
    required String quoteNumber,
    String? customerId,
    String? notes,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c
        .from('shop_quotations')
        .insert({
          'firebase_uid': firebaseUid,
          'quote_number': quoteNumber.trim(),
          'customer_id': ?customerId,
          if (notes != null) 'notes': notes.trim(),
        })
        .select('id')
        .maybeSingle();
    return res?['id'] as String?;
  }

  Future<void> updateSubCategoryGst(String subCategoryId, double defaultGst) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('sub_categories').update({'default_gst_percentage': defaultGst}).eq('id', subCategoryId);
  }
}
