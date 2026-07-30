import 'package:url_launcher/url_launcher.dart';

Future<bool> openGoogleImagesPopup(Uri uri) async {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
