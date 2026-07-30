import '../domain/brand_logo_layout.dart';
import '../domain/shop_attribute.dart';
import '../domain/shop_category.dart';
import '../domain/shop_product.dart';
import '../domain/shop_product_detail.dart';
import '../domain/shop_seo.dart';
import '../domain/shop_structured_data.dart';
import 'supabase_repository_base.dart';

class ShopCatalogRepository {
  Future<List<ShopCategory>> listCategories({bool activeOnly = true}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    var q = c.from('categories').select();
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('sort_order');
    return (rows as List).map((e) => ShopCategory.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  static const _subCategorySelect =
      '*, sub_category_attribute_groups(attribute_group_id, attribute_groups(id, name))';

  Future<List<ShopSubCategory>> listSubCategories(String categoryId, {bool activeOnly = true}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null || categoryId.isEmpty) return [];
    var q = c.from('sub_categories').select(_subCategorySelect).eq('category_id', categoryId);
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('sort_order');
    return (rows as List).map((e) => ShopSubCategory.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<ShopSubCategory?> getSubCategory(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c.from('sub_categories').select(_subCategorySelect).eq('id', id).maybeSingle();
    if (row == null) return null;
    return ShopSubCategory.fromRow(SupabaseRepositoryBase.rowToMap(row));
  }

  Future<List<String>> listSubCategoryAttributeGroupIds(String subCategoryId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('sub_category_attribute_groups')
        .select('attribute_group_id')
        .eq('sub_category_id', subCategoryId);
    return (rows as List).map((e) => (e as Map)['attribute_group_id'] as String).toList();
  }

  Future<void> setSubCategoryAttributeGroups(String subCategoryId, List<String> groupIds) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('sub_category_attribute_groups').delete().eq('sub_category_id', subCategoryId);
    for (final gid in groupIds) {
      await c.from('sub_category_attribute_groups').insert({
        'sub_category_id': subCategoryId,
        'attribute_group_id': gid,
      });
    }
  }

  Future<ShopCategory?> getCategory(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c.from('categories').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return ShopCategory.fromRow(SupabaseRepositoryBase.rowToMap(row));
  }

  Future<String?> createCategory({
    required String name,
    int sortOrder = 0,
    ShopSeoAdminInput? seo,
    String? imagePublicUrl,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) {
      throw StateError('Supabase not ready. Restart app after login.');
    }
    final resolved = ShopSeoService.resolveCategory(
      input: seo ?? const ShopSeoAdminInput(),
      name: name,
      imageUrl: imagePublicUrl,
    );
    final res = await c
        .from('categories')
        .insert({
          'name': name.trim(),
          'sort_order': sortOrder,
          'is_active': true,
          if (imagePublicUrl != null && imagePublicUrl.trim().isNotEmpty) 'image_url': imagePublicUrl.trim(),
          ...resolved.toCategoryPayload(),
        })
        .select('id')
        .maybeSingle();
    return res?['id'] as String?;
  }

  Future<void> updateCategory(
    String id, {
    required String name,
    int? sortOrder,
    bool? isActive,
    ShopSeoAdminInput? seo,
    String? imagePublicUrl,
    String? existingSlug,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final resolved = ShopSeoService.resolveCategory(
      input: seo ?? const ShopSeoAdminInput(),
      name: name,
      existingSlug: existingSlug,
      imageUrl: imagePublicUrl,
    );
    final payload = <String, dynamic>{
      'name': name.trim(),
      ...resolved.toCategoryPayload(),
    };
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    if (isActive != null) payload['is_active'] = isActive;
    await c.from('categories').update(payload).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) throw StateError('Supabase not ready');
    await c.from('categories').delete().eq('id', id);
  }

  Future<String?> createSubCategory({
    required String categoryId,
    required String name,
    String? description,
    int sortOrder = 0,
    bool isActive = true,
    double defaultGstPercentage = 18,
    String? defaultHsnCode,
    ShopSeoAdminInput? seo,
    String? categorySlug,
    String? imagePublicUrl,
    List<String> attributeGroupIds = const [],
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    var catSlug = categorySlug;
    if (catSlug == null || catSlug.isEmpty) {
      final cat = await getCategory(categoryId);
      catSlug = cat?.slug ?? '';
    }
    final resolved = ShopSeoService.resolveSubCategory(
      input: seo ?? const ShopSeoAdminInput(),
      name: name,
      categorySlug: catSlug,
      imageUrl: imagePublicUrl,
    );
    final res = await c
        .from('sub_categories')
        .insert({
          'category_id': categoryId,
          'name': name.trim(),
          'sort_order': sortOrder,
          'is_active': isActive,
          'default_gst_percentage': defaultGstPercentage,
          if (defaultHsnCode != null && defaultHsnCode.trim().isNotEmpty) 'default_hsn_code': defaultHsnCode.trim(),
          if (description != null && description.isNotEmpty) 'description': description.trim(),
          ...resolved.toSubCategoryPayload(),
        })
        .select('id')
        .maybeSingle();
    final id = res?['id'] as String?;
    if (id != null && attributeGroupIds.isNotEmpty) {
      await setSubCategoryAttributeGroups(id, attributeGroupIds);
    }
    return id;
  }

  Future<void> updateSubCategory(
    String id, {
    required String name,
    String? description,
    int? sortOrder,
    bool? isActive,
    double? defaultGstPercentage,
    String? defaultHsnCode,
    ShopSeoAdminInput? seo,
    String? categorySlug,
    String? imagePublicUrl,
    String? existingSlug,
    List<String>? attributeGroupIds,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    var catSlug = categorySlug;
    if (catSlug == null || catSlug.isEmpty) {
      final sub = await getSubCategory(id);
      if (sub != null) {
        final cat = await getCategory(sub.categoryId);
        catSlug = cat?.slug ?? '';
      }
    }
    final resolved = ShopSeoService.resolveSubCategory(
      input: seo ?? const ShopSeoAdminInput(),
      name: name,
      categorySlug: catSlug ?? '',
      existingSlug: existingSlug,
      imageUrl: imagePublicUrl,
    );
    final payload = <String, dynamic>{
      'name': name.trim(),
      'description': description?.trim(),
      ...resolved.toSubCategoryPayload(),
    };
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    if (isActive != null) payload['is_active'] = isActive;
    if (defaultGstPercentage != null) payload['default_gst_percentage'] = defaultGstPercentage;
    if (defaultHsnCode != null) {
      payload['default_hsn_code'] = defaultHsnCode.trim().isEmpty ? null : defaultHsnCode.trim();
    }
    await c.from('sub_categories').update(payload).eq('id', id);
    if (attributeGroupIds != null) {
      await setSubCategoryAttributeGroups(id, attributeGroupIds);
    }
  }

  Future<void> deleteSubCategory(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) throw StateError('Supabase not ready');
    await c.from('sub_categories').delete().eq('id', id);
  }

  static const _attributeMasterSelect =
      '*, attribute_options(id, attribute_id, label, sort_order, is_active)';

  Future<List<ShopAttributeMaster>> listAttributeMaster({bool activeOnly = false}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    var q = c.from('attribute_master').select(_attributeMasterSelect);
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('key');
    return (rows as List).map((e) => ShopAttributeMaster.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<ShopAttributeMaster?> getAttributeMaster(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c.from('attribute_master').select(_attributeMasterSelect).eq('id', id).maybeSingle();
    if (row == null) return null;
    return ShopAttributeMaster.fromRow(SupabaseRepositoryBase.rowToMap(row));
  }

  Future<List<ShopAttributeMaster>> listFilterAttributes({String? categoryId, String? subCategoryId}) async {
    return _listAttributesByFlag(useInFilter: true, categoryId: categoryId, subCategoryId: subCategoryId);
  }

  Future<List<ShopAttributeMaster>> listCalculatorAttributes() async {
    return _listAttributesByFlag(useInCalculator: true);
  }

  Future<List<ShopAttributeGroupSection>> listAttributeSectionsForSubCategory(String subCategoryId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null || subCategoryId.isEmpty) return [];
    final rows = await c
        .from('sub_category_attribute_groups')
        .select(
          'attribute_groups(id, name, attribute_group_attributes(sort_order, is_required, attribute_master($_attributeMasterSelect)))',
        )
        .eq('sub_category_id', subCategoryId);
    final sections = <ShopAttributeGroupSection>[];
    final seenAttrs = <String>{};
    for (final scag in rows as List) {
      final map = SupabaseRepositoryBase.rowToMap(scag as Map<String, dynamic>);
      final ag = map['attribute_groups'] as Map<String, dynamic>?;
      if (ag == null) continue;
      final groupId = ag['id'] as String? ?? '';
      final groupName = ag['name'] as String? ?? 'Group';
      final attrs = <ShopSubCategoryLinkedAttribute>[];
      for (final agaMap in SupabaseRepositoryBase.embeddedRows(ag['attribute_group_attributes'])) {
        final am = agaMap['attribute_master'] as Map<String, dynamic>?;
        if (am == null) continue;
        final master = ShopAttributeMaster.fromRow(am);
        if (!seenAttrs.add(master.id)) continue;
        attrs.add(
          ShopSubCategoryLinkedAttribute(
            master: master,
            isRequiredInGroup: agaMap['is_required'] as bool? ?? false,
          ),
        );
      }
      attrs.sort((a, b) => a.master.label.compareTo(b.master.label));
      if (attrs.isNotEmpty) {
        sections.add(ShopAttributeGroupSection(groupId: groupId, groupName: groupName, attributes: attrs));
      }
    }
    sections.sort((a, b) => a.groupName.compareTo(b.groupName));
    return sections;
  }

  Future<List<ShopAttributeMaster>> listAttributesForSubCategory(String subCategoryId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null || subCategoryId.isEmpty) return [];
    final rows = await c
        .from('sub_category_attribute_groups')
        .select(
          'attribute_groups(attribute_group_attributes(sort_order, is_required, attribute_master($_attributeMasterSelect)))',
        )
        .eq('sub_category_id', subCategoryId);
    final out = <ShopAttributeMaster>[];
    final seen = <String>{};
    for (final scag in rows as List) {
      final map = SupabaseRepositoryBase.rowToMap(scag as Map<String, dynamic>);
      final ag = map['attribute_groups'] as Map<String, dynamic>?;
      for (final agaMap in SupabaseRepositoryBase.embeddedRows(ag?['attribute_group_attributes'])) {
        final am = agaMap['attribute_master'] as Map<String, dynamic>?;
        if (am == null) continue;
        final master = ShopAttributeMaster.fromRow(am);
        if (seen.add(master.id)) out.add(master);
      }
    }
    out.sort((a, b) => a.label.compareTo(b.label));
    return out;
  }

  Future<List<ShopAttributeMaster>> _listAttributesByFlag({
    bool useInFilter = false,
    bool useInCalculator = false,
    String? categoryId,
    String? subCategoryId,
  }) async {
    if (subCategoryId != null && subCategoryId.isNotEmpty) {
      return (await listAttributesForSubCategory(subCategoryId))
          .where((a) => a.isActive && (!useInFilter || a.useInFilter) && (!useInCalculator || a.useInCalculator))
          .toList();
    }
    final all = await listAttributeMaster(activeOnly: true);
    return all
        .where((a) {
          if (useInFilter && !a.useInFilter) return false;
          if (useInCalculator && !a.useInCalculator) return false;
          return true;
        })
        .toList();
  }

  Future<String?> createAttributeMaster({
    required String key,
    required String label,
    required String dataType,
    String? unit,
    bool isRequired = false,
    bool useInFilter = false,
    bool useInCalculator = false,
    bool isActive = true,
    List<String>? allowedValues,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c
        .from('attribute_master')
        .insert({
          'key': key.trim(),
          'label': label.trim(),
          'data_type': dataType,
          if (unit != null && unit.isNotEmpty) 'unit': unit.trim(),
          'is_required': isRequired,
          'use_in_filter': useInFilter,
          'use_in_calculator': useInCalculator,
          'is_active': isActive,
          'allowed_values': ?allowedValues,
        })
        .select('id')
        .maybeSingle();
    return res?['id'] as String?;
  }

  Future<void> updateAttributeMaster(
    String id, {
    required String key,
    required String label,
    required String dataType,
    String? unit,
    bool? isRequired,
    bool? useInFilter,
    bool? useInCalculator,
    bool? isActive,
    List<String>? allowedValues,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('attribute_master').update({
      'key': key.trim(),
      'label': label.trim(),
      'data_type': dataType,
      if (unit != null) 'unit': unit.trim().isEmpty ? null : unit.trim(),
      'is_required': ?isRequired,
      'use_in_filter': ?useInFilter,
      'use_in_calculator': ?useInCalculator,
      'is_active': ?isActive,
      'allowed_values': ?allowedValues,
    }).eq('id', id);
  }

  Future<void> deleteAttributeMaster(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) throw StateError('Supabase not ready');
    await c.from('attribute_master').delete().eq('id', id);
  }

  Future<List<ShopAttributeOption>> listAttributeOptions(String attributeId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('attribute_options').select().eq('attribute_id', attributeId).order('sort_order');
    return (rows as List).map((e) => ShopAttributeOption.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<void> _syncAllowedValuesFromOptions(String attributeId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final opts = await listAttributeOptions(attributeId);
    final labels = opts.where((o) => o.isActive).map((o) => o.label).toList();
    await c.from('attribute_master').update({'allowed_values': labels}).eq('id', attributeId);
  }

  Future<void> createAttributeOption({
    required String attributeId,
    required String label,
    int sortOrder = 0,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('attribute_options').insert({
      'attribute_id': attributeId,
      'label': label.trim(),
      'sort_order': sortOrder,
    });
    await _syncAllowedValuesFromOptions(attributeId);
  }

  Future<void> updateAttributeOption({
    required String optionId,
    required String attributeId,
    required String label,
    int? sortOrder,
    bool? isActive,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('attribute_options').update({
      'label': label.trim(),
      'sort_order': ?sortOrder,
      'is_active': ?isActive,
    }).eq('id', optionId);
    await _syncAllowedValuesFromOptions(attributeId);
  }

  Future<void> deleteAttributeOption({required String optionId, required String attributeId}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('attribute_options').delete().eq('id', optionId);
    await _syncAllowedValuesFromOptions(attributeId);
  }

  Future<void> reorderAttributeOptions(String attributeId, List<String> orderedOptionIds) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    for (var i = 0; i < orderedOptionIds.length; i++) {
      await c.from('attribute_options').update({'sort_order': i}).eq('id', orderedOptionIds[i]);
    }
    await _syncAllowedValuesFromOptions(attributeId);
  }

  static const _attributeGroupSelect =
      '*, attribute_group_attributes(sort_order, is_required, attribute_id, attribute_master($_attributeMasterSelect))';

  Future<List<ShopAttributeGroup>> listAttributeGroups() async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('attribute_groups').select(_attributeGroupSelect).order('name');
    return (rows as List).map((e) => ShopAttributeGroup.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<void> updateAttributeGroup(String id, {required String name, String? description, bool? isActive}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('attribute_groups').update({
      'name': name.trim(),
      'description': ?description,
      'is_active': ?isActive,
    }).eq('id', id);
  }

  Future<void> deleteAttributeGroup(String id) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) throw StateError('Supabase not ready');
    final rows = await c.from('attribute_groups').delete().eq('id', id).select('id');
    if ((rows as List).isEmpty) {
      throw StateError('Could not delete attribute group. Check superadmin login.');
    }
  }

  Future<String?> createAttributeGroup({required String name, String? description}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c.from('attribute_groups').insert({
      'name': name.trim(),
      'description': ?description,
    }).select('id').maybeSingle();
    return res?['id'] as String?;
  }

  Future<void> linkAttributeToGroup({
    required String groupId,
    required String attributeId,
    int sortOrder = 0,
    bool isRequired = false,
  }) async {
    await linkAttributesToGroup(
      groupId: groupId,
      links: [(attributeId: attributeId, sortOrder: sortOrder, isRequired: isRequired)],
    );
  }

  /// Link many attributes to a group in one request.
  Future<void> linkAttributesToGroup({
    required String groupId,
    required List<({String attributeId, int sortOrder, bool isRequired})> links,
  }) async {
    if (links.isEmpty) return;
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('attribute_group_attributes').upsert(
      links
          .map(
            (l) => {
              'attribute_group_id': groupId,
              'attribute_id': l.attributeId,
              'sort_order': l.sortOrder,
              'is_required': l.isRequired,
            },
          )
          .toList(),
      onConflict: 'attribute_group_id,attribute_id',
    );
  }

  Future<void> unlinkAttributeFromGroup({
    required String groupId,
    required String attributeId,
  }) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) throw StateError('Supabase not ready');
    final rows = await c
        .from('attribute_group_attributes')
        .delete()
        .eq('attribute_group_id', groupId)
        .eq('attribute_id', attributeId)
        .select('id');
    if ((rows as List).isEmpty) {
      throw StateError('Could not unlink attribute. Check superadmin login.');
    }
  }

  Future<void> assignGroupToSubCategory({
    required String subCategoryId,
    required String attributeGroupId,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('sub_category_attribute_groups').upsert(
      {
        'sub_category_id': subCategoryId,
        'attribute_group_id': attributeGroupId,
      },
      onConflict: 'sub_category_id,attribute_group_id',
      ignoreDuplicates: true,
    );
  }

  Future<List<ShopBrand>> listBrands() async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('brands').select().order('name');
    return (rows as List).map((e) => ShopBrand.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<void> createBrand(String name) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('brands').insert({
      'name': name.trim(),
      'slug': SupabaseRepositoryBase.slugify(name),
    });
  }

  Future<void> updateBrand(
    String id, {
    required String name,
    bool? isActive,
    BrandLogoLayout? logoLayout,
    String? shortDescription,
    bool? isFeaturedOnHomepage,
    int? displayOrder,
    String? logoMimeType,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final payload = <String, dynamic>{
      'name': name.trim(),
      'slug': SupabaseRepositoryBase.slugify(name),
      'is_active': ?isActive,
      if (logoLayout != null) ...logoLayout.toUpdateMap(),
      if (shortDescription != null) 'short_description': shortDescription.trim().isEmpty ? null : shortDescription.trim(),
      'is_featured_on_homepage': ?isFeaturedOnHomepage,
      'display_order': ?displayOrder,
      'logo_mime_type': ?logoMimeType,
    };
    await c.from('brands').update(payload).eq('id', id);
  }

  Future<void> deleteBrand(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) throw StateError('Supabase not ready');
    await c.from('brands').delete().eq('id', id);
  }

  Future<List<ShopProduct>> listProducts({
    String? subCategoryId,
    bool activeOnly = true,
    int limit = 100,
  }) async {
    return listProductsAdmin(
      subCategoryId: subCategoryId,
      activeOnly: activeOnly,
      limit: limit,
      lightSelect: false,
    );
  }

  /// Admin product list — all products by default, optional filters, higher limit.
  Future<List<ShopProduct>> listProductsAdmin({
    String? subCategoryId,
    String? categoryId,
    bool activeOnly = false,
    int limit = 3000,
    bool lightSelect = true,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];

    final select = lightSelect
        ? 'id, name, sku, base_price, selling_price, online_price, mrp, dealer_price, '
            'is_active, sub_category_id, brand_id, '
            'inventory(qty_on_hand), product_images(url, sort_order), '
            'sub_categories(name, categories(name))'
        : '*, inventory(qty_on_hand), product_images(url, sort_order), '
            'sub_categories(name, categories(name))';

    var q = c.from('products').select(select);
    if (subCategoryId != null && subCategoryId.isNotEmpty) {
      q = q.eq('sub_category_id', subCategoryId);
    } else if (categoryId != null && categoryId.isNotEmpty) {
      final subs = await c.from('sub_categories').select('id').eq('category_id', categoryId);
      final subIds = (subs as List).map((e) => (e as Map)['id'] as String).toList();
      if (subIds.isEmpty) return [];
      q = q.inFilter('sub_category_id', subIds);
    }
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('name').limit(limit);
    return (rows as List).map((e) => ShopProduct.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  /// Full product rows for CSV export (single query).
  Future<List<Map<String, dynamic>>> listProductExportRows({int limit = 5000}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('products')
        .select(
          '*, inventory(qty_on_hand, reorder_level, unit, stock_status), product_images(url, sort_order), '
          'sub_categories(slug, category_id, categories(slug)), brands(name), calculator_families(name)',
        )
        .order('name')
        .limit(limit);
    return (rows as List).map((e) => SupabaseRepositoryBase.rowToMap(e)).toList();
  }

  /// Product attribute values for CSV export.
  Future<List<Map<String, dynamic>>> listProductAttributeExportRows({int limit = 20000}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('product_attributes')
        .select('value_text, value_number, value_json, products(sku), attribute_master(key, data_type)')
        .limit(limit);
    return (rows as List).map((e) => SupabaseRepositoryBase.rowToMap(e)).toList();
  }

  /// All sub-categories (for admin filters) — no attribute group join.
  Future<List<ShopSubCategory>> listAllSubCategories({bool activeOnly = false}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    var q = c.from('sub_categories').select('id, name, slug, category_id, sort_order, is_active, default_gst_percentage, default_hsn_code');
    if (activeOnly) q = q.eq('is_active', true);
    final rows = await q.order('sort_order');
    return (rows as List).map((e) => ShopSubCategory.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<ShopProduct?> getProduct(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c
        .from('products')
        .select('*, inventory(qty_on_hand, reorder_level, unit, stock_status), product_images(url, sort_order)')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return ShopProduct.fromRow(SupabaseRepositoryBase.rowToMap(row));
  }

  Future<ShopProductDetail?> getProductDetail(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final row = await c
        .from('products')
        .select(
          '*, inventory(qty_on_hand, reorder_level, unit, stock_status), '
          'product_images(url, sort_order), '
          'product_calculator_families(family_id, priority)',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final map = SupabaseRepositoryBase.rowToMap(row);
    final subId = map['sub_category_id'] as String?;
    String? catId;
    if (subId != null) {
      final sub = await c.from('sub_categories').select('category_id').eq('id', subId).maybeSingle();
      catId = sub?['category_id'] as String?;
    }
    return ShopProductDetail.fromRow(map, categoryId: catId);
  }

  Future<void> setProductCalculatorFamilies(
    String productId,
    List<String> familyIds, {
    int priority = 0,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('product_calculator_families').delete().eq('product_id', productId);
    final unique = familyIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return;
    await c.from('product_calculator_families').insert([
      for (var i = 0; i < unique.length; i++)
        {
          'product_id': productId,
          'family_id': unique[i],
          'priority': priority,
        },
    ]);
  }

  Future<List<({String id, String name})>> listCalculatorFamilies() async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c.from('calculator_families').select('id, name').eq('is_active', true).order('sort_order');
    return (rows as List)
        .map((e) => (id: (e as Map)['id'] as String, name: e['name'] as String? ?? ''))
        .toList();
  }

  Future<String?> createProduct({
    required String subCategoryId,
    required String sku,
    required String name,
    String? description,
    double basePrice = 0,
    String? brandId,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    final res = await c.from('products').insert({
      'sub_category_id': subCategoryId,
      'sku': sku.trim(),
      'name': name.trim(),
      'description': description,
      'base_price': basePrice,
      'brand_id': ?brandId,
    }).select('id').maybeSingle();
    return res?['id'] as String?;
  }

  Future<void> updateProduct(String id, Map<String, dynamic> fields) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    await c.from('products').update(fields).eq('id', id);
  }

  /// Quick price update from admin product list (MRP, online/customer, dealer).
  Future<void> updateProductPricing({
    required String productId,
    double? mrp,
    double? onlinePrice,
    double? dealerPrice,
  }) async {
    final fields = <String, dynamic>{
      'mrp': mrp,
      'dealer_price': dealerPrice,
    };
    if (onlinePrice != null && onlinePrice > 0) {
      fields['online_price'] = onlinePrice;
      fields['selling_price'] = onlinePrice;
      fields['base_price'] = onlinePrice;
    } else {
      fields['online_price'] = onlinePrice;
      fields['selling_price'] = onlinePrice;
    }
    await updateProduct(productId, fields);
  }

  Future<String?> saveProductDetail(
    ShopProductDetail detail, {
    String? existingId,
    String? categorySlug,
    String? subCategorySlug,
    String? brandName,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return null;
    var catSlug = categorySlug ?? '';
    var subSlug = subCategorySlug ?? '';
    if (catSlug.isEmpty || subSlug.isEmpty) {
      final sub = await getSubCategory(detail.subCategoryId);
      subSlug = sub?.slug ?? subSlug;
      if (sub != null) {
        final cat = await getCategory(sub.categoryId);
        catSlug = cat?.slug ?? catSlug;
      }
    }
    final payload = detail.toProductPayload();
    payload['metadata'] = Map<String, dynamic>.from(payload['metadata'] as Map? ?? {});
    final schema = ShopStructuredData.productPage(
      seo: detail.seo,
      productName: detail.name,
      sku: detail.sku,
      price: detail.onlinePrice ?? detail.sellingPrice,
      qtyOnHand: detail.qtyOnHand,
      brandName: brandName,
      description: detail.description,
      mainImageUrl: detail.mainImageUrl,
    );
    (payload['metadata'] as Map<String, dynamic>)['schema_json_ld'] = schema;
    String? productId = existingId;
    if (productId == null || productId.isEmpty) {
      final res = await c.from('products').insert(payload).select('id').maybeSingle();
      productId = res?['id'] as String?;
    } else {
      await c.from('products').update(payload).eq('id', productId);
    }
    if (productId == null) return null;
    final familyIds = detail.showInCalculator ? detail.resolvedCalculatorFamilyIds : const <String>[];
    await Future.wait([
      updateInventory(
        productId,
        qtyOnHand: existingId == null ? 0 : null,
        reorderLevel: detail.reorderLevel,
        unit: detail.unit,
        stockStatus: detail.stockStatus,
      ),
      ensureProductAttributesForSubCategory(productId, detail.subCategoryId),
      setProductCalculatorFamilies(
        productId,
        familyIds,
        priority: detail.calculatorPriority,
      ),
    ]);
    final hasUrlImages = (detail.mainImageUrl != null && detail.mainImageUrl!.trim().isNotEmpty) ||
        detail.galleryUrls.any((u) => u.trim().isNotEmpty);
    if (hasUrlImages) {
      await _syncProductImages(productId, detail.mainImageUrl, detail.galleryUrls);
    }
    return productId;
  }

  Future<void> _syncProductImages(String productId, String? mainUrl, List<String> gallery) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final urls = <String>[];
    if (mainUrl != null && mainUrl.trim().isNotEmpty) urls.add(mainUrl.trim());
    for (final u in gallery) {
      final t = u.trim();
      if (t.isNotEmpty && !urls.contains(t)) urls.add(t);
    }
    await c.from('product_images').delete().eq('product_id', productId);
    for (var i = 0; i < urls.length; i++) {
      await c.from('product_images').insert({
        'product_id': productId,
        'url': urls[i],
        'sort_order': i,
      });
    }
  }

  Future<void> setProductActive(String id, bool isActive) async {
    await updateProduct(id, {'is_active': isActive});
  }

  Future<void> deleteProduct(String id) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) throw StateError('Supabase not ready');
    await c.from('products').delete().eq('id', id);
  }

  Future<bool> productSkuExists(String sku, {String? excludeProductId}) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return false;
    final trimmed = sku.trim();
    if (trimmed.isEmpty) return false;
    var q = c.from('products').select('id').eq('sku', trimmed);
    if (excludeProductId != null && excludeProductId.isNotEmpty) {
      q = q.neq('id', excludeProductId);
    }
    final row = await q.limit(1).maybeSingle();
    return row != null;
  }

  /// Ensures SKU is unique (appends -2, -3, … when auto-generated slug collides).
  Future<String> resolveUniqueProductSku(String baseSku, {String? excludeProductId}) async {
    var sku = baseSku.trim();
    if (sku.isEmpty) return sku;
    if (!await productSkuExists(sku, excludeProductId: excludeProductId)) return sku;
    for (var i = 2; i <= 99; i++) {
      final candidate = '$sku-$i';
      if (!await productSkuExists(candidate, excludeProductId: excludeProductId)) return candidate;
    }
    return '$sku-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  }

  Future<List<ShopProductAttributeValue>> listProductAttributeValues(String productId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final rows = await c
        .from('product_attributes')
        .select('*, attribute_master($_attributeMasterSelect)')
        .eq('product_id', productId);
    return (rows as List).map((e) => ShopProductAttributeValue.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  /// Backward-compatible alias.
  Future<List<ShopProductAttributeValue>> listProductAttributes(String productId) =>
      listProductAttributeValues(productId);

  Future<void> updateProductAttribute(
    String id, {
    String? valueText,
    double? valueNumber,
    List<dynamic>? valueJson,
    bool clearNumber = false,
    bool clearJson = false,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final payload = <String, dynamic>{};
    if (valueText != null) payload['value_text'] = valueText;
    if (valueNumber != null) payload['value_number'] = valueNumber;
    if (valueJson != null) payload['value_json'] = valueJson;
    if (clearNumber) payload['value_number'] = null;
    if (clearJson) payload['value_json'] = null;
    await c.from('product_attributes').update(payload).eq('id', id);
  }

  Future<List<ShopProductAttributeValue>> listProductAttributesForSubCategory(String subCategoryId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null || subCategoryId.isEmpty) return [];
    final rows = await c
        .from('product_attributes')
        .select('*, attribute_master($_attributeMasterSelect), products!inner(sub_category_id)')
        .eq('products.sub_category_id', subCategoryId);
    return (rows as List).map((e) => ShopProductAttributeValue.fromRow(SupabaseRepositoryBase.rowToMap(e))).toList();
  }

  Future<void> ensureProductAttributesForSubCategory(String productId, String subCategoryId) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final masters = await listAttributesForSubCategory(subCategoryId);
    if (masters.isEmpty) return;
    await c.from('product_attributes').upsert(
      masters
          .map(
            (m) => {
              'product_id': productId,
              'attribute_id': m.id,
            },
          )
          .toList(),
      onConflict: 'product_id,attribute_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> updateInventory(
    String productId, {
    int? qtyOnHand,
    int? reorderLevel,
    String? unit,
    String? stockStatus,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return;
    final patch = <String, dynamic>{'product_id': productId};
    if (qtyOnHand != null) patch['qty_on_hand'] = qtyOnHand;
    if (reorderLevel != null) patch['reorder_level'] = reorderLevel;
    if (unit != null) patch['unit'] = unit;
    if (stockStatus != null) patch['stock_status'] = stockStatus;
    await c.from('inventory').upsert(patch, onConflict: 'product_id');
  }

  Future<List<ShopProduct>> findProductsBySubCategorySlug(
    String slug, {
    int limit = 20,
    Map<String, String>? attributes,
  }) async {
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return [];
    final subs = await c.from('sub_categories').select('id').eq('slug', slug).limit(1);
    if ((subs as List).isEmpty) return [];
    final subId = (subs.first as Map)['id'] as String;
    final products =
        await listProducts(subCategoryId: subId, activeOnly: true, limit: limit);
    final filters = <String, String>{
      for (final e in (attributes ?? const <String, String>{}).entries)
        if (e.key.trim().isNotEmpty && e.value.trim().isNotEmpty)
          e.key.trim(): e.value.trim(),
    };
    if (filters.isEmpty) return products;
    return _filterProductsByAttributeKeyValues(products, filters);
  }

  /// Keep products that have ALL attribute key → value pairs (AND).
  /// Only considers [products] (already subcategory-scoped) — never expands
  /// the search to other subcategories that share the same attribute key.
  Future<List<ShopProduct>> _filterProductsByAttributeKeyValues(
    List<ShopProduct> products,
    Map<String, String> filters,
  ) async {
    if (products.isEmpty) return products;
    final c = await SupabaseRepositoryBase.clientWithAuth();
    if (c == null) return products;

    final productIds = [for (final p in products) p.id];
    Set<String>? matchingIds;
    for (final entry in filters.entries) {
      final amRows = await c
          .from('attribute_master')
          .select('id')
          .eq('key', entry.key)
          .limit(1);
      if ((amRows as List).isEmpty) return const [];
      final attrId = (amRows.first as Map)['id']?.toString();
      if (attrId == null || attrId.isEmpty) return const [];

      final ids = <String>{};
      for (var i = 0; i < productIds.length; i += 80) {
        final chunk = productIds.sublist(
          i,
          i + 80 > productIds.length ? productIds.length : i + 80,
        );
        final rows = await c
            .from('product_attributes')
            .select('product_id, value_text, value_number')
            .eq('attribute_id', attrId)
            .inFilter('product_id', chunk);
        for (final raw in rows as List) {
          final row = Map<String, dynamic>.from(raw as Map);
          final pid = row['product_id']?.toString();
          if (pid == null || pid.isEmpty) continue;
          final text = (row['value_text'] ?? '').toString().trim();
          final numVal = row['value_number'];
          final numStr = numVal == null ? '' : numVal.toString();
          final want = entry.value;
          if (text == want ||
              numStr == want ||
              (numVal is num &&
                  double.tryParse(want) != null &&
                  (numVal - double.parse(want)).abs() < 0.0001)) {
            ids.add(pid);
          }
        }
      }
      matchingIds = matchingIds == null ? ids : matchingIds.intersection(ids);
      if (matchingIds.isEmpty) return const [];
    }
    final keep = matchingIds ?? {};
    return [for (final p in products) if (keep.contains(p.id)) p];
  }
}
