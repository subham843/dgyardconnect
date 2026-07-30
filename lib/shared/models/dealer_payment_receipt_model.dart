import 'package:cloud_firestore/cloud_firestore.dart';

class DealerPaymentReceiptModel {
  DealerPaymentReceiptModel({
    required this.id,
    required this.jobId,
    this.jobCode,
    required this.dealerId,
    this.dealerCode,
    required this.dealerName,
    this.serviceSector,
    this.serviceType,
    required this.paymentAmount,
    this.razorpayFee = 0,
    this.paymentDate,
    this.paymentMethod,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.paymentStatus,
    this.createdAt,
  });

  final String id;
  final String jobId;
  final String? jobCode;
  final String dealerId;
  final String? dealerCode;
  final String dealerName;
  final String? serviceSector;
  final String? serviceType;
  final double paymentAmount;
  final double razorpayFee;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final String? paymentStatus;
  final DateTime? createdAt;

  factory DealerPaymentReceiptModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DealerPaymentReceiptModel(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      jobCode: d['jobCode'] as String?,
      dealerId: d['dealerId'] as String? ?? '',
      dealerCode: d['dealerCode'] as String?,
      dealerName: d['dealerName'] as String? ?? '',
      serviceSector: d['serviceSector'] as String?,
      serviceType: d['serviceType'] as String?,
      paymentAmount: (d['paymentAmount'] as num?)?.toDouble() ?? 0,
      razorpayFee: (d['razorpayFee'] as num?)?.toDouble() ?? 0,
      paymentDate: (d['paymentDate'] as Timestamp?)?.toDate(),
      paymentMethod: d['paymentMethod'] as String?,
      razorpayPaymentId: d['razorpayPaymentId'] as String?,
      razorpayOrderId: d['razorpayOrderId'] as String?,
      paymentStatus: d['paymentStatus'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get displayReceiptId {
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
