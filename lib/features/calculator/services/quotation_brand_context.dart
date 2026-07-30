import 'package:flutter/widgets.dart';

import '../../../shared/models/brand_kit_model.dart';
import '../../../shared/services/brand_kit_service.dart';
import '../../../shared/widgets/brand_kit_provider.dart';

/// Brand kit fields used on quotation PDF letterhead.
class QuotationBrandContext {
  const QuotationBrandContext({
    required this.companyName,
    required this.address,
    required this.phone,
    required this.email,
    required this.website,
    required this.tagline,
    required this.logoUrls,
    this.primaryColorHex,
    this.accentColorHex,
  });

  final String companyName;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String tagline;
  final List<String> logoUrls;
  final String? primaryColorHex;
  final String? accentColorHex;

  static QuotationBrandContext? _cache;
  static Future<QuotationBrandContext>? _inflight;

  static QuotationBrandContext get defaults => const QuotationBrandContext(
        companyName: 'D.G.Yard Connect',
        address: 'Piska More, Ratu Road, Ranchi - 834005, Jharkhand, India',
        phone: '+91 82989 55009',
        email: 'info@dgyard.com',
        website: 'dgyard.com',
        tagline: 'Digital | Secure | Smart Living',
        logoUrls: [],
      );

  /// Cached resolve — first call may hit Firestore; later calls are instant.
  static Future<QuotationBrandContext> resolve([BuildContext? context]) {
    if (_cache != null) return Future.value(_cache);
    return _inflight ??= _resolve(context).then((b) {
      _cache = b;
      return b;
    });
  }

  /// Instant brand for PDF: cache / provider / defaults. Refreshes Firestore in background.
  static QuotationBrandContext resolveFast([BuildContext? context]) {
    if (_cache != null) {
      // Keep cache fresh without blocking PDF.
      _inflight ??= _resolve(context).then((b) {
        _cache = b;
        return b;
      });
      return _cache!;
    }

    BrandKitModel kit = const BrandKitModel();
    if (context != null) {
      try {
        kit = BrandKitProvider.of(context);
      } catch (_) {}
    }
    final quick = _fromKit(kit);
    _inflight ??= _resolve(context).then((b) {
      _cache = b;
      return b;
    });
    return quick;
  }

  static Future<QuotationBrandContext> _resolve(BuildContext? context) async {
    BrandKitModel kit = const BrandKitModel();
    if (context != null) {
      try {
        kit = BrandKitProvider.of(context);
      } catch (_) {}
    }

    try {
      final fetched = await BrandKitService.fetch().timeout(const Duration(seconds: 3));
      kit = _merge(kit, fetched);
    } catch (_) {}

    return _fromKit(kit);
  }

  static QuotationBrandContext _fromKit(BrandKitModel kit) {
    String text(String? v, String fallback) {
      final t = v?.trim() ?? '';
      return t.isNotEmpty ? t : fallback;
    }

    String website(String? raw) {
      var w = (raw ?? '').trim();
      if (w.isEmpty || w == '#') return 'dgyard.com';
      w = w.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
      if (w.endsWith('/')) w = w.substring(0, w.length - 1);
      return w;
    }

    final logos = <String?>[
      kit.logoColorUrl,
      kit.logoWhiteUrl,
      kit.logoIconUrl,
      kit.splashLogoUrl,
      kit.appIcon512Url,
      kit.appIcon192Url,
      kit.faviconUrl,
    ].whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return QuotationBrandContext(
      companyName: text(kit.appName, defaults.companyName),
      address: text(kit.publicWeb.contactAddress, defaults.address),
      phone: text(kit.publicWeb.contactPhone, defaults.phone),
      email: text(kit.publicWeb.contactEmail, defaults.email),
      website: website(kit.publicWeb.socialWebsiteUrl),
      tagline: text(kit.tagline, defaults.tagline),
      logoUrls: logos,
      primaryColorHex: kit.primaryColorHex,
      accentColorHex: kit.accentColorHex,
    );
  }

  static BrandKitModel _merge(BrandKitModel a, BrandKitModel b) {
    if (_isEmpty(a) && !_isEmpty(b)) return b;
    if (_isEmpty(b)) return a;
    return BrandKitModel(
      appName: a.appName ?? b.appName,
      tagline: a.tagline ?? b.tagline,
      primaryColorHex: a.primaryColorHex ?? b.primaryColorHex,
      secondaryColorHex: a.secondaryColorHex ?? b.secondaryColorHex,
      accentColorHex: a.accentColorHex ?? b.accentColorHex,
      publicWeb: a.publicWeb.contactAddress != null ? a.publicWeb : b.publicWeb,
      logoColorUrl: a.logoColorUrl ?? b.logoColorUrl,
      logoWhiteUrl: a.logoWhiteUrl ?? b.logoWhiteUrl,
      logoIconUrl: a.logoIconUrl ?? b.logoIconUrl,
      splashLogoUrl: a.splashLogoUrl ?? b.splashLogoUrl,
      appIcon512Url: a.appIcon512Url ?? b.appIcon512Url,
      appIcon192Url: a.appIcon192Url ?? b.appIcon192Url,
      faviconUrl: a.faviconUrl ?? b.faviconUrl,
    );
  }

  static bool _isEmpty(BrandKitModel k) =>
      (k.logoColorUrl ?? '').isEmpty &&
      (k.logoWhiteUrl ?? '').isEmpty &&
      (k.appName ?? '').isEmpty;
}
