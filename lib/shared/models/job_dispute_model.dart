import 'package:cloud_firestore/cloud_firestore.dart';

class JobDisputeModel {
  JobDisputeModel({
    required this.id,
    required this.jobId,
    this.jobCode,
    required this.dealerId,
    this.dealerCode,
    this.dealerName,
    required this.description,
    this.photoUrls = const [],
    this.videoUrl,
    this.status = 'open',
    this.adminNotes,
    this.resolvedAt,
    this.resolution,
    this.createdAt,
  });

  final String id;
  final String jobId;
  final String? jobCode;
  final String dealerId;
  final String? dealerCode;
  final String? dealerName;
  final String description;
  final List<String> photoUrls;
  final String? videoUrl;
  final String status; // open | approved_tech | partial | refund_dealer
  final String? adminNotes;
  final DateTime? resolvedAt;
  final String? resolution;
  final DateTime? createdAt;

  factory JobDisputeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final photos = d['photoUrls'] as List<dynamic>?;
    return JobDisputeModel(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      jobCode: d['jobCode'] as String?,
      dealerId: d['dealerId'] as String? ?? '',
      dealerCode: d['dealerCode'] as String?,
      dealerName: d['dealerName'] as String?,
      description: d['description'] as String? ?? '',
      photoUrls: photos?.map((e) => e.toString()).toList() ?? [],
      videoUrl: d['videoUrl'] as String?,
      status: d['status'] as String? ?? 'open',
      adminNotes: d['adminNotes'] as String?,
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
      resolution: d['resolution'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
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
