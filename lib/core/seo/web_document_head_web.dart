import 'dart:html' as html;

import 'web_seo_meta.dart';

/// Updates live document `<head>` tags for crawlers and social previews.
abstract final class WebDocumentHead {
  WebDocumentHead._();

  static const _jsonLdId = 'dg-seo-jsonld';

  static void apply(WebSeoMeta meta) {
    html.document.title = meta.title;

    _upsertMeta('name', 'description', meta.description);
    _upsertMeta('name', 'robots', meta.robotsContent);

    _upsertLink('canonical', meta.canonicalUrl);

    _upsertMeta('property', 'og:type', meta.ogType);
    _upsertMeta('property', 'og:site_name', 'D.G.Yard Connect');
    _upsertMeta('property', 'og:title', meta.title);
    _upsertMeta('property', 'og:description', meta.description);
    _upsertMeta('property', 'og:url', meta.canonicalUrl);
    _upsertMeta('property', 'og:image', meta.resolvedImage);

    _upsertMeta('name', 'twitter:card', meta.twitterCard);
    _upsertMeta('name', 'twitter:title', meta.title);
    _upsertMeta('name', 'twitter:description', meta.description);
    _upsertMeta('name', 'twitter:image', meta.resolvedImage);

    _upsertJsonLd(meta.jsonLdScript);
  }

  static void _upsertMeta(String attr, String key, String content) {
    final selector = 'meta[$attr="$key"]';
    final existing = html.document.querySelector(selector) as html.MetaElement?;
    final el = existing ?? html.MetaElement();
    el.setAttribute(attr, key);
    el.content = content;
    if (existing == null) {
      html.document.head?.append(el);
    }
  }

  static void _upsertLink(String rel, String href) {
    final selector = 'link[rel="$rel"]';
    final existing = html.document.querySelector(selector) as html.LinkElement?;
    final el = existing ?? html.LinkElement();
    el.rel = rel;
    el.href = href;
    if (existing == null) {
      html.document.head?.append(el);
    }
  }

  static void _upsertJsonLd(String? json) {
    final existing = html.document.getElementById(_jsonLdId) as html.ScriptElement?;
    if (json == null || json.isEmpty) {
      existing?.remove();
      return;
    }
    final el = existing ?? html.ScriptElement();
    el.id = _jsonLdId;
    el.type = 'application/ld+json';
    el.text = json;
    if (existing == null) {
      html.document.head?.append(el);
    }
  }
}
