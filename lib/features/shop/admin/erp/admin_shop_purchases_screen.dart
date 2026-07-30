import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../admin/widgets/admin_embedded_scaffold.dart';
import '../../admin/validation/shop_erp_validation.dart';
import '../../data/shop_catalog_repository.dart';
import '../../data/shop_erp_repository.dart';
import '../../domain/shop_erp_models.dart';
import '../../../../core/editing/dg_assist_text_field.dart';
import '../../domain/shop_product.dart';
import 'admin_shop_purchase_line_pricing_fields.dart';

class AdminShopPurchasesScreen extends StatefulWidget {
  const AdminShopPurchasesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopPurchasesScreen> createState() => _AdminShopPurchasesScreenState();
}

class _AdminShopPurchasesScreenState extends State<AdminShopPurchasesScreen> {
  final _erp = ShopErpRepository();
  final _catalog = ShopCatalogRepository();
  List<InventoryReceipt> _receipts = [];
  List<ShopSupplier> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _receipts = await _erp.listInventoryReceipts();
    _suppliers = await _erp.listSuppliers(activeOnly: true);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _newPurchase() async {
    final invoice = TextEditingController();
    final remarks = TextEditingController();
    var purchaseDate = DateTime.now();
    String? supplierId;
    final products = await _catalog.listProducts(activeOnly: true, limit: 500);

    if (!mounted) return;
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Purchase receipt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— None —')),
                    for (final s in _suppliers)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setLocal(() => supplierId = v),
                ),
                TextField(
                  controller: invoice,
                  decoration: const InputDecoration(labelText: 'Purchase invoice no *'),
                ),
                ListTile(
                  title: Text(DateFormat.yMMMd().format(purchaseDate)),
                  subtitle: const Text('Purchase date'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: purchaseDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setLocal(() => purchaseDate = d);
                    },
                  ),
                ),
                DgAssistTextField(
                  controller: remarks,
                  assistProfile: TextAssistProfile.erpNotes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Purchase notes / remarks', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Next')),
          ],
        ),
      ),
    );
    if (step1 != true) return;
    final invErr = ShopErpValidation.purchaseInvoiceNo(invoice.text);
    if (invErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(invErr)));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final receiptId = await _erp.createInventoryReceiptDraft(
      supplierId: supplierId,
      purchaseInvoiceNo: invoice.text,
      purchaseDate: purchaseDate,
      remarks: remarks.text,
      createdByUid: uid,
    );
    if (receiptId == null || !mounted) return;

    await _addLineDialog(receiptId, products);
    if (!mounted) return;
    await _erp.finalizeReceipt(receiptId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase posted — stock updated (FIFO)')),
    );
    await _load();
  }

  Future<void> _addLineDialog(String receiptId, List<ShopProduct> products) async {
    ShopProduct? product;
    var trackSerial = false;
    var trackBatch = false;
    final qty = TextEditingController(text: '1');
    final rate = TextEditingController();
    final batch = TextEditingController();
    final serials = TextEditingController();
    final mrp = TextEditingController();
    final online = TextEditingController();
    final dealer = TextEditingController();

    var addMore = true;
    while (addMore && mounted) {
      addMore = false;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Inventory line'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ShopProduct?>(
                    initialValue: product,
                    decoration: const InputDecoration(labelText: 'Product (existing SKU) *'),
                    items: [
                      for (final p in products)
                        DropdownMenuItem(value: p, child: Text('${p.sku} — ${p.name}')),
                    ],
                    onChanged: (v) async {
                      setLocal(() => product = v);
                      if (v != null) {
                        final d = await _catalog.getProductDetail(v.id);
                        setLocal(() {
                          trackSerial = d?.trackSerial ?? false;
                          trackBatch = d?.trackBatch ?? false;
                          if (d != null) {
                            rate.text = d.costPrice > 0 ? '${d.costPrice}' : rate.text;
                            mrp.text = d.mrp?.toString() ?? '';
                            online.text = '${d.onlinePrice ?? d.sellingPrice}';
                            dealer.text = d.dealerPrice?.toString() ?? '';
                          }
                        });
                      }
                    },
                  ),
                  if (trackSerial || trackBatch)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        [
                          if (trackSerial) 'Serial tracking ON',
                          if (trackBatch) 'Batch tracking ON',
                        ].join(' · '),
                        style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity *')),
                  TextField(
                    controller: rate,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Purchase price *',
                      border: OutlineInputBorder(),
                      helperText: 'Updates product cost on post',
                    ),
                  ),
                  const SizedBox(height: 8),
                  AdminShopPurchaseLinePricingFields(
                    mrpController: mrp,
                    onlineController: online,
                    dealerController: dealer,
                  ),
                  TextField(
                    controller: batch,
                    decoration: InputDecoration(
                      labelText: trackBatch ? 'Batch number *' : 'Batch number',
                    ),
                  ),
                  TextField(
                    controller: serials,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: trackSerial ? 'Serial numbers * (one per line)' : 'Serial numbers (one per line)',
                      helperText: trackSerial ? 'Count must match quantity' : 'Optional unless product tracks serial',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Done')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add line')),
            ],
          ),
        ),
      );
      if (ok != true) break;

      final serialList = serials.text.split(RegExp(r'[\n,;]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (trackBatch && batch.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch number is required for this product')));
        }
        addMore = true;
        continue;
      }
      final lineErr = ShopErpValidation.inventoryReceiptLine(
        productId: product?.id,
        quantity: int.tryParse(qty.text),
        purchaseRate: double.tryParse(rate.text),
        serials: serialList,
        trackSerial: trackSerial,
      );
      if (lineErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lineErr)));
        addMore = true;
        continue;
      }

      await _erp.addReceiptLine(
        receiptId: receiptId,
        line: InventoryReceiptLineInput(
          productId: product!.id,
          quantity: int.parse(qty.text),
          purchaseRate: double.parse(rate.text),
          mrp: double.tryParse(mrp.text),
          onlinePrice: double.tryParse(online.text),
          dealerPrice: double.tryParse(dealer.text),
          batchNumber: batch.text,
          serialNumbers: serialList,
        ),
      );
      addMore = true;
      qty.text = '1';
      rate.clear();
      batch.clear();
      serials.clear();
      mrp.clear();
      online.clear();
      dealer.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Purchases',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPurchase,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Purchase'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _receipts.length,
                itemBuilder: (_, i) {
                  final r = _receipts[i];
                  return ListTile(
                    leading: Icon(
                      r.status == 'posted' ? Icons.check_circle : Icons.edit_note,
                      color: r.status == 'posted' ? Colors.green : Colors.orange,
                    ),
                    title: Text(r.purchaseInvoiceNo),
                    subtitle: Text(
                      '${r.supplierName ?? 'No supplier'} · ${DateFormat.yMMMd().format(r.purchaseDate)} · ${r.status}',
                    ),
                    trailing: Text(
                      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(r.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
