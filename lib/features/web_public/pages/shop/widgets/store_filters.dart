// Client-side filter state + faceting for the Store catalog.

import '../../../data/models/public_store_models.dart';

enum StoreSort { featured, priceLowHigh, priceHighLow, newest, nameAZ, discount }

extension StoreSortLabel on StoreSort {
  String get label {
    switch (this) {
      case StoreSort.featured:
        return 'Featured';
      case StoreSort.priceLowHigh:
        return 'Price: Low to High';
      case StoreSort.priceHighLow:
        return 'Price: High to Low';
      case StoreSort.newest:
        return 'Newest first';
      case StoreSort.nameAZ:
        return 'Name: A–Z';
      case StoreSort.discount:
        return 'Biggest discount';
    }
  }
}

class BrandFacet {
  BrandFacet({required this.id, required this.name, required this.count});
  final String id;
  final String name;
  final int count;
}

class StoreFilters {
  StoreFilters({
    this.categoryId,
    this.subCategoryId,
    Set<String>? brandIds,
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    Map<String, Set<String>>? attributes,
    this.query = '',
    this.sort = StoreSort.featured,
  })  : brandIds = brandIds ?? <String>{},
        attributes = attributes ?? <String, Set<String>>{};

  String? categoryId;
  String? subCategoryId;
  Set<String> brandIds;
  double? minPrice;
  double? maxPrice;
  bool inStockOnly;
  Map<String, Set<String>> attributes;
  String query;
  StoreSort sort;

  bool get hasActiveScope =>
      categoryId != null ||
      subCategoryId != null ||
      brandIds.isNotEmpty ||
      query.trim().isNotEmpty;

  bool get hasRefinements =>
      brandIds.isNotEmpty ||
      minPrice != null ||
      maxPrice != null ||
      inStockOnly ||
      attributes.values.any((s) => s.isNotEmpty);

  int get activeRefinementCount {
    var n = 0;
    n += brandIds.length;
    if (minPrice != null || maxPrice != null) n += 1;
    if (inStockOnly) n += 1;
    n += attributes.values.fold<int>(0, (a, s) => a + s.length);
    return n;
  }

  StoreFilters copyWith({
    Object? categoryId = _sentinel,
    Object? subCategoryId = _sentinel,
    Set<String>? brandIds,
    Object? minPrice = _sentinel,
    Object? maxPrice = _sentinel,
    bool? inStockOnly,
    Map<String, Set<String>>? attributes,
    String? query,
    StoreSort? sort,
  }) {
    return StoreFilters(
      categoryId:
          identical(categoryId, _sentinel) ? this.categoryId : categoryId as String?,
      subCategoryId: identical(subCategoryId, _sentinel)
          ? this.subCategoryId
          : subCategoryId as String?,
      brandIds: brandIds ?? {...this.brandIds},
      minPrice:
          identical(minPrice, _sentinel) ? this.minPrice : minPrice as double?,
      maxPrice:
          identical(maxPrice, _sentinel) ? this.maxPrice : maxPrice as double?,
      inStockOnly: inStockOnly ?? this.inStockOnly,
      attributes: attributes ??
          {for (final e in this.attributes.entries) e.key: {...e.value}},
      query: query ?? this.query,
      sort: sort ?? this.sort,
    );
  }

  static const _sentinel = Object();
}

/// Pure filtering + sorting + faceting over the loaded catalog.
class StoreQueryEngine {
  StoreQueryEngine(this.catalog);
  final StoreCatalog catalog;

  /// Products in scope of category/subcategory/search only (used for facets so
  /// brand/price/attribute counts reflect the current section, not refinements).
  List<PublicProduct> scopedProducts(StoreFilters f) {
    final q = f.query.trim().toLowerCase();
    return catalog.products.where((p) {
      if (f.subCategoryId != null && p.subCategoryId != f.subCategoryId) {
        return false;
      }
      if (f.categoryId != null && p.categoryId != f.categoryId) return false;
      if (q.isNotEmpty && !_matchesQuery(p, q)) return false;
      return true;
    }).toList();
  }

  List<PublicProduct> apply(StoreFilters f) {
    final list = scopedProducts(f).where((p) {
      if (f.brandIds.isNotEmpty &&
          (p.brandId == null || !f.brandIds.contains(p.brandId))) {
        return false;
      }
      if (f.minPrice != null && (p.price ?? 0) < f.minPrice!) return false;
      if (f.maxPrice != null && (p.price ?? double.infinity) > f.maxPrice!) {
        return false;
      }
      if (f.inStockOnly && !p.inStock) return false;
      for (final entry in f.attributes.entries) {
        if (entry.value.isEmpty) continue;
        final value = p.attributes[entry.key];
        if (value == null || !entry.value.contains(value)) return false;
      }
      return true;
    }).toList();

    _sort(list, f.sort);
    return list;
  }

  bool _matchesQuery(PublicProduct p, String q) {
    return p.name.toLowerCase().contains(q) ||
        (p.brandName ?? '').toLowerCase().contains(q) ||
        (p.sku ?? '').toLowerCase().contains(q) ||
        (p.modelName ?? '').toLowerCase().contains(q) ||
        (p.shortDescription ?? '').toLowerCase().contains(q);
  }

  void _sort(List<PublicProduct> list, StoreSort sort) {
    switch (sort) {
      case StoreSort.priceLowHigh:
        list.sort((a, b) => (a.price ?? 1e12).compareTo(b.price ?? 1e12));
        break;
      case StoreSort.priceHighLow:
        list.sort((a, b) => (b.price ?? -1).compareTo(a.price ?? -1));
        break;
      case StoreSort.newest:
        list.sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
        break;
      case StoreSort.nameAZ:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case StoreSort.discount:
        list.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
        break;
      case StoreSort.featured:
        break;
    }
  }

  List<BrandFacet> brandFacets(StoreFilters f) {
    final counts = <String, int>{};
    for (final p in scopedProducts(f)) {
      if (p.brandId != null) counts[p.brandId!] = (counts[p.brandId!] ?? 0) + 1;
    }
    final byId = {for (final b in catalog.brands) b.id: b.name};
    final facets = counts.entries
        .map((e) => BrandFacet(id: e.key, name: byId[e.key] ?? 'Brand', count: e.value))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return facets;
  }

  ({double min, double max}) priceBounds(StoreFilters f) {
    double? lo, hi;
    for (final p in scopedProducts(f)) {
      final v = p.price;
      if (v == null || v <= 0) continue;
      lo = (lo == null || v < lo) ? v : lo;
      hi = (hi == null || v > hi) ? v : hi;
    }
    return (min: lo ?? 0, max: hi ?? 100000);
  }

  /// label -> sorted distinct values (capped per group for usable UI).
  Map<String, List<String>> attributeFacets(StoreFilters f) {
    final map = <String, Set<String>>{};
    for (final p in scopedProducts(f)) {
      p.attributes.forEach((label, value) {
        (map[label] ??= <String>{}).add(value);
      });
    }
    final result = <String, List<String>>{};
    for (final entry in map.entries) {
      if (entry.value.length < 2 || entry.value.length > 24) continue;
      final values = entry.value.toList()..sort();
      result[entry.key] = values;
    }
    return result;
  }
}