import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../../../core/bootstrap/firebase_auth_safe.dart';
import '../../../../../core/config/maps_config.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../shared/services/pincode_service.dart';
import '../../../../../shared/widgets/address_location_map.dart';
import '../../../v2/v2_colors.dart';
import '../../../v2/v2_font_styles.dart';
import '../../../v2/v2_glass.dart';
import '../../../v2/v2_text.dart';
import '../../../v2/v2_tokens.dart';
import 'product_detail_glass.dart';
import 'store_checkout_alert.dart';
import '../models/shop_checkout_address.dart';

/// Address picker: map search, current location, then details form.
Future<ShopCheckoutAddress?> showStoreCheckoutAddressPicker(
  BuildContext context, {
  ShopCheckoutAddress? initial,
  bool autoUseCurrentLocation = false,
  bool autoFocusSearch = false,
}) {
  return showDialog<ShopCheckoutAddress>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _StoreCheckoutAddressDialog(
      initial: initial,
      autoUseCurrentLocation: autoUseCurrentLocation,
      autoFocusSearch: autoFocusSearch,
    ),
  );
}

class _StoreCheckoutAddressDialog extends StatefulWidget {
  const _StoreCheckoutAddressDialog({
    this.initial,
    this.autoUseCurrentLocation = false,
    this.autoFocusSearch = false,
  });
  final ShopCheckoutAddress? initial;
  final bool autoUseCurrentLocation;
  final bool autoFocusSearch;

  @override
  State<_StoreCheckoutAddressDialog> createState() =>
      _StoreCheckoutAddressDialogState();
}

class _StoreCheckoutAddressDialogState extends State<_StoreCheckoutAddressDialog> {
  static const _defaultLat = 20.5937;
  static const _defaultLng = 78.9629;

  final _searchController = TextEditingController();
  final _flatController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pinController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _streetController = TextEditingController();

  double _lat = _defaultLat;
  double _lng = _defaultLng;
  bool _locationSet = false;
  bool _loadingLocation = false;
  bool _loadingPin = false;
  String _addressType = 'home';
  List<_PlaceSuggestion> _predictions = [];
  bool _predictionsLoading = false;
  bool _skipNextSearch = false;
  Timer? _autocompleteDebounce;
  Timer? _pinDebounce;
  int _lastRequestId = 0;
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _flatController.text = i.flatHouse;
      _nameController.text = i.name;
      _phoneController.text = i.phone;
      _altPhoneController.text = i.alternatePhone ?? '';
      _landmarkController.text = i.landmark ?? '';
      _pinController.text = i.pincode;
      _cityController.text = i.city;
      _stateController.text = i.state;
      _countryController.text = i.country;
      _streetController.text = i.streetAddress;
      _addressType = i.addressType;
      _lat = i.latitude ?? _defaultLat;
      _lng = i.longitude ?? _defaultLng;
      _locationSet = i.streetAddress.isNotEmpty;
      _searchController.text = i.streetAddress;
    } else {
      final user = FirebaseAuthSafe.currentUser;
      _nameController.text = user?.displayName ?? '';
      final phone = user?.phoneNumber ?? '';
      _phoneController.text = phone.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^91'), '');
    }
    _searchController.addListener(_onSearchChanged);
    _pinController.addListener(_onPinChanged);
    if (widget.autoUseCurrentLocation && widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentLocation());
    } else if (widget.autoFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
  }

  @override
  void dispose() {
    _autocompleteDebounce?.cancel();
    _pinDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _pinController.removeListener(_onPinChanged);
    _searchController.dispose();
    _flatController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _landmarkController.dispose();
    _pinController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _streetController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onPinChanged() {
    _pinDebounce?.cancel();
    final digits = _pinController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return;
    _pinDebounce = Timer(const Duration(milliseconds: 400), () => _lookupPin(digits));
  }

  Future<void> _lookupPin(String pin) async {
    setState(() => _loadingPin = true);
    final result = await PincodeService.lookup(pin);
    if (!mounted) return;
    setState(() => _loadingPin = false);
    if (result != null) {
      _cityController.text = result.town;
      _stateController.text = result.state;
      _countryController.text = result.country;
    }
  }

  void _onSearchChanged() {
    _autocompleteDebounce?.cancel();
    if (_skipNextSearch) {
      _skipNextSearch = false;
      _lastRequestId++;
      setState(() => _predictions = []);
      return;
    }
    final query = _searchController.text.trim();
    if (query.length < 3) {
      setState(() => _predictions = []);
      return;
    }
    _autocompleteDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchAutocomplete(query),
    );
  }

  Future<void> _fetchAutocomplete(String query) async {
    if (mapsApiKey.isEmpty) return;
    final requestId = ++_lastRequestId;
    setState(() => _predictionsLoading = true);
    try {
      final response = await http.post(
        placesAutocompleteNewUri,
        headers: placesApiHeaders(mapsApiKey),
        body: jsonEncode(placesAutocompleteRequestBody(query)),
      );
      if (!mounted || requestId != _lastRequestId) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final suggestions = data?['suggestions'] as List<dynamic>? ?? [];
      final results = <_PlaceSuggestion>[];
      for (final s in suggestions) {
        final map = s as Map<String, dynamic>?;
        if (map == null) continue;
        final placePred = map['placePrediction'] as Map<String, dynamic>?;
        String? text;
        String? placeId;
        String? placeResource;
        if (placePred != null) {
          final textObj = placePred['text'] as Map<String, dynamic>?;
          text = textObj?['text'] as String?;
          placeId = placePred['placeId'] as String?;
          placeResource = placePred['place'] as String?;
        }
        if (text != null && text.isNotEmpty) {
          results.add(_PlaceSuggestion(text: text, placeId: placeId, placeResource: placeResource));
        }
      }
      if (mounted && requestId == _lastRequestId) {
        setState(() {
          _predictions = results;
          _predictionsLoading = false;
        });
      }
    } catch (_) {
      if (mounted && requestId == _lastRequestId) {
        setState(() {
          _predictions = [];
          _predictionsLoading = false;
        });
      }
    }
  }

  Future<void> _onSelectPlace(_PlaceSuggestion suggestion) async {
    _autocompleteDebounce?.cancel();
    _lastRequestId++;
    FocusScope.of(context).unfocus();
    setState(() {
      _predictions = [];
      _predictionsLoading = true;
    });
    try {
      if (suggestion.placeId != null || suggestion.placeResource != null) {
        final id = suggestion.placeResource ?? suggestion.placeId ?? '';
        if (id.isNotEmpty) {
          final uri = placesPlaceDetailsUri(id);
          final response = await http.get(
            uri,
            headers: {
              ...placesDetailsHeaders(mapsApiKey),
              'X-Goog-FieldMask': 'location,formattedAddress,addressComponents',
            },
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>?;
            final loc = data?['location'] as Map<String, dynamic>?;
            final lat = (loc?['latitude'] as num?)?.toDouble();
            final lng = (loc?['longitude'] as num?)?.toDouble();
            final addr = data?['formattedAddress'] as String? ?? suggestion.text;
            _applyLocation(lat: lat, lng: lng, formattedAddress: addr, components: data?['addressComponents']);
            return;
          }
        }
      }
      final locations = await locationFromAddress(suggestion.text);
      if (locations.isNotEmpty) {
        await _reverseGeocode(locations.first.latitude, locations.first.longitude, suggestion.text);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _predictionsLoading = false);
        showStoreCheckoutValidationAlert(
          context,
          title: 'Location not found',
          message: 'Could not find this location. Try a nearby landmark or area name.',
        );
      }
    }
  }

  void _applyLocation({
    double? lat,
    double? lng,
    required String formattedAddress,
    dynamic components,
  }) {
    var pin = '';
    var city = '';
    var state = '';
    var country = 'India';
    if (components is List) {
      for (final raw in components) {
        final c = raw as Map<String, dynamic>?;
        if (c == null) continue;
        final types = (c['types'] as List<dynamic>?)?.cast<String>() ?? [];
        final long = c['longText'] as String? ?? c['shortText'] as String? ?? '';
        if (types.contains('postal_code')) pin = long;
        if (types.contains('locality') && city.isEmpty) city = long;
        if (types.contains('administrative_area_level_1') && state.isEmpty) state = long;
        if (types.contains('country') && country.isEmpty) country = long;
      }
    }
    if (pin.isEmpty) {
      final m = RegExp(r'\b(\d{6})\b').firstMatch(formattedAddress);
      if (m != null) pin = m.group(1)!;
    }
    _skipNextSearch = true;
    setState(() {
      if (lat != null && lng != null) {
        _lat = lat;
        _lng = lng;
      }
      _streetController.text = formattedAddress;
      _searchController.text = formattedAddress;
      if (pin.isNotEmpty) _pinController.text = pin;
      if (city.isNotEmpty) _cityController.text = city;
      if (state.isNotEmpty) _stateController.text = state;
      if (country.isNotEmpty) _countryController.text = country;
      _locationSet = true;
      _predictionsLoading = false;
      _predictions = [];
    });
    if (pin.length == 6) _lookupPin(pin);
  }

  Future<void> _reverseGeocode(double lat, double lng, String fallback) async {
    if (mapsApiKey.isNotEmpty) {
      try {
        final response = await http.get(geocodeReverseUri(lat, lng));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>?;
          if (data?['status'] == 'OK') {
            final results = data?['results'] as List<dynamic>? ?? [];
            if (results.isNotEmpty) {
              final first = results.first as Map<String, dynamic>;
              final addr = first['formatted_address'] as String? ?? fallback;
              _applyLocation(lat: lat, lng: lng, formattedAddress: addr, components: first['address_components']);
              return;
            }
          }
        }
      } catch (_) {}
    }
    _applyLocation(lat: lat, lng: lng, formattedAddress: fallback, components: null);
  }

  Future<void> _useCurrentLocation() async {
    _autocompleteDebounce?.cancel();
    _lastRequestId++;
    _skipNextSearch = true;
    FocusScope.of(context).unfocus();
    setState(() {
      _loadingLocation = true;
      _predictions = [];
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showStoreCheckoutValidationAlert(
            context,
            title: 'Location permission',
            message: AppConstants.locationPermissionDenied,
          );
        }
        setState(() => _loadingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      await _reverseGeocode(pos.latitude, pos.longitude, '${pos.latitude}, ${pos.longitude}');
    } catch (e) {
      if (mounted) {
        showStoreCheckoutErrorAlert(
          context,
          title: 'Location error',
          message: '${AppConstants.locationError} $e',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _save() {
    if (!_locationSet || _streetController.text.trim().isEmpty) {
      showStoreCheckoutValidationAlert(
        context,
        title: 'Select location',
        message: 'Please search and select your area on the map first.',
      );
      return;
    }
    if (_flatController.text.trim().isEmpty) {
      showStoreCheckoutValidationAlert(
        context,
        title: 'Missing field',
        message: 'Enter flat / house / building number.',
      );
      return;
    }
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().length < 10) {
      showStoreCheckoutValidationAlert(
        context,
        title: 'Contact details required',
        message: 'Enter your full name and a valid 10-digit mobile number.',
      );
      return;
    }
    Navigator.of(context).pop(
      ShopCheckoutAddress(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        alternatePhone: _altPhoneController.text.trim().isEmpty
            ? null
            : _altPhoneController.text.trim(),
        flatHouse: _flatController.text.trim(),
        streetAddress: _streetController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: _countryController.text.trim().isEmpty
            ? 'India'
            : _countryController.text.trim(),
        pincode: _pinController.text.trim(),
        addressType: _addressType,
        landmark: _landmarkController.text.trim().isEmpty
            ? null
            : _landmarkController.text.trim(),
        latitude: _lat,
        longitude: _lng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width < 720 ? 12 : 48,
          vertical: 24,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: v2BackdropGlass(
            blurSigma: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 720,
                maxHeight: size.height * 0.92,
              ),
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _mapSection(),
                          const SizedBox(height: V2.s6),
                          _locationActions(),
                          const SizedBox(height: V2.s6),
                          _addressDetailsForm(),
                        ],
                      ),
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add delivery address', style: V2Text.h3(context)),
                Text(
                  'Search your area on the map to set delivery location',
                  style: V2Text.small(),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _mapSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: AddressLocationMap(latitude: _lat, longitude: _lng, height: 220),
          ),
          if (!_locationSet)
            Positioned.fill(
              child: Container(
                color: V2Colors.ink.withValues(alpha: 0.04),
                alignment: Alignment.center,
                child: Text(
                  'Search area or use current location',
                  style: V2Text.bodyEmph().copyWith(color: V2Colors.fgSubtle),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _locationActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassField(
          controller: _searchController,
          focusNode: _searchFocus,
          hint: 'Search by area, street, landmark…',
          icon: Icons.search_rounded,
          suffix: _predictionsLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
        if (_predictions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: V2Colors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _predictions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.place_outlined, color: V2Colors.plasma),
                title: Text(_predictions[i].text, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _onSelectPlace(_predictions[i]),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LocationChoiceButton(
                icon: Icons.map_outlined,
                label: 'Away from my location',
                outlined: true,
                onTap: () {
                  _searchFocus.requestFocus();
                  _searchController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _searchController.text.length,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LocationChoiceButton(
                icon: Icons.my_location_rounded,
                label: 'Use my current location',
                loading: _loadingLocation,
                onTap: _useCurrentLocation,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _addressDetailsForm() {
    return ProductGlassPanel(
      padding: const EdgeInsets.all(V2.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Address details', style: V2Text.bodyEmph().copyWith(fontSize: 17)),
          const SizedBox(height: V2.s4),
          _GlassField(
            controller: _flatController,
            label: 'Flat / House / Building no. *',
            icon: Icons.home_work_outlined,
          ),
          const SizedBox(height: V2.s3),
          _GlassField(
            controller: _streetController,
            label: 'Area & street (from map)',
            icon: Icons.location_on_outlined,
            readOnly: true,
            maxLines: 2,
          ),
          const SizedBox(height: V2.s3),
          Row(
            children: [
              Expanded(
                child: _GlassField(
                  controller: _pinController,
                  label: 'Pincode',
                  icon: Icons.pin_outlined,
                  keyboard: TextInputType.number,
                  suffix: _loadingPin
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GlassField(
                  controller: _cityController,
                  label: 'City',
                  icon: Icons.location_city_outlined,
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: V2.s3),
          Row(
            children: [
              Expanded(
                child: _GlassField(
                  controller: _stateController,
                  label: 'State',
                  icon: Icons.map_outlined,
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GlassField(
                  controller: _countryController,
                  label: 'Country',
                  icon: Icons.public_outlined,
                  readOnly: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: V2.s3),
          _GlassField(
            controller: _landmarkController,
            label: 'Landmark (optional)',
            icon: Icons.signpost_outlined,
          ),
          const SizedBox(height: V2.s6),
          Text('Contact', style: V2Text.bodyEmph()),
          const SizedBox(height: V2.s3),
          _GlassField(controller: _nameController, label: 'Full name *', icon: Icons.person_outline),
          const SizedBox(height: V2.s3),
          Row(
            children: [
              Expanded(
                child: _GlassField(
                  controller: _phoneController,
                  label: 'Mobile *',
                  icon: Icons.phone_iphone_outlined,
                  keyboard: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GlassField(
                  controller: _altPhoneController,
                  label: 'Alternate mobile',
                  icon: Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: V2.s4),
          Text('Save as', style: V2Text.small()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final type in const [
                ('home', 'Home', Icons.home_outlined),
                ('work', 'Work', Icons.work_outline),
                ('other', 'Other', Icons.more_horiz),
              ])
                _AddressTypeChip(
                  selected: _addressType == type.$1,
                  label: type.$2,
                  icon: type.$3,
                  onTap: () => setState(() => _addressType = type.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: V2Colors.border.withValues(alpha: 0.6))),
        color: Colors.white.withValues(alpha: 0.5),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: V2Colors.ink,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Save & deliver here'),
        ),
      ),
    );
  }
}

class _GlassField extends StatefulWidget {
  const _GlassField({
    required this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.icon,
    this.keyboard,
    this.maxLines = 1,
    this.readOnly = false,
    this.suffix,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboard;
  final int maxLines;
  final bool readOnly;
  final Widget? suffix;

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: _focused ? 0.95 : 0.72),
        border: Border.all(
          color: _focused
              ? V2Colors.plasma.withValues(alpha: 0.45)
              : V2Colors.border.withValues(alpha: 0.8),
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: V2Colors.plasma.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        readOnly: widget.readOnly,
        keyboardType: widget.keyboard,
        maxLines: widget.maxLines,
        onTap: widget.readOnly ? null : () => setState(() => _focused = true),
        onTapOutside: (_) => setState(() => _focused = false),
        onEditingComplete: () => setState(() => _focused = false),
        style: V2FontStyles.inter(fontSize: 15, fontWeight: FontWeight.w500, color: V2Colors.ink),
        cursorColor: V2Colors.plasma,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: V2Text.small().copyWith(
            color: _focused ? V2Colors.plasma : V2Colors.fgSubtle,
          ),
          prefixIcon: widget.icon != null
              ? Icon(widget.icon, size: 20, color: _focused ? V2Colors.plasma : V2Colors.fgFaint)
              : null,
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _LocationChoiceButton extends StatelessWidget {
  const _LocationChoiceButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: V2Colors.plasma.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: outlined ? Colors.white.withValues(alpha: 0.6) : V2Colors.plasma.withValues(alpha: 0.1),
            border: Border.all(
              color: outlined ? V2Colors.border : V2Colors.plasma.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 18, color: V2Colors.plasma),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: V2Text.small().copyWith(fontWeight: FontWeight.w600, color: V2Colors.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressTypeChip extends StatelessWidget {
  const _AddressTypeChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? V2Colors.plasma.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.7),
            border: Border.all(
              color: selected ? V2Colors.plasma : V2Colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? V2Colors.plasma : V2Colors.fgSubtle),
              const SizedBox(width: 6),
              Text(
                label,
                style: V2Text.small().copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? V2Colors.plasma : V2Colors.fgSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion({required this.text, this.placeId, this.placeResource});
  final String text;
  final String? placeId;
  final String? placeResource;
}