import 'web_seo_meta.dart';

/// No-op on non-web platforms.
abstract final class WebDocumentHead {
  WebDocumentHead._();

  static void apply(WebSeoMeta meta) {}
}
