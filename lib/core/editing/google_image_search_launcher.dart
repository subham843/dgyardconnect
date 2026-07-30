import 'google_image_search_launcher_stub.dart'
    if (dart.library.html) 'google_image_search_launcher_web.dart' as platform;

import 'dg_image_search_context.dart';

/// Opens Google Images in a browser window/tab (no third-party image API).
abstract final class GoogleImageSearchLauncher {
  static String queryFrom(DgImageSearchContext ctx) {
    final q = ctx.buildSearchQuery();
    return q.isEmpty ? 'product' : q;
  }

  static Uri googleImagesUri(String query) => Uri.parse(
        'https://www.google.com/search?tbm=isch&q=${Uri.encodeQueryComponent(query)}',
      );

  static Future<bool> open(DgImageSearchContext ctx) async {
    return platform.openGoogleImagesPopup(googleImagesUri(queryFrom(ctx)));
  }
}
