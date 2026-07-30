// Public Store Repository
// Loads the full admin-managed catalog bundle in a few queries, then the UI
// facets / filters / searches client-side for an instant, premium experience.
//
// Sources (all admin-controlled, anon-readable):
//   v_public_categories, v_public_subcategories, v_public_products,
//   v_public_product_images, v_public_product_attributes,
//   brands, shop_banners, v_active_offers
//
// No hardcoded store content. Sensitive pricing (cost/dealer/distributor)
// never leaves the secure views.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/public_rest_client.dart';
import '../../../../core/supabase/public_supabase_client.dart';
import '../models/public_brand.dart';
import '../models/public_store_models.dart';

class PublicStoreRepository {
  SupabaseClient get _client => PublicSupabaseClient.instance;

  Future<StoreCatalog> loadCatalog() async {
    final results = await Future.wait([
      _safeRest(() => PublicRestClient.select('v_public_categories', order: 'sort_order')),
      _safeRest(() => PublicRestClient.select('v_public_subcategories', order: 'sort_order')),
      _safeRest(() => PublicRestClient.select('v_public_products', limit: 2000)),
      _safeRest(
        () => PublicRestClient.select(
          'brands',
          order: 'display_order,name',
          eq: {'is_active': 'true'},
        ),
      ),
      _safeRest(() => PublicRestClient.select('v_public_product_images', order: 'sort_order')),
      _safeRest(_loadBannersRest),
      _safeRest(_loadOffersRest),
      _safeRest(() => PublicRestClient.select('v_public_product_attributes', limit: 8000)),
    ]);

    final categoryRows = results[0];
    final subcategoryRows = results[1];
    final productRows = results[2];
    final brandRows = results[3];
    final imageRows = results[4];
    final bannerRows = results[5];
    final offerRows = results[6];
    final attributeRows = results[7];

    final categories = categoryRows.map(PublicCategory.fromRow).toList();
    final subcategories =
        subcategoryRows.map(PublicSubcategory.fromRow).toList();
    final brands = brandRows.map(PublicBrand.fromRow).toList();
    final products = productRows.map(PublicProduct.fromRow).toList();

    // --- Lookups -------------------------------------------------------------
    final brandById = {for (final b in brands) b.id: b};
    final subById = {for (final s in subcategories) s.id: s};

    // Primary image (lowest sort_order) + gallery per product.
    final imagesByProduct = <String, List<String>>{};
    for (final row in imageRows) {
      final pid = row['product_id']?.toString();
      if (pid == null) continue;
      final url = (row['medium_url'] ?? row['large_url'] ?? row['url']) as String?;
      if (url == null || url.trim().isEmpty) continue;
      (imagesByProduct[pid] ??= []).add(url);
    }
    final thumbByProduct = <String, String>{};
    for (final row in imageRows) {
      final pid = row['product_id']?.toString();
      if (pid == null) continue;
      final url = (row['thumbnail_url'] ?? row['medium_url'] ?? row['url']) as String?;
      if (url == null || url.trim().isEmpty) continue;
      thumbByProduct.putIfAbsent(pid, () => url);
    }

    // Attributes per product (label -> value), only meaningful values kept.
    final attrsByProduct = <String, Map<String, String>>{};
    for (final row in attributeRows) {
      final pid = row['product_id']?.toString();
      if (pid == null) continue;
      final label = (row['attribute_label'] ?? '').toString().trim();
      final value = _attrValue(row);
      if (label.isEmpty || value.isEmpty) continue;
      (attrsByProduct[pid] ??= <String, String>{})[label] = value;
    }

    // --- Resolve products ----------------------------------------------------
    for (final p in products) {
      final sub = p.subCategoryId != null ? subById[p.subCategoryId] : null;
      p.categoryId = sub?.categoryId;
      p.brandName = p.brandId != null ? brandById[p.brandId]?.name : null;
      p.galleryUrls = imagesByProduct[p.id] ?? const [];
      p.imageUrl = p.galleryUrls.isNotEmpty ? p.galleryUrls.first : null;
      p.thumbnailUrl = thumbByProduct[p.id] ?? p.imageUrl;
      p.attributes = attrsByProduct[p.id] ?? const {};
    }

    // --- Counts --------------------------------------------------------------
    final subCount = <String, int>{};
    final catCount = <String, int>{};
    for (final p in products) {
      if (p.subCategoryId != null) {
        subCount[p.subCategoryId!] = (subCount[p.subCategoryId!] ?? 0) + 1;
      }
      if (p.categoryId != null) {
        catCount[p.categoryId!] = (catCount[p.categoryId!] ?? 0) + 1;
      }
    }
    for (final s in subcategories) {
      s.productCount = subCount[s.id] ?? 0;
    }

    // Nest subcategories under categories.
    final subsByCat = <String, List<PublicSubcategory>>{};
    for (final s in subcategories) {
      (subsByCat[s.categoryId] ??= []).add(s);
    }
    final nestedCategories = <PublicCategory>[];
    for (final c in categories) {
      c.productCount = catCount[c.id] ?? 0;
      nestedCategories.add(PublicCategory(
        id: c.id,
        name: c.name,
        slug: c.slug,
        description: c.description,
        imageUrl: c.imageUrl,
        imageEditorSourceUrl: c.imageEditorSourceUrl,
        imagePlacements: c.imagePlacements,
        imageSourceW: c.imageSourceW,
        imageSourceH: c.imageSourceH,
        productCount: c.productCount,
        subcategories: subsByCat[c.id] ?? const [],
      ));
    }

    return StoreCatalog(
      categories: nestedCategories,
      subcategories: subcategories,
      products: products,
      brands: brands,
      banners: bannerRows.map(PublicBanner.fromRow).toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
      offers: offerRows.map(PublicOffer.fromRow).toList()
        ..sort((a, b) => b.priority.compareTo(a.priority)),
    );
  }

  /// Loads a single product with gallery, grouped specs, brand, taxonomy and
  /// related items — for the premium product detail page.
  Future<ProductDetailData?> loadProductDetail(String slugOrId) async {
    Map<String, dynamic>? row = await _client
        .from('v_public_products')
        .select()
        .eq('url_slug', slugOrId)
        .maybeSingle();
    row ??= await _client
        .from('v_public_products')
        .select()
        .eq('id', slugOrId)
        .maybeSingle();
    if (row == null) return null;

    final product = PublicProduct.fromRow(row);

    final imageRows = await _safe(() => _client
        .from('v_public_product_images')
        .select()
        .eq('product_id', product.id)
        .order('sort_order'));
    product.galleryUrls = imageRows
        .map((r) =>
            (r['large_url'] ?? r['medium_url'] ?? r['url']) as String?)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    product.imageUrl =
        product.galleryUrls.isNotEmpty ? product.galleryUrls.first : null;

    final attrRows = await _safe(() => _client
        .from('v_public_product_attributes')
        .select()
        .eq('product_id', product.id));
    final specs = <ProductSpec>[];
    for (final r in attrRows) {
      final label = (r['attribute_label'] ?? '').toString().trim();
      final value = _attrValue(r);
      if (label.isEmpty || value.isEmpty) continue;
      specs.add(ProductSpec(label: label, value: value));
    }
    specs.sort((a, b) => a.label.compareTo(b.label));

    PublicBrand? brand;
    if (product.brandId != null) {
      final b = await _client
          .from('brands')
          .select()
          .eq('id', product.brandId!)
          .maybeSingle();
      if (b != null) {
        brand = PublicBrand.fromRow(b);
        product.brandName = brand.name;
      }
    }

    String? categoryName;
    String? categorySlug;
    String? subcategoryName;
    if (product.subCategoryId != null) {
      final sub = await _client
          .from('v_public_subcategories')
          .select()
          .eq('id', product.subCategoryId!)
          .maybeSingle();
      if (sub != null) {
        subcategoryName = sub['name'] as String?;
        final catId = sub['category_id']?.toString();
        if (catId != null) {
          final cat = await _client
              .from('v_public_categories')
              .select()
              .eq('id', catId)
              .maybeSingle();
          categoryName = cat?['name'] as String?;
          categorySlug = cat?['slug'] as String?;
        }
      }
    }

    // Documents (datasheets / brochures) — public bucket, anon-readable view.
    final docRows = await _safe(() => _client
        .from('v_public_product_media')
        .select()
        .eq('product_id', product.id)
        .order('sort_order'));
    final documents = docRows
        .map(PublicDocument.fromRow)
        .where((d) => d.url.isNotEmpty)
        .toList();

    final related = <PublicProduct>[];
    if (product.subCategoryId != null) {
      final relRows = await _safe(() => _client
          .from('v_public_products')
          .select()
          .eq('sub_category_id', product.subCategoryId!)
          .neq('id', product.id)
          .limit(8));
      final relProducts = relRows.map(PublicProduct.fromRow).toList();
      if (relProducts.isNotEmpty) {
        final ids = relProducts.map((p) => p.id).toList();
        final relImages = await _safe(() => _client
            .from('v_public_product_images')
            .select()
            .inFilter('product_id', ids)
            .order('sort_order'));
        final firstImage = <String, String>{};
        for (final r in relImages) {
          final pid = r['product_id']?.toString();
          final url =
              (r['medium_url'] ?? r['thumbnail_url'] ?? r['url']) as String?;
          if (pid == null || url == null || url.trim().isEmpty) continue;
          firstImage.putIfAbsent(pid, () => url);
        }
        if (brand != null) {
          for (final p in relProducts) {
            if (p.brandId == product.brandId) p.brandName = brand.name;
          }
        }
        for (final p in relProducts) {
          p.imageUrl = firstImage[p.id];
        }
        related.addAll(relProducts);
      }
    }

    return ProductDetailData(
      product: product,
      specs: specs,
      brand: brand,
      categoryName: categoryName,
      categorySlug: categorySlug,
      subcategoryName: subcategoryName,
      related: related,
      documents: documents,
    );
  }

  Future<List<Map<String, dynamic>>> _loadBannersRest() async {
    return PublicRestClient.select(
      'shop_banners',
      order: 'display_order',
      inFilter: 'banner_type=in.(store,homepage,offer,festival)',
      eq: {'is_active': 'true'},
    );
  }

  Future<List<Map<String, dynamic>>> _loadOffersRest() async {
    return PublicRestClient.select('v_active_offers');
  }

  String _attrValue(Map<String, dynamic> row) {
    final text = row['value_text'];
    if (text != null && text.toString().trim().isNotEmpty) {
      final unit = (row['unit'] ?? '').toString().trim();
      return unit.isEmpty ? text.toString().trim() : '${text.toString().trim()} $unit';
    }
    final number = row['value_number'];
    if (number != null) {
      final unit = (row['unit'] ?? '').toString().trim();
      final n = number.toString();
      return unit.isEmpty ? n : '$n $unit';
    }
    return '';
  }

  /// Lightweight category load for homepage (no full catalog dependency).
  Future<List<PublicCategory>> loadCategories() async {
    // Always use raw anon REST — immune to leaked Supabase auth sessions on web.
    final rows = await _safeRest(
      () => PublicRestClient.select(
        'v_public_categories',
        order: 'sort_order',
      ),
    );
    final categories = rows.map(PublicCategory.fromRow).toList();
    if (categories.isEmpty) return categories;

    final productRows = await _safeRest(
      () => PublicRestClient.select(
        'v_public_products',
        columns: 'id,sub_category_id',
        limit: 2000,
      ),
    );
    final subRows = await _safeRest(
      () => PublicRestClient.select(
        'v_public_subcategories',
        columns: 'id,category_id',
      ),
    );
    final subToCat = {
      for (final row in subRows)
        row['id'].toString(): row['category_id'].toString(),
    };
    final catCount = <String, int>{};
    for (final row in productRows) {
      final subId = row['sub_category_id']?.toString();
      final catId = subId != null ? subToCat[subId] : null;
      if (catId != null) catCount[catId] = (catCount[catId] ?? 0) + 1;
    }
    return [
      for (final c in categories)
        PublicCategory(
          id: c.id,
          name: c.name,
          slug: c.slug,
          description: c.description,
          imageUrl: c.imageUrl,
          imageEditorSourceUrl: c.imageEditorSourceUrl,
          imagePlacements: c.imagePlacements,
          imageSourceW: c.imageSourceW,
          imageSourceH: c.imageSourceH,
          productCount: catCount[c.id] ?? 0,
        ),
    ];
  }

  Future<List<Map<String, dynamic>>> _safeRest(
    Future<List<Map<String, dynamic>>> Function() query,
  ) async {
    try {
      return await query();
    } catch (e, st) {
      debugPrint('PublicStoreRepository REST failed: $e');
      debugPrint('$st');
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _safe(
    Future<dynamic> Function() query,
  ) async {
    try {
      final res = await query();
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e, st) {
      debugPrint('PublicStoreRepository query failed: $e');
      debugPrint('$st');
      return <Map<String, dynamic>>[];
    }
  }
}

class ProductSpec {
  ProductSpec({required this.label, required this.value});
  final String label;
  final String value;
}

class PublicDocument {
  PublicDocument({
    required this.url,
    required this.mediaType,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
  });

  final String url;
  final String mediaType; // datasheet | brochure
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;

  bool get isPdf =>
      (mimeType ?? '').toLowerCase().contains('pdf') ||
      (fileName ?? '').toLowerCase().endsWith('.pdf') ||
      url.toLowerCase().contains('.pdf');

  String get title {
    if (fileName != null && fileName!.trim().isNotEmpty) return fileName!.trim();
    return mediaType == 'brochure' ? 'Brochure' : 'Datasheet';
  }

  String get typeLabel => mediaType == 'brochure' ? 'Brochure' : 'Datasheet';

  String? get readableSize {
    if (sizeBytes == null || sizeBytes! <= 0) return null;
    final kb = sizeBytes! / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  factory PublicDocument.fromRow(Map<String, dynamic> row) {
    return PublicDocument(
      url: (row['public_url'] ?? '').toString(),
      mediaType: (row['media_type'] ?? 'datasheet').toString(),
      fileName: row['file_name'] as String?,
      mimeType: row['mime_type'] as String?,
      sizeBytes: (row['file_size_bytes'] as num?)?.toInt(),
    );
  }
}

class ProductDetailData {
  ProductDetailData({
    required this.product,
    required this.specs,
    this.brand,
    this.categoryName,
    this.categorySlug,
    this.subcategoryName,
    this.related = const [],
    this.documents = const [],
  });

  final PublicProduct product;
  final List<ProductSpec> specs;
  final PublicBrand? brand;
  final String? categoryName;
  final String? categorySlug;
  final String? subcategoryName;
  final List<PublicProduct> related;
  final List<PublicDocument> documents;
}
