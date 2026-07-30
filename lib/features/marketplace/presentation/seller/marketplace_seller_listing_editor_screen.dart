import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/services/firestore_service.dart';
import '../../../../shared/services/storage_service.dart';
import '../../data/marketplace_listing_repository.dart';
import '../../data/marketplace_taxonomy_repository.dart';
import '../../domain/marketplace_listing.dart';
import '../../domain/marketplace_price_tier.dart';
import '../../domain/marketplace_taxonomy.dart';
import '../widgets/marketplace_barcode_scan_screen.dart';
import '../widgets/marketplace_premium_shell.dart';

class _TierRowCtrls {
  _TierRowCtrls({String min = '1', String max = '', String price = ''})
      : min = TextEditingController(text: min),
        max = TextEditingController(text: max),
        price = TextEditingController(text: price);

  final TextEditingController min;
  final TextEditingController max;
  final TextEditingController price;

  void dispose() {
    min.dispose();
    max.dispose();
    price.dispose();
  }
}

/// Create (`listingId == null`) or edit seller listing draft/rejected.
class MarketplaceSellerListingEditorScreen extends StatefulWidget {
  const MarketplaceSellerListingEditorScreen({super.key, this.listingId});

  final String? listingId;

  @override
  State<MarketplaceSellerListingEditorScreen> createState() => _MarketplaceSellerListingEditorScreenState();
}

class _MarketplaceSellerListingEditorScreenState extends State<MarketplaceSellerListingEditorScreen> {
  final _repo = MarketplaceListingRepository();
  final _tax = MarketplaceTaxonomyRepository();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _stockInitial = TextEditingController();
  final _proposedSubCtrl = TextEditingController();
  final List<_TierRowCtrls> _tierRows = [];
  bool _loading = true;
  bool _busy = false;
  bool _blocked = false;
  String? _autoDraftId;
  static const int _maxImages = 8;
  List<String> _imageUrls = [];

  /// First column: category the seller started from.
  String _browseCategoryId = '';
  String _browseSubcategoryId = '';
  String _browseCategoryName = '';
  String _browseSubcategoryName = '';

  /// When subcategory is [kMarketplaceOtherSubcategoryId]: parent category for the new proposed sub.
  String _resolvedCategoryId = '';
  String _resolvedCategoryName = '';

  List<SellerProposedFeatureDef> _proposalFeatures = [];

  Map<String, String> _attrSelections = {};
  final Map<String, TextEditingController> _attrTextControllers = {};
  MarketplaceListing? _loadedListing;

  bool get _usingOtherPath => _browseSubcategoryId == kMarketplaceOtherSubcategoryId;

  String get _effectiveCategoryId => _usingOtherPath ? _resolvedCategoryId : _browseCategoryId;

  String? get _effectiveListingId => widget.listingId ?? _autoDraftId;

  bool get _isPublished => _loadedListing?.status == 'published';

  List<Map<String, dynamic>> _mapsFromPayload(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _clearAllAttrTextControllers() {
    for (final c in _attrTextControllers.values) {
      c.dispose();
    }
    _attrTextControllers.clear();
  }

  TextEditingController _attrTextController(String key) {
    return _attrTextControllers.putIfAbsent(key, () => TextEditingController());
  }

  void _syncAttrControllersFromSelections() {
    final selKeys = _attrSelections.keys.toSet();
    for (final k in List<String>.from(_attrTextControllers.keys)) {
      if (!selKeys.contains(k)) {
        _attrTextControllers.remove(k)?.dispose();
      }
    }
    for (final e in _attrSelections.entries) {
      final c = _attrTextControllers.putIfAbsent(e.key, () => TextEditingController());
      if (c.text != e.value) {
        c.text = e.value;
      }
    }
  }

  Future<void> _scanIntoAttrField(String key) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => const MarketplaceBarcodeScanScreen(),
      ),
    );
    if (code == null || !mounted) return;
    final upper = code.toUpperCase();
    final c = _attrTextController(key);
    c.text = upper;
    setState(() {
      _attrSelections = Map<String, String>.from(_attrSelections)..[key] = upper;
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _disposeTierRows() {
    for (final r in _tierRows) {
      r.dispose();
    }
    _tierRows.clear();
  }

  void _initDefaultTierRows() {
    _disposeTierRows();
    _tierRows.add(_TierRowCtrls());
  }

  void _fillTiersFromListing(MarketplaceListing l) {
    _disposeTierRows();
    if (l.priceTiers.isNotEmpty) {
      for (final t in l.priceTiers) {
        _tierRows.add(
          _TierRowCtrls(
            min: '${t.minQty}',
            max: t.maxQty == null ? '' : '${t.maxQty}',
            price: (t.pricePaise / 100).toStringAsFixed(t.pricePaise % 100 == 0 ? 0 : 2),
          ),
        );
      }
    } else {
      _tierRows.add(
        _TierRowCtrls(
          price: (l.proposedPricePaise / 100).toStringAsFixed(l.proposedPricePaise % 100 == 0 ? 0 : 2),
        ),
      );
    }
  }

  int? _parsedStockInitial() {
    final t = _stockInitial.text.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < 0) return null;
    return n;
  }

  List<MarketplacePriceTier>? _parseTiers(BuildContext context) {
    if (_tierRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one quantity band and price.')),
      );
      return null;
    }
    final out = <MarketplacePriceTier>[];
    for (final row in _tierRows) {
      final min = int.tryParse(row.min.text.trim());
      final maxT = row.max.text.trim();
      final max = maxT.isEmpty ? null : int.tryParse(maxT);
      final rupees = double.tryParse(row.price.text.trim());
      if (min == null || min < 1 || rupees == null || rupees < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Each band needs min qty ≥ 1 and a valid price (INR).')),
        );
        return null;
      }
      if (max != null && max < min) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max qty must be ≥ min qty, or leave max empty for “and above”.')),
        );
        return null;
      }
      out.add(MarketplacePriceTier(minQty: min, maxQty: max, pricePaise: (rupees * 100).round()));
    }
    out.sort((a, b) => a.minQty.compareTo(b.minQty));
    return out;
  }

  int _referencePaise(List<MarketplacePriceTier> tiers) {
    if (tiers.isEmpty) return 0;
    return MarketplacePriceTier.pricePaiseForQuantity(tiers, tiers.first.minQty);
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (widget.listingId == null) {
      if (uid != null) {
        try {
          _autoDraftId = await _repo.createDraftListing(
            sellerUid: uid,
            title: 'Draft listing',
            description: '',
            proposedPricePaise: 0,
            priceTiers: const [],
          );
        } catch (_) {}
      }
      _initDefaultTierRows();
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final l = await _repo.getListing(widget.listingId!);
    if (!mounted) return;
    if (l != null) {
      _loadedListing = l;
      if (l.status == 'pending_review' || l.status == 'archived') {
        _blocked = true;
      }
      _title.text = l.title;
      _desc.text = l.description;
      _fillTiersFromListing(l);
      _stockInitial.text = l.stockQtyInitial != null ? '${l.stockQtyInitial}' : '';
      _imageUrls = List<String>.from(l.imageUrls);
      if (l.usedOtherSubcategory) {
        _browseCategoryId = l.entryCategoryId.isNotEmpty ? l.entryCategoryId : l.categoryId;
        _browseCategoryName = l.entryCategoryName.isNotEmpty ? l.entryCategoryName : l.categoryName;
        _browseSubcategoryId = kMarketplaceOtherSubcategoryId;
        _browseSubcategoryName = 'Others';
        _resolvedCategoryId = l.categoryId;
        _resolvedCategoryName = l.categoryName;
        _proposedSubCtrl.text = l.subcategoryName;
        _proposalFeatures = List<SellerProposedFeatureDef>.from(l.sellerProposedFeatureDefs);
      } else {
        _browseCategoryId = l.categoryId;
        _browseSubcategoryId = l.subcategoryId;
        _browseCategoryName = l.categoryName;
        _browseSubcategoryName = l.subcategoryName;
        _resolvedCategoryId = l.categoryId;
        _resolvedCategoryName = l.categoryName;
        _proposalFeatures = [];
      }
      _attrSelections = Map<String, String>.from(l.attributeSelections);
      _syncAttrControllersFromSelections();
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _stockInitial.dispose();
    _disposeTierRows();
    _clearAllAttrTextControllers();
    _proposedSubCtrl.dispose();
    super.dispose();
  }

  Future<void> _persistImages(String listingId) async {
    await _repo.updateListingImages(listingId, List<String>.from(_imageUrls));
  }

  Future<void> _showAddPhotoSource() async {
    final listingId = _effectiveListingId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (listingId == null || uid == null) return;
    if (_imageUrls.length >= _maxImages) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Add product photo',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo with camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndUploadImage(source);
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final listingId = _effectiveListingId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (listingId == null || uid == null) return;
    if (_imageUrls.length >= _maxImages) return;
    final picker = ImagePicker();
    XFile? xfile;
    try {
      xfile = await picker.pickImage(source: source, imageQuality: 88);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e')),
        );
      }
      return;
    }
    if (xfile == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await xfile.readAsBytes();
      final ct = xfile.mimeType ?? 'image/jpeg';
      final url = await StorageService.uploadMarketplaceListingImage(
        userId: uid,
        listingId: listingId,
        bytes: bytes,
        contentType: ct,
      );
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
        }
        return;
      }
      setState(() => _imageUrls = [..._imageUrls, url]);
      await _persistImages(listingId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhotoAt(int index) async {
    final listingId = _effectiveListingId;
    if (listingId == null) return;
    setState(() {
      _imageUrls = [..._imageUrls]..removeAt(index);
    });
    setState(() => _busy = true);
    try {
      await _persistImages(listingId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _taxonomyPayload() {
    final other = _usingOtherPath;
    final cat = other ? _resolvedCategoryId : _browseCategoryId;
    final sub = other ? kMarketplaceProposedSubcategoryId : _browseSubcategoryId;
    final cname = other ? _resolvedCategoryName : _browseCategoryName;
    final sname = other ? _proposedSubCtrl.text.trim() : _browseSubcategoryName;
    return {
      'category_id': cat.isEmpty ? 'general' : cat,
      'subcategory_id': sub,
      'category_name': cname,
      'subcategory_name': sname,
      'attribute_selections': _attrSelections,
      'used_other_subcategory': other,
      'entry_category_id': other ? _browseCategoryId : '',
      'entry_category_name': other ? _browseCategoryName : '',
      'seller_proposed_feature_defs': _proposalFeatures.map((e) => e.toFirestoreMap()).toList(growable: false),
    };
  }

  Future<void> _applyAdminSuggestions() async {
    final l = _loadedListing;
    final id = widget.listingId;
    if (l == null || !l.hasAdminTaxonomySuggestion || id == null) return;
    setState(() {
      _browseCategoryId = l.adminSuggestedCategoryId!.trim();
      _browseSubcategoryId = l.adminSuggestedSubcategoryId!.trim();
      _browseCategoryName = l.adminSuggestedCategoryName?.trim() ?? '';
      _browseSubcategoryName = l.adminSuggestedSubcategoryName?.trim() ?? '';
      _resolvedCategoryId = _browseCategoryId;
      _resolvedCategoryName = _browseCategoryName;
      _proposalFeatures = [];
      _proposedSubCtrl.clear();
      _attrSelections = Map<String, String>.from(l.adminSuggestedAttributeSelections);
      _loadedListing = MarketplaceListing(
        id: l.id,
        sellerUid: l.sellerUid,
        status: l.status,
        title: l.title,
        description: l.description,
        proposedPricePaise: l.proposedPricePaise,
        imageUrls: l.imageUrls,
        categoryId: l.categoryId,
        subcategoryId: l.subcategoryId,
        categoryName: l.categoryName,
        subcategoryName: l.subcategoryName,
        attributeSelections: l.attributeSelections,
        usedOtherSubcategory: l.usedOtherSubcategory,
        entryCategoryId: l.entryCategoryId,
        entryCategoryName: l.entryCategoryName,
        sellerProposedFeatureDefs: l.sellerProposedFeatureDefs,
        priceTiers: l.priceTiers,
        stockQtyInitial: l.stockQtyInitial,
        deletionRequested: l.deletionRequested,
        adminSuggestedCategoryId: null,
        adminSuggestedSubcategoryId: null,
        adminSuggestedCategoryName: null,
        adminSuggestedSubcategoryName: null,
        adminSuggestedAttributeSelections: const {},
        catalogProductId: l.catalogProductId,
        rejectionReason: l.rejectionReason,
        updatedAt: l.updatedAt,
      );
    });
    _syncAttrControllersFromSelections();
    setState(() => _busy = true);
    try {
      await _repo.clearAdminTaxonomySuggestions(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Applied admin suggestions. Save draft or submit when ready.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _validateTaxonomyForSubmit(BuildContext context) async {
    if (_browseCategoryId.isEmpty || _browseSubcategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select category and subcategory before submitting.')),
      );
      return false;
    }
    if (_usingOtherPath) {
      if (_resolvedCategoryId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select the parent category for your new subcategory.')),
        );
        return false;
      }
      if (_proposedSubCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the new subcategory name (e.g. Outdoor UTP).')),
        );
        return false;
      }
      final keys = <String>{};
      for (final def in _proposalFeatures) {
        if (def.key.isEmpty || def.label.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Each feature needs a key and label.')),
          );
          return false;
        }
        if (keys.contains(def.key)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Duplicate feature key: ${def.key}')),
          );
          return false;
        }
        keys.add(def.key);
      }
      for (final def in _proposalFeatures) {
        final sel = (_attrSelections[def.key] ?? '').trim();
        if (def.usesTextInput) {
          if (sel.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Enter a value for "${def.label}"')),
            );
            return false;
          }
        } else if (sel.isEmpty || !def.values.contains(sel)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Select a value for "${def.label}"')),
          );
          return false;
        }
      }
      return true;
    }
    if (!FirestoreService.isAvailable) return false;
    final snap = await FirestoreService.marketplaceCategoryAttributes(_effectiveCategoryId, _browseSubcategoryId)
        .orderBy('sort_order')
        .get();
    if (!context.mounted) return false;
    for (final doc in snap.docs) {
      final def = MarketplaceAttributeDef.fromDoc(doc);
      if (def == null) continue;
      if (!def.required) continue;
      final sel = (_attrSelections[def.key] ?? '').trim();
      if (sel.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(def.usesTextInput ? 'Enter "${def.label}"' : 'Select "${def.label}"')),
        );
        return false;
      }
      if (!def.usesTextInput && !def.values.contains(sel)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Select "${def.label}"')),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _saveDraft(BuildContext context) async {
    if (_isPublished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Published listings: use “Submit changes for approval” below.')),
      );
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final tiers = _parseTiers(context);
    if (tiers == null || tiers.isEmpty) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title required')));
      return;
    }
    final stock = _parsedStockInitial();
    if (_stockInitial.text.trim().isNotEmpty && stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock must be a non‑negative whole number or empty')));
      return;
    }
    final paise = _referencePaise(tiers);
    setState(() => _busy = true);
    try {
      var id = (_effectiveListingId ?? '').trim();
      final t = _taxonomyPayload();
      final sellerDefs = _mapsFromPayload(t['seller_proposed_feature_defs']);
      if (id.isEmpty) {
        id = await _repo.createDraftListing(
          sellerUid: uid,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          proposedPricePaise: paise,
          categoryId: t['category_id'] as String,
          subcategoryId: t['subcategory_id'] as String,
          categoryName: t['category_name'] as String,
          subcategoryName: t['subcategory_name'] as String,
          attributeSelections: Map<String, String>.from(t['attribute_selections'] as Map),
          usedOtherSubcategory: t['used_other_subcategory'] as bool,
          entryCategoryId: t['entry_category_id'] as String,
          entryCategoryName: t['entry_category_name'] as String,
          sellerProposedFeatureDefs: sellerDefs,
          priceTiers: tiers,
          stockQtyInitial: stock,
        );
      } else {
        await _repo.updateDraft(
          listingId: id,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          proposedPricePaise: paise,
          categoryId: t['category_id'] as String,
          subcategoryId: t['subcategory_id'] as String,
          categoryName: t['category_name'] as String,
          subcategoryName: t['subcategory_name'] as String,
          attributeSelections: Map<String, String>.from(t['attribute_selections'] as Map),
          usedOtherSubcategory: t['used_other_subcategory'] as bool,
          entryCategoryId: t['entry_category_id'] as String,
          entryCategoryName: t['entry_category_name'] as String,
          sellerProposedFeatureDefs: sellerDefs,
          priceTiers: tiers,
          stockQtyInitial: stock,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitForReview(BuildContext context) async {
    if (_isPublished) {
      await _queuePublishedChanges(context);
      return;
    }
    if (!await _validateTaxonomyForSubmit(context)) return;
    if (!context.mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final tiers = _parseTiers(context);
    if (tiers == null || tiers.isEmpty) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title required')));
      return;
    }
    final stock = _parsedStockInitial();
    if (_stockInitial.text.trim().isNotEmpty && stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock must be a non‑negative whole number or empty')));
      return;
    }
    final paise = _referencePaise(tiers);
    setState(() => _busy = true);
    try {
      var id = (_effectiveListingId ?? '').trim();
      final t = _taxonomyPayload();
      final sellerDefs = _mapsFromPayload(t['seller_proposed_feature_defs']);
      if (id.isEmpty) {
        id = await _repo.createDraftListing(
          sellerUid: uid,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          proposedPricePaise: paise,
          categoryId: t['category_id'] as String,
          subcategoryId: t['subcategory_id'] as String,
          categoryName: t['category_name'] as String,
          subcategoryName: t['subcategory_name'] as String,
          attributeSelections: Map<String, String>.from(t['attribute_selections'] as Map),
          usedOtherSubcategory: t['used_other_subcategory'] as bool,
          entryCategoryId: t['entry_category_id'] as String,
          entryCategoryName: t['entry_category_name'] as String,
          sellerProposedFeatureDefs: sellerDefs,
          priceTiers: tiers,
          stockQtyInitial: stock,
        );
      } else {
        await _repo.updateDraft(
          listingId: id,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          proposedPricePaise: paise,
          categoryId: t['category_id'] as String,
          subcategoryId: t['subcategory_id'] as String,
          categoryName: t['category_name'] as String,
          subcategoryName: t['subcategory_name'] as String,
          attributeSelections: Map<String, String>.from(t['attribute_selections'] as Map),
          usedOtherSubcategory: t['used_other_subcategory'] as bool,
          entryCategoryId: t['entry_category_id'] as String,
          entryCategoryName: t['entry_category_name'] as String,
          sellerProposedFeatureDefs: sellerDefs,
          priceTiers: tiers,
          stockQtyInitial: stock,
          clearAdminSuggestions: true,
        );
      }
      await _repo.submitForReview(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for admin review')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _queuePublishedChanges(BuildContext context) async {
    if (!await _validateTaxonomyForSubmit(context)) return;
    if (!context.mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final id = (_effectiveListingId ?? '').trim();
    if (id.isEmpty) return;
    final tiers = _parseTiers(context);
    if (tiers == null || tiers.isEmpty) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title required')));
      return;
    }
    final stock = _parsedStockInitial();
    if (_stockInitial.text.trim().isNotEmpty && stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock must be a non‑negative whole number or empty')));
      return;
    }
    final paise = _referencePaise(tiers);
    setState(() => _busy = true);
    try {
      final t = _taxonomyPayload();
      final sellerDefs = _mapsFromPayload(t['seller_proposed_feature_defs']);
      await _repo.updateDraft(
        listingId: id,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        proposedPricePaise: paise,
        categoryId: t['category_id'] as String,
        subcategoryId: t['subcategory_id'] as String,
        categoryName: t['category_name'] as String,
        subcategoryName: t['subcategory_name'] as String,
        attributeSelections: Map<String, String>.from(t['attribute_selections'] as Map),
        usedOtherSubcategory: t['used_other_subcategory'] as bool,
        entryCategoryId: t['entry_category_id'] as String,
        entryCategoryName: t['entry_category_name'] as String,
        sellerProposedFeatureDefs: sellerDefs,
        priceTiers: tiers,
        stockQtyInitial: stock,
        clearAdminSuggestions: true,
        nextStatus: 'pending_review',
        deletionRequested: false,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes sent for admin approval. Buyers still see the last approved version until then.')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _attributeDropdownsFor(String categoryId, String subcategoryId) {
    if (categoryId.isEmpty || subcategoryId.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<MarketplaceAttributeDef>>(
      stream: _tax.watchAttributes(categoryId, subcategoryId),
      builder: (context, attrSnap) {
        final defs = attrSnap.data ?? [];
        if (defs.isEmpty) {
          return Text(
            'No extra options for this subcategory yet. Admin can add features in Marketplace → Categories.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: defs.map((def) {
            final cur = _attrSelections[def.key];
            if (def.usesTextInput) {
              final ctl = _attrTextController(def.key);
              final showScan = def.scanQrBarcode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey<String>('attr_txt_${categoryId}_${subcategoryId}_${def.key}'),
                        controller: ctl,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: def.label + (def.required ? ' *' : ''),
                          hintText: 'Type value',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          final t = v.trim();
                          if (t.isEmpty) {
                            _attrSelections.remove(def.key);
                          } else {
                            _attrSelections = Map<String, String>.from(_attrSelections)..[def.key] = v;
                          }
                        },
                      ),
                    ),
                    if (showScan) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Scan QR or barcode',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        onPressed: _busy ? null : () => _scanIntoAttrField(def.key),
                      ),
                    ],
                  ],
                ),
              );
            }
            final valid = cur != null && def.values.contains(cur);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>('attr_${categoryId}_${subcategoryId}_${def.id}_$cur'),
                isExpanded: true,
                initialValue: valid ? cur : null,
                decoration: InputDecoration(
                  labelText: def.label + (def.required ? ' *' : ''),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: def.values
                    .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                    .toList(),
                onChanged: _busy
                    ? null
                    : (val) {
                        setState(() {
                          if (val == null) {
                            _attrSelections.remove(def.key);
                          } else {
                            _attrSelections = Map<String, String>.from(_attrSelections)..[def.key] = val;
                          }
                        });
                      },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _addProposalFeatureDialog(BuildContext context) async {
    final keyCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final valuesCtrl = TextEditingController();
    try {
      var enableScan = false;
      List<String> parseOptionVals(String raw) => raw
          .split(RegExp(r'[,;\n]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) {
            final optionsBlank = parseOptionVals(valuesCtrl.text).isEmpty;
            return AlertDialog(
              title: const Text('New feature'),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: keyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Key (machine id)',
                            hintText: 'cable_type',
                            helperText: 'Lowercase, underscores',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: labelCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Label',
                            hintText: 'Cable type',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: valuesCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Options (comma-separated)',
                            hintText: 'CAT5e, CAT6, CAT6A',
                            helperText: 'Leave blank — seller types a custom value for this product.',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (_) {
                            setModalState(() {
                              if (parseOptionVals(valuesCtrl.text).isNotEmpty) {
                                enableScan = false;
                              }
                            });
                          },
                        ),
                        if (optionsBlank) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('QR / barcode scan'),
                            subtitle: const Text(
                              'Show a scan icon next to the value field; camera fills text in capitals.',
                            ),
                            value: enableScan,
                            onChanged: (v) => setModalState(() => enableScan = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
              ],
            );
          },
        ),
      );
      if (ok != true || !context.mounted) return;
      final key = keyCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final label = labelCtrl.text.trim();
      final vals = parseOptionVals(valuesCtrl.text);
      if (key.isEmpty || label.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Key and label are required')),
        );
        return;
      }
      if (_proposalFeatures.any((d) => d.key == key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Key "$key" already exists')),
        );
        return;
      }
      final freeText = vals.isEmpty;
      final scanOn = freeText && enableScan;
      setState(() {
        _proposalFeatures = [
          ..._proposalFeatures,
          SellerProposedFeatureDef(
            key: key,
            label: label,
            values: vals,
            freeText: freeText,
            scanQrBarcode: scanOn,
          ),
        ];
      });
    } finally {
      keyCtrl.dispose();
      labelCtrl.dispose();
      valuesCtrl.dispose();
    }
  }

  Widget _taxonomyBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Category & features', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Pick your category, then a subcategory. If nothing fits, choose Others — add a new subcategory name and features like admin does; it goes for approval before going live.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<MarketplaceCategoryNode>>(
          stream: _tax.watchCategories(activeOnly: true),
          builder: (context, catSnap) {
            final cats = catSnap.data ?? [];
            return DropdownButtonFormField<String>(
              key: ValueKey<String>('browse_cat_$_browseCategoryId'),
              isExpanded: true,
              initialValue: _browseCategoryId.isNotEmpty && cats.any((c) => c.id == _browseCategoryId) ? _browseCategoryId : null,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(value: '', child: Text('Select…')),
                ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      setState(() {
                        _browseCategoryId = v ?? '';
                        _browseSubcategoryId = '';
                        _browseSubcategoryName = '';
                        _attrSelections = {};
                        _clearAllAttrTextControllers();
                        _browseCategoryName = '';
                        _resolvedCategoryId = '';
                        _resolvedCategoryName = '';
                        _proposedSubCtrl.clear();
                        _proposalFeatures = [];
                        if (_browseCategoryId.isNotEmpty) {
                          for (final c in cats) {
                            if (c.id == _browseCategoryId) {
                              _browseCategoryName = c.name;
                              break;
                            }
                          }
                        }
                      });
                    },
            );
          },
        ),
        const SizedBox(height: 12),
        if (_browseCategoryId.isEmpty)
          Text('Choose a category to load subcategories.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary))
        else
          StreamBuilder<List<MarketplaceSubcategoryNode>>(
            stream: _tax.watchSubcategories(_browseCategoryId, activeOnly: true),
            builder: (context, subSnap) {
              final subs = subSnap.data ?? [];
              final subOk = _browseSubcategoryId.isNotEmpty &&
                  (_browseSubcategoryId == kMarketplaceOtherSubcategoryId || subs.any((s) => s.id == _browseSubcategoryId));
              return DropdownButtonFormField<String>(
                key: ValueKey<String>('browse_sub_${_browseCategoryId}_$_browseSubcategoryId'),
                isExpanded: true,
                initialValue: subOk ? _browseSubcategoryId : null,
                decoration: const InputDecoration(
                  labelText: 'Subcategory',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Select…')),
                  ...subs.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                  const DropdownMenuItem<String>(
                    value: kMarketplaceOtherSubcategoryId,
                    child: Text('Others (propose new sub + features)'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() {
                          _browseSubcategoryId = v ?? '';
                          _attrSelections = {};
                          _clearAllAttrTextControllers();
                          _browseSubcategoryName = '';
                          _resolvedCategoryId = '';
                          _resolvedCategoryName = '';
                          _proposedSubCtrl.clear();
                          _proposalFeatures = [];
                          if (_browseSubcategoryId == kMarketplaceOtherSubcategoryId) {
                            _browseSubcategoryName = 'Others';
                          } else if (_browseSubcategoryId.isNotEmpty) {
                            for (final s in subs) {
                              if (s.id == _browseSubcategoryId) {
                                _browseSubcategoryName = s.name;
                                break;
                              }
                            }
                          }
                        });
                      },
              );
            },
          ),
        if (_browseCategoryId.isNotEmpty &&
            _browseSubcategoryId.isNotEmpty &&
            _browseSubcategoryId != kMarketplaceOtherSubcategoryId) ...[
          const SizedBox(height: 16),
          _attributeDropdownsFor(_browseCategoryId, _browseSubcategoryId),
        ],
        if (_usingOtherPath) ...[
          const SizedBox(height: 20),
          Text(
            'Propose new subcategory (like admin)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick the parent category, type a new subcategory name, then add features. Leave options blank to type a custom value for this listing; or add comma-separated options like admin.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<MarketplaceCategoryNode>>(
            stream: _tax.watchCategories(activeOnly: true),
            builder: (context, catSnap) {
              final cats = catSnap.data ?? [];
              return DropdownButtonFormField<String>(
                key: ValueKey<String>('other_parent_cat_$_resolvedCategoryId'),
                isExpanded: true,
                initialValue:
                    _resolvedCategoryId.isNotEmpty && cats.any((c) => c.id == _resolvedCategoryId) ? _resolvedCategoryId : null,
                decoration: const InputDecoration(
                  labelText: 'Parent category',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('Select…')),
                  ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() {
                          _resolvedCategoryId = v ?? '';
                          _resolvedCategoryName = '';
                          _attrSelections = {};
                          _clearAllAttrTextControllers();
                          if (_resolvedCategoryId.isNotEmpty) {
                            for (final c in cats) {
                              if (c.id == _resolvedCategoryId) {
                                _resolvedCategoryName = c.name;
                                break;
                              }
                            }
                          }
                        });
                      },
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _proposedSubCtrl,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'New subcategory name',
              hintText: 'e.g. Outdoor armoured UTP',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Features',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _busy ? null : () => _addProposalFeatureDialog(context),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add feature'),
              ),
            ],
          ),
          if (_proposalFeatures.isEmpty)
            Text(
              'Optional: add features — options can be blank for a text field on this product, or comma-separated like admin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
            )
          else
            ..._proposalFeatures.asMap().entries.map((e) {
              final def = e.value;
              final idx = e.key;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              def.label,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      _attrTextControllers.remove(def.key)?.dispose();
                                      _proposalFeatures = List<SellerProposedFeatureDef>.from(_proposalFeatures)..removeAt(idx);
                                      _attrSelections.remove(def.key);
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      Text('Key: ${def.key}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      if (def.usesTextInput)
                        Text(
                          'Free text — enter value under “Your product choices”.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: def.values
                              .map((v) => Chip(label: Text(v, style: const TextStyle(fontSize: 12))))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              );
            }),
          if (_proposalFeatures.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Your product choices', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ..._proposalFeatures.map((def) {
              final cur = _attrSelections[def.key];
              if (def.usesTextInput) {
                final ctl = _attrTextController(def.key);
                final showScan = def.scanQrBarcode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey<String>('prop_attr_txt_${def.key}'),
                          controller: ctl,
                          enabled: !_busy,
                          decoration: InputDecoration(
                            labelText: '${def.label} *',
                            hintText: 'Type value for this product',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final t = v.trim();
                            if (t.isEmpty) {
                              _attrSelections.remove(def.key);
                            } else {
                              _attrSelections = Map<String, String>.from(_attrSelections)..[def.key] = v;
                            }
                          },
                        ),
                      ),
                      if (showScan) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Scan QR or barcode',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          onPressed: _busy ? null : () => _scanIntoAttrField(def.key),
                        ),
                      ],
                    ],
                  ),
                );
              }
              final valid = cur != null && def.values.contains(cur);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>('prop_attr_${def.key}_$cur'),
                  isExpanded: true,
                  initialValue: valid ? cur : null,
                  decoration: InputDecoration(
                    labelText: '${def.label} *',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: def.values
                      .map((v) => DropdownMenuItem<String>(value: v, child: Text(v)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (val) {
                          setState(() {
                            if (val == null) {
                              _attrSelections.remove(def.key);
                            } else {
                              _attrSelections = Map<String, String>.from(_attrSelections)..[def.key] = val;
                            }
                          });
                        },
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  Widget _bulkPriceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bulk pricing (per unit INR)',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _tierRows.add(_TierRowCtrls()));
                    },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add band'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Example: 1–5 pcs at one price, 6–10 at another, leave max empty for “51+”.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _tierRows.length; i++) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tierRows[i].min,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min qty',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _tierRows[i].max,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max qty',
                        hintText: 'optional',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tierRows[i].price,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Unit price',
                        hintText: 'INR',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_tierRows.length > 1)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                final r = _tierRows.removeAt(i);
                                r.dispose();
                              });
                            },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _stockInitial,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Starting stock (optional)',
            helperText: 'Leave empty if you do not track quantity. You can change stock after approval from My listings.',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget? _rejectionBanner(BuildContext context) {
    final l = _loadedListing;
    if (l == null || l.status != 'rejected') return null;
    final reason = l.rejectionReason?.trim() ?? '';
    final hasSug = l.hasAdminTaxonomySuggestion;
    if (reason.isEmpty && !hasSug) return null;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Admin feedback', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reason, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
            ],
            if (hasSug) ...[
              const SizedBox(height: 12),
              Text(
                'Suggested placement: ${l.adminSuggestedCategoryName ?? l.adminSuggestedCategoryId} → '
                '${l.adminSuggestedSubcategoryName ?? l.adminSuggestedSubcategoryId}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
              ),
              if (l.adminSuggestedAttributeSelections.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  l.adminSuggestedAttributeSelections.entries.map((e) => '${e.key}: ${e.value}').join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _busy ? null : _applyAdminSuggestions,
                child: const Text('Apply suggested category & features'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return MarketplacePremiumShell(
        body: Column(
          children: [
            Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }
    if (_blocked) {
      return MarketplacePremiumShell(
        appBar: AppBar(title: const Text('Listing')),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'This listing is waiting for admin review or has been archived. You cannot edit it here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final canPhotos = _effectiveListingId != null;
    final banner = _rejectionBanner(context);

    return MarketplacePremiumShell(
      appBar: AppBar(
        title: Text(
          widget.listingId == null
              ? 'New listing'
              : (_isPublished ? 'Edit product (approval required)' : 'Edit listing'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ?banner,
          if (_isPublished) ...[
            Text(
              'Changes to a live product are sent to admin. Buyers keep seeing the current approved version until approved.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
          ],
          _taxonomyBlock(context),
          const SizedBox(height: 24),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          _bulkPriceSection(context),
          const SizedBox(height: 8),
          Text(
            'Final buyer-facing prices are set by D.G.Yard at review; quantity bands you enter are scaled to the approved base.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 24),
          Text('Photos', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (!canPhotos)
            Text(
              'Sign in and wait a moment for the draft to be created, then add up to $_maxImages photos.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.4),
            )
          else ...[
            Text(
              '${_imageUrls.length} / $_maxImages',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imageUrls.length + 1,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i == _imageUrls.length) {
                    return AspectRatio(
                      aspectRatio: 1,
                      child: OutlinedButton(
                        onPressed: _busy || _imageUrls.length >= _maxImages ? null : _showAddPhotoSource,
                        child: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                    );
                  }
                  final url = _imageUrls[i];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 18, color: Colors.white),
                            onPressed: _busy ? null : () => _removePhotoAt(i),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isPublished) ...[
                FilledButton(
                  onPressed: _busy ? null : () => _queuePublishedChanges(context),
                  child: const Text('Submit changes for approval'),
                ),
              ] else ...[
                OutlinedButton(
                  onPressed: _busy ? null : () => _saveDraft(context),
                  child: const Text('Save draft'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _busy ? null : () => _submitForReview(context),
                  child: const Text('Submit for review'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
