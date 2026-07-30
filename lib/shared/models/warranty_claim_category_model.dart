import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyClaimCategoryModel {
  WarrantyClaimCategoryModel({
    required this.id,
    this.sectorId,
    this.subOptionId,
    required this.title,
    this.description,
    this.sortOrder = 0,
  });

  final String id;
  final String? sectorId;
  final String? subOptionId;
  final String title;
  final String? description;
  final int sortOrder;

  factory WarrantyClaimCategoryModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return WarrantyClaimCategoryModel(
      id: doc.id,
      sectorId: d['sectorId'] as String?,
      subOptionId: d['subOptionId'] as String?,
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      sortOrder: d['sortOrder'] as int? ?? 0,
    );
  }
}
