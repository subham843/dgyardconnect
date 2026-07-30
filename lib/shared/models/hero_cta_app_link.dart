/// App store button on hero CTA 1 — icon always visible; navigates only when [url] is set.
class HeroCtaAppLink {
  const HeroCtaAppLink({
    required this.platform,
    required this.label,
    this.url,
    this.iconUrl,
  });

  final HeroCtaAppPlatform platform;
  final String label;
  final String? url;
  final String? iconUrl;

  bool get hasUrl {
    final v = url?.trim() ?? '';
    return v.isNotEmpty && v != '#';
  }
}

enum HeroCtaAppPlatform { android, ios }
