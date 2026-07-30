import 'package:firebase_auth/firebase_auth.dart';

import '../../shop/data/supabase_repository_base.dart';
import '../domain/calculator_models.dart';

class QuotationLine {
  const QuotationLine({
    required this.id,
    required this.label,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.productId,
    this.sku,
  });

  final String id;
  final String label;
  final double qty;
  final double unitPrice;
  final double lineTotal;
  final String? productId;
  final String? sku;

  factory QuotationLine.fromRow(Map<String, dynamic> row) {
    return QuotationLine(
      id: row['id'] as String,
      label: row['label'] as String? ?? '',
      qty: (row['qty'] as num?)?.toDouble() ?? 1,
      unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (row['line_total'] as num?)?.toDouble() ?? 0,
      productId: row['product_id'] as String?,
      sku: row['sku'] as String?,
    );
  }
}

/// Customer details shown as "Prepared for" on quotation PDFs.
class QuotationPreparedFor {
  const QuotationPreparedFor({this.name, this.address, this.phone});

  final String? name;
  final String? address;
  final String? phone;

  bool get hasAny =>
      (name ?? '').trim().isNotEmpty ||
      (address ?? '').trim().isNotEmpty ||
      (phone ?? '').trim().isNotEmpty;

  String? get displayLabel {
    final n = (name ?? '').trim();
    if (n.isNotEmpty) return n;
    final p = (phone ?? '').trim();
    if (p.isNotEmpty) return p;
    return null;
  }
}

class Quotation {
  const Quotation({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.totalAmount,
    this.customerName,
    this.customerAddress,
    this.customerPhone,
    this.createdAt,
  });

  final String id;
  final String status;
  final double subtotal;
  final double totalAmount;
  final String? customerName;
  final String? customerAddress;
  final String? customerPhone;
  final DateTime? createdAt;

  QuotationPreparedFor get preparedFor => QuotationPreparedFor(
        name: customerName,
        address: customerAddress,
        phone: customerPhone,
      );

  factory Quotation.fromRow(Map<String, dynamic> row) {
    return Quotation(
      id: row['id'] as String,
      status: row['status'] as String? ?? 'draft',
      subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      customerName: row['customer_name'] as String?,
      customerAddress: row['customer_address'] as String?,
      customerPhone: row['customer_phone'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString())
          : null,
    );
  }
}

class QuotationRepository {
  Future<String?> createFromCalculatorResult({
    required String? sessionId,
    required String? templateId,
    required CalculatorResult result,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;

    var subtotal = 0.0;
    for (final line in result.suggestedLines) {
      subtotal += (line.unitPrice ?? 0) * line.qty;
    }

    final qRes = await c
        .from('quotations')
        .insert({
          'firebase_uid': uid,
          'session_id': ?sessionId,
          'template_id': ?templateId,
          'status': 'draft',
          'customer_name': customerName,
          'customer_address': customerAddress,
          'customer_phone': customerPhone,
          'subtotal': subtotal,
          'total_amount': subtotal,
        })
        .select('id')
        .maybeSingle();

    final quotationId = qRes?['id'] as String?;
    if (quotationId == null) return null;

    var order = 0;
    for (final line in result.suggestedLines) {
      final unit = line.unitPrice ?? 0;
      final total = unit * line.qty;
      await c.from('quotation_lines').insert({
        'quotation_id': quotationId,
        'product_id': line.productId,
        'line_type': 'product',
        'label': line.label,
        'sku': line.sku,
        'qty': line.qty,
        'unit_price': unit,
        'line_total': total,
        'source_rule_id': line.sourceRuleId,
        'sort_order': order++,
      });
    }

    for (final f in result.formulas) {
      await c.from('quotation_lines').insert({
        'quotation_id': quotationId,
        'line_type': 'formula',
        'label': '${_formulaDisplayName(f.key)}: ${f.value.toStringAsFixed(0)}',
        'qty': f.value,
        'unit_price': 0,
        'line_total': 0,
        'sort_order': order++,
      });
    }

    return quotationId;
  }

  static String _formulaDisplayName(String key) {
    const labels = <String, String>{
      'bnc_qty': 'BNC connector',
      'dc_connector_qty': 'DC connector',
      'cat6_qty': 'Cat6 cable (meters)',
      'rj45_qty': 'RJ45 connector',
      'camera_qty': 'Camera quantity',
      'storage_days': 'Storage days',
    };
    final k = key.trim();
    if (labels.containsKey(k)) return labels[k]!;
    var normalized = k;
    if (normalized.endsWith('_qty')) {
      normalized = normalized.substring(0, normalized.length - 4);
    }
    return normalized
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => p.length == 1 ? p.toUpperCase() : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  Future<List<Quotation>> listMyQuotations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('quotations')
        .select()
        .eq('firebase_uid', uid)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Quotation.fromRow(SupabaseRepositoryBase.rowToMap(e)))
        .toList();
  }

  Future<Quotation?> getById(String quotationId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c.from('quotations').select().eq('id', quotationId).maybeSingle();
    if (row == null) return null;
    return Quotation.fromRow(SupabaseRepositoryBase.rowToMap(row));
  }

  Future<List<QuotationLine>> listLines(String quotationId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('quotation_lines')
        .select()
        .eq('quotation_id', quotationId)
        .order('sort_order');
    return (rows as List)
        .map((e) => QuotationLine.fromRow(SupabaseRepositoryBase.rowToMap(e)))
        .toList();
  }
}
