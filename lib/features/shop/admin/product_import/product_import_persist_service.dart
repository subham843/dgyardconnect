import '../../data/shop_catalog_repository.dart';
import '../../data/supabase_repository_base.dart';
import '../../domain/attribute_data_type.dart';
import '../../domain/shop_media_models.dart';
import '../../domain/shop_product_detail.dart';
import '../../domain/shop_seo.dart';
import '../widgets/product_attribute_fields.dart';
import 'product_import_draft.dart';
import 'product_import_media_service.dart';

class ProductImportPersistResult {
  const ProductImportPersistResult({required this.productId, required this.sku});

  final String productId;
  final String sku;
}

class ProductImportPersistService {
  ProductImportPersistService({
    ShopCatalogRepository? repo,
  }) : _repo = repo ?? ShopCatalogRepository();

  final ShopCatalogRepository _repo;

  Future<ProductImportPersistResult> save({
    required ProductImportDraft draft,
    required String categoryId,
    required String subCategoryId,
    String? brandId,
    List<String> attributeGroupIds = const [],
    bool createMissingAttributes = true,
    bool downloadMedia = true,
  }) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();

    if (attributeGroupIds.isNotEmpty) {
      await _assignAttributeGroups(subCategoryId, attributeGroupIds);
    }

    if (createMissingAttributes) {
      await _ensureAttributes(draft, attributeGroupIds: attributeGroupIds);
    }

    final cat = await _repo.getCategory(categoryId);
    final sub = await _repo.getSubCategory(subCategoryId);
    if (sub == null) throw StateError('Sub-category not found');

    var skuBase = draft.modelName?.trim().isNotEmpty == true
        ? SupabaseRepositoryBase.slugify(draft.modelName!)
        : SupabaseRepositoryBase.slugify(draft.name);
    final sku = await _repo.resolveUniqueProductSku(skuBase);

    final seo = ShopSeoService.resolveProduct(
      input: ShopSeoAdminInput(
        seoTitle: draft.seoTitle ?? '',
        metaDescription: draft.metaDescription ?? '',
        slugOverride: draft.slug ?? '',
      ),
      name: draft.name,
      categorySlug: cat?.slug ?? draft.categorySlug ?? '',
      subCategorySlug: sub.slug,
      fallbackSku: sku,
    );

    final detail = ShopProductDetail(
      id: '',
      subCategoryId: subCategoryId,
      categoryId: categoryId,
      brandId: brandId,
      sku: sku,
      name: draft.name.trim(),
      modelName: draft.modelName,
      hsnCode: draft.hsnCode,
      taxPercentage: draft.gstPercentage ?? sub.defaultGstPercentage,
      useGstOverride: draft.gstPercentage != null,
      description: draft.description,
      shortDescription: draft.shortDescription,
      technicalNotes: draft.technicalNotes ??
          (draft.specifications.isNotEmpty
              ? draft.specifications.map((s) => '${s.label}: ${s.value}').join('\n')
              : null),
      installationNotes: draft.installationNotes,
      costPrice: draft.costPrice ?? 0,
      mrp: draft.mrp,
      onlinePrice: draft.onlinePrice,
      dealerPrice: draft.dealerPrice,
      sellingPrice: draft.onlinePrice ?? 0,
      warranty: draft.warranty,
      warrantyMonths: draft.warrantyMonths,
      isActive: true,
      seo: seo,
    );

    String? brandName;
    if (brandId != null) {
      final brands = await _repo.listBrands();
      brandName = brands.where((b) => b.id == brandId).map((b) => b.name).firstOrNull;
    }

    final productId = await _repo.saveProductDetail(
      detail,
      brandName: brandName,
      categorySlug: cat?.slug ?? draft.categorySlug,
      subCategorySlug: sub.slug,
    );
    if (productId == null) throw StateError('Could not save product');

    if (draft.keywords.isNotEmpty) {
      await _saveKeywords(productId, draft.keywords);
    }

    final attrRows = await _repo.listProductAttributeValues(productId);
    final values = <String, dynamic>{};
    for (final attr in draft.attributes) {
      if (attr.value == null || attr.value!.trim().isEmpty) continue;
      final row = attrRows.where((r) => r.master.key.toLowerCase() == attr.key.toLowerCase()).firstOrNull;
      if (row != null) values[row.master.id] = attr.value;
    }
    if (values.isNotEmpty) {
      await saveProductAttributeValues(_repo, attrRows, values);
    }

    if (downloadMedia &&
        (draft.imageUrls.isNotEmpty || draft.datasheetUrls.isNotEmpty || draft.manualUrls.isNotEmpty)) {
      ProcessedShopImage? main;
      if (draft.imageUrls.isNotEmpty) {
        main = await ProductImportMediaService.downloadMainImage(
          url: draft.imageUrls.first,
          productName: draft.name,
        );
      }
      final items = await ProductImportMediaService.buildMediaItems(
        productName: draft.name,
        imageUrls: draft.imageUrls.length > 1 ? draft.imageUrls.sublist(1) : const [],
        datasheetUrls: draft.datasheetUrls,
        manualUrls: draft.manualUrls,
        mainImage: main,
      );
      await ProductImportMediaService.persistAll(
        productId: productId,
        productName: draft.name,
        mainPending: main,
        items: items,
      );
    }

    return ProductImportPersistResult(productId: productId, sku: sku);
  }

  Future<String?> resolveBrandId(String? brandName) async {
    if (brandName == null || brandName.trim().isEmpty) return null;
    final brands = await _repo.listBrands();
    final match = brands.where((b) => b.name.toLowerCase() == brandName.toLowerCase()).firstOrNull;
    if (match != null) return match.id;
    await _repo.createBrand(brandName.trim());
    final refreshed = await _repo.listBrands();
    return refreshed.where((b) => b.name.toLowerCase() == brandName.toLowerCase()).map((b) => b.id).firstOrNull;
  }

  Future<void> _assignAttributeGroups(String subCategoryId, List<String> groupIds) async {
    for (final gid in groupIds) {
      await _repo.assignGroupToSubCategory(subCategoryId: subCategoryId, attributeGroupId: gid);
    }
  }

  Future<void> _saveKeywords(String productId, List<String> keywords) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final text = keywords.map((k) => k.trim()).where((k) => k.isNotEmpty).join(', ');
    if (text.isEmpty) return;
    await c.from('products').update({'seo_keywords': text}).eq('id', productId);
  }

  Future<void> _ensureAttributes(
    ProductImportDraft draft, {
    List<String> attributeGroupIds = const [],
  }) async {
    final existing = await _repo.listAttributeMaster(activeOnly: false);
    final idByKey = {for (final a in existing) a.key.toLowerCase(): a.id};
    final seenKeys = idByKey.keys.toSet();

    for (final attr in draft.attributes) {
      if (attr.key.trim().isEmpty) continue;
      final k = attr.key.toLowerCase();
      String? attrId;

      if (!seenKeys.contains(k)) {
        attrId = await _repo.createAttributeMaster(
          key: attr.key.trim(),
          label: attr.label.trim().isEmpty ? attr.key.trim() : attr.label.trim(),
          dataType: AttributeDataType.all.contains(attr.dataType) ? attr.dataType : AttributeDataType.text,
          allowedValues: attr.allowedValues.isEmpty ? null : attr.allowedValues,
          useInFilter: true,
        );
        if (attrId != null) {
          seenKeys.add(k);
          idByKey[k] = attrId;
        }
      } else {
        attrId = idByKey[k];
      }

      if (attrId == null) continue;

      for (final gid in attributeGroupIds) {
        await _repo.linkAttributeToGroup(groupId: gid, attributeId: attrId);
      }

      if (attr.allowedValues.isNotEmpty) {
        final opts = await _repo.listAttributeOptions(attrId);
        final labels = opts.map((o) => o.label.toLowerCase()).toSet();
        var sort = opts.length;
        for (final value in attr.allowedValues) {
          final v = value.trim();
          if (v.isEmpty || labels.contains(v.toLowerCase())) continue;
          await _repo.createAttributeOption(attributeId: attrId, label: v, sortOrder: sort++);
          labels.add(v.toLowerCase());
        }
      }
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
