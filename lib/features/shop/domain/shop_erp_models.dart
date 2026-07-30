class ShopSupplier {
  const ShopSupplier({
    required this.id,
    required this.code,
    required this.name,
    this.contactName,
    this.email,
    this.phone,
    this.gstin,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String? contactName;
  final String? email;
  final String? phone;
  final String? gstin;
  final bool isActive;

  factory ShopSupplier.fromRow(Map<String, dynamic> row) {
    return ShopSupplier(
      id: row['id'] as String,
      code: row['code'] as String? ?? '',
      name: row['name'] as String? ?? '',
      contactName: row['contact_name'] as String?,
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      gstin: row['gstin'] as String?,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}

class ShopCustomer {
  const ShopCustomer({
    required this.id,
    required this.code,
    required this.name,
    this.email,
    this.phone,
    this.gstin,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String? email;
  final String? phone;
  final String? gstin;
  final bool isActive;

  factory ShopCustomer.fromRow(Map<String, dynamic> row) {
    return ShopCustomer(
      id: row['id'] as String,
      code: row['code'] as String? ?? '',
      name: row['name'] as String? ?? '',
      email: row['email'] as String?,
      phone: row['phone'] as String?,
      gstin: row['gstin'] as String?,
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}

class InventoryReceipt {
  const InventoryReceipt({
    required this.id,
    this.supplierId,
    required this.purchaseInvoiceNo,
    required this.purchaseDate,
    this.remarks,
    required this.status,
    required this.totalAmount,
    this.supplierName,
  });

  final String id;
  final String? supplierId;
  final String purchaseInvoiceNo;
  final DateTime purchaseDate;
  final String? remarks;
  final String status;
  final double totalAmount;
  final String? supplierName;

  factory InventoryReceipt.fromRow(Map<String, dynamic> row) {
    final sup = row['suppliers'] as Map<String, dynamic>?;
    return InventoryReceipt(
      id: row['id'] as String,
      supplierId: row['supplier_id'] as String?,
      purchaseInvoiceNo: row['purchase_invoice_no'] as String? ?? '',
      purchaseDate: DateTime.tryParse(row['purchase_date'].toString()) ?? DateTime.now(),
      remarks: row['remarks'] as String?,
      status: row['status'] as String? ?? 'draft',
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      supplierName: sup?['name'] as String?,
    );
  }
}

class InventoryReceiptLineInput {
  const InventoryReceiptLineInput({
    required this.productId,
    required this.quantity,
    required this.purchaseRate,
    this.gstPercentage,
    this.mrp,
    this.onlinePrice,
    this.dealerPrice,
    this.batchNumber,
    this.remarks,
    this.serialNumbers = const [],
  });

  final String productId;
  final int quantity;
  final double purchaseRate;
  final double? gstPercentage;
  final double? mrp;
  final double? onlinePrice;
  final double? dealerPrice;
  final String? batchNumber;
  final String? remarks;
  final List<String> serialNumbers;
}

class ShopQuotation {
  const ShopQuotation({
    required this.id,
    required this.quoteNumber,
    required this.status,
    required this.totalAmount,
    this.customerName,
    required this.createdAt,
  });

  final String id;
  final String quoteNumber;
  final String status;
  final double totalAmount;
  final String? customerName;
  final DateTime createdAt;

  factory ShopQuotation.fromRow(Map<String, dynamic> row) {
    final cust = row['customers'] as Map<String, dynamic>?;
    return ShopQuotation(
      id: row['id'] as String,
      quoteNumber: row['quote_number'] as String? ?? '',
      status: row['status'] as String? ?? 'draft',
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      customerName: cust?['name'] as String?,
      createdAt: DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now(),
    );
  }
}

class StockReportRow {
  const StockReportRow({
    required this.productId,
    required this.sku,
    required this.productName,
    required this.qtyOnHand,
    required this.avgCost,
    required this.stockValue,
    required this.serialsInStock,
  });

  final String productId;
  final String sku;
  final String productName;
  final int qtyOnHand;
  final double avgCost;
  final double stockValue;
  final int serialsInStock;

  factory StockReportRow.fromRow(Map<String, dynamic> row) {
    return StockReportRow(
      productId: row['product_id'] as String,
      sku: row['sku'] as String? ?? '',
      productName: row['product_name'] as String? ?? '',
      qtyOnHand: (row['qty_on_hand'] as num?)?.toInt() ?? 0,
      avgCost: (row['avg_cost'] as num?)?.toDouble() ?? 0,
      stockValue: (row['stock_value'] as num?)?.toDouble() ?? 0,
      serialsInStock: (row['serials_in_stock'] as num?)?.toInt() ?? 0,
    );
  }
}
