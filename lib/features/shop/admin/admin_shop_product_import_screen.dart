import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_catalog_repository.dart';
import '../domain/shop_attribute.dart';
import '../domain/shop_category.dart';
import '../domain/shop_product.dart';
import 'product_import/product_import_draft.dart';
import 'product_import/product_import_engine_service.dart';
import 'product_import/product_import_image_preview.dart';
import 'product_import/product_import_persist_service.dart';

class AdminShopProductImportScreen extends StatefulWidget {
  const AdminShopProductImportScreen({super.key, this.embedded = false, this.onNavigateRoute});

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminShopProductImportScreen> createState() => _AdminShopProductImportScreenState();
}

class _AdminShopProductImportScreenState extends State<AdminShopProductImportScreen> {
  final _engine = ProductImportEngineService();
  final _persist = ProductImportPersistService();
  final _repo = ShopCatalogRepository();
  final _urlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();

  ProductImportSourceType _source = ProductImportSourceType.url;
  List<int>? _pdfBytes;
  String? _pdfName;
  bool _loading = false;
  bool _saving = false;
  ProductImportDraft? _draft;
  List<ShopCategory> _categories = [];
  List<ShopSubCategory> _allSubs = [];
  List<ShopBrand> _brands = [];
  List<ShopAttributeGroup> _attributeGroups = [];
  String? _categoryId;
  String? _subCategoryId;
  String? _brandId;
  final _selectedGroupIds = <String>{};
  List<String> _previewImageUrls = [];
  List<String> _previewDatasheetUrls = [];
  List<String> _previewManualUrls = [];
  bool _createAttributes = true;
  bool _downloadMedia = true;

  // Preview controllers
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrlPreview = TextEditingController();
  final _hsnCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _onlineCtrl = TextEditingController();
  final _shortCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _seoTitleCtrl = TextEditingController();
  final _metaCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _modelCtrl.dispose();
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrlPreview.dispose();
    _hsnCtrl.dispose();
    _gstCtrl.dispose();
    _onlineCtrl.dispose();
    _shortCtrl.dispose();
    _descCtrl.dispose();
    _seoTitleCtrl.dispose();
    _metaCtrl.dispose();
    _slugCtrl.dispose();
    _keywordsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final results = await Future.wait([
      _repo.listCategories(activeOnly: false),
      _repo.listAllSubCategories(),
      _repo.listBrands(),
      _repo.listAttributeGroups(),
    ]);
    if (!mounted) return;
    setState(() {
      _categories = results[0] as List<ShopCategory>;
      _allSubs = results[1] as List<ShopSubCategory>;
      _brands = results[2] as List<ShopBrand>;
      _attributeGroups = results[3] as List<ShopAttributeGroup>;
    });
  }

  List<ShopSubCategory> get _subsForCategory {
    if (_categoryId == null) return _allSubs;
    return _allSubs.where((s) => s.categoryId == _categoryId).toList();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _pdfBytes = f.bytes;
      _pdfName = f.name;
    });
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _draft = null;
    });
    try {
      final draft = await _engine.analyze(
        sourceType: _source,
        url: _source == ProductImportSourceType.modelNumber ? _urlCtrl.text : _urlCtrl.text,
        modelNumber: _source == ProductImportSourceType.modelNumber ? _modelCtrl.text : null,
        pdfBytes: _source == ProductImportSourceType.datasheetPdf ? _pdfBytes : null,
        fileName: _pdfName,
      );
      if (!mounted) return;
      _applyDraftToPreview(draft);
      setState(() {
        _draft = draft;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _applyDraftToPreview(ProductImportDraft draft) {
    _nameCtrl.text = draft.name;
    _brandCtrl.text = draft.brandName ?? '';
    _modelCtrlPreview.text = draft.modelName ?? '';
    _hsnCtrl.text = draft.hsnCode ?? '';
    _gstCtrl.text = draft.gstPercentage?.toString() ?? '18';
    _onlineCtrl.text = draft.onlinePrice?.toString() ?? '';
    _shortCtrl.text = draft.shortDescription ?? '';
    _descCtrl.text = draft.description ?? '';
    _seoTitleCtrl.text = draft.seoTitle ?? '';
    _metaCtrl.text = draft.metaDescription ?? '';
    _slugCtrl.text = draft.slug ?? '';
    _keywordsCtrl.text = draft.keywords.join(', ');
    _previewImageUrls = List<String>.from(draft.imageUrls);
    _previewDatasheetUrls = List<String>.from(draft.datasheetUrls);
    _previewManualUrls = List<String>.from(draft.manualUrls);

    final cat = _categories.where((c) =>
        c.slug == draft.categorySlug || c.name.toLowerCase() == (draft.categoryName ?? '').toLowerCase());
    _categoryId = cat.isNotEmpty ? cat.first.id : (_categories.isNotEmpty ? _categories.first.id : null);
    final subs = _subsForCategory;
    final sub = subs.where((s) =>
        s.slug == draft.subCategorySlug || s.name.toLowerCase() == (draft.subCategoryName ?? '').toLowerCase());
    _subCategoryId = sub.isNotEmpty ? sub.first.id : (subs.isNotEmpty ? subs.first.id : null);

    final b = _brands.where((x) => x.name.toLowerCase() == (draft.brandName ?? '').toLowerCase());
    _brandId = b.isNotEmpty ? b.first.id : null;

    _resolveAttributeGroups(draft);
  }

  void _resolveAttributeGroups(ProductImportDraft draft) {
    _selectedGroupIds.clear();
    final names = draft.attributeGroupNames.map((n) => n.toLowerCase().trim()).toSet();
    for (final g in _attributeGroups) {
      if (names.contains(g.name.toLowerCase())) _selectedGroupIds.add(g.id);
    }
    if (_subCategoryId != null) {
      _repo.listSubCategoryAttributeGroupIds(_subCategoryId!).then((ids) {
        if (!mounted) return;
        setState(() => _selectedGroupIds.addAll(ids));
      });
    }
  }

  List<String> _keywordsFromCtrl() {
    return _keywordsCtrl.text
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _onSubCategoryChanged(String? subId) {
    setState(() {
      _subCategoryId = subId;
      if (subId == null) return;
      _repo.listSubCategoryAttributeGroupIds(subId).then((ids) {
        if (!mounted || _subCategoryId != subId) return;
        setState(() => _selectedGroupIds.addAll(ids));
      });
    });
  }

  ProductImportDraft _draftFromPreview() {
    final base = _draft!;
    return base.copyWith(
      name: _nameCtrl.text.trim(),
      brandName: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      modelName: _modelCtrlPreview.text.trim().isEmpty ? null : _modelCtrlPreview.text.trim(),
      hsnCode: _hsnCtrl.text.trim().isEmpty ? null : _hsnCtrl.text.trim(),
      gstPercentage: double.tryParse(_gstCtrl.text.trim()),
      onlinePrice: double.tryParse(_onlineCtrl.text.trim()),
      shortDescription: _shortCtrl.text.trim().isEmpty ? null : _shortCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      seoTitle: _seoTitleCtrl.text.trim().isEmpty ? null : _seoTitleCtrl.text.trim(),
      metaDescription: _metaCtrl.text.trim().isEmpty ? null : _metaCtrl.text.trim(),
      slug: _slugCtrl.text.trim().isEmpty ? null : _slugCtrl.text.trim(),
      keywords: _keywordsFromCtrl(),
      imageUrls: _previewImageUrls,
      datasheetUrls: _previewDatasheetUrls,
      manualUrls: _previewManualUrls,
      attributeGroupNames: _attributeGroups
          .where((g) => _selectedGroupIds.contains(g.id))
          .map((g) => g.name)
          .toList(),
    );
  }

  Future<void> _save() async {
    if (_draft == null || _categoryId == null || _subCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select category and sub-category')));
      return;
    }
    setState(() => _saving = true);
    try {
      final draft = _draftFromPreview();
      final brandId = _brandId ?? await _persist.resolveBrandId(draft.brandName);
      final result = await _persist.save(
        draft: draft,
        categoryId: _categoryId!,
        subCategoryId: _subCategoryId!,
        brandId: brandId,
        attributeGroupIds: _selectedGroupIds.toList(),
        createMissingAttributes: _createAttributes,
        downloadMedia: _downloadMedia,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product imported — SKU ${result.sku}')),
      );
      final route = RouteNames.adminShopProductEdit(result.productId);
      if (widget.onNavigateRoute != null) {
        widget.onNavigateRoute!(route);
      } else {
        context.push(route);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'AI Product Import',
      embedded: widget.embedded,
      body: _draft == null ? _buildInputStep() : _buildPreviewStep(),
    );
  }

  Widget _buildInputStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Product Import Engine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  'Paste a URL, model number, or datasheet — AI extracts specs, category, SEO, images & documents. '
                  'Supports CP Plus, Hikvision, Dahua, TP-Link, Dell, HP, Lenovo, Intel, AMD & more.',
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ProductImportSourceType.values.map((t) {
            final selected = _source == t;
            return ChoiceChip(
              label: Text(t.label),
              selected: selected,
              onSelected: _loading ? null : (_) => setState(() => _source = t),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_source == ProductImportSourceType.modelNumber) ...[
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: 'Model number *',
              border: OutlineInputBorder(),
              hintText: 'e.g. DS-2CD1023G0-I, CP-URC-TC24PL3',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Optional product page URL',
              border: OutlineInputBorder(),
            ),
          ),
        ] else if (_source == ProductImportSourceType.datasheetPdf) ...[
          OutlinedButton.icon(
            onPressed: _loading ? null : _pickPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_pdfName ?? 'Select datasheet PDF'),
          ),
        ] else ...[
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: _source == ProductImportSourceType.manufacturerPage
                  ? 'Manufacturer product page URL *'
                  : 'Product page URL *',
              border: const OutlineInputBorder(),
              hintText: 'https://www.hikvision.com/...',
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _loading ? null : _analyze,
          icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_loading ? 'Analyzing…' : 'Analyze & preview'),
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    final draft = _draft!;
    final conf = draft.confidence.overall;
    final confColor = conf >= 0.75 ? Colors.green : conf >= 0.5 ? Colors.orange : Colors.red;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import confidence', style: Theme.of(context).textTheme.titleMedium),
                  Text('${(conf * 100).round()}% overall', style: TextStyle(color: confColor, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            CircularProgressIndicator(value: conf, color: confColor),
            const SizedBox(width: 12),
            TextButton(onPressed: () => setState(() => _draft = null), child: const Text('Start over')),
          ],
        ),
        if (draft.provider != null) Text('AI: ${draft.provider}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        _confidenceChips(draft),
        if (_previewImageUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          ProductImportImagePreview(
            urls: _previewImageUrls,
            onRemove: (i) => setState(() => _previewImageUrls.removeAt(i)),
            onSetMain: (i) => setState(() {
              final url = _previewImageUrls.removeAt(i);
              _previewImageUrls.insert(0, url);
            }),
          ),
        ],
        if (_previewDatasheetUrls.isNotEmpty || _previewManualUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          ProductImportDocumentPreview(
            title: 'Datasheets',
            urls: _previewDatasheetUrls,
            icon: Icons.picture_as_pdf_outlined,
            onRemove: (i) => setState(() => _previewDatasheetUrls.removeAt(i)),
          ),
          ProductImportDocumentPreview(
            title: 'Manuals',
            urls: _previewManualUrls,
            icon: Icons.menu_book_outlined,
            onRemove: (i) => setState(() => _previewManualUrls.removeAt(i)),
          ),
        ],
        const Divider(height: 32),
        TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Product name *', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _modelCtrlPreview, decoration: const InputDecoration(labelText: 'Model (optional)', border: OutlineInputBorder()))),
          ],
        ),
        const SizedBox(height: 8),
        if (_brands.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _brandId,
            decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('— None —')),
              for (final b in _brands) DropdownMenuItem(value: b.id, child: Text(b.name)),
            ],
            onChanged: (v) => setState(() => _brandId = v),
          ),
        const SizedBox(height: 8),
        if (_categories.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
            items: [for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() {
              _categoryId = v;
              final subs = _subsForCategory;
              _onSubCategoryChanged(subs.isNotEmpty ? subs.first.id : null);
            }),
          ),
        const SizedBox(height: 8),
        if (_subsForCategory.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _subCategoryId,
            decoration: const InputDecoration(labelText: 'Sub-category *', border: OutlineInputBorder()),
            items: [for (final s in _subsForCategory) DropdownMenuItem(value: s.id, child: Text(s.name))],
            onChanged: _onSubCategoryChanged,
          ),
        const SizedBox(height: 8),
        _buildAttributeGroupsSection(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextField(controller: _hsnCtrl, decoration: const InputDecoration(labelText: 'HSN (suggested)', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _gstCtrl, decoration: const InputDecoration(labelText: 'GST %', border: OutlineInputBorder()))),
          ],
        ),
        const SizedBox(height: 8),
        TextField(controller: _onlineCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Online price', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _shortCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Short description', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _seoTitleCtrl, decoration: const InputDecoration(labelText: 'SEO title', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _metaCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Meta description', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: _slugCtrl, decoration: const InputDecoration(labelText: 'URL slug', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(
          controller: _keywordsCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'SEO keywords',
            hintText: 'Comma-separated, e.g. 4MP camera, Hikvision, dome CCTV',
            border: OutlineInputBorder(),
          ),
        ),
        if (draft.specifications.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Specifications (${draft.specifications.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
          ...draft.specifications.take(10).map((s) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.label, style: const TextStyle(fontSize: 13)),
                subtitle: Text(s.value),
              )),
        ],
        if (draft.attributes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Attributes (${draft.attributes.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
          ...draft.attributes.take(8).map((a) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${a.label} (${a.key})', style: const TextStyle(fontSize: 13)),
                subtitle: Text(a.value ?? '—'),
              )),
        ],
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Create missing attributes'),
          value: _createAttributes,
          onChanged: (v) => setState(() => _createAttributes = v),
        ),
        SwitchListTile(
          title: const Text('Download images & PDFs to Supabase Storage'),
          value: _downloadMedia,
          onChanged: (v) => setState(() => _downloadMedia = v),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_circle_outline),
          label: Text(_saving ? 'Saving…' : 'Approve & import product'),
        ),
      ],
    );
  }

  Widget _buildAttributeGroupsSection() {
    if (_attributeGroups.isEmpty) {
      return Text(
        'No attribute groups in catalog — create groups first to map imported specs.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attribute groups', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'AI-suggested groups are pre-selected. Linked groups are assigned to this sub-category on import.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                if (_selectedGroupIds.length == _attributeGroups.length) {
                  _selectedGroupIds.clear();
                } else {
                  _selectedGroupIds.addAll(_attributeGroups.map((g) => g.id));
                }
              });
            },
            child: Text(_selectedGroupIds.length == _attributeGroups.length ? 'Clear all' : 'Select all'),
          ),
        ),
        ..._attributeGroups.map(
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
            title: Text(g.name, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              '${g.linkedAttributes.length} attributes${g.description != null ? ' · ${g.description}' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _confidenceChips(ProductImportDraft draft) {
    final fields = draft.confidence.fields;
    if (fields.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: fields.entries.map((e) {
        final pct = (e.value * 100).round();
        final c = e.value >= 0.75 ? Colors.green.shade100 : e.value >= 0.5 ? Colors.orange.shade100 : Colors.red.shade100;
        return Chip(
          label: Text('${e.key} $pct%', style: const TextStyle(fontSize: 11)),
          backgroundColor: c,
        );
      }).toList(),
    );
  }
}
