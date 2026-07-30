import 'package:flutter/foundation.dart' show kIsWeb;

/// Service Completion Record – platform disclaimer text and verification URL.
abstract final class ServiceCompletionConstants {
  /// Base URL for verification link (e.g. https://yourapp.web.app). On web uses current origin.
  static String get verificationBaseUrl =>
      kIsWeb ? '' : 'https://dgyardconnect.web.app'; // Set your production web URL if different

  static String verificationUrlForRecord(String recordId) {
    final base = kIsWeb ? Uri.base.origin : verificationBaseUrl;
    final normalized = base.replaceFirst(RegExp(r'/$'), '');
    return '$normalized/verify?recordId=${Uri.encodeComponent(recordId)}';
  }

  static const String platformDisclaimer =
      'D.G.Yard Connect is a digital marketplace platform that connects dealers and technicians. '
      'The platform does not directly perform installation or repair services. '
      'This record confirms that the technician completed the service job through the platform.';

  static const String platformHeader = 'D.G.Yard Connect';
  static const String recordTitle = 'Verified Service Completion Record';
}
