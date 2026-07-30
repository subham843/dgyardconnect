// Mobile: full Connect + marketplace + shop/calc in-app routes.
// Web: slim public site + deferred admin shop/calculator (see app_router_web.dart).
export 'app_router_mobile.dart'
    if (dart.library.html) 'app_router_web.dart';
