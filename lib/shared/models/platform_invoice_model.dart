import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformInvoiceModel {
  PlatformInvoiceModel({
    required this.id,
    required this.jobId,
    this.jobCode,
    required this.dealerId,
    this.dealerCode,
    required this.dealerName,
    required this.serviceAmount,
    required this.platformCommission,
    required this.gstAmount,
    required this.totalPlatformCharge,
    this.invoiceDate,
    this.invoiceStatus,
    this.razorpayPaymentId,
    this.createdAt,
  });

  final String id;
  final String jobId;
  final String? jobCode;
  final String dealerId;
  final String? dealerCode;
  final String dealerName;
  final double serviceAmount;
  final double platformCommission;
  final double gstAmount;
  final double totalPlatformCharge;
  final DateTime? invoiceDate;
  final String? invoiceStatus;
  final String? razorpayPaymentId;
  final DateTime? createdAt;

  factory PlatformInvoiceModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PlatformInvoiceModel(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      jobCode: d['jobCode'] as String?,
      dealerId: d['dealerId'] as String? ?? '',
      dealerCode: d['dealerCode'] as String?,
      dealerName: d['dealerName'] as String? ?? '',
      serviceAmount: (d['serviceAmount'] as num?)?.toDouble() ?? 0,
      platformCommission: (d['platformCommission'] as num?)?.toDouble() ?? 0,
      gstAmount: (d['gstAmount'] as num?)?.toDouble() ?? 0,
      totalPlatformCharge: (d['totalPlatformCharge'] as num?)?.toDouble() ?? 0,
      invoiceDate: (d['invoiceDate'] as Timestamp?)?.toDate(),
      invoiceStatus: d['invoiceStatus'] as String?,
      razorpayPaymentId: d['razorpayPaymentId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get displayInvoiceId {
    if (id.isEmpty) return '—';
    return id.length <= 8 ? id : id.substring(0, 8).toUpperCase();
  }

  String get displayJobId {
    final c = (jobCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (jobId.isEmpty) return '—';
    return jobId.length <= 8 ? jobId : jobId.substring(0, 8).toUpperCase();
  }

  String get displayDealerId {
    final c = (dealerCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (dealerId.isEmpty) return '—';
    return dealerId.length <= 8 ? dealerId : dealerId.substring(0, 8).toUpperCase();
  }
}
