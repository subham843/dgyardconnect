import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceCompletionRecordModel {
  ServiceCompletionRecordModel({
    required this.id,
    this.recordCode,
    required this.jobId,
    this.jobCode,
    required this.dealerId,
    this.dealerCode,
    required this.dealerName,
    required this.technicianId,
    this.technicianCode,
    required this.technicianName,
    this.serviceSector,
    this.serviceSubSector,
    this.serviceType,
    this.serviceLocation,
    this.serviceDate,
    this.completionDate,
    this.customerOtpVerified = false,
    this.dealerApprovalStatus,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.warrantyDurationDays = 0,
    this.technicianPaymentReleased = 0,
    this.holdPaymentAmount = 0,
    this.recordStatus,
    this.createdAt,
  });

  final String id;
  final String? recordCode;
  final String jobId;
  final String? jobCode;
  final String dealerId;
  final String? dealerCode;
  final String dealerName;
  final String technicianId;
  final String? technicianCode;
  final String technicianName;
  final String? serviceSector;
  final String? serviceSubSector;
  final String? serviceType;
  final String? serviceLocation;
  final DateTime? serviceDate;
  final DateTime? completionDate;
  final bool customerOtpVerified;
  final String? dealerApprovalStatus;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final int warrantyDurationDays;
  final double technicianPaymentReleased;
  final double holdPaymentAmount;
  final String? recordStatus; // active | warranty_active | warranty_expired
  final DateTime? createdAt;

  factory ServiceCompletionRecordModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ServiceCompletionRecordModel(
      id: doc.id,
      recordCode: d['recordCode'] as String?,
      jobId: d['jobId'] as String? ?? '',
      jobCode: d['jobCode'] as String?,
      dealerId: d['dealerId'] as String? ?? '',
      dealerCode: d['dealerCode'] as String?,
      dealerName: d['dealerName'] as String? ?? '',
      technicianId: d['technicianId'] as String? ?? '',
      technicianCode: d['technicianCode'] as String?,
      technicianName: d['technicianName'] as String? ?? '',
      serviceSector: d['serviceSector'] as String?,
      serviceSubSector: d['serviceSubSector'] as String?,
      serviceType: d['serviceType'] as String?,
      serviceLocation: d['serviceLocation'] as String?,
      serviceDate: (d['serviceDate'] as Timestamp?)?.toDate(),
      completionDate: (d['completionDate'] as Timestamp?)?.toDate(),
      customerOtpVerified: d['customerOtpVerified'] as bool? ?? false,
      dealerApprovalStatus: d['dealerApprovalStatus'] as String?,
      warrantyStartDate: (d['warrantyStartDate'] as Timestamp?)?.toDate(),
      warrantyEndDate: (d['warrantyEndDate'] as Timestamp?)?.toDate(),
      warrantyDurationDays: d['warrantyDurationDays'] as int? ?? 0,
      technicianPaymentReleased: (d['technicianPaymentReleased'] as num?)?.toDouble() ?? 0,
      holdPaymentAmount: (d['holdPaymentAmount'] as num?)?.toDouble() ?? 0,
      recordStatus: d['recordStatus'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get displayRecordId {
    final c = (recordCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (id.isEmpty) return '—';
    return id.length <= 8 ? id : id.substring(0, 8).toUpperCase();
  }

  String get displayJobId {
    final c = (jobCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (jobId.isEmpty) return '—';
    return jobId.length <= 8 ? jobId : jobId.substring(0, 8).toUpperCase();
  }

  String get warrantyStatusLabel {
    switch (recordStatus) {
      case 'warranty_active':
        return 'Warranty active';
      case 'warranty_expired':
        return 'Warranty expired';
      default:
        return 'Active';
    }
  }

  String get displayDealerId {
    final c = (dealerCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (dealerId.isEmpty) return '—';
    return dealerId.length <= 8 ? dealerId : dealerId.substring(0, 8).toUpperCase();
  }

  String get displayTechnicianId {
    final c = (technicianCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (technicianId.isEmpty) return '—';
    return technicianId.length <= 8 ? technicianId : technicianId.substring(0, 8).toUpperCase();
  }

  DateTime? get effectiveWarrantyEndDate {
    if (warrantyEndDate != null) {
      if (warrantyStartDate != null &&
          !warrantyEndDate!.isAfter(warrantyStartDate!) &&
          recordStatus == 'warranty_active') {
        return warrantyStartDate!.add(Duration(days: effectiveWarrantyDurationDays));
      }
      return warrantyEndDate;
    }
    if (warrantyStartDate != null && (recordStatus == 'warranty_active' || warrantyDurationDays > 0)) {
      return warrantyStartDate!.add(Duration(days: effectiveWarrantyDurationDays));
    }
    return null;
  }

  int get effectiveWarrantyDurationDays {
    if (warrantyDurationDays > 0) return warrantyDurationDays;
    if (warrantyStartDate != null && warrantyEndDate != null) {
      final diff = warrantyEndDate!.difference(warrantyStartDate!).inDays;
      if (diff > 0) return diff;
    }
    if (recordStatus == 'warranty_active') return 20;
    return 0;
  }
}
