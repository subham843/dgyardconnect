import '../data/supabase_repository_base.dart';
import 'entity_image_placements.dart';
import 'shop_attribute.dart';
import 'shop_pricing.dart';
import 'shop_seo.dart';

/// Extended product record for admin create/edit (maps to products + inventory + metadata).
class ShopProductDetail {
  const ShopProductDetail({
    required this.id,
    required this.subCategoryId,
    this.categoryId,
    this.brandId,
    required this.sku,
    required this.name,
    this.barcode,
    this.modelName,
    this.hsnCode,
    this.taxPercentage = 0,
    this.useGstOverride = false,
    this.warranty,
    this.warrantyMonths,
    this.trackSerial = false,
    this.trackBatch = false,
    this.description,
    this.shortDescription,
    this.technicalNotes,
    this.installationNotes,
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.onlinePrice,
    this.dealerPrice,
    this.distributorPrice,
    this.mrp,
    this.basePrice = 0,
    this.taxClass,
    this.isActive = true,
    this.qtyOnHand = 0,
    this.reorderLevel = 0,
    this.unit = 'pcs',
    this.stockStatus = 'in_stock',
    this.mainImageUrl,
    this.mainImageEditorSourceUrl,
    this.mainImagePlacements,
    this.mainImageSourceW,
    this.mainImageSourceH,
    this.galleryUrls = const [],
    this.documentUrls = const [],
    this.datasheetUrls = const [],
    this.brochureUrls = const [],
    this.seo = const ShopSeoResolved(slug: ''),
    this.showInCalculator = false,
    this.calculatorFamilyId,
    this.calculatorFamilyIds = const [],
    this.calculatorPriority = 0,
    this.metadata = const {},
  });

  final String id;
  final String subCategoryId;
  final String? categoryId;
  final String? brandId;
  final String sku;
  final String name;
  final String? barcode;
  final String? modelName;
  final String? hsnCode;
  final double taxPercentage;
  final bool useGstOverride;
  final String? warranty;
  final int? warrantyMonths;
  final bool trackSerial;
  final bool trackBatch;
  final String? description;
  final String? shortDescription;
  final String? technicalNotes;
  final String? installationNotes;
  final double costPrice;
  final double sellingPrice;
  final double? onlinePrice;
  final double? dealerPrice;
  final double? distributorPrice;
  final double? mrp;
  final double basePrice;
  final String? taxClass;
  final bool isActive;
  final int qtyOnHand;
  final int reorderLevel;
  final String unit;
  final String stockStatus;
  final String? mainImageUrl;
  final String? mainImageEditorSourceUrl;
  final EntityImagePlacements? mainImagePlacements;
  final int? mainImageSourceW;
  final int? mainImageSourceH;
  final List<String> galleryUrls;
  final List<String> documentUrls;
  final List<String> datasheetUrls;
  final List<String> brochureUrls;
  final ShopSeoResolved seo;
  final bool showInCalculator;
  /// Primary / legacy single family (first of [calculatorFamilyIds]).
  final String? calculatorFamilyId;
  /// All calculator families this product belongs to (multi-select).
  final List<String> calculatorFamilyIds;
  final int calculatorPriority;
  final Map<String, dynamic> metadata;

  String? get seoTitle => seo.seoTitle;
  String? get seoDescription => seo.metaDescription;
  String? get urlSlug => seo.slug;
  String? get ogImageOverride => seo.ogImageOverride;

  static List<String> _urlsFromMeta(Map<String, dynamic> meta, String key) {
    final v = meta[key];
    if (v is List) return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  static List<String> _familyIdsFromRow(Map<String, dynamic> row) {
    final embedded = row['product_calculator_families'];
    if (embedded is List && embedded.isNotEmpty) {
      final ids = <String>[];
      for (final e in embedded) {
        if (e is Map && e['family_id'] != null) {
          ids.add(e['family_id'].toString());
        }
      }
      if (ids.isNotEmpty) return ids;
    }
    final single = row['calculator_family_id'] as String?;
    if (single != null && single.isNotEmpty) return [single];
    return const [];
  }

  /// Prefer multi-select list; fall back to legacy single id.
  List<String> get resolvedCalculatorFamilyIds {
    if (calculatorFamilyIds.isNotEmpty) return calculatorFamilyIds;
    if (calculatorFamilyId != null && calculatorFamilyId!.isNotEmpty) {
      return [calculatorFamilyId!];
    }
    return const [];
  }

  factory ShopProductDetail.fromRow(Map<String, dynamic> row, {String? categoryId}) {
    final meta = row['metadata'] is Map ? Map<String, dynamic>.from(row['metadata'] as Map) : <String, dynamic>{};
    final inv = SupabaseRepositoryBase.embeddedRows(row['inventory']);
    var qty = 0;
    var reorder = 0;
    var unit = 'pcs';
    var stockStatus = 'in_stock';
    if (inv.isNotEmpty) {
      final m = inv.first;
      qty = (m['qty_on_hand'] as num?)?.toInt() ?? 0;
      reorder = (m['reorder_level'] as num?)?.toInt() ?? 0;
      unit = m['unit'] as String? ?? 'pcs';
      stockStatus = m['stock_status'] as String? ?? 'in_stock';
    }
    final images = SupabaseRepositoryBase.embeddedRows(row['product_images']);
    String? mainImg;
    final gallery = <String>[];
    for (final img in images) {
      final url = img['url'] as String?;
      if (url == null || url.isEmpty) continue;
      gallery.add(url);
    }
    if (gallery.isNotEmpty) mainImg = gallery.first;
    final online = (row['online_price'] as num?)?.toDouble();
    final selling = (row['selling_price'] as num?)?.toDouble() ?? (row['base_price'] as num?)?.toDouble() ?? 0;
    final customer = ShopPricing.customerPrice(onlinePrice: online, sellingPrice: selling, basePrice: (row['base_price'] as num?)?.toDouble());
    return ShopProductDetail(
      id: row['id'] as String,
      subCategoryId: row['sub_category_id'] as String,
      categoryId: categoryId,
      brandId: row['brand_id'] as String?,
      sku: row['sku'] as String? ?? '',
      name: row['name'] as String? ?? '',
      barcode: row['barcode'] as String?,
      modelName: row['model_name'] as String?,
      hsnCode: row['hsn_code'] as String?,
      taxPercentage: (row['tax_percentage'] as num?)?.toDouble() ?? 0,
      useGstOverride: row['use_gst_override'] as bool? ?? false,
      warranty: row['warranty'] as String?,
      warrantyMonths: (row['warranty_months'] as num?)?.toInt(),
      trackSerial: row['track_serial'] as bool? ?? false,
      trackBatch: row['track_batch'] as bool? ?? false,
      description: row['description'] as String?,
      shortDescription: row['short_description'] as String?,
      technicalNotes: row['technical_notes'] as String?,
      installationNotes: row['installation_notes'] as String?,
      costPrice: (row['cost_price'] as num?)?.toDouble() ?? 0,
      sellingPrice: customer,
      onlinePrice: online ?? customer,
      dealerPrice: (row['dealer_price'] as num?)?.toDouble(),
      distributorPrice: (row['distributor_price'] as num?)?.toDouble(),
      mrp: (row['mrp'] as num?)?.toDouble(),
      basePrice: customer,
      taxClass: row['tax_class'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      qtyOnHand: qty,
      reorderLevel: reorder,
      unit: unit,
      stockStatus: stockStatus,
      mainImageUrl: mainImg,
      mainImageEditorSourceUrl: row['main_image_editor_source_url'] as String?,
      mainImagePlacements: EntityImagePlacements.fromJson(row['main_image_placements']),
      mainImageSourceW: (row['main_image_source_width'] as num?)?.toInt(),
      mainImageSourceH: (row['main_image_source_height'] as num?)?.toInt(),
      galleryUrls: _urlsFromMeta(meta, 'gallery_urls').isEmpty ? gallery : _urlsFromMeta(meta, 'gallery_urls'),
      documentUrls: _urlsFromMeta(meta, 'document_urls'),
      datasheetUrls: _urlsFromMeta(meta, 'datasheet_urls'),
      brochureUrls: _urlsFromMeta(meta, 'brochure_urls'),
      seo: ShopSeoResolved.fromProductRow(row),
      showInCalculator: row['show_in_calculator'] as bool? ?? false,
      calculatorFamilyId: row['calculator_family_id'] as String?,
      calculatorFamilyIds: _familyIdsFromRow(row),
      calculatorPriority: (row['calculator_priority'] as num?)?.toInt() ?? 0,
      metadata: meta,
    );
  }

  Map<String, dynamic> toProductPayload() {
    final meta = Map<String, dynamic>.from(metadata);
    if (galleryUrls.isNotEmpty) meta['gallery_urls'] = galleryUrls;
    if (documentUrls.isNotEmpty) meta['document_urls'] = documentUrls;
    if (datasheetUrls.isNotEmpty) meta['datasheet_urls'] = datasheetUrls;
    if (brochureUrls.isNotEmpty) meta['brochure_urls'] = brochureUrls;
    return {
      'sub_category_id': subCategoryId,
      if (brandId != null && brandId!.isNotEmpty) 'brand_id': brandId,
      'sku': sku.trim(),
      'name': name.trim(),
      if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      if (modelName != null && modelName!.isNotEmpty) 'model_name': modelName,
      if (hsnCode != null && hsnCode!.isNotEmpty) 'hsn_code': hsnCode,
      'tax_percentage': taxPercentage,
      'use_gst_override': useGstOverride,
      if (warranty != null) 'warranty': warranty,
      if (warrantyMonths != null) 'warranty_months': warrantyMonths,
      'track_serial': trackSerial,
      'track_batch': trackBatch,
      'description': description,
      if (shortDescription != null) 'short_description': shortDescription,
      if (technicalNotes != null) 'technical_notes': technicalNotes,
      if (installationNotes != null) 'installation_notes': installationNotes,
      'cost_price': costPrice,
      if (onlinePrice != null && onlinePrice! > 0) ...{
        'online_price': onlinePrice,
        'selling_price': onlinePrice,
        'base_price': onlinePrice,
      } else if (sellingPrice > 0) ...{
        'online_price': sellingPrice,
        'selling_price': sellingPrice,
        'base_price': sellingPrice,
      },
      if (dealerPrice != null) 'dealer_price': dealerPrice,
      if (mrp != null) 'mrp': mrp,
      if (taxClass != null) 'tax_class': taxClass,
      'is_active': isActive,
      ...seo.toProductPayload(),
      'show_in_calculator': showInCalculator,
      'calculator_family_id': showInCalculator
          ? (resolvedCalculatorFamilyIds.isNotEmpty ? resolvedCalculatorFamilyIds.first : null)
          : null,
      'calculator_priority': calculatorPriority,
      'metadata': meta,
    };
  }
}

/// Attributes grouped by attribute group for product forms.
class ShopAttributeGroupSection {
  const ShopAttributeGroupSection({
    required this.groupId,
    required this.groupName,
    required this.attributes,
  });

  final String groupId;
  final String groupName;
  final List<ShopSubCategoryLinkedAttribute> attributes;
}

class ShopSubCategoryLinkedAttribute {
  const ShopSubCategoryLinkedAttribute({required this.master, this.isRequiredInGroup = false});

  final ShopAttributeMaster master;
  final bool isRequiredInGroup;
}
