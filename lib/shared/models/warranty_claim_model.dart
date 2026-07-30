import 'package:cloud_firestore/cloud_firestore.dart';

/// Warranty claim status values (must match backend).
enum WarrantyClaimStatus {
  pending,
  technicianAccepted,
  technicianFailed,
  replacementAssigned,
  resolved,
  closed,
}

class WarrantyClaimModel {
  WarrantyClaimModel({
    required this.id,
    required this.jobId,
    this.jobCode,
    required this.dealerId,
    required this.technicianId,
    required this.problemDescription,
    this.photoUrls = const [],
    this.videoUrl,
    this.categoryId,
    this.categoryTitle,
    required this.claimStatus,
    required this.claimTime,
    this.claimResponseDeadline,
    this.technicianResponseStatus,
    this.rejectionReason,
    this.replacementTechnicianId,
    this.resolvedAt,
    this.holdPaymentAmount,
    this.extraPaymentApproved,
  });

  final String id;
  final String jobId;
  final String? jobCode;
  final String dealerId;
  final String technicianId;
  final String problemDescription;
  final List<String> photoUrls;
  final String? videoUrl;
  final String? categoryId;
  final String? categoryTitle;
  final WarrantyClaimStatus claimStatus;
  final DateTime? claimTime;
  final DateTime? claimResponseDeadline;
  final String? technicianResponseStatus; // 'accepted' | 'rejected' | null
  final String? rejectionReason;
  final String? replacementTechnicianId;
  final DateTime? resolvedAt;
  final double? holdPaymentAmount;
  final bool? extraPaymentApproved;

  factory WarrantyClaimModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final photos = d['photoUrls'] as List<dynamic>?;
    return WarrantyClaimModel(
      id: doc.id,
      jobId: d['jobId'] as String? ?? '',
      jobCode: d['jobCode'] as String?,
      dealerId: d['dealerId'] as String? ?? '',
      technicianId: d['technicianId'] as String? ?? '',
      problemDescription: d['problemDescription'] as String? ?? '',
      photoUrls: photos?.map((e) => e as String).toList() ?? [],
      videoUrl: d['videoUrl'] as String?,
      categoryId: d['categoryId'] as String?,
      categoryTitle: d['categoryTitle'] as String?,
      claimStatus: _parseStatus(d['claimStatus'] as String?),
      claimTime: (d['claimTime'] as Timestamp?)?.toDate(),
      claimResponseDeadline: (d['claimResponseDeadline'] as Timestamp?)?.toDate(),
      technicianResponseStatus: d['technicianResponseStatus'] as String?,
      rejectionReason: d['rejectionReason'] as String?,
      replacementTechnicianId: d['replacementTechnicianId'] as String?,
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
      holdPaymentAmount: (d['holdPaymentAmount'] as num?)?.toDouble(),
      extraPaymentApproved: d['extraPaymentApproved'] as bool?,
    );
  }

  static WarrantyClaimStatus _parseStatus(String? v) {
    switch (v) {
      case 'technician_accepted':
        return WarrantyClaimStatus.technicianAccepted;
      case 'technician_failed':
        return WarrantyClaimStatus.technicianFailed;
      case 'replacement_assigned':
        return WarrantyClaimStatus.replacementAssigned;
      case 'resolved':
        return WarrantyClaimStatus.resolved;
      case 'closed':
        return WarrantyClaimStatus.closed;
      default:
        return WarrantyClaimStatus.pending;
    }
  }

  String get statusLabel {
    switch (claimStatus) {
      case WarrantyClaimStatus.pending:
        return 'Pending';
      case WarrantyClaimStatus.technicianAccepted:
        return 'Technician accepted';
      case WarrantyClaimStatus.technicianFailed:
        return 'Technician failed';
      case WarrantyClaimStatus.replacementAssigned:
        return 'Replacement assigned';
      case WarrantyClaimStatus.resolved:
        return 'Resolved';
      case WarrantyClaimStatus.closed:
        return 'Closed';
    }
  }

  bool get isPending => claimStatus == WarrantyClaimStatus.pending;
  bool get isResolved => claimStatus == WarrantyClaimStatus.resolved || claimStatus == WarrantyClaimStatus.closed;
  bool get isTechnicianFailed => claimStatus == WarrantyClaimStatus.technicianFailed;
  bool get hasResponseDeadline => claimResponseDeadline != null && claimStatus == WarrantyClaimStatus.pending;

  String get displayJobId {
    final c = (jobCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (jobId.isEmpty) return '—';
    return jobId.length <= 8 ? jobId : jobId.substring(0, 8).toUpperCase();
  }
}
