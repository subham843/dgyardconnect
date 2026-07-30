import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import 'validation/shop_erp_validation.dart';
import '../data/shop_catalog_repository.dart';
import '../domain/shop_attribute.dart';
import '../domain/shop_category.dart';
import '../data/shop_media_repository.dart';
import '../domain/shop_media_models.dart';
import '../../../../core/editing/dg_assist_text_field.dart';
import '../../../../core/editing/dg_image_search_context.dart';
import '../../../../core/editing/models/text_assist_models.dart';
import '../domain/shop_seo.dart';
import 'widgets/shop_entity_image_field.dart';
import 'shop_text_assist.dart';
import 'widgets/shop_seo_form_section.dart';

class AdminShopSubCategoryEditorScreen extends StatefulWidget {
  const AdminShopSubCategoryEditorScreen({
    super.key,
    this.subCategoryId,
    this.initialCategoryId,
    this.embedded = false,
    this.onNavigateRoute,
  });

  final String? subCategoryId;
  final String? initialCategoryId;
  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  bool get isCreate => subCategoryId == null || subCategoryId!.isEmpty;

  @override
  State<AdminShopSubCategoryEditorScreen> createState() => _AdminShopSubCategoryEditorScreenState();
}

class _AdminShopSubCategoryEditorScreenState extends State<AdminShopSubCategoryEditorScreen> {
  final _repo = ShopCatalogRepository();
  final _mediaRepo = ShopMediaRepository();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _sortCtrl = TextEditingController(text: '0');
  final _gstCtrl = TextEditingController(text: '18');
  final _hsnCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _seoTitleCtrl = TextEditingController();
  ProcessedShopImage? _pendingImage;
  String? _existingImageUrl;
  bool _mediaCleared = false;
  final _metaDescCtrl = TextEditingController();

  List<ShopCategory> _categories = [];
  List<ShopAttributeGroup> _allGroups = [];
  String? _categoryId;
  final _selectedGroupIds = <String>{};
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _savedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _descCtrl, _sortCtrl, _gstCtrl, _hsnCtrl, _slugCtrl, _seoTitleCtrl, _metaDescCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _categories = await _repo.listCategories(activeOnly: false);
    _allGroups = await _repo.listAttributeGroups();
    _categoryId = widget.initialCategoryId ?? (_categories.isNotEmpty ? _categories.first.id : null);
    if (!widget.isCreate) {
      final s = await _repo.getSubCategory(widget.subCategoryId!);
      if (s != null) {
        _savedId = s.id;
        _categoryId = s.categoryId;
        _nameCtrl.text = s.name;
        _descCtrl.text = s.description ?? '';
        _sortCtrl.text = '${s.sortOrder}';
        _isActive = s.isActive;
        _gstCtrl.text = '${s.defaultGstPercentage}';
        _hsnCtrl.text = s.defaultHsnCode ?? '';
        _slugCtrl.text = s.slug;
        _existingImageUrl = s.imageUrl ?? s.seo.ogImage;
        _seoTitleCtrl.text = s.seo.seoTitle ?? '';
        _metaDescCtrl.text = s.seo.metaDescription ?? '';
        _selectedGroupIds.addAll(s.attributeGroupIds);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  TextAssistContext _assistContext() {
    final cat = _categories.where((c) => c.id == _categoryId).toList();
    return ShopTextAssist.subCategory(
      subCategoryName: _nameCtrl.text.trim(),
      categoryName: cat.isEmpty ? null : cat.first.name,
    );
  }

  DgImageSearchContext _assistSearchContext() {
    final cat = _categories.where((c) => c.id == _categoryId).toList();
    return DgImageSearchContext(
      productName: _nameCtrl.text.trim(),
      categoryName: cat.isEmpty ? null : cat.first.name,
    );
  }

  String? _previewCanonical() {
    if (_categoryId == null || _nameCtrl.text.trim().isEmpty) return null;
    final cat = _categories.where((c) => c.id == _categoryId).toList();
    if (cat.isEmpty) return null;
    return ShopSeoService.resolveSubCategory(
      input: ShopSeoAdminInput(
        seoTitle: _seoTitleCtrl.text,
        metaDescription: _metaDescCtrl.text,
        slugOverride: _slugCtrl.text,
      ),
      name: _nameCtrl.text,
      categorySlug: cat.first.slug,
      imageUrl: _pendingImage?.publicUrl ?? _existingImageUrl,
    ).canonicalUrl;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category and name are required')));
      return;
    }
    final gst = double.tryParse(_gstCtrl.text.trim()) ?? 18;
    final gstErr = ShopErpValidation.gstPercentage(gst);
    if (gstErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gstErr)));
      return;
    }
    final hsn = _hsnCtrl.text.trim();
    final hsnErr = ShopErpValidation.hsnCode(hsn.isEmpty ? null : hsn);
    if (hsnErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hsnErr)));
      return;
    }
    final slugErr = ShopSeoFormSection.validateSlug(_slugCtrl.text);
    if (slugErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(slugErr)));
      return;
    }
    final seo = ShopSeoAdminInput(
      seoTitle: _seoTitleCtrl.text.trim(),
      metaDescription: _metaDescCtrl.text.trim(),
      slugOverride: _slugCtrl.text.trim(),
    );
    final catList = _categories.where((c) => c.id == _categoryId).toList();
    final catSlug = catList.isEmpty ? '' : catList.first.slug;
    setState(() => _saving = true);
    try {
      final sort = int.tryParse(_sortCtrl.text.trim()) ?? 0;
      final groups = _selectedGroupIds.toList();
      if (widget.isCreate && _savedId == null) {
        final id = await _repo.createSubCategory(
          categoryId: _categoryId!,
          name: name,
          description: _descCtrl.text.trim(),
          sortOrder: sort,
          isActive: _isActive,
          defaultGstPercentage: gst,
          defaultHsnCode: hsn.isEmpty ? null : hsn,
          seo: seo,
          categorySlug: catSlug,
          imagePublicUrl: _pendingImage?.publicUrl ?? _existingImageUrl,
          attributeGroupIds: groups,
        );
        if (id != null) {
          final up = await uploadPendingSubCategoryImage(subCategoryId: id, pending: _pendingImage);
          if (up != null) await _mediaRepo.applySubCategoryMedia(id, uploaded: up);
        }
        if (id != null && mounted) {
          _savedId = id;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sub-category created${groups.isEmpty ? '' : ' with ${groups.length} group(s)'}')),
          );
        }
      } else {
        final id = _savedId ?? widget.subCategoryId!;
        await _repo.updateSubCategory(
          id,
          name: name,
          description: _descCtrl.text.trim(),
          sortOrder: sort,
          isActive: _isActive,
          defaultGstPercentage: gst,
          defaultHsnCode: hsn,
          seo: seo,
          categorySlug: catSlug,
          imagePublicUrl: _pendingImage?.publicUrl ?? _existingImageUrl,
          existingSlug: _slugCtrl.text.trim().isEmpty ? null : _slugCtrl.text.trim(),
          attributeGroupIds: groups,
        );
        final sid = _savedId ?? widget.subCategoryId!;
        if (_mediaCleared && _pendingImage == null) {
          await _mediaRepo.applySubCategoryMedia(sid, uploaded: null, clear: true);
        } else {
          final up = await uploadPendingSubCategoryImage(subCategoryId: sid, pending: _pendingImage);
          if (up != null) await _mediaRepo.applySubCategoryMedia(sid, uploaded: up);
        }
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(RouteNames.adminShopSubCategories);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: widget.isCreate && _savedId == null ? 'New sub-category' : 'Edit sub-category',
      embedded: widget.embedded,
      onBack: _back,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_categories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: [for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                    onChanged: widget.isCreate && _savedId == null
                        ? (v) => setState(() => _categoryId = v)
                        : null,
                  ),
                const SizedBox(height: 12),
                DgAssistTextField(
                  controller: _nameCtrl,
                  assistProfile: TextAssistProfile.entityName,
                  textCapitalization: TextCapitalization.words,
                  contextHints: _assistContext(),
                  decoration: const InputDecoration(labelText: 'Sub-category name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DgAssistTextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  assistProfile: TextAssistProfile.subCategoryDesc,
                  contextHints: _assistContext(),
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sortCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort order', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hsnCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Default HSN code',
                    border: OutlineInputBorder(),
                    helperText: 'Products in this sub-category inherit this HSN (4–8 digits)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _gstCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Default GST %',
                    border: OutlineInputBorder(),
                    helperText: 'Applied to products unless product-level GST override is enabled',
                  ),
                ),
                SwitchListTile(
                  title: const Text('Status: Active'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 8),
                Text('Attribute groups', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Products in this sub-category will automatically load all attributes from selected groups.'),
                if (_allGroups.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Create attribute groups first.'))
                else ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedGroupIds.length == _allGroups.length) {
                            _selectedGroupIds.clear();
                          } else {
                            _selectedGroupIds.addAll(_allGroups.map((g) => g.id));
                          }
                        });
                      },
                      child: Text(_selectedGroupIds.length == _allGroups.length ? 'Clear all' : 'Select all'),
                    ),
                  ),
                  ..._allGroups.map(
                    (g) => CheckboxListTile(
                      value: _selectedGroupIds.contains(g.id),
                      onChanged: (on) {
                        setState(() {
                          if (on == true) {
                            _selectedGroupIds.add(g.id);
                          } else {
                            _selectedGroupIds.remove(g.id);
                          }
                        });
                      },
                      title: Text(g.name),
                      subtitle: g.description != null ? Text(g.description!) : null,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ShopEntityImageField(
                  label: 'Sub-category image',
                  preset: ShopImagePreset.subCategory,
                  entityName: _nameCtrl.text,
                  searchContext: _assistSearchContext(),
                  pending: _pendingImage,
                  existingUrl: _existingImageUrl,
                  onPendingChanged: (p) => setState(() {
                    _pendingImage = p;
                    _mediaCleared = false;
                  }),
                  onClear: () => setState(() {
                    _pendingImage = null;
                    _existingImageUrl = null;
                    _mediaCleared = true;
                  }),
                ),
                const SizedBox(height: 16),
                Text('SEO', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ShopSeoFormSection(
                  seoTitleController: _seoTitleCtrl,
                  metaDescriptionController: _metaDescCtrl,
                  slugController: _slugCtrl,
                  contextHints: _assistContext(),
                  slugAutoHint: 'Auto from name if empty, e.g. dvr',
                  canonicalPreview: _previewCanonical(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(widget.isCreate && _savedId == null ? 'Create sub-category' : 'Save changes'),
                ),
              ],
            ),
    );
  }
}
