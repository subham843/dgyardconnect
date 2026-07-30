/// Delivery address collected during store checkout.
class ShopCheckoutAddress {
  const ShopCheckoutAddress({
    required this.name,
    required this.phone,
    required this.flatHouse,
    required this.streetAddress,
    required this.city,
    required this.state,
    required this.country,
    required this.pincode,
    required this.addressType,
    this.alternatePhone,
    this.landmark,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String phone;
  final String? alternatePhone;
  final String flatHouse;
  final String streetAddress;
  final String city;
  final String state;
  final String country;
  final String pincode;
  final String addressType;
  final String? landmark;
  final double? latitude;
  final double? longitude;

  String get displayLine =>
      [flatHouse, streetAddress, city, state, pincode, country]
          .where((s) => s.trim().isNotEmpty)
          .join(', ');

  Map<String, dynamic> toShippingJson() => {
        'name': name,
        'phone': phone,
        if (alternatePhone != null && alternatePhone!.isNotEmpty)
          'alternate_phone': alternatePhone,
        'address': '$flatHouse, $streetAddress'.trim(),
        'city': city,
        'state': state,
        'country': country,
        'pincode': pincode,
        'address_type': addressType,
        if (landmark != null && landmark!.isNotEmpty) 'landmark': landmark,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      };
}