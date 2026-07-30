import 'dart:convert';

import '../../data/shop_catalog_repository.dart';
import '../../../../core/editing/platform_edge_client.dart';
import 'product_import_draft.dart';

/// Calls Supabase AI import engine with live catalog context.
class ProductImportEngineService {
  ProductImportEngineService({ShopCatalogRepository? repo}) : _repo = repo ?? ShopCatalogRepository();

  final ShopCatalogRepository _repo;

  Future<ProductImportDraft> analyze({
    required ProductImportSourceType sourceType,
    String? url,
    String? modelNumber,
    List<int>? pdfBytes,
    String? fileName,
  }) async {
    final context = await _buildCatalogContext();
    final body = <String, dynamic>{
      'sourceType': sourceType.apiValue,
      'catalogContext': context,
      if (url != null && url.trim().isNotEmpty) 'url': url.trim(),
      if (modelNumber != null && modelNumber.trim().isNotEmpty) 'modelNumber': modelNumber.trim(),
      if (pdfBytes != null && pdfBytes.isNotEmpty) 'pdfBase64': base64Encode(pdfBytes),
      'fileName': ?fileName,
    };

    final json = await PlatformEdgeClient.post('platform-product-import', body);
    if (json == null) throw StateError('Import engine unavailable — check Supabase login');
    if (json['error'] != null) throw StateError(json['error'].toString());

    final draft = ProductImportDraft.fromJson(json);
    if (draft.name.trim().isEmpty) {
      throw StateError('Could not detect product name — try another URL or add model number');
    }
    return draft;
  }

  Future<Map<String, dynamic>> _buildCatalogContext() async {
    final results = await Future.wait([
      _repo.listCategories(activeOnly: false),
      _repo.listAllSubCategories(),
      _repo.listBrands(),
      _repo.listAttributeGroups(),
      _repo.listAttributeMaster(activeOnly: false),
    ]);
    final categories = results[0] as List;
    final subs = results[1] as List;
    final brands = results[2] as List;
    final groups = results[3] as List;
    final attrs = results[4] as List;

    final catSlugById = {for (final c in categories) c.id: c.slug};

    return {
      'categories': categories
          .map((c) => {'name': c.name, 'slug': c.slug})
          .toList(),
      'subCategories': subs
          .map((s) => {
                'name': s.name,
                'slug': s.slug,
                'categorySlug': catSlugById[s.categoryId] ?? '',
              })
          .toList(),
      'brands': brands.map((b) => {'name': b.name, 'slug': b.slug}).toList(),
      'attributeGroups': groups
          .map((g) => {
                'name': g.name,
                'attributeKeys': g.linkedAttributes.map((l) => l.master.key).toList(),
              })
          .toList(),
      'attributes': attrs
          .map((a) => {
                'key': a.key,
                'label': a.label,
                'dataType': a.dataType,
                'allowedValues': a.allowedValues ?? [],
              })
          .toList(),
    };
  }
}
