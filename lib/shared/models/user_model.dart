import 'package:cloud_firestore/cloud_firestore.dart';

enum AppRole { superadmin, dealer, technician, customer }

enum TechnicianLevel { bronze, silver, gold, elite }

enum DealerLevel { basic, trusted, premium, enterprise }

enum AccountStatus { active, warning, temporarilyBlocked, suspended }

class UserModel {
  UserModel({
    required this.uid,
    this.userCode,
    this.email,
    this.role = AppRole.dealer,
    this.approved = false,
    this.profile,
    this.dealerSectors,
    this.skills,
    this.serviceArea,
    this.avgRating,
    this.totalJobsCompleted = 0,
    this.totalCancelledJobs = 0,
    this.onTimeRate,
    this.trustScore,
    this.reputationLevel,
    this.accountStatus = AccountStatus.active,
    this.technicianLevel,
    this.technicianPenaltyPoints = 0,
    this.dealerLevel,
    this.dealerPenaltyPoints = 0,
    this.adminOverrideLevel,
    this.manualLevelOverride = false,
    this.availabilityStatus,
    this.createdAt,
  });

  final String uid;
  final String? userCode;
  final String? email;
  final AppRole role;
  final bool approved;
  final Map<String, dynamic>? profile;
  final List<String>? dealerSectors;
  final List<Map<String, dynamic>>? skills;
  final Map<String, dynamic>? serviceArea;
  final double? avgRating;
  final int totalJobsCompleted;
  final int totalCancelledJobs;
  final double? onTimeRate;
  final double? trustScore;
  /// Reputation level from trust score: elite | trusted | standard | risky | restricted
  final String? reputationLevel;
  final AccountStatus accountStatus;
  final TechnicianLevel? technicianLevel;
  final int technicianPenaltyPoints;
  final DealerLevel? dealerLevel;
  final int dealerPenaltyPoints;
  final String? adminOverrideLevel;
  /// When true, technician level is not auto-updated from trust score.
  final bool manualLevelOverride;
  /// Technician availability: online | busy | offline. When busy, cannot switch to online until job completes.
  final String? availabilityStatus;
  final DateTime? createdAt;

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      userCode: d['userCode'] as String?,
      email: d['email'] as String?,
      role: _parseRole(d['role']),
      approved: d['approved'] as bool? ?? false,
      profile: d['profile'] as Map<String, dynamic>?,
      dealerSectors: (d['dealerSectors'] as List?)?.cast<String>(),
      skills: (d['skills'] as List?)?.cast<Map<String, dynamic>>(),
      serviceArea: d['serviceArea'] as Map<String, dynamic>?,
      avgRating: (d['avgRating'] as num?)?.toDouble(),
      totalJobsCompleted: d['totalJobsCompleted'] as int? ?? 0,
      totalCancelledJobs: d['totalCancelledJobs'] as int? ?? 0,
      onTimeRate: (d['onTimeRate'] as num?)?.toDouble(),
      trustScore: (d['trustScore'] as num?)?.toDouble(),
      reputationLevel: d['reputationLevel'] as String?,
      accountStatus: _parseAccountStatus(d['accountStatus']),
      technicianLevel: _parseTechnicianLevel(d['technicianLevel']),
      technicianPenaltyPoints: d['technicianPenaltyPoints'] as int? ?? 0,
      dealerLevel: _parseDealerLevel(d['dealerLevel']),
      dealerPenaltyPoints: d['dealerPenaltyPoints'] as int? ?? 0,
      adminOverrideLevel: d['adminOverrideLevel'] as String?,
      manualLevelOverride: d['manual_level_override'] as bool? ?? false,
      availabilityStatus: d['availabilityStatus'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static AppRole _parseRole(String? v) {
    switch (v) {
      case 'superadmin': return AppRole.superadmin;
      case 'technician': return AppRole.technician;
      case 'customer': return AppRole.customer;
      default: return AppRole.dealer;
    }
  }

  static AccountStatus _parseAccountStatus(String? v) {
    switch (v) {
      case 'warning': return AccountStatus.warning;
      case 'temporarily_blocked': return AccountStatus.temporarilyBlocked;
      case 'suspended': return AccountStatus.suspended;
      default: return AccountStatus.active;
    }
  }

  static TechnicianLevel? _parseTechnicianLevel(String? v) {
    switch (v) {
      case 'bronze': return TechnicianLevel.bronze;
      case 'silver': return TechnicianLevel.silver;
      case 'gold': return TechnicianLevel.gold;
      case 'elite': return TechnicianLevel.elite;
      case 'platinum': return TechnicianLevel.elite; // legacy
      default: return null;
    }
  }

  static DealerLevel? _parseDealerLevel(String? v) {
    switch (v) {
      case 'basic': return DealerLevel.basic;
      case 'trusted': return DealerLevel.trusted;
      case 'premium': return DealerLevel.premium;
      case 'enterprise': return DealerLevel.enterprise;
      default: return null;
    }
  }

  String get displayName => profile?['name'] as String? ?? email ?? uid;

  String get displayId {
    final c = (userCode ?? '').trim();
    if (c.isNotEmpty) return c;
    if (uid.isEmpty) return '—';
    return uid.length <= 8 ? uid : uid.substring(0, 8).toUpperCase();
  }
}
