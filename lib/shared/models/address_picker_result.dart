/// Result from the address picker (pickup/return address selection).
class AddressPickerResult {
  const AddressPickerResult({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.houseFlatShop,
    this.building,
    this.landmark,
  });

  final String address;
  final double latitude;
  final double longitude;
  final String? houseFlatShop;
  final String? building;
  final String? landmark;

  /// Full address string including details.
  String get fullAddress {
    final parts = <String>[address];
    if (houseFlatShop != null && houseFlatShop!.isNotEmpty) {
      parts.add('Shop/Flat/House no: $houseFlatShop');
    }
    if (building != null && building!.isNotEmpty) {
      parts.add('Building: $building');
    }
    if (landmark != null && landmark!.isNotEmpty) {
      parts.add('Landmark: $landmark');
    }
    return parts.join(', ');
  }
}
