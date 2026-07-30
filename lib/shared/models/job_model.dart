import 'package:cloud_firestore/cloud_firestore.dart';

enum JobStatus {
  posted,
  bidding,
  agreed,
  paymentPending,
  paid,
  inProgress,
  pendingDealerConfirm,
  completed,
  cancelled,
  expired,
  closed,
}

enum JobPriority { normal, emergency }

class JobModel {
  JobModel({
    required this.id,
    required this.dealerId,
    this.jobCode,
    this.jobTypeId,
    this.sectorId,
    this.subOptionId,
    this.industryId,
    this.priority = JobPriority.normal,
    this.emergencyChargeAmount,
    this.fixedRate,
    this.dealerRate,
    this.biddingEnabled = true,
    this.materialOption,
    this.pickupAddress,
    this.pickupMaterialList,
    this.warrantyPeriod,
    this.title,
    this.description,
    this.address,
    this.siteContactName,
    this.siteContactPhone,
    this.status = JobStatus.posted,
    this.technicianId,
    this.agreedAmount,
    this.platformChargeAmount,
    this.technicianPayoutAmount,
    this.createdAt,
    this.completedAt,
    this.proofPhotos,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.warrantyStatus,
    this.holdPaymentAmount,
    this.paymentStatus,
    this.dealerApprovalDeadline,
    this.techniciansNotifiedCount,
    this.techniciansRejectedCount,
    this.bidsReceivedCount,
    this.notificationRound,
    this.bidRound,
    this.lastRejectionReason,
    this.lastRejectedBy,
    this.duplicateJobFlag = false,
    this.biddingMaxReached = false,
  });

  final String id;
  final String dealerId;
  final String? jobCode;
  final String? jobTypeId;
  final String? sectorId;
  final String? subOptionId;
  final String? industryId;
  final JobPriority priority;
  final double? emergencyChargeAmount;
  final double? fixedRate;
  final double? dealerRate;
  final bool biddingEnabled;
  final String? materialOption;
  final String? pickupAddress;
  final List<Map<String, dynamic>>? pickupMaterialList;
  final int? warrantyPeriod;
  final String? title;
  final String? description;
  final String? address;
  final String? siteContactName;
  final String? siteContactPhone;
  final JobStatus status;
  final String? technicianId;
  final double? agreedAmount;
  final double? platformChargeAmount;
  final double? technicianPayoutAmount;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final List<Map<String, dynamic>>? proofPhotos;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final String? warrantyStatus; // 'active' | 'expired' | 'claim_open'
  final double? holdPaymentAmount;
  /// Payment lifecycle: payment_pending | payment_escrowed | approval_pending | payment_released | warranty_hold | warranty_released
  final String? paymentStatus;
  /// When status is pending_dealer_confirm, dealer must approve before this time or auto-approval runs.
  final DateTime? dealerApprovalDeadline;
  final int? techniciansNotifiedCount;
  final int? techniciansRejectedCount;
  final int? bidsReceivedCount;
  final int? notificationRound;
  final int? bidRound;
  final String? lastRejectionReason;
  final String? lastRejectedBy;
  final bool duplicateJobFlag;
  final bool biddingMaxReached;

  factory JobModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return JobModel(
      id: doc.id,
      dealerId: d['dealerId'] as String? ?? '',
      jobCode: d['jobCode'] as String?,
      jobTypeId: d['jobTypeId'] as String?,
      sectorId: d['sectorId'] as String?,
      subOptionId: d['subOptionId'] as String? ?? d['sectorSubOptionId'] as String?,
      industryId: d['industryId'] as String?,
      priority: d['priority'] == 'emergency' ? JobPriority.emergency : JobPriority.normal,
      emergencyChargeAmount: (d['emergencyChargeAmount'] as num?)?.toDouble(),
      fixedRate: (d['fixedRate'] as num?)?.toDouble(),
      dealerRate: (d['dealerRate'] as num?)?.toDouble(),
      biddingEnabled: d['biddingEnabled'] as bool? ?? true,
      materialOption: d['materialOption'] as String?,
      pickupAddress: d['pickupAddress'] as String?,
      pickupMaterialList: (d['pickupMaterialList'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      warrantyPeriod: d['warrantyPeriod'] as int? ?? d['warrantyPeriodDays'] as int?,
      title: d['title'] as String?,
      description: d['description'] as String?,
      address: d['address'] as String?,
      siteContactName: d['siteContactName'] as String?,
      siteContactPhone: d['siteContactPhone'] as String?,
      status: _parseStatus(d['status']),
      technicianId: d['technicianId'] as String?,
      agreedAmount: (d['agreedAmount'] as num?)?.toDouble(),
      platformChargeAmount: (d['platformChargeAmount'] as num?)?.toDouble(),
      technicianPayoutAmount: (d['technicianPayoutAmount'] as num?)?.toDouble(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
      proofPhotos: (d['proofPhotos'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      warrantyStartDate: (d['warrantyStartDate'] as Timestamp?)?.toDate(),
      warrantyEndDate: (d['warrantyEndDate'] as Timestamp?)?.toDate(),
      warrantyStatus: d['warrantyStatus'] as String?,
      holdPaymentAmount: (d['holdPaymentAmount'] as num?)?.toDouble(),
      paymentStatus: d['paymentStatus'] as String?,
      dealerApprovalDeadline: (d['dealerApprovalDeadline'] as Timestamp?)?.toDate(),
      techniciansNotifiedCount: d['techniciansNotifiedCount'] as int?,
      techniciansRejectedCount: d['techniciansRejectedCount'] as int?,
      bidsReceivedCount: d['bidsReceivedCount'] as int?,
      notificationRound: d['notificationRound'] as int?,
      bidRound: d['bidRound'] as int?,
      lastRejectionReason: d['lastRejectionReason'] as String?,
      lastRejectedBy: d['lastRejectedBy'] as String?,
      duplicateJobFlag: d['duplicateJobFlag'] as bool? ?? false,
      biddingMaxReached: d['biddingMaxReached'] as bool? ?? false,
    );
  }

  bool get hasActiveWarranty {
    // Warranty is considered active if its effective end date is in the future,
    // unless explicitly marked expired.
    //
    // Backward compatibility:
    // - Some jobs have warrantyStatus='active' but missing warrantyEndDate.
    //   In that case, default warranty applies from completedAt (or warrantyStartDate) for 20 days.
    final status = (warrantyStatus ?? '').trim();
    if (status == 'expired') return false;

    DateTime? end = warrantyEndDate;
    if (end == null) {
      if (status == 'active') {
        final base = completedAt ?? warrantyStartDate ?? createdAt;
        if (base != null) end = base.add(const Duration(days: 20));
        // Legacy docs may have active status without any date fields.
        // In such case, trust explicit active flag so UI can still allow claim flow.
        if (base == null) return true;
      }
    }
    if (end == null) return false;
    if (!end.isAfter(DateTime.now())) return false;
    return true;
  }

  bool get canRaiseWarrantyClaim {
    final status = (warrantyStatus ?? '').trim();
    if (status == 'claim_open') return false;
    return hasActiveWarranty;
  }

  static JobStatus _parseStatus(String? v) {
    switch (v) {
      case 'bidding': return JobStatus.bidding;
      case 'agreed': return JobStatus.agreed;
      case 'payment_pending': return JobStatus.paymentPending;
      case 'paid': return JobStatus.paid;
      case 'in_progress': return JobStatus.inProgress;
      case 'pending_dealer_confirm': return JobStatus.pendingDealerConfirm;
      case 'completed': return JobStatus.completed;
      case 'cancelled': return JobStatus.cancelled;
      case 'expired': return JobStatus.expired;
      case 'closed': return JobStatus.closed;
      default: return JobStatus.posted;
    }
  }

  bool get isEmergency => priority == JobPriority.emergency;

  String get displayId {
    final c = (jobCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (id.isEmpty) return '—';
    // Legacy fallback (Firestore auto-id): show only first few chars to reduce noise.
    return id.length <= 8 ? id : id.substring(0, 8).toUpperCase();
  }
}
