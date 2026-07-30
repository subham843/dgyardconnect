import '../../../core/constants/route_names.dart';

/// Guards dynamic /{city}/{service} routes from colliding with app routes.
abstract final class SeoRouteGuard {
  SeoRouteGuard._();

  static const _reservedFirstSegments = <String>{
    'store',
    'product',
    'calculator',
    'services',
    'connect',
    'about',
    'contact',
    'support',
    'admin',
    'login',
    'phone',
    'otp',
    'register',
    'settings',
    'legal',
    'marketplace',
    'shop',
    'dealer',
    'technician',
    'walkthrough',
    'service-area',
    'role-choice',
    'pending-approval',
    'success',
    'splash',
    'verify',
    'rate',
    'chat',
    'offers',
    'blog',
    'privacy-policy',
    'data-deletion',
    'app',
  };

  static bool isReservedSegment(String segment) {
    final s = segment.trim().toLowerCase();
    return s.isEmpty || _reservedFirstSegments.contains(s);
  }

  static bool isPotentialLandingPath(String citySlug, String serviceSlug) {
    if (isReservedSegment(citySlug) || isReservedSegment(serviceSlug)) {
      return false;
    }
    return citySlug.trim().isNotEmpty && serviceSlug.trim().isNotEmpty;
  }

  static String landingPath(String citySlug, String serviceSlug) =>
      '/${citySlug.trim().toLowerCase()}/${serviceSlug.trim().toLowerCase()}';

  static String citiesHubPath() => RouteNames.publicServicesCities;
}
