import 'dart:html' as html;

Future<bool> openGoogleImagesPopup(Uri uri) async {
  html.window.open(
    uri.toString(),
    'dg_google_images',
    'width=1280,height=800,menubar=no,toolbar=no,location=yes,status=no,scrollbars=yes,resizable=yes',
  );
  return true;
}
