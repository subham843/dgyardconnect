// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;

import 'dart:html' as html;

import '../models/brand_kit_model.dart';

String? _kitVisualSignature(BrandKitModel kit) {
  return [
    kit.faviconUrl,
    kit.appIcon192Url,
    kit.appIcon512Url,
    kit.appIconUrl,
    kit.appleTouchIconUrl,
    kit.animatedAppIconUrl,
    kit.logoIconUrl,
    kit.logoColorUrl,
    kit.logoWhiteUrl,
    kit.splashLogoUrl,
    kit.appName,
    kit.primaryColorHex,
  ].map((e) => e?.trim() ?? '').join('\u001e');
}

String? _firstNonEmpty(Iterable<String?> urls) {
  for (final raw in urls) {
    final s = raw?.trim() ?? '';
    if (s.isNotEmpty) return s;
  }
  return null;
}

/// Tab / window icon — same priority family as in-app [BrandLogo] (square assets first).
String? pickFaviconUrl(BrandKitModel kit) {
  return _firstNonEmpty([
    kit.faviconUrl,
    kit.appIcon192Url,
    kit.appIcon512Url,
    kit.appIconUrl,
    kit.animatedAppIconUrl,
    kit.logoIconUrl,
    kit.logoColorUrl,
    kit.logoWhiteUrl,
    kit.splashLogoUrl,
  ]);
}

/// Home-screen icon on iOS — prefers dedicated touch + app icons, then logos.
String? pickAppleTouchUrl(BrandKitModel kit) {
  return _firstNonEmpty([
    kit.appleTouchIconUrl,
    kit.appIcon192Url,
    kit.appIcon512Url,
    kit.appIconUrl,
    kit.animatedAppIconUrl,
    kit.logoIconUrl,
    kit.logoColorUrl,
    kit.logoWhiteUrl,
    kit.splashLogoUrl,
    kit.faviconUrl,
  ]);
}

String? _pickManifest192(BrandKitModel kit) {
  return _firstNonEmpty([
    kit.appIcon192Url,
    kit.appIconUrl,
    kit.logoIconUrl,
    kit.faviconUrl,
    kit.appIcon512Url,
    kit.logoColorUrl,
  ]);
}

String? _pickManifest512(BrandKitModel kit) {
  return _firstNonEmpty([
    kit.appIcon512Url,
    kit.appIcon192Url,
    kit.appIconUrl,
    kit.logoIconUrl,
    kit.faviconUrl,
    kit.logoColorUrl,
  ]);
}

String? _lastSignature;
String? _manifestObjectUrl;

void _setOrCreateLink(String rel, String href) {
  final head = html.document.head;
  if (head == null) return;

  final ts = DateTime.now().millisecondsSinceEpoch;
  final sep = href.contains('?') ? '&' : '?';
  final hrefWithBust = '$href${sep}v=$ts';

  final existing = head.querySelectorAll('link[rel="$rel"]');
  if (existing.isNotEmpty) {
    for (final node in existing) {
      (node as html.LinkElement).href = hrefWithBust;
    }
    return;
  }

  head.append(
    html.LinkElement()
      ..rel = rel
      ..type = 'image/png'
      ..href = hrefWithBust,
  );
}

Future<void> _applyManifestFromKit(BrandKitModel kit) async {
  final src192 = _pickManifest192(kit);
  final src512 = _pickManifest512(kit);
  if (src192 == null && src512 == null) return;

  final link = html.document.querySelector('link[rel="manifest"]') as html.LinkElement?;
  if (link == null) return;

  try {
    final resp = await html.window.fetch('manifest.json');
    final text = await resp.text();
    if (text.trim().isEmpty) return;
    final map = jsonDecode(text) as Map<String, dynamic>;

    final icon192 = src192 ?? src512!;
    final icon512 = src512 ?? src192!;

    map['icons'] = <Map<String, Object?>>[
      {'src': icon192, 'sizes': '192x192', 'type': 'image/png'},
      {'src': icon512, 'sizes': '512x512', 'type': 'image/png'},
      {'src': icon192, 'sizes': '192x192', 'type': 'image/png', 'purpose': 'maskable'},
      {'src': icon512, 'sizes': '512x512', 'type': 'image/png', 'purpose': 'maskable'},
    ];

    final name = kit.appName?.trim();
    if (name != null && name.isNotEmpty) {
      map['name'] = name;
      map['short_name'] = name.length > 12 ? '${name.substring(0, 11)}…' : name;
    }

    final hex = kit.primaryColorHex?.trim();
    if (hex != null && hex.isNotEmpty) {
      final normalized = hex.startsWith('#') ? hex : '#$hex';
      map['theme_color'] = normalized;
      map['background_color'] = normalized;
    }

    final jsonStr = jsonEncode(map);
    final blob = html.Blob([jsonStr], 'application/json');
    final newUrl = html.Url.createObjectUrlFromBlob(blob);
    final old = _manifestObjectUrl;
    _manifestObjectUrl = newUrl;
    link.href = newUrl;
    if (old != null) {
      html.Url.revokeObjectUrl(old);
    }
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('brand_kit_web_impl: manifest update failed: $e\n$st');
    }
  }
}

/// Updates favicon, shortcut icon, apple-touch-icon, and PWA manifest icons from brand kit (web only).
void updateFaviconAndIcons(BrandKitModel kit) {
  final sig = _kitVisualSignature(kit);
  if (sig == _lastSignature) return;
  _lastSignature = sig;

  final fav = pickFaviconUrl(kit);
  if (fav != null) {
    _setOrCreateLink('icon', fav);
    _setOrCreateLink('shortcut icon', fav);
  }

  final apple = pickAppleTouchUrl(kit);
  if (apple != null) {
    _setOrCreateLink('apple-touch-icon', apple);
  }

  scheduleMicrotask(() => _applyManifestFromKit(kit));
}
