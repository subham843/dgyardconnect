import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/link.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/route_names.dart';
import '../../shared/models/brand_kit_model.dart';
import '../../shared/models/brand_kit_public_web.dart';
import '../../shared/models/public_web_offer_bar_item.dart';
import 'widgets/brand_kit_public_web_form.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/brand_kit_service.dart';
import '../../shared/widgets/brand_kit_logo_image.dart';
import '../../shared/utils/brand_logo_tint.dart';

class BrandKitScreen extends StatefulWidget {
  const BrandKitScreen({super.key});

  @override
  State<BrandKitScreen> createState() => _BrandKitScreenState();
}

class _BrandKitScreenState extends State<BrandKitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _publicWebFormKey = GlobalKey<BrandKitPublicWebFormState>();
  bool _loading = true;
  bool _saving = false;
  late TextEditingController _appNameController;
  late TextEditingController _taglineController;
  late TextEditingController _primaryColorController;
  late TextEditingController _secondaryColorController;
  late TextEditingController _accentColorController;
  BrandKitModel _kit = const BrandKitModel();
  BrandKitPublicWeb _publicWebDraft = const BrandKitPublicWeb();
  List<String> _howItWorksMobileShots = List<String>.filled(5, '');
  List<String> _howItWorksWebShots = List<String>.filled(5, '');
  List<String> _heroSlides = List<String>.filled(5, '');
  final List<_OfferBarSlot> _offerBarSlots = List.generate(5, (_) => _OfferBarSlot());
  late TextEditingController _webLogoCustomHexController;
  /// Instant preview bytes while / after picking (before network image loads).
  final Map<String, Uint8List> _previewBytes = {};

  @override
  void initState() {
    super.initState();
    _appNameController = TextEditingController();
    _taglineController = TextEditingController();
    _primaryColorController = TextEditingController(text: '#0D47A1');
    _secondaryColorController = TextEditingController(text: '#00838F');
    _accentColorController = TextEditingController(text: '#4285F4');
    _webLogoCustomHexController = TextEditingController(text: '#F59E0B');
    _load();
  }

  Future<void> _load() async {
    if (!FirestoreService.isAvailable) {
      setState(() => _loading = false);
      return;
    }
    final kit = await BrandKitService.fetch();
    Map<String, dynamic>? runtimeData;
    try {
      final runtimeDoc = await FirestoreService.appRuntimeConfig().get();
      runtimeData = runtimeDoc.data();
    } catch (_) {}
    final mobile = _normalizeUrls(runtimeData?['howItWorksMobileScreenshots']);
    final web = _normalizeUrls(runtimeData?['howItWorksWebScreenshots']);
    setState(() {
      _kit = kit;
      _publicWebDraft = kit.publicWeb;
      _appNameController.text = kit.appName ?? 'D.G.Yard Connect';
      _taglineController.text = kit.tagline ?? 'Connect. Dispatch. Deliver.';
      _primaryColorController.text = kit.primaryColorHex ?? '#0D47A1';
      _secondaryColorController.text = kit.secondaryColorHex ?? '#00838F';
      _accentColorController.text = kit.accentColorHex ?? '#4285F4';
      _howItWorksMobileShots = List<String>.generate(5, (i) => i < mobile.length ? mobile[i] : '');
      _howItWorksWebShots = List<String>.generate(5, (i) => i < web.length ? web[i] : '');
      final heroSlides = kit.publicWeb.heroSlideUrls ?? const <String>[];
      _heroSlides = List<String>.generate(5, (i) => i < heroSlides.length ? heroSlides[i] : '');
      _loadOfferBarSlots(kit.publicWeb.topOfferBarItems);
      _webLogoCustomHexController.text = kit.publicWeb.webLogoCustomTintHex ?? '#F59E0B';
      _loading = false;
    });
  }

  List<String> _normalizeUrls(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _pickAndUpload(String assetKey, {String contentType = 'image/png'}) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (xfile == null || !mounted) return;
    final bytes = await xfile.readAsBytes();
    if (!mounted) return;
    await _uploadLogoBytes(assetKey, bytes, xfile.mimeType ?? contentType);
  }

  /// PNG, JPG, WebP or SVG for landscape / icon logos.
  Future<void> _pickLogoFile(String assetKey) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'svg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final ext = (file.extension ?? 'png').toLowerCase();
    final ct = switch (ext) {
      'svg' => 'image/svg+xml',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'image/png',
    };
    await _uploadLogoBytes(assetKey, bytes, ct);
  }

  Future<void> _uploadLogoBytes(String assetKey, Uint8List bytes, String contentType) async {
    if (!mounted) return;
    setState(() => _previewBytes[assetKey] = bytes);

    final url = await StorageService.uploadBrandAsset(
      assetKey: assetKey,
      bytes: bytes,
      contentType: contentType,
    );
    if (url == null) {
      if (mounted) {
        setState(() => _previewBytes.remove(assetKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
      return;
    }
    if (!mounted) return;
    try {
      await _updateField(assetKey, url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$assetKey uploaded & saved')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Upload OK but Firestore save failed. Check superadmin login, then try Save brand kit.',
            ),
          ),
        );
      }
    }
  }

  void _setWebLogoTint(BrandLogoTintMode mode, {String? customHex}) {
    final nextWeb = _publicWebDraft.copyWith(
      webLogoTintMode: mode.id,
      webLogoCustomTintHex: mode == BrandLogoTintMode.custom
          ? (customHex ?? _webLogoCustomHexController.text.trim())
          : _publicWebDraft.webLogoCustomTintHex,
    );
    setState(() {
      _publicWebDraft = nextWeb;
      _kit = _kit.copyWith(publicWeb: nextWeb);
    });
    _persistLogoTint(nextWeb);
  }

  Future<void> _persistLogoTint(BrandKitPublicWeb web) async {
    if (!FirestoreService.isAvailable) return;
    try {
      await FirestoreService.brandKit().set(
        {
          'publicWeb': {
            'webLogoTintMode': web.webLogoTintMode,
            if (web.webLogoCustomTintHex != null)
              'webLogoCustomTintHex': web.webLogoCustomTintHex,
          },
        },
        SetOptions(merge: true),
      );
      BrandKitService.cacheAndEmit(_kit.copyWith(publicWeb: web));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Color saved locally — click Save brand kit to sync fully.'),
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadHeroSlide(int index) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (xfile == null || !mounted) return;
    final bytes = await xfile.readAsBytes();
    final ct = xfile.mimeType ?? 'image/png';
    final previewKey = 'hero_slide_${index + 1}';
    if (!mounted) return;
    setState(() => _previewBytes[previewKey] = bytes);

    final url = await StorageService.uploadBrandAsset(
      assetKey: previewKey,
      bytes: bytes,
      contentType: ct,
    );
    if (url == null) {
      if (mounted) {
        setState(() => _previewBytes.remove(previewKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _previewBytes.remove(previewKey);
      _heroSlides[index] = url;
    });
    await _persistHeroSlides();
  }

  Future<void> _removeHeroSlide(int index) async {
    setState(() => _heroSlides[index] = '');
    await _persistHeroSlides();
  }

  List<String> _currentHeroSlideUrls() =>
      _heroSlides.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  void _loadOfferBarSlots(List<PublicWebOfferBarItem>? items) {
    final list = items ?? const <PublicWebOfferBarItem>[];
    for (var i = 0; i < _offerBarSlots.length; i++) {
      _offerBarSlots[i].load(i < list.length ? list[i] : null);
    }
  }

  List<PublicWebOfferBarItem> _currentOfferBarItems() =>
      _offerBarSlots.map((s) => s.toItem()).whereType<PublicWebOfferBarItem>().toList();

  Future<void> _pickAndUploadHeroCtaIcon({required bool android}) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (xfile == null || !mounted) return;
    final bytes = await xfile.readAsBytes();
    final ct = xfile.mimeType ?? 'image/png';
    final assetKey = android ? 'hero_cta1_android_icon' : 'hero_cta1_ios_icon';
    if (!mounted) return;
    setState(() => _previewBytes[assetKey] = bytes);

    final url = await StorageService.uploadBrandAsset(
      assetKey: assetKey,
      bytes: bytes,
      contentType: ct,
    );
    if (url == null) {
      if (mounted) {
        setState(() => _previewBytes.remove(assetKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
      return;
    }
    if (!mounted) return;

    final baseWeb = _publicWebFormKey.currentState?.value ?? _publicWebDraft;
    final nextWeb = baseWeb.copyWith(
      heroCta1AndroidIconUrl: android ? url : baseWeb.heroCta1AndroidIconUrl,
      heroCta1IosIconUrl: android ? baseWeb.heroCta1IosIconUrl : url,
    );
    final updatedKit = _kit.copyWith(publicWeb: nextWeb);
    setState(() {
      _previewBytes.remove(assetKey);
      _publicWebDraft = nextWeb;
      _kit = updatedKit;
    });
    try {
      await BrandKitService.save(updatedKit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${android ? 'Android' : 'iOS'} store icon saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Icon uploaded — click Save brand kit to sync.')),
        );
      }
    }
  }

  Future<void> _clearHeroCtaIcon({required bool android}) async {
    final baseWeb = _publicWebFormKey.currentState?.value ?? _publicWebDraft;
    final nextWeb = baseWeb.copyWith(
      heroCta1AndroidIconUrl: android ? '' : baseWeb.heroCta1AndroidIconUrl,
      heroCta1IosIconUrl: android ? baseWeb.heroCta1IosIconUrl : '',
    );
    final updatedKit = _kit.copyWith(publicWeb: nextWeb);
    setState(() {
      _publicWebDraft = nextWeb;
      _kit = updatedKit;
    });
    try {
      await BrandKitService.save(updatedKit);
    } catch (_) {}
  }

  Future<void> _persistHeroSlides() async {
    if (!FirestoreService.isAvailable) return;
    final urls = _currentHeroSlideUrls();
    final nextWeb = _publicWebDraft.copyWith(
      heroSlideUrls: urls.isEmpty ? null : urls,
    );
    final updatedKit = _kit.copyWith(publicWeb: nextWeb);
    setState(() {
      _publicWebDraft = nextWeb;
      _kit = updatedKit;
    });
    try {
      await BrandKitService.save(updatedKit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              urls.isEmpty
                  ? 'Hero slides cleared.'
                  : 'Hero slide saved — refresh homepage (/) to preview.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hero slide save failed — try Save brand kit.')),
        );
      }
    }
  }

  Future<void> _pickAndUploadWorkflowShot({
    required bool isMobile,
    required int index,
  }) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (xfile == null || !mounted) return;
    final bytes = await xfile.readAsBytes();
    final ct = xfile.mimeType ?? 'image/png';
    final keyPrefix = isMobile ? 'how_it_works_mobile' : 'how_it_works_web';
    final previewKey = '${keyPrefix}_${index + 1}';
    if (!mounted) return;
    setState(() => _previewBytes[previewKey] = bytes);

    final url = await StorageService.uploadBrandAsset(
      assetKey: previewKey,
      bytes: bytes,
      contentType: ct,
    );
    if (url == null) {
      if (mounted) {
        setState(() => _previewBytes.remove(previewKey));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _previewBytes.remove(previewKey);
      if (isMobile) {
        _howItWorksMobileShots[index] = url;
      } else {
        _howItWorksWebShots[index] = url;
      }
    });
    await FirestoreService.appRuntimeConfig().set({
      'howItWorksMobileScreenshots': _howItWorksMobileShots.where((e) => e.trim().isNotEmpty).toList(),
      'howItWorksWebScreenshots': _howItWorksWebShots.where((e) => e.trim().isNotEmpty).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeWorkflowShot({
    required bool isMobile,
    required int index,
  }) async {
    setState(() {
      if (isMobile) {
        _howItWorksMobileShots[index] = '';
      } else {
        _howItWorksWebShots[index] = '';
      }
    });
    await FirestoreService.appRuntimeConfig().set({
      'howItWorksMobileScreenshots': _howItWorksMobileShots.where((e) => e.trim().isNotEmpty).toList(),
      'howItWorksWebScreenshots': _howItWorksWebShots.where((e) => e.trim().isNotEmpty).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static const Map<String, String> _keyToField = {
    'appIcon512': 'appIcon512Url',
    'appIcon192': 'appIcon192Url',
    'favicon': 'faviconUrl',
    'logoWhite': 'logoWhiteUrl',
    'logoColor': 'logoColorUrl',
    'logoIcon': 'logoIconUrl',
    'animatedLogo': 'animatedLogoUrl',
    'animatedAppIcon': 'animatedAppIconUrl',
    'splashBackground': 'splashBackgroundUrl',
    'splashLogo': 'splashLogoUrl',
    'ogImage': 'ogImageUrl',
    'appleTouchIcon': 'appleTouchIconUrl',
  };

  Future<void> _updateField(String key, String value) async {
    final updated = _kitWithAssetUrl(key, value);
    final field = _keyToField[key] ?? '${key}Url';
    final patch = <String, dynamic>{field: value};
    if (key == 'appIcon512') patch['appIconUrl'] = value;

    await FirestoreService.brandKit().set(patch, SetOptions(merge: true));
    _kit = updated;
    BrandKitService.cacheAndEmit(_kit);
    if (mounted) setState(() {});
  }

  BrandKitModel _kitWithAssetUrl(String key, String value) {
    switch (key) {
      case 'appIcon512':
        return _kit.copyWith(appIcon512Url: value, appIconUrl: value);
      case 'appIcon192':
        return _kit.copyWith(appIcon192Url: value);
      case 'favicon':
        return _kit.copyWith(faviconUrl: value);
      case 'logoWhite':
        return _kit.copyWith(logoWhiteUrl: value);
      case 'logoColor':
        return _kit.copyWith(logoColorUrl: value);
      case 'logoIcon':
        return _kit.copyWith(logoIconUrl: value);
      case 'animatedLogo':
        return _kit.copyWith(animatedLogoUrl: value);
      case 'animatedAppIcon':
        return _kit.copyWith(animatedAppIconUrl: value);
      case 'splashBackground':
        return _kit.copyWith(splashBackgroundUrl: value);
      case 'splashLogo':
        return _kit.copyWith(splashLogoUrl: value);
      case 'ogImage':
        return _kit.copyWith(ogImageUrl: value);
      case 'appleTouchIcon':
        return _kit.copyWith(appleTouchIconUrl: value);
      default:
        return _kit;
    }
  }

  Future<void> _removeField(String key) async {
    final field = _keyToField[key] ?? '${key}Url';
    final map = _kit.toMap();
    map.remove(field);
    if (key == 'appIcon512') {
      map.remove('appIconUrl');
    }
    _kit = BrandKitModel.fromMap(map);
    await FirestoreService.brandKit().set({
      field: FieldValue.delete(),
      if (key == 'appIcon512') 'appIconUrl': FieldValue.delete(),
    }, SetOptions(merge: true));
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !FirestoreService.isAvailable) return;
    setState(() => _saving = true);
    try {
      final webDraft = _publicWebFormKey.currentState?.value ?? _publicWebDraft;
      final kit = BrandKitModel(
        appName: _appNameController.text.trim().isEmpty ? null : _appNameController.text.trim(),
        tagline: _taglineController.text.trim().isEmpty ? null : _taglineController.text.trim(),
        primaryColorHex: _primaryColorController.text.trim().isEmpty ? null : _primaryColorController.text.trim(),
        secondaryColorHex: _secondaryColorController.text.trim().isEmpty ? null : _secondaryColorController.text.trim(),
        accentColorHex: _accentColorController.text.trim().isEmpty ? null : _accentColorController.text.trim(),
        publicWeb: webDraft.copyWith(
          heroSlideUrls: _currentHeroSlideUrls().isEmpty ? null : _currentHeroSlideUrls(),
          topOfferBarItems: _currentOfferBarItems().isEmpty ? null : _currentOfferBarItems(),
        ),
        appIconUrl: _kit.appIconUrl,
        appIcon192Url: _kit.appIcon192Url,
        appIcon512Url: _kit.appIcon512Url,
        faviconUrl: _kit.faviconUrl,
        logoWhiteUrl: _kit.logoWhiteUrl,
        logoColorUrl: _kit.logoColorUrl,
        logoIconUrl: _kit.logoIconUrl,
        animatedLogoUrl: _kit.animatedLogoUrl,
        animatedAppIconUrl: _kit.animatedAppIconUrl,
        splashBackgroundUrl: _kit.splashBackgroundUrl,
        splashLogoUrl: _kit.splashLogoUrl,
        ogImageUrl: _kit.ogImageUrl,
        appleTouchIconUrl: _kit.appleTouchIconUrl,
      );
      await BrandKitService.save(kit);
      final fresh = await BrandKitService.fetch();
      if (mounted) {
        setState(() {
          _kit = fresh;
          _publicWebDraft = fresh.publicWeb;
          _loadOfferBarSlots(fresh.publicWeb.topOfferBarItems);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fresh.logoColorUrl != null || fresh.logoWhiteUrl != null
                  ? 'Brand kit saved. Logo URL is in Firestore — refresh homepage (/).'
                  : 'Brand kit saved. Upload Logo (colored) for the website navbar.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _urlFor(String key) {
    switch (key) {
      case 'appIcon':
      case 'appIcon512':
        return _kit.appIcon512Url ?? _kit.appIconUrl;
      case 'appIcon192':
        return _kit.appIcon192Url;
      case 'favicon':
        return _kit.faviconUrl;
      case 'logoWhite':
        return _kit.logoWhiteUrl;
      case 'logoColor':
        return _kit.logoColorUrl;
      case 'logoIcon':
        return _kit.logoIconUrl;
      case 'animatedLogo':
        return _kit.animatedLogoUrl;
      case 'animatedAppIcon':
        return _kit.animatedAppIconUrl;
      case 'splashBackground':
        return _kit.splashBackgroundUrl;
      case 'splashLogo':
        return _kit.splashLogoUrl;
      case 'ogImage':
        return _kit.ogImageUrl;
      case 'appleTouchIcon':
        return _kit.appleTouchIconUrl;
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _taglineController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _accentColorController.dispose();
    _webLogoCustomHexController.dispose();
    for (final slot in _offerBarSlots) {
      slot.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand Kit'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'App identity & colors',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate().fadeIn(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _appNameController,
                      decoration: const InputDecoration(
                        labelText: 'App name',
                        helperText: 'Used app-wide. Navbar uses Public website → Company short name if set.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taglineController,
                      decoration: const InputDecoration(
                        labelText: 'Tagline',
                        helperText: 'Fallback only if Public website → Hero headline is empty.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _primaryColorController,
                      decoration: const InputDecoration(labelText: 'Primary color (hex, e.g. #0D47A1)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _secondaryColorController,
                      decoration: const InputDecoration(labelText: 'Secondary color (hex)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accentColorController,
                      decoration: const InputDecoration(labelText: 'Accent color (hex)'),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Icons & logos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 16),
                    _AssetTile(
                      label: 'App icon (512×512)',
                      hint: 'PWA, Android, launcher icon',
                      url: _urlFor('appIcon'),
                      previewBytes: _previewBytes['appIcon512'],
                      onUpload: () => _pickAndUpload('appIcon512'),
                    ),
                    if (_urlFor('appIcon') != null) _AppLauncherSyncTile(url: _urlFor('appIcon')!),
                    _AssetTile(
                      label: 'App icon (192×192)',
                      hint: 'PWA, medium size',
                      url: _urlFor('appIcon192'),
                      previewBytes: _previewBytes['appIcon192'],
                      onUpload: () => _pickAndUpload('appIcon192'),
                    ),
                    _AssetTile(
                      label: 'Favicon (32×32)',
                      hint: 'Browser tab icon',
                      url: _urlFor('favicon'),
                      previewBytes: _previewBytes['favicon'],
                      onUpload: () => _pickAndUpload('favicon'),
                    ),
                    _AssetTile(
                      label: 'Apple touch icon (180×180)',
                      hint: 'iOS home screen',
                      url: _urlFor('appleTouchIcon'),
                      previewBytes: _previewBytes['appleTouchIcon'],
                      onUpload: () => _pickAndUpload('appleTouchIcon'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Logos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 16),
                    _AssetTile(
                      label: 'Logo (white)',
                      hint: 'For dark backgrounds',
                      url: _urlFor('logoWhite'),
                      previewBytes: _previewBytes['logoWhite'],
                      onUpload: () => _pickAndUpload('logoWhite'),
                    ),
                    _AssetTile(
                      label: 'Logo (colored)',
                      hint: 'Landscape logo for website navbar — PNG or SVG recommended',
                      url: _urlFor('logoColor'),
                      previewBytes: _previewBytes['logoColor'],
                      previewTint: BrandLogoTint.resolveTint(
                        _kit.copyWith(publicWeb: _publicWebDraft),
                      ),
                      onUpload: () => _pickLogoFile('logoColor'),
                    ),
                    _WebsiteLogoTintPicker(
                      kit: _kit.copyWith(publicWeb: _publicWebDraft),
                      primaryHex: _primaryColorController.text.trim(),
                      secondaryHex: _secondaryColorController.text.trim(),
                      accentHex: _accentColorController.text.trim(),
                      logoUrl: _urlFor('logoColor'),
                      onModeChanged: _setWebLogoTint,
                      customHex: _webLogoCustomHexController.text,
                      customHexController: _webLogoCustomHexController,
                      onCustomHexChanged: (hex) => _setWebLogoTint(
                        BrandLogoTintMode.custom,
                        customHex: hex,
                      ),
                    ),
                    _AssetTile(
                      label: 'Logo icon (square)',
                      hint: 'Icon-only, square — PNG or SVG',
                      url: _urlFor('logoIcon'),
                      previewBytes: _previewBytes['logoIcon'],
                      onUpload: () => _pickLogoFile('logoIcon'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Animated assets',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 16),
                    _AssetTile(
                      label: 'Animated logo (GIF)',
                      hint: 'Loading, splash',
                      url: _urlFor('animatedLogo'),
                      previewBytes: _previewBytes['animatedLogo'],
                      onUpload: () => _pickAndUpload('animatedLogo', contentType: 'image/gif'),
                    ),
                    _AssetTile(
                      label: 'Animated app icon (GIF)',
                      hint: 'Splash animation',
                      url: _urlFor('animatedAppIcon'),
                      previewBytes: _previewBytes['animatedAppIcon'],
                      onUpload: () => _pickAndUpload('animatedAppIcon', contentType: 'image/gif'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Splash & social',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate().fadeIn(delay: 400.ms),
                    const SizedBox(height: 16),
                    _AssetTile(
                      label: 'Splash background',
                      hint: 'Intro screen background. Recommended 1080x1920 (9:16), JPG/PNG, max 2 MB.',
                      url: _urlFor('splashBackground'),
                      previewBytes: _previewBytes['splashBackground'],
                      onUpload: () => _pickAndUpload('splashBackground'),
                      onClear: _urlFor('splashBackground') == null
                          ? null
                          : () => _removeField('splashBackground'),
                    ),
                    _AssetTile(
                      label: 'Splash logo',
                      hint: 'Logo on splash screen',
                      url: _urlFor('splashLogo'),
                      previewBytes: _previewBytes['splashLogo'],
                      onUpload: () => _pickAndUpload('splashLogo'),
                    ),
                    _AssetTile(
                      label: 'OG image (1200×630)',
                      hint: 'Social sharing preview',
                      url: _urlFor('ogImage'),
                      previewBytes: _previewBytes['ogImage'],
                      onUpload: () => _pickAndUpload('ogImage'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Top offer bar (below navbar)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate().fadeIn(delay: 410.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Apple-style rotating promo lines on the homepage — directly under the navbar. '
                      'Add up to 5 offers. Leave text empty to hide a slot.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      5,
                      (index) => _OfferBarSlotEditor(
                        index: index,
                        slot: _offerBarSlots[index],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Homepage hero carousel',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate().fadeIn(delay: 420.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Upload up to 5 landscape images. They auto-slide in the homepage hero section (right side on desktop).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      5,
                      (index) => _AssetTile(
                        label: 'Hero slide ${index + 1}',
                        hint: 'Recommended 1200×800 or wider — PNG/JPG/WebP',
                        url: _heroSlides[index].isEmpty ? null : _heroSlides[index],
                        previewBytes: _previewBytes['hero_slide_${index + 1}'],
                        onUpload: () => _pickAndUploadHeroSlide(index),
                        onClear: _heroSlides[index].isEmpty
                            ? null
                            : () => _removeHeroSlide(index),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'How It Works screenshots (Web landing)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate().fadeIn(delay: 450.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Upload up to 5 mobile and 5 web screenshots. These appear in the "How It Works" section on the web landing page.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text('Mobile screenshots (5)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...List.generate(
                      5,
                      (index) => _AssetTile(
                        label: 'Mobile screen ${index + 1}',
                        hint: 'Recommended portrait screenshot',
                        url: _howItWorksMobileShots[index].isEmpty ? null : _howItWorksMobileShots[index],
                        previewBytes: _previewBytes['how_it_works_mobile_${index + 1}'],
                        onUpload: () => _pickAndUploadWorkflowShot(isMobile: true, index: index),
                        onClear: _howItWorksMobileShots[index].isEmpty
                            ? null
                            : () => _removeWorkflowShot(isMobile: true, index: index),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Web screenshots (5)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...List.generate(
                      5,
                      (index) => _AssetTile(
                        label: 'Web screen ${index + 1}',
                        hint: 'Recommended landscape screenshot',
                        url: _howItWorksWebShots[index].isEmpty ? null : _howItWorksWebShots[index],
                        previewBytes: _previewBytes['how_it_works_web_${index + 1}'],
                        onUpload: () => _pickAndUploadWorkflowShot(isMobile: false, index: index),
                        onClear: _howItWorksWebShots[index].isEmpty
                            ? null
                            : () => _removeWorkflowShot(isMobile: false, index: index),
                      ),
                    ),
                    const SizedBox(height: 24),
                    BrandKitPublicWebForm(
                      key: _publicWebFormKey,
                      initial: _publicWebDraft,
                      heroCta1AndroidIconUrl: _publicWebDraft.heroCta1AndroidIconUrl,
                      heroCta1IosIconUrl: _publicWebDraft.heroCta1IosIconUrl,
                      onUploadCta1AndroidIcon: () => _pickAndUploadHeroCtaIcon(android: true),
                      onUploadCta1IosIcon: () => _pickAndUploadHeroCtaIcon(android: false),
                      onClearCta1AndroidIcon: _publicWebDraft.heroCta1AndroidIconUrl?.trim().isNotEmpty == true
                          ? () => _clearHeroCtaIcon(android: true)
                          : null,
                      onClearCta1IosIcon: _publicWebDraft.heroCta1IosIconUrl?.trim().isNotEmpty == true
                          ? () => _clearHeroCtaIcon(android: false)
                          : null,
                      onChanged: (web) {
                        if (_publicWebDraft == web) return;
                        setState(() => _publicWebDraft = web.copyWith(
                          webLogoTintMode: _publicWebDraft.webLogoTintMode,
                          webLogoCustomTintHex: _publicWebDraft.webLogoCustomTintHex,
                          heroSlideUrls: _currentHeroSlideUrls().isEmpty
                              ? null
                              : _currentHeroSlideUrls(),
                          topOfferBarItems: _currentOfferBarItems().isEmpty
                              ? null
                              : _currentOfferBarItems(),
                          heroCta1AndroidIconUrl: _publicWebDraft.heroCta1AndroidIconUrl,
                          heroCta1IosIconUrl: _publicWebDraft.heroCta1IosIconUrl,
                        ));
                      },
                    ),
                    const SizedBox(height: 24),
                    _FreeToolsNote(),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: AppColors.primary,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save brand kit'),
                    ).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _AppLauncherSyncTile extends StatelessWidget {
  const _AppLauncherSyncTile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final cmd = "dart run scripts/sync_app_icon.dart '$url'";
    return Card(
      color: AppColors.primary.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone_android, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Update app launcher icon',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'To update app icon: paste the URL into scripts/app_icon_url.txt (one line), then run:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText('dart run scripts/sync_app_icon.dart', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            const SizedBox(height: 4),
            Text('Or copy URL and run with single quotes:', style: Theme.of(context).textTheme.bodySmall),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(cmd, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copied — paste into scripts/app_icon_url.txt')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy URL'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'dart run scripts/sync_app_icon.dart'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Command copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy command'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.label,
    required this.hint,
    required this.url,
    required this.onUpload,
    this.previewBytes,
    this.previewTint,
    this.onClear,
  });

  final String label;
  final String hint;
  final String? url;
  final Uint8List? previewBytes;
  final Color? previewTint;
  final VoidCallback onUpload;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _BrandKitAssetPreview(url: url, bytes: previewBytes, tintColor: previewTint),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(hint, style: Theme.of(context).textTheme.bodySmall),
                  if (url != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Saved to storage',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.green.shade700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                FilledButton.tonal(
                  onPressed: onUpload,
                  child: Text(url == null && previewBytes == null ? 'Upload' : 'Replace'),
                ),
                if (onClear != null) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Preview for brand kit uploads — PNG, SVG (with tint), or memory bytes.
class _BrandKitAssetPreview extends StatelessWidget {
  const _BrandKitAssetPreview({
    this.url,
    this.bytes,
    this.tintColor,
  });

  static const double _size = 72;

  final String? url;
  final Uint8List? bytes;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (bytes != null) {
      return Image.memory(
        bytes!,
        fit: BoxFit.contain,
        width: _size,
        height: _size,
        gaplessPlayback: true,
      );
    }

    if (url != null && url!.trim().isNotEmpty) {
      return BrandKitLogoImage(
        url: url!,
        fit: BoxFit.contain,
        width: _size,
        height: _size,
        tintColor: tintColor,
        errorWidget: Icon(Icons.broken_image, color: Colors.grey[500]),
      );
    }

    return Icon(Icons.add_photo_alternate, color: Colors.grey[500], size: 28);
  }
}

/// Website navbar logo color — especially useful for SVG single-color logos.
class _WebsiteLogoTintPicker extends StatelessWidget {
  const _WebsiteLogoTintPicker({
    required this.kit,
    required this.primaryHex,
    required this.secondaryHex,
    required this.accentHex,
    required this.logoUrl,
    required this.onModeChanged,
    required this.customHex,
    required this.customHexController,
    required this.onCustomHexChanged,
  });

  final BrandKitModel kit;
  final String primaryHex;
  final String secondaryHex;
  final String accentHex;
  final String? logoUrl;
  final ValueChanged<BrandLogoTintMode> onModeChanged;
  final String customHex;
  final TextEditingController customHexController;
  final ValueChanged<String> onCustomHexChanged;

  Color _hex(String hex, Color fallback) {
    final h = hex.replaceFirst('#', '').trim();
    if (h.length != 6) return fallback;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return fallback;
    return Color(v | 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    if (logoUrl == null || logoUrl!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = BrandLogoTintMode.fromId(kit.publicWeb.webLogoTintMode);
    final isSvg = BrandLogoTint.isSvgUrl(logoUrl);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Website logo color',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (isSvg) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: const Text('SVG', style: TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isSvg
                  ? 'Choose which brand color to apply to your SVG logo on the public website navbar.'
                  : 'Tint the navbar logo on the public website (best with single-color or SVG logos).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _TintChip(
                  label: BrandLogoTintMode.original.label,
                  selected: selected == BrandLogoTintMode.original,
                  swatch: null,
                  onTap: () => onModeChanged(BrandLogoTintMode.original),
                ),
                _TintChip(
                  label: 'Primary',
                  selected: selected == BrandLogoTintMode.primary,
                  swatch: _hex(primaryHex, const Color(0xFF0D47A1)),
                  onTap: () => onModeChanged(BrandLogoTintMode.primary),
                ),
                _TintChip(
                  label: 'Secondary',
                  selected: selected == BrandLogoTintMode.secondary,
                  swatch: _hex(secondaryHex, const Color(0xFF00838F)),
                  onTap: () => onModeChanged(BrandLogoTintMode.secondary),
                ),
                _TintChip(
                  label: 'Accent',
                  selected: selected == BrandLogoTintMode.accent,
                  swatch: _hex(accentHex, const Color(0xFFF59E0B)),
                  onTap: () => onModeChanged(BrandLogoTintMode.accent),
                ),
                _TintChip(
                  label: 'White',
                  selected: selected == BrandLogoTintMode.white,
                  swatch: Colors.white,
                  border: true,
                  onTap: () => onModeChanged(BrandLogoTintMode.white),
                ),
                _TintChip(
                  label: 'Black',
                  selected: selected == BrandLogoTintMode.black,
                  swatch: const Color(0xFF0F172A),
                  onTap: () => onModeChanged(BrandLogoTintMode.black),
                ),
                _TintChip(
                  label: 'Custom',
                  selected: selected == BrandLogoTintMode.custom,
                  swatch: _hex(customHex, const Color(0xFFF59E0B)),
                  onTap: () => onModeChanged(BrandLogoTintMode.custom),
                ),
              ],
            ),
            if (selected == BrandLogoTintMode.custom) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Custom logo color (hex)',
                  hintText: '#F59E0B',
                  isDense: true,
                ),
                controller: customHexController,
                onChanged: onCustomHexChanged,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Color applies instantly on the website after you pick a swatch.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green.shade700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TintChip extends StatelessWidget {
  const _TintChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.swatch,
    this.border = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatch;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey[100],
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey[300]!,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (swatch != null)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: border ? Border.all(color: Colors.grey[400]!) : null,
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.primary : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeToolsNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final links = [
      ('FaviconGenerator.io', 'https://favicongenerator.io/', 'Favicon, app icons, PWA icons from image/text'),
      ('LogoFast.app', 'https://logofast.app/', 'Free logo, favicon & OG image generator'),
      ('AppIconGenerator.org', 'https://www.appicongenerator.org/', 'iOS, Android, Web icons in all sizes'),
      ('iLoveSVG', 'https://www.ilovesvg.com/svg-to-favicon-generator', 'SVG/PNG to favicon & app icons'),
    ];
    return Card(
      color: AppColors.primary.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Free tools to create & convert logos',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You can create logos in multiple sizes, colors and formats for free using these websites. Upload your logo or create one, then export favicon, app icons, PNG, SVG, ICO, GIF as needed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...links.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Link(
                    uri: Uri.parse(e.$2),
                    target: LinkTarget.blank,
                    builder: (context, followLink) => InkWell(
                      onTap: followLink,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.link, size: 16, color: AppColors.googleBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.$1,
                                    style: TextStyle(
                                      color: AppColors.googleBlue,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  Text(e.$3, style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _OfferBarSlot {
  final text = TextEditingController();
  final linkUrl = TextEditingController();
  final linkLabel = TextEditingController();

  void load(PublicWebOfferBarItem? item) {
    text.text = item?.text ?? '';
    linkUrl.text = item?.linkUrl ?? '';
    linkLabel.text = item?.linkLabel ?? '';
  }

  PublicWebOfferBarItem? toItem() {
    final message = text.text.trim();
    if (message.isEmpty) return null;
    final url = linkUrl.text.trim();
    final label = linkLabel.text.trim();
    return PublicWebOfferBarItem(
      text: message,
      linkUrl: url.isEmpty ? null : url,
      linkLabel: label.isEmpty ? null : label,
    );
  }

  void dispose() {
    text.dispose();
    linkUrl.dispose();
    linkLabel.dispose();
  }
}

class _OfferBarSlotEditor extends StatelessWidget {
  const _OfferBarSlotEditor({
    required this.index,
    required this.slot,
  });

  final int index;
  final _OfferBarSlot slot;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Offer ${index + 1}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: slot.text,
              decoration: const InputDecoration(
                labelText: 'Offer text',
                hintText: 'e.g. Get up to 20% off CCTV cameras this week.',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: slot.linkUrl,
              decoration: const InputDecoration(
                labelText: 'Link URL (optional)',
                hintText: '/store or https://…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: slot.linkLabel,
              decoration: const InputDecoration(
                labelText: 'Link label (optional)',
                hintText: 'Shop',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
