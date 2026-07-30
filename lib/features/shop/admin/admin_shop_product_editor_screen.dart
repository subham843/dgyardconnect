import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_catalog_repository.dart';
import '../data/shop_media_repository.dart';
import '../data/supabase_repository_base.dart';
import '../domain/shop_attribute.dart';
import '../domain/shop_category.dart';
import '../domain/entity_image_placements.dart';
import '../domain/shop_media_models.dart';
import '../domain/shop_product.dart';
import '../domain/shop_product_detail.dart';
import '../../../../core/editing/dg_assist_text_field.dart';
import '../../../../core/editing/dg_image_search_context.dart';
import '../../../../core/editing/models/text_assist_models.dart';
import '../domain/shop_seo.dart';
import 'validation/shop_erp_validation.dart';
import 'validation/shop_media_validation.dart';
import 'widgets/product_attribute_fields.dart';
import 'widgets/shop_product_media_panel.dart';
import 'widgets/shop_product_pricing_section.dart';
import 'shop_text_assist.dart';
import 'widgets/shop_seo_form_section.dart';
import 'datasheet/datasheet_spec_extractor_service.dart';
import 'datasheet/datasheet_spec_models.dart';
import 'datasheet/datasheet_specs_review_sheet.dart';

class AdminShopProductEditorScreen extends StatefulWidget {
  const AdminShopProductEditorScreen({
    super.key,
    this.productId,
    this.initialSubCategoryId,
    this.embedded = false,
    this.onNavigateRoute,
  });

  final String? productId;
  final String? initialSubCategoryId;
  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  bool get isCreate => productId == null || productId!.isEmpty;

  /// Category/sub-category were chosen on the Products list before opening this form.
  bool get categoryPreSelected =>
      isCreate && initialSubCategoryId != null && initialSubCategoryId!.trim().isNotEmpty;

  @override
  State<AdminShopProductEditorScreen> createState() => _AdminShopProductEditorScreenState();
}

class _AdminShopProductEditorScreenState extends State<AdminShopProductEditorScreen> {
  final _repo = ShopCatalogRepository();
  final _mediaRepo = ShopMediaRepository();

  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _modelNameCtrl = TextEditingController();
  final _hsnCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '0');
  final _warrantyCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: '0');
  final _mrpCtrl = TextEditingController();
  final _onlineCtrl = TextEditingController();
  final _dealerCtrl = TextEditingController();
  final _shortDescCtrl = TextEditingController();
  final _fullDescCtrl = TextEditingController();
  final _techCtrl = TextEditingController();
  final _installCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _seoTitleCtrl = TextEditingController();
  final _metaDescCtrl = TextEditingController();
  final _calcPriorityCtrl = TextEditingController(text: '0');

  ProcessedShopImage? _mainPending;
  String? _existingMainUrl;
  String? _existingMainEditorSourceUrl;
  EntityImagePlacements? _existingMainPlacements;
  int? _existingMainSourceW;
  int? _existingMainSourceH;
  List<ShopProductMediaItem> _mediaItems = [];

  double _subCategoryDefaultGst = 18;
  String? _subCategoryDefaultHsn;
  bool _useGstOverride = false;
  bool _trackSerial = false;
  bool _trackBatch = false;

  List<ShopCategory> _categories = [];
  List<ShopSubCategory> _subs = [];
  List<ShopBrand> _brands = [];
  List<({String id, String name})> _calcFamilies = [];
  List<ShopAttributeGroupSection> _sections = [];
  List<ShopProductAttributeValue> _attrRows = [];
  final Map<String, dynamic> _attrValues = {};

  String? _categoryId;
  String? _subCategoryId;
  String? _brandId;
  String? _calcFamilyId;
  final Set<String> _calcFamilyIds = {};
  int _inventoryQty = 0;
  int _reorderLevel = 0;
  String _inventoryUnit = 'pcs';
  String _stockStatus = 'in_stock';

  /// Sell / stock units shown in product editor.
  static const _productUnits = <(String, String)>[
    ('pcs', 'Pieces'),
    ('mtr', 'Meter'),
    ('box', 'Box'),
    ('roll', 'Roll'),
    ('pair', 'Pair'),
    ('set', 'Set'),
    ('pack', 'Pack'),
    ('kg', 'Kilogram'),
    ('ltr', 'Litre'),
  ];
  bool _isActive = true;
  bool _showInCalculator = false;
  bool _loading = true;
  bool _saving = false;
  String? _productId;
  bool _skuLocked = false;
  bool _skuManual = false;
  bool _extractingDatasheet = false;
  final _datasheetExtractor = DatasheetSpecExtractorService();

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_syncSkuFromName);
    _nameCtrl.addListener(_syncSlugFromName);
    _modelNameCtrl.addListener(_syncSkuFromName);
    _load();
  }

  String _deriveSkuBase() {
    final model = _modelNameCtrl.text.trim();
    if (model.isNotEmpty) return SupabaseRepositoryBase.slugify(model);
    return SupabaseRepositoryBase.slugify(_nameCtrl.text);
  }

  void _syncSkuFromName() {
    if (_skuLocked || _skuManual) return;
    final sku = _deriveSkuBase();
    if (_skuCtrl.text != sku) {
      _skuCtrl.text = sku;
      if (mounted) setState(() {});
    }
  }

  static bool _isModelAttribute(ShopAttributeMaster m) {
    final k = m.key.toLowerCase();
    return k == 'model' ||
        k == 'model_number' ||
        k == 'model_name' ||
        k == 'model_no' ||
        k.contains('model_number') ||
        k.contains('model_no');
  }

  void _syncSlugFromName() {
    if (_slugCtrl.text.trim().isNotEmpty) return;
    final slug = SupabaseRepositoryBase.slugify(_nameCtrl.text);
    if (_slugCtrl.text != slug) {
      _slugCtrl.text = slug;
      if (mounted) setState(() {});
    }
  }

  String get _resolvedSku {
    final fromField = _skuCtrl.text.trim();
    if (_skuLocked || _skuManual) return fromField;
    return _deriveSkuBase();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_syncSkuFromName);
    _modelNameCtrl.removeListener(_syncSkuFromName);
    _nameCtrl.removeListener(_syncSlugFromName);
    for (final c in [
      _nameCtrl, _skuCtrl, _modelNameCtrl, _hsnCtrl, _taxCtrl, _warrantyCtrl,
      _costCtrl, _mrpCtrl, _onlineCtrl, _dealerCtrl,
      _shortDescCtrl, _fullDescCtrl, _techCtrl, _installCtrl, _slugCtrl,
      _seoTitleCtrl, _metaDescCtrl,
      _calcPriorityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _selectedCategorySubLabel {
    if (_categoryId == null || _subCategoryId == null) return null;
    final cats = _categories.where((c) => c.id == _categoryId).toList();
    final subs = _subs.where((s) => s.id == _subCategoryId).toList();
    if (cats.isEmpty || subs.isEmpty) return null;
    return '${cats.first.name} → ${subs.first.name}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final isEdit = !widget.isCreate;
    final lists = await Future.wait<dynamic>([
      _repo.listCategories(activeOnly: false),
      _repo.listBrands(),
      _repo.listCalculatorFamilies(),
      if (isEdit) _repo.getProductDetail(widget.productId!),
    ]);
    _categories = lists[0] as List<ShopCategory>;
    _brands = lists[1] as List<ShopBrand>;
    _calcFamilies = lists[2] as List<({String id, String name})>;
    final existingDetail = isEdit ? lists[3] as ShopProductDetail? : null;

    if (widget.categoryPreSelected) {
      _subCategoryId = widget.initialSubCategoryId!.trim();
      final sub = await _repo.getSubCategory(_subCategoryId!);
      if (sub != null) {
        _categoryId = sub.categoryId;
        _subs = await _repo.listSubCategories(_categoryId!, activeOnly: false);
      }
      await _applySubCategoryDefaults(_subCategoryId!);
    } else {
      _categoryId = _categories.isNotEmpty ? _categories.first.id : null;
      if (_categoryId != null) {
        _subs = await _repo.listSubCategories(_categoryId!, activeOnly: false);
      }
      _subCategoryId = widget.initialSubCategoryId ?? (_subs.isNotEmpty ? _subs.first.id : null);
      if (_subCategoryId != null) {
        await _applySubCategoryDefaults(_subCategoryId!);
      }
    }
    if (existingDetail != null) {
      _productId = existingDetail.id;
      _subCategoryId = existingDetail.subCategoryId;
      _categoryId = existingDetail.categoryId ?? _categoryId;
      _bindDetail(existingDetail);
      _skuLocked = true;
      final subsFuture = _categoryId == null
          ? Future<void>.value()
          : _repo.listSubCategories(_categoryId!, activeOnly: false).then((s) => _subs = s);
      await Future.wait([
        _loadProductMedia(existingDetail),
        subsFuture,
      ]);
    }
    await _reloadAttributes();
    if (mounted) setState(() => _loading = false);
  }

  void _bindDetail(ShopProductDetail d) {
    _nameCtrl.text = d.name;
    _skuCtrl.text = d.sku;
    _modelNameCtrl.text = d.modelName ?? '';
    _hsnCtrl.text = d.hsnCode ?? '';
    _taxCtrl.text = '${d.taxPercentage}';
    _warrantyCtrl.text = d.warranty ?? '';
    _costCtrl.text = '${d.costPrice}';
    _mrpCtrl.text = d.mrp?.toString() ?? '';
    _onlineCtrl.text = '${d.onlinePrice ?? d.sellingPrice}';
    _dealerCtrl.text = d.dealerPrice?.toString() ?? '';
    _inventoryQty = d.qtyOnHand;
    _reorderLevel = d.reorderLevel;
    final u = d.unit.trim().toLowerCase();
    _inventoryUnit = switch (u) {
      'meter' || 'meters' || 'metre' || 'metres' || 'm' => 'mtr',
      'piece' || 'pieces' || 'pc' || 'nos' || 'no' => 'pcs',
      'boxes' => 'box',
      'rolls' => 'roll',
      'pairs' => 'pair',
      'sets' => 'set',
      'packs' || 'pkt' || 'packet' => 'pack',
      'kilogram' || 'kilograms' || 'kgs' => 'kg',
      'liter' || 'litre' || 'liters' || 'litres' || 'l' => 'ltr',
      _ when _productUnits.any((e) => e.$1 == u) => u,
      _ when u.isEmpty => 'pcs',
      _ => 'pcs',
    };
    _stockStatus = d.stockStatus;
    _existingMainUrl = d.mainImageUrl;
    _existingMainEditorSourceUrl = d.mainImageEditorSourceUrl;
    _existingMainPlacements = d.mainImagePlacements;
    _existingMainSourceW = d.mainImageSourceW;
    _existingMainSourceH = d.mainImageSourceH;
    _shortDescCtrl.text = d.shortDescription ?? '';
    _fullDescCtrl.text = d.description ?? '';
    _techCtrl.text = d.technicalNotes ?? '';
    _installCtrl.text = d.installationNotes ?? '';
    _useGstOverride = d.useGstOverride;
    _trackSerial = d.trackSerial;
    _trackBatch = d.trackBatch;
    _slugCtrl.text = d.seo.slug;
    _seoTitleCtrl.text = d.seo.seoTitle ?? '';
    _metaDescCtrl.text = d.seo.metaDescription ?? '';
    _brandId = d.brandId;
    _isActive = d.isActive;
    _showInCalculator = d.showInCalculator;
    _calcFamilyId = d.calculatorFamilyId;
    _calcFamilyIds
      ..clear()
      ..addAll(d.resolvedCalculatorFamilyIds);
    if (_calcFamilyIds.isEmpty && (_calcFamilyId ?? '').isNotEmpty) {
      _calcFamilyIds.add(_calcFamilyId!);
    }
    _calcPriorityCtrl.text = '${d.calculatorPriority}';
  }

  Future<void> _reloadAttributes({bool syncMissingAttributeRows = false}) async {
    if (_subCategoryId == null) {
      setState(() {
        _sections = [];
        _attrRows = [];
      });
      return;
    }
    if (_productId != null) {
      if (syncMissingAttributeRows) {
        await _repo.ensureProductAttributesForSubCategory(_productId!, _subCategoryId!);
      }
      final pair = await Future.wait([
        _repo.listAttributeSectionsForSubCategory(_subCategoryId!),
        _repo.listProductAttributes(_productId!),
      ]);
      _sections = pair[0] as List<ShopAttributeGroupSection>;
      _attrRows = pair[1] as List<ShopProductAttributeValue>;
    } else {
      _sections = await _repo.listAttributeSectionsForSubCategory(_subCategoryId!);
      _attrRows = _sections
          .expand((s) => s.attributes)
          .map(
            (a) => ShopProductAttributeValue(
              id: '',
              productId: '',
              master: a.master,
            ),
          )
          .toList();
    }
    _attrValues.clear();
    for (final row in _attrRows) {
      final t = row.master.dataType;
      if (t == 'multi_select') {
        _attrValues[row.master.id] = row.multiSelectValues;
      } else if (t == 'number') {
        _attrValues[row.master.id] = row.valueNumber;
      } else if (t == 'bool') {
        _attrValues[row.master.id] = row.valueText == 'true' || row.valueText == 'yes';
      } else {
        _attrValues[row.master.id] = row.valueText;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _applySubCategoryDefaults(String subId) async {
    ShopSubCategory? sub;
    for (final s in _subs) {
      if (s.id == subId) {
        sub = s;
        break;
      }
    }
    sub ??= await _repo.getSubCategory(subId);
    if (sub == null) return;
    _subCategoryDefaultGst = sub.defaultGstPercentage;
    _subCategoryDefaultHsn = sub.defaultHsnCode;
    if (!_useGstOverride) {
      _taxCtrl.text = '${sub.defaultGstPercentage}';
    }
    final hsn = sub.defaultHsnCode?.trim();
    if (hsn != null && hsn.isNotEmpty) {
      _hsnCtrl.text = hsn;
    }
    if (mounted) setState(() {});
  }

  Future<void> _onSubCategoryChanged(String? subId) async {
    setState(() => _subCategoryId = subId);
    if (subId != null) await _applySubCategoryDefaults(subId);
    await _reloadAttributes(syncMissingAttributeRows: true);
  }

  Future<void> _loadProductMedia(ShopProductDetail d) async {
    if (_productId == null || _productId!.isEmpty) return;
    var items = await _mediaRepo.listProductMedia(_productId!);
    if (items.isEmpty) {
      var order = 0;
      for (final url in d.galleryUrls) {
        if (url == d.mainImageUrl) continue;
        items.add(ShopProductMediaItem(
          kind: ShopProductMediaKind.gallery,
          publicUrl: url,
          sortOrder: order++,
        ));
      }
      order = 0;
      for (final url in d.datasheetUrls) {
        items.add(ShopProductMediaItem(
          kind: ShopProductMediaKind.datasheet,
          publicUrl: url,
          sortOrder: order++,
          fileName: url.split('/').last,
        ));
      }
      order = 0;
      for (final url in d.brochureUrls) {
        items.add(ShopProductMediaItem(
          kind: ShopProductMediaKind.brochure,
          publicUrl: url,
          sortOrder: order++,
          fileName: url.split('/').last,
        ));
      }
      for (final url in d.documentUrls) {
        if (d.datasheetUrls.contains(url) || d.brochureUrls.contains(url)) continue;
        items.add(ShopProductMediaItem(
          kind: ShopProductMediaKind.brochure,
          publicUrl: url,
          sortOrder: items.where((i) => i.kind == ShopProductMediaKind.brochure).length,
          fileName: url.split('/').last,
        ));
      }
    }
    if (mounted) setState(() => _mediaItems = items);
  }

  String? get _resolvedMainImageUrl => _mainPending?.publicUrl ?? _existingMainUrl;

  List<String> _resolvedGalleryUrls() {
    final list = _mediaItems
        .where((i) => i.kind == ShopProductMediaKind.gallery && !i.markedForDelete && i.publicUrl.isNotEmpty)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list.map((i) => i.publicUrl).toList();
  }

  List<String> _docUrls(ShopProductMediaKind kind) => _mediaItems
      .where((i) => i.kind == kind && !i.markedForDelete && i.publicUrl.isNotEmpty)
      .map((i) => i.publicUrl)
      .toList();

  String? _validate() {
    if (_nameCtrl.text.trim().isEmpty) return 'Product name is required';
    final online = double.tryParse(_onlineCtrl.text.trim());
    if (online == null || online <= 0) return 'Online sales price is required for customer shop';
    if (_resolvedSku.isEmpty) return 'Could not generate SKU — use letters or numbers in the product name';
    if (_subCategoryId == null) return 'Select a sub-category';
    if (_useGstOverride) {
      final tax = double.tryParse(_taxCtrl.text);
      final taxErr = ShopErpValidation.gstPercentage(tax);
      if (taxErr != null) return taxErr;
    }
    final hsnErr = ShopErpValidation.hsnCode(_hsnCtrl.text.trim().isEmpty ? null : _hsnCtrl.text.trim());
    if (hsnErr != null) return hsnErr;
    final slugErr = ShopSeoFormSection.validateSlug(_slugCtrl.text);
    if (slugErr != null) return slugErr;
    if (_showInCalculator && _calcFamilyIds.isEmpty) {
      return 'Select at least one calculator family when Show in Calculator is on';
    }
    final galleryErr = ShopMediaValidation.productGalleryCount(_mediaItems);
    if (galleryErr != null) return galleryErr;
    for (final s in _sections) {
      for (final a in s.attributes) {
        final m = a.master;
        if (_isModelAttribute(m)) continue;
        if (!m.isRequired && !a.isRequiredInGroup) continue;
        final v = _attrValues[m.id];
        if (v == null || (v is String && v.isEmpty) || (v is List && v.isEmpty)) {
          return '${m.label} is required';
        }
      }
    }
    return null;
  }

  TextAssistContext _assistContext() {
    final catList = _categories.where((c) => c.id == _categoryId).toList();
    final subList = _subs.where((s) => s.id == _subCategoryId).toList();
    final brandList = _brandId == null ? <ShopBrand>[] : _brands.where((b) => b.id == _brandId).toList();
    return ShopTextAssist.product(
      productName: _nameCtrl.text.trim(),
      categoryName: catList.isEmpty ? null : catList.first.name,
      subCategoryName: subList.isEmpty ? null : subList.first.name,
      brandName: brandList.isEmpty ? null : brandList.first.name,
    );
  }

  DgImageSearchContext _imageSearchContext() {
    final ctx = _assistContext();
    return DgImageSearchContext(
      productName: ctx.productName,
      categoryName: ctx.categoryName,
      brandName: ctx.brandName,
    );
  }

  ShopSeoResolved _resolveSeo() {
    final catList = _categories.where((c) => c.id == _categoryId).toList();
    final subList = _subs.where((s) => s.id == _subCategoryId).toList();
    return ShopSeoService.resolveProduct(
      input: ShopSeoAdminInput(
        seoTitle: _seoTitleCtrl.text.trim(),
        metaDescription: _metaDescCtrl.text.trim(),
        slugOverride: _slugCtrl.text.trim(),
      ),
      name: _nameCtrl.text.trim(),
      categorySlug: catList.isEmpty ? '' : catList.first.slug,
      subCategorySlug: subList.isEmpty ? '' : subList.first.slug,
      existingSlug: _productId != null ? _slugCtrl.text.trim() : null,
      mainImageUrl: _resolvedMainImageUrl,
      fallbackSku: _resolvedSku,
    );
  }

  ShopProductDetail _buildDetail() {
    return ShopProductDetail(
      id: _productId ?? '',
      subCategoryId: _subCategoryId!,
      categoryId: _categoryId,
      brandId: _brandId,
      sku: _resolvedSku,
      name: _nameCtrl.text.trim(),
      modelName: _modelNameCtrl.text.trim().isEmpty ? null : _modelNameCtrl.text.trim(),
      hsnCode: _hsnCtrl.text.trim(),
      taxPercentage: _useGstOverride ? (double.tryParse(_taxCtrl.text) ?? 0) : _subCategoryDefaultGst,
      useGstOverride: _useGstOverride,
      warranty: _warrantyCtrl.text.trim().isEmpty ? null : _warrantyCtrl.text.trim(),
      trackSerial: _trackSerial,
      trackBatch: _trackBatch,
      description: _fullDescCtrl.text.trim(),
      shortDescription: _shortDescCtrl.text.trim(),
      technicalNotes: _techCtrl.text.trim(),
      installationNotes: _installCtrl.text.trim(),
      costPrice: double.tryParse(_costCtrl.text) ?? 0,
      sellingPrice: double.tryParse(_onlineCtrl.text) ?? 0,
      onlinePrice: double.tryParse(_onlineCtrl.text),
      dealerPrice: double.tryParse(_dealerCtrl.text),
      mrp: double.tryParse(_mrpCtrl.text),
      isActive: _isActive,
      qtyOnHand: _productId == null ? 0 : _inventoryQty,
      reorderLevel: _reorderLevel,
      unit: _inventoryUnit,
      stockStatus: _stockStatus,
      mainImageUrl: _resolvedMainImageUrl,
      galleryUrls: _resolvedGalleryUrls(),
      documentUrls: [..._docUrls(ShopProductMediaKind.datasheet), ..._docUrls(ShopProductMediaKind.brochure)],
      datasheetUrls: _docUrls(ShopProductMediaKind.datasheet),
      brochureUrls: _docUrls(ShopProductMediaKind.brochure),
      seo: _resolveSeo(),
      showInCalculator: _showInCalculator,
      calculatorFamilyId: _calcFamilyIds.isNotEmpty ? _calcFamilyIds.first : null,
      calculatorFamilyIds: _calcFamilyIds.toList(),
      calculatorPriority: int.tryParse(_calcPriorityCtrl.text) ?? 0,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onDatasheetPdfAdded(List<int> bytes, String fileName) async {
    if (_extractingDatasheet) return;
    setState(() => _extractingDatasheet = true);
    try {
      final brandName = _brandId == null
          ? null
          : _brands.where((b) => b.id == _brandId).map((b) => b.name).firstOrNull;
      final catName = _categoryId == null
          ? null
          : _categories.where((c) => c.id == _categoryId).map((c) => c.name).firstOrNull;
      final specs = await _datasheetExtractor.extractFromPdf(
        pdfBytes: bytes,
        fileName: fileName,
        productName: _nameCtrl.text.trim(),
        brandName: brandName,
        categoryName: catName,
      );
      if (!mounted || specs == null) return;
      final applied = await DatasheetSpecsReviewSheet.show(
        context,
        specs: specs,
        fileName: fileName,
      );
      if (applied != null) _applyDatasheetSpecs(applied);
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final msg = raw.contains('429') || raw.toLowerCase().contains('quota')
            ? 'Datasheet AI quota full — PDF saved; fill specs manually or retry later.'
            : 'Could not read datasheet: $e';
        _showSnack(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _extractingDatasheet = false);
    }
  }

  void _applyDatasheetSpecs(DatasheetExtractedSpecs specs) {
    setState(() {
      if (specs.modelName?.trim().isNotEmpty == true) {
        _modelNameCtrl.text = specs.modelName!.trim();
        _syncSkuFromName();
      }
      if (specs.hsnCode?.trim().isNotEmpty == true) _hsnCtrl.text = specs.hsnCode!.trim();
      if (specs.warranty?.trim().isNotEmpty == true) _warrantyCtrl.text = specs.warranty!.trim();
      if (specs.shortDescription?.trim().isNotEmpty == true) _shortDescCtrl.text = specs.shortDescription!.trim();
      if (specs.description?.trim().isNotEmpty == true) _fullDescCtrl.text = specs.description!.trim();
      if (specs.technicalNotes?.trim().isNotEmpty == true) {
        _techCtrl.text = specs.technicalNotes!.trim();
      } else if (specs.specifications.isNotEmpty) {
        _techCtrl.text = specs.specifications.map((p) => '${p.label}: ${p.value}').join('\n');
      }
      if (specs.installationNotes?.trim().isNotEmpty == true) {
        _installCtrl.text = specs.installationNotes!.trim();
      }
      for (final hint in specs.attributeHints) {
        final key = hint.label.toLowerCase();
        final row = _attrRows.where((r) => r.master.key.toLowerCase() == key).firstOrNull;
        if (row != null && hint.value.trim().isNotEmpty) {
          _attrValues[row.master.id] = hint.value.trim();
        }
      }
    });
    _showSnack('Datasheet specs applied — review fields before saving');
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      _showSnack(err, isError: true);
      return;
    }
    final wasNew = _productId == null || _productId!.isEmpty;
    setState(() => _saving = true);
    try {
      final uniqueSku = await _repo.resolveUniqueProductSku(
        _resolvedSku,
        excludeProductId: _productId,
      );
      if (uniqueSku != _skuCtrl.text) {
        _skuCtrl.text = uniqueSku;
        if (mounted) setState(() {});
      }
      final detail = _buildDetail();
      String? brandName;
      if (_brandId != null) {
        final bl = _brands.where((b) => b.id == _brandId).toList();
        if (bl.isNotEmpty) brandName = bl.first.name;
      }
      final catSlug = _categoryId == null
          ? null
          : _categories.where((c) => c.id == _categoryId).map((c) => c.slug).firstOrNull;
      final subSlug = _subCategoryId == null
          ? null
          : _subs.where((s) => s.id == _subCategoryId).map((s) => s.slug).firstOrNull;

      final id = await _repo.saveProductDetail(
        detail,
        existingId: _productId,
        brandName: brandName,
        categorySlug: catSlug,
        subCategorySlug: subSlug,
      );
      if (id == null) {
        _showSnack('Could not save product. Check login and required fields.', isError: true);
        return;
      }

      if (wasNew) {
        _attrRows = await _repo.listProductAttributes(id);
      }
      final persisted = _attrRows.where((r) => r.id.isNotEmpty).toList();
      final hasMedia = productMediaHasPendingWork(mainPending: _mainPending, items: _mediaItems);

      await Future.wait([
        if (persisted.isNotEmpty)
          saveProductAttributeValues(_repo, persisted, _attrValues)
        else
          Future<void>.value(),
        if (hasMedia)
          persistProductMediaOnSave(
            productId: id,
            productName: _nameCtrl.text.trim(),
            mainPending: _mainPending,
            existingMainUrl: _existingMainUrl,
            items: _mediaItems,
            repo: _mediaRepo,
          )
        else
          Future<void>.value(),
      ]);
      if (!mounted) return;
      _showSnack(wasNew ? 'Product created successfully' : 'Product updated successfully');
      _back();
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final msg = raw.contains('products_sku_key')
            ? 'SKU already exists. Edit SKU field or change product/model name.'
            : 'Save failed: $e';
        _showSnack(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(RouteNames.adminShopProducts);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: title == 'Basic information' || title == 'Attributes',
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: widget.isCreate && _productId == null ? 'New product' : 'Edit product',
      embedded: widget.embedded,
      onBack: _back,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.categoryPreSelected && _selectedCategorySubLabel != null)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                    child: ListTile(
                      leading: Icon(Icons.category_outlined, color: Theme.of(context).colorScheme.primary),
                      title: const Text('Category & sub-category', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _selectedCategorySubLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: TextButton(
                        onPressed: _back,
                        child: const Text('Change'),
                      ),
                    ),
                  ),
                _section('Basic information', [
                  DgAssistTextField(
                    controller: _nameCtrl,
                    assistProfile: TextAssistProfile.entityName,
                    enableRemoteSpellCheck: false,
                    debounceSpellMs: 0,
                    textCapitalization: TextCapitalization.words,
                    contextHints: _assistContext(),
                    decoration: const InputDecoration(
                      labelText: 'Product name *',
                      border: OutlineInputBorder(),
                      helperText: 'SKU is generated automatically from the product name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _skuCtrl,
                    readOnly: _skuLocked,
                    onChanged: _skuLocked ? null : (_) => _skuManual = true,
                    decoration: InputDecoration(
                      labelText: 'SKU / Product code',
                      border: const OutlineInputBorder(),
                      helperText: _skuLocked
                          ? 'SKU cannot be changed after creation'
                          : 'Auto from model or name; edit if duplicate. -2 suffix added on collision.',
                      suffixIcon: _skuLocked ? null : const Icon(Icons.auto_fix_high_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_brands.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      initialValue: _brandId,
                      decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        for (final b in _brands) DropdownMenuItem(value: b.id, child: Text(b.name)),
                      ],
                      onChanged: (v) => setState(() => _brandId = v),
                    ),
                  if (!widget.categoryPreSelected) ...[
                    const SizedBox(height: 8),
                    if (_categories.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'Category *', border: OutlineInputBorder()),
                        items: [for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name))],
                        onChanged: (v) async {
                          if (v == null) return;
                          final subs = await _repo.listSubCategories(v, activeOnly: false);
                          setState(() {
                            _categoryId = v;
                            _subs = subs;
                            _subCategoryId = subs.isNotEmpty ? subs.first.id : null;
                          });
                          await _onSubCategoryChanged(_subCategoryId);
                        },
                      ),
                    const SizedBox(height: 8),
                    if (_subs.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _subCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Sub-category *',
                          border: OutlineInputBorder(),
                          helperText: 'Attributes load automatically from assigned groups',
                        ),
                        items: [for (final s in _subs) DropdownMenuItem(value: s.id, child: Text(s.name))],
                        onChanged: _onSubCategoryChanged,
                      ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _modelNameCtrl,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(
                      labelText: 'Model name (optional)',
                      border: OutlineInputBorder(),
                      helperText: 'Manufacturer model — used for SKU when filled; datasheet PDF can auto-fill',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _hsnCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'HSN code',
                      border: const OutlineInputBorder(),
                      helperText: _subCategoryDefaultHsn != null && _subCategoryDefaultHsn!.isNotEmpty
                          ? 'Inherited from sub-category ($_subCategoryDefaultHsn); updates when sub-category changes'
                          : 'Set default HSN on sub-category or enter manually',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Override GST at product level'),
                    subtitle: Text(_useGstOverride ? 'Using product GST %' : 'Using sub-category default ($_subCategoryDefaultGst%)'),
                    value: _useGstOverride,
                    onChanged: (v) => setState(() {
                      _useGstOverride = v;
                      if (!v) _taxCtrl.text = '$_subCategoryDefaultGst';
                    }),
                  ),
                  TextField(
                    controller: _taxCtrl,
                    readOnly: !_useGstOverride,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'GST %',
                      border: const OutlineInputBorder(),
                      helperText: _useGstOverride ? 'Product override' : 'Inherited from sub-category ($_subCategoryDefaultGst%)',
                    ),
                  ),
                  TextField(
                    controller: _warrantyCtrl,
                    decoration: const InputDecoration(labelText: 'Warranty label', border: OutlineInputBorder(), helperText: 'e.g. 1 Year onsite'),
                  ),
                  SwitchListTile(
                    title: const Text('Track serial numbers'),
                    value: _trackSerial,
                    onChanged: (v) => setState(() => _trackSerial = v),
                  ),
                  SwitchListTile(
                    title: const Text('Track batch numbers'),
                    value: _trackBatch,
                    onChanged: (v) => setState(() => _trackBatch = v),
                  ),
                  SwitchListTile(title: const Text('Active'), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
                ]),
                _section('Pricing', [
                  ShopProductPricingSection(
                    costController: _costCtrl,
                    mrpController: _mrpCtrl,
                    onlineController: _onlineCtrl,
                    dealerController: _dealerCtrl,
                  ),
                ]),
                _section('Unit & stock', [
                  DropdownButtonFormField<String>(
                    key: ValueKey('unit-$_inventoryUnit'),
                    initialValue: _productUnits.any((e) => e.$1 == _inventoryUnit)
                        ? _inventoryUnit
                        : 'pcs',
                    decoration: const InputDecoration(
                      labelText: 'Selling unit *',
                      border: OutlineInputBorder(),
                      helperText:
                          'How this product is sold — e.g. cable per meter = mtr, camera = pcs, cable box = box',
                    ),
                    items: [
                      for (final u in _productUnits)
                        DropdownMenuItem(
                          value: u.$1,
                          child: Text('${u.$2} (${u.$1})'),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _inventoryUnit = v ?? 'pcs';
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('stock-$_stockStatus'),
                    initialValue: _stockStatus,
                    decoration: const InputDecoration(
                      labelText: 'Stock status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'in_stock', child: Text('In stock')),
                      DropdownMenuItem(
                        value: 'out_of_stock',
                        child: Text('Out of stock'),
                      ),
                      DropdownMenuItem(
                        value: 'preorder',
                        child: Text('Pre-order'),
                      ),
                      DropdownMenuItem(
                        value: 'discontinued',
                        child: Text('Discontinued'),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _stockStatus = v ?? 'in_stock';
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: '$_reorderLevel',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Reorder level',
                      border: const OutlineInputBorder(),
                      helperText:
                          'Alert when stock falls below this (in $_inventoryUnit)',
                    ),
                    onChanged: (v) {
                      _reorderLevel = int.tryParse(v.trim()) ?? 0;
                    },
                  ),
                  if (_productId != null) ...[
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Qty on hand',
                        border: const OutlineInputBorder(),
                        helperText:
                            'Current stock: $_inventoryQty $_inventoryUnit (update via inventory / ERP if needed)',
                      ),
                      child: Text(
                        '$_inventoryQty $_inventoryUnit',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ]),
                _section('Attributes', [
                  if (_sections.isEmpty)
                    const Text('Assign attribute groups to this sub-category to see fields here.')
                  else
                    for (final sec in _sections) ...[
                      Text(sec.groupName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 8),
                      ProductAttributeFields(
                        attributes: _attrRows.where((r) => sec.attributes.any((a) => a.master.id == r.master.id)).toList(),
                        values: _attrValues,
                        onChanged: (id, v) => setState(() => _attrValues[id] = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                ]),
                _section('Descriptions', [
                  DgAssistTextField(
                    controller: _shortDescCtrl,
                    maxLines: 2,
                    assistProfile: TextAssistProfile.productShortDesc,
                    enableRemoteSpellCheck: false,
                    debounceSpellMs: 0,
                    contextHints: _assistContext(),
                    decoration: const InputDecoration(
                      labelText: 'Short description (optional)',
                      border: OutlineInputBorder(),
                      helperText: 'AI assist → Generate short description',
                    ),
                  ),
                  DgAssistTextField(
                    controller: _fullDescCtrl,
                    maxLines: 4,
                    showLanguagePicker: true,
                    assistProfile: TextAssistProfile.productFullDesc,
                    enableRemoteSpellCheck: false,
                    debounceSpellMs: 0,
                    contextHints: _assistContext(),
                    decoration: const InputDecoration(labelText: 'Full description', border: OutlineInputBorder()),
                  ),
                  DgAssistTextField(
                    controller: _techCtrl,
                    maxLines: 3,
                    assistProfile: TextAssistProfile.technicalNotes,
                    enableRemoteSpellCheck: false,
                    debounceSpellMs: 0,
                    contextHints: _assistContext(),
                    decoration: const InputDecoration(labelText: 'Technical notes', border: OutlineInputBorder()),
                  ),
                  DgAssistTextField(
                    controller: _installCtrl,
                    maxLines: 3,
                    assistProfile: TextAssistProfile.technicalNotes,
                    enableRemoteSpellCheck: false,
                    debounceSpellMs: 0,
                    contextHints: _assistContext(),
                    decoration: const InputDecoration(labelText: 'Installation notes', border: OutlineInputBorder()),
                  ),
                ]),
                _section('Media', [
                  if (_extractingDatasheet)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(),
                    ),
                  ShopProductMediaPanel(
                    productName: _nameCtrl.text,
                    items: _mediaItems,
                    existingMainUrl: _existingMainUrl,
                    existingEditorSourceUrl: _existingMainEditorSourceUrl,
                    existingPlacements: _existingMainPlacements,
                    existingSourceW: _existingMainSourceW,
                    existingSourceH: _existingMainSourceH,
                    mainPending: _mainPending,
                    searchContext: _imageSearchContext(),
                    onMainPendingChanged: (p) => setState(() => _mainPending = p),
                    onClearMain: () => setState(() => _existingMainUrl = null),
                    onChanged: (items) => setState(() => _mediaItems = items),
                    onDatasheetPdfAdded: _onDatasheetPdfAdded,
                  ),
                ]),
                _section('SEO', [
                  ShopSeoFormSection(
                    seoTitleController: _seoTitleCtrl,
                    metaDescriptionController: _metaDescCtrl,
                    slugController: _slugCtrl,
                    contextHints: _assistContext(),
                    enableRemoteSpellCheck: false,
                    debounceSpellMs: 0,
                    slugAutoHint: 'Auto from product name if empty',
                    canonicalPreview: _resolveSeo().canonicalUrl,
                  ),
                ]),
                _section('Calculator', [
                  SwitchListTile(
                    title: const Text('Show in calculator'),
                    subtitle: const Text(
                      'Link this product to one or more calculator families '
                      '(e.g. Hard Disk → HD CCTV + IP CCTV + Computer Assemble)',
                    ),
                    value: _showInCalculator,
                    onChanged: (v) => setState(() => _showInCalculator = v),
                  ),
                  if (_showInCalculator && _calcFamilies.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Calculator families (select all that apply)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in _calcFamilies)
                            FilterChip(
                              label: Text(f.name),
                              selected: _calcFamilyIds.contains(f.id),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _calcFamilyIds.add(f.id);
                                  } else {
                                    _calcFamilyIds.remove(f.id);
                                  }
                                  _calcFamilyId =
                                      _calcFamilyIds.isNotEmpty ? _calcFamilyIds.first : null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    if (_calcFamilyIds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Select at least one family',
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _calcPriorityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calculator priority',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save product'),
                ),
              ],
            ),
    );
  }
}
