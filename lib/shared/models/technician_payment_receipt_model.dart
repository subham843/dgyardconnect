import 'package:cloud_firestore/cloud_firestore.dart';

class TechnicianPaymentReceiptModel {
  TechnicianPaymentReceiptModel({
    required this.id,
    required this.jobId,
    this.jobCode,
    required this.technicianId,
    this.technicianCode,
    required this.technicianName,
    required this.totalJobAmount,
    required this.technicianPaidAmount,
    required this.holdAmount,
    this.transferId,
    this.transferDate,
    this.paymentStatus,
    this.createdAt,
  });

  final String id;
  final String jobId;
  final String? jobCode;
  final String technicianId;
  final String? technicianCode;
  final String technicianName;
  final double totalJobAmount;
  final double technicianPaidAmount;
  final double holdAmount;
  final String? transferId;
  final DateTime? transferDate;
  final String? paymentStatus;
  final DateTime? createdAt;

  factory TechnicianPaymentReceiptModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TechnicianPaymentReceiptModel(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      jobCode: d['jobCode'] as String?,
      technicianId: d['technicianId'] as String? ?? '',
      technicianCode: d['technicianCode'] as String?,
      technicianName: d['technicianName'] as String? ?? '',
      totalJobAmount: (d['totalJobAmount'] as num?)?.toDouble() ?? 0,
      technicianPaidAmount: (d['technicianPaidAmount'] as num?)?.toDouble() ?? 0,
      holdAmount: (d['holdAmount'] as num?)?.toDouble() ?? 0,
      transferId: d['transferId'] as String?,
      transferDate: (d['transferDate'] as Timestamp?)?.toDate(),
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

  String get displayTechnicianId {
    final c = (technicianCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (technicianId.isEmpty) return '—';
    return technicianId.length <= 8 ? technicianId : technicianId.substring(0, 8).toUpperCase();
  }
}
