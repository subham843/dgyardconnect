import 'package:flutter/material.dart';
import '../../../shared/models/brand_kit_public_web.dart';
import '../../../shared/models/hero_accent_config.dart';

class BrandKitPublicWebForm extends StatefulWidget {
  const BrandKitPublicWebForm({
    super.key,
    required this.initial,
    required this.onChanged,
    this.heroCta1AndroidIconUrl,
    this.heroCta1IosIconUrl,
    this.onUploadCta1AndroidIcon,
    this.onUploadCta1IosIcon,
    this.onClearCta1AndroidIcon,
    this.onClearCta1IosIcon,
  });

  final BrandKitPublicWeb initial;
  final ValueChanged<BrandKitPublicWeb> onChanged;
  final String? heroCta1AndroidIconUrl;
  final String? heroCta1IosIconUrl;
  final VoidCallback? onUploadCta1AndroidIcon;
  final VoidCallback? onUploadCta1IosIcon;
  final VoidCallback? onClearCta1AndroidIcon;
  final VoidCallback? onClearCta1IosIcon;

  @override
  State<BrandKitPublicWebForm> createState() => BrandKitPublicWebFormState();
}

class BrandKitPublicWebFormState extends State<BrandKitPublicWebForm> {
  late final Map<String, TextEditingController> _c;
  late HeroAccentAnimation _accentAnimation;
  late HeroAccentFontFamily _accentFontFamily;
  late HeroAccentFontWeight _accentFontWeight;
  late String _accentFontStyle;

  @override
  void initState() {
    super.initState();
    _accentAnimation = HeroAccentAnimation.fromId(widget.initial.heroAccentAnimation);
    _accentFontFamily = HeroAccentFontFamily.fromId(widget.initial.heroAccentFontFamily);
    _accentFontWeight = HeroAccentFontWeight.fromId(widget.initial.heroAccentFontWeight);
    _accentFontStyle = widget.initial.heroAccentFontStyle ?? 'normal';
    _c = {
      'companyShortName': TextEditingController(text: widget.initial.companyShortName ?? ''),
      'heroBadgeText': TextEditingController(text: widget.initial.heroBadgeText ?? ''),
      'heroHeadline': TextEditingController(text: widget.initial.heroHeadline ?? ''),
      'heroAccentWord': TextEditingController(text: widget.initial.heroAccentWord ?? ''),
      'heroAccentColorHex': TextEditingController(text: widget.initial.heroAccentColorHex ?? '#FF7A00'),
      'heroSubheadline': TextEditingController(text: widget.initial.heroSubheadline ?? ''),
      'heroDescription': TextEditingController(text: widget.initial.heroDescription ?? ''),
      'heroCta1Label': TextEditingController(text: widget.initial.heroCta1Label ?? ''),
      'heroCta1Url': TextEditingController(text: widget.initial.heroCta1Url ?? ''),
      'heroCta1AndroidUrl': TextEditingController(text: widget.initial.heroCta1AndroidUrl ?? ''),
      'heroCta1IosUrl': TextEditingController(text: widget.initial.heroCta1IosUrl ?? ''),
      'heroCta1AndroidLabel': TextEditingController(text: widget.initial.heroCta1AndroidLabel ?? ''),
      'heroCta1IosLabel': TextEditingController(text: widget.initial.heroCta1IosLabel ?? ''),
      'heroCta2Label': TextEditingController(text: widget.initial.heroCta2Label ?? ''),
      'heroCta2Url': TextEditingController(text: widget.initial.heroCta2Url ?? ''),
      'heroCta3Label': TextEditingController(text: widget.initial.heroCta3Label ?? ''),
      'heroCta3Url': TextEditingController(text: widget.initial.heroCta3Url ?? ''),
      'footerDescription': TextEditingController(text: widget.initial.footerDescription ?? ''),
      'contactEmail': TextEditingController(text: widget.initial.contactEmail ?? ''),
      'contactPhone': TextEditingController(text: widget.initial.contactPhone ?? ''),
      'contactAddress': TextEditingController(text: widget.initial.contactAddress ?? ''),
      'socialFacebookUrl': TextEditingController(text: widget.initial.socialFacebookUrl ?? ''),
      'socialInstagramUrl': TextEditingController(text: widget.initial.socialInstagramUrl ?? ''),
      'socialLinkedinUrl': TextEditingController(text: widget.initial.socialLinkedinUrl ?? ''),
      'socialTwitterUrl': TextEditingController(text: widget.initial.socialTwitterUrl ?? ''),
      'socialYoutubeUrl': TextEditingController(text: widget.initial.socialYoutubeUrl ?? ''),
      'socialWebsiteUrl': TextEditingController(text: widget.initial.socialWebsiteUrl ?? ''),
      'appDownloadTitle': TextEditingController(text: widget.initial.appDownloadTitle ?? ''),
      'appDownloadDescription': TextEditingController(text: widget.initial.appDownloadDescription ?? ''),
      'playStoreUrl': TextEditingController(text: widget.initial.playStoreUrl ?? ''),
      'appStoreUrl': TextEditingController(text: widget.initial.appStoreUrl ?? ''),
      'appStoreLabel': TextEditingController(text: widget.initial.appStoreLabel ?? ''),
      'statProducts': TextEditingController(text: widget.initial.statProducts ?? ''),
      'statBrands': TextEditingController(text: widget.initial.statBrands ?? ''),
      'statDealers': TextEditingController(text: widget.initial.statDealers ?? ''),
      'statTechnicians': TextEditingController(text: widget.initial.statTechnicians ?? ''),
      'statDeals': TextEditingController(text: widget.initial.statDeals ?? ''),
      'statProjects': TextEditingController(text: widget.initial.statProjects ?? ''),
      'darkBackgroundColorHex': TextEditingController(text: widget.initial.darkBackgroundColorHex ?? ''),
      'lightBackgroundColorHex': TextEditingController(text: widget.initial.lightBackgroundColorHex ?? ''),
    };
    for (final controller in _c.values) {
      controller.addListener(_notify);
    }
  }

  void _notify() {
    // Defer parent update — initState/listeners must not call setState during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged(value);
    });
  }

  BrandKitPublicWeb get value {
    String? t(String key) {
      final v = _c[key]!.text.trim();
      return v.isEmpty ? null : v;
    }

    return BrandKitPublicWeb(
      companyShortName: t('companyShortName'),
      heroBadgeText: t('heroBadgeText'),
      heroHeadline: t('heroHeadline'),
      heroSubheadline: t('heroSubheadline'),
      heroDescription: t('heroDescription'),
      heroCta1Label: t('heroCta1Label'),
      heroCta1Url: t('heroCta1Url'),
      heroCta1AndroidUrl: t('heroCta1AndroidUrl'),
      heroCta1IosUrl: t('heroCta1IosUrl'),
      heroCta1AndroidLabel: t('heroCta1AndroidLabel'),
      heroCta1IosLabel: t('heroCta1IosLabel'),
      heroCta1AndroidIconUrl: widget.heroCta1AndroidIconUrl?.trim().isNotEmpty == true
          ? widget.heroCta1AndroidIconUrl!.trim()
          : widget.initial.heroCta1AndroidIconUrl,
      heroCta1IosIconUrl: widget.heroCta1IosIconUrl?.trim().isNotEmpty == true
          ? widget.heroCta1IosIconUrl!.trim()
          : widget.initial.heroCta1IosIconUrl,
      heroCta2Label: t('heroCta2Label'),
      heroCta2Url: t('heroCta2Url'),
      heroCta3Label: t('heroCta3Label'),
      heroCta3Url: t('heroCta3Url'),
      footerDescription: t('footerDescription'),
      contactEmail: t('contactEmail'),
      contactPhone: t('contactPhone'),
      contactAddress: t('contactAddress'),
      socialFacebookUrl: t('socialFacebookUrl'),
      socialInstagramUrl: t('socialInstagramUrl'),
      socialLinkedinUrl: t('socialLinkedinUrl'),
      socialTwitterUrl: t('socialTwitterUrl'),
      socialYoutubeUrl: t('socialYoutubeUrl'),
      socialWebsiteUrl: t('socialWebsiteUrl'),
      appDownloadTitle: t('appDownloadTitle'),
      appDownloadDescription: t('appDownloadDescription'),
      playStoreUrl: t('playStoreUrl'),
      appStoreUrl: t('appStoreUrl'),
      appStoreLabel: t('appStoreLabel'),
      statProducts: t('statProducts'),
      statBrands: t('statBrands'),
      statDealers: t('statDealers'),
      statTechnicians: t('statTechnicians'),
      statDeals: t('statDeals'),
      statProjects: t('statProjects'),
      darkBackgroundColorHex: t('darkBackgroundColorHex'),
      lightBackgroundColorHex: t('lightBackgroundColorHex'),
      heroAccentWord: t('heroAccentWord'),
      heroAccentColorHex: t('heroAccentColorHex'),
      heroAccentFontWeight: _accentFontWeight.name,
      heroAccentFontStyle: _accentFontStyle,
      heroAccentFontFamily: _accentFontFamily.name,
      heroAccentAnimation: _accentAnimation.name,
    );
  }

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Public website', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Controls navbar, hero, footer, trust stats, app download and theme backgrounds on the public website. '
          'These fields override App name and Tagline on the homepage.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _field('companyShortName', 'Company short name (navbar text)'),
        const Divider(height: 24),
        Text('Hero', style: Theme.of(context).textTheme.titleMedium),
        _field('heroBadgeText', 'Hero badge text'),
        _field(
          'heroHeadline',
          'Hero headline',
          helper: 'Full line e.g. "Digital Smart Secure". Accent word is styled separately below.',
        ),
        const SizedBox(height: 4),
        Text('Hero accent word (animated)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _field(
          'heroAccentWord',
          'Accent word',
          helper: 'Last word to animate. Leave empty to auto-use the last word of the headline.',
        ),
        _field(
          'heroAccentColorHex',
          'Accent color (hex)',
          helper: 'e.g. #FF7A00 (Saffron) or #1D4ED8 (blue)',
        ),
        _dropdown<HeroAccentFontWeight>(
          label: 'Accent font weight',
          value: _accentFontWeight,
          items: HeroAccentFontWeight.values,
          itemLabel: (v) => v.label,
          onChanged: (v) => setState(() {
            _accentFontWeight = v;
            _notify();
          }),
        ),
        _dropdown<String>(
          label: 'Accent font style',
          value: _accentFontStyle,
          items: const ['normal', 'italic'],
          itemLabel: (v) => v == 'italic' ? 'Italic' : 'Normal',
          onChanged: (v) => setState(() {
            _accentFontStyle = v;
            _notify();
          }),
        ),
        _dropdown<HeroAccentFontFamily>(
          label: 'Accent font family',
          value: _accentFontFamily,
          items: HeroAccentFontFamily.values,
          itemLabel: (v) => v.label,
          onChanged: (v) => setState(() {
            _accentFontFamily = v;
            _notify();
          }),
        ),
        _dropdown<HeroAccentAnimation>(
          label: 'Accent animation',
          value: _accentAnimation,
          items: HeroAccentAnimation.values,
          itemLabel: (v) => v.label,
          onChanged: (v) => setState(() {
            _accentAnimation = v;
            _notify();
          }),
        ),
        _field('heroSubheadline', 'Hero subheadline'),
        _field('heroDescription', 'Hero description'),
        _field(
          'heroCta1Label',
          'CTA 1 label (beside store icons)',
          helper: 'Shown next to Android/iOS icon buttons when icons or store URLs are set below.',
        ),
        const SizedBox(height: 4),
        Text('CTA 1 — App store icon buttons', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Upload full-width store badge images (Google Play / App Store). Click the Download button on the homepage — badges open in a panel below.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _field(
          'heroCta1AndroidUrl',
          'Android / Google Play URL (optional)',
          helper: 'Leave empty to show icon only — no link until you add a URL.',
        ),
        _field('heroCta1AndroidLabel', 'Android option label', helper: 'e.g. Get it on Google Play'),
        _cta1IconRow(
          label: 'Android store badge',
          iconUrl: widget.heroCta1AndroidIconUrl ?? widget.initial.heroCta1AndroidIconUrl,
          onUpload: widget.onUploadCta1AndroidIcon,
          onClear: widget.onClearCta1AndroidIcon,
        ),
        _field(
          'heroCta1IosUrl',
          'iOS / App Store URL (optional)',
          helper: 'Leave empty to show icon only — no link until you add a URL.',
        ),
        _field('heroCta1IosLabel', 'iOS option label', helper: 'e.g. Download on the App Store'),
        _cta1IconRow(
          label: 'iOS store badge',
          iconUrl: widget.heroCta1IosIconUrl ?? widget.initial.heroCta1IosIconUrl,
          onUpload: widget.onUploadCta1IosIcon,
          onClear: widget.onClearCta1IosIcon,
        ),
        _field(
          'heroCta1Url',
          'CTA 1 fallback URL',
          helper: 'Single-link mode only — used when no store URLs above are set.',
        ),
        _field('heroCta2Label', 'CTA 2 label'),
        _field('heroCta2Url', 'CTA 2 URL'),
        _field('heroCta3Label', 'CTA 3 label'),
        _field('heroCta3Url', 'CTA 3 URL'),
        const Divider(height: 24),
        Text('Trust stats', style: Theme.of(context).textTheme.titleMedium),
        _field('statProducts', 'Products count', helper: 'e.g. 2000+ — animates on homepage hero'),
        _field('statBrands', 'Brands count', helper: 'e.g. 50+'),
        _field('statDeals', 'Deals count', helper: 'e.g. 150+'),
        _field('statDealers', 'Dealers count', helper: 'e.g. 500+'),
        _field('statTechnicians', 'Technicians count', helper: 'e.g. 300+'),
        _field('statProjects', 'Projects count (trust section)', helper: 'Shown in Trust section below hero'),
        const Divider(height: 24),
        Text('Footer & contact', style: Theme.of(context).textTheme.titleMedium),
        _field('footerDescription', 'Footer description'),
        _field('contactEmail', 'Contact email'),
        _field('contactPhone', 'Contact phone'),
        _field('contactAddress', 'Contact address'),
        _field('socialFacebookUrl', 'Facebook URL'),
        _field('socialInstagramUrl', 'Instagram URL'),
        _field('socialLinkedinUrl', 'LinkedIn URL'),
        _field('socialTwitterUrl', 'Twitter/X URL'),
        _field('socialYoutubeUrl', 'YouTube URL'),
        _field('socialWebsiteUrl', 'Website URL'),
        const Divider(height: 24),
        Text('Download app', style: Theme.of(context).textTheme.titleMedium),
        _field('appDownloadTitle', 'Section title'),
        _field('appDownloadDescription', 'Section description'),
        _field('playStoreUrl', 'Google Play URL'),
        _field('appStoreUrl', 'App Store URL'),
        _field('appStoreLabel', 'App Store button label'),
        const Divider(height: 24),
        Text('Theme backgrounds', style: Theme.of(context).textTheme.titleMedium),
        _field('darkBackgroundColorHex', 'Dark background hex'),
        _field('lightBackgroundColorHex', 'Light background hex'),
      ],
    );
  }

  Widget _cta1IconRow({
    required String label,
    required String? iconUrl,
    required VoidCallback? onUpload,
    required VoidCallback? onClear,
  }) {
    if (onUpload == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            clipBehavior: Clip.antiAlias,
            child: iconUrl != null && iconUrl.trim().isNotEmpty
                ? Image.network(iconUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined))
                : const Icon(Icons.storefront_outlined, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Upload icon'),
          ),
          if (onClear != null && iconUrl != null && iconUrl.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Remove icon',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(String key, String label, {String? helper}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _c[key],
        decoration: InputDecoration(labelText: label, helperText: helper),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(itemLabel(e))))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
