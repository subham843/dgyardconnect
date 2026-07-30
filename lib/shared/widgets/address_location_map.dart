import 'package:flutter/material.dart';

import 'address_location_map_impl.dart'
    if (dart.library.html) 'address_location_map_impl_web.dart'
    if (dart.library.io) 'address_location_map_impl_io.dart' as impl;

/// Map with a marker at the given location (for address picker).
class AddressLocationMap extends StatelessWidget {
  const AddressLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 200,
  });

  final double latitude;
  final double longitude;
  final double height;

  @override
  Widget build(BuildContext context) {
    return impl.buildAddressLocationMap(
      latitude: latitude,
      longitude: longitude,
      height: height,
    );
  }
}
