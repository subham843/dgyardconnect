import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyReleaseReceiptModel {
  WarrantyReleaseReceiptModel({
    required this.id,
    required this.jobId,
    this.jobCode,
    required this.technicianId,
    this.technicianCode,
    this.technicianName,
    required this.holdAmount,
    this.releaseDate,
    this.transferId,
    this.status,
    this.createdAt,
  });

  final String id;
  final String jobId;
  final String? jobCode;
  final String technicianId;
  final String? technicianCode;
  final String? technicianName;
  final double holdAmount;
  final DateTime? releaseDate;
  final String? transferId;
  final String? status;
  final DateTime? createdAt;

  factory WarrantyReleaseReceiptModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return WarrantyReleaseReceiptModel(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      jobCode: d['jobCode'] as String?,
      technicianId: d['technicianId'] as String? ?? '',
      technicianCode: d['technicianCode'] as String?,
      technicianName: d['technicianName'] as String?,
      holdAmount: (d['holdAmount'] as num?)?.toDouble() ?? 0,
      releaseDate: (d['releaseDate'] as Timestamp?)?.toDate(),
      transferId: d['transferId'] as String?,
      status: d['status'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get displayReleaseId {
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
