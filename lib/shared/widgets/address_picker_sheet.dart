import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../core/config/maps_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../models/address_picker_result.dart';
import 'address_location_map.dart';

/// Address picker bottom sheet with map, current location, and Google search.
/// Same UX as dealer/technician registration.
Future<AddressPickerResult?> showAddressPickerSheet(
  BuildContext context, {
  required String title,
  AddressPickerResult? initial,
}) async {
  return showModalBottomSheet<AddressPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddressPickerSheet(
      title: title,
      initial: initial,
    ),
  );
}

class _AddressPickerSheet extends StatefulWidget {
  const _AddressPickerSheet({
    required this.title,
    this.initial,
  });

  final String title;
  final AddressPickerResult? initial;

  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  static const double _defaultLat = 20.5937;
  static const double _defaultLng = 78.9629;

  final _searchController = TextEditingController();
  final _houseFlatShopController = TextEditingController();
  final _buildingController = TextEditingController();
  final _landmarkController = TextEditingController();

  double _lat = _defaultLat;
  double _lng = _defaultLng;
  String _address = '';
  bool _loadingLocation = false;
  bool _locationSet = false;
  List<_PlaceSuggestion> _predictions = [];
  bool _predictionsLoading = false;
  bool _skipNextSearchTrigger = false;
  Timer? _autocompleteDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _lat = widget.initial!.latitude;
      _lng = widget.initial!.longitude;
      _address = widget.initial!.address;
      _locationSet = true;
      _searchController.text = widget.initial!.address;
      _houseFlatShopController.text = widget.initial!.houseFlatShop ?? '';
      _buildingController.text = widget.initial!.building ?? '';
      _landmarkController.text = widget.initial!.landmark ?? '';
    }
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _autocompleteDebounce?.cancel();
    if (_skipNextSearchTrigger) {
      _skipNextSearchTrigger = false;
      _autocompleteDebounce?.cancel();
      _lastRequestId++; // invalidate in-flight requests
      setState(() => _predictions = []);
      return;
    }
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    _autocompleteDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _fetchPlacesAutocomplete(query),
    );
  }

  int _lastRequestId = 0;

  Future<void> _fetchPlacesAutocomplete(String query) async {
    if (mapsApiKey.isEmpty) return;
    final requestId = ++_lastRequestId;
    setState(() => _predictionsLoading = true);
    try {
      final uri = placesAutocompleteNewUri;
      final body = jsonEncode(placesAutocompleteRequestBody(query));
      final response = await http.post(
        uri,
        headers: placesApiHeaders(mapsApiKey),
        body: body,
      );
      if (!mounted || requestId != _lastRequestId) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final suggestionsList = data?['suggestions'] as List<dynamic>? ?? [];
      final results = <_PlaceSuggestion>[];
      for (final s in suggestionsList) {
        final map = s as Map<String, dynamic>?;
        if (map == null) continue;
        final placePred = map['placePrediction'] as Map<String, dynamic>?;
        final queryPred = map['queryPrediction'] as Map<String, dynamic>?;
        String? text;
        String? placeId;
        String? placeResource;
        if (placePred != null) {
          final textObj = placePred['text'] as Map<String, dynamic>?;
          text = textObj?['text'] as String?;
          placeId = placePred['placeId'] as String?;
          placeResource = placePred['place'] as String?;
        } else if (queryPred != null) {
          final textObj = queryPred['text'] as Map<String, dynamic>?;
          text = textObj?['text'] as String?;
        }
        if (text != null && text.isNotEmpty) {
          results.add(_PlaceSuggestion(
            text: text,
            placeId: placeId,
            placeResource: placeResource,
          ));
        }
      }
      if (mounted && requestId == _lastRequestId) {
        setState(() {
          _predictions = results;
          _predictionsLoading = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _lastRequestId) {
        setState(() {
          _predictions = [];
          _predictionsLoading = false;
        });
      }
    }
  }

  Future<void> _onSelectPlace(_PlaceSuggestion suggestion) async {
    // Ensure any in-flight autocomplete cannot repopulate predictions after selection.
    _autocompleteDebounce?.cancel();
    _lastRequestId++;
    FocusScope.of(context).unfocus();
    if (mounted) {
      setState(() {
        _predictions = [];
        _predictionsLoading = true;
      });
    }
    try {
      if (suggestion.placeId != null || suggestion.placeResource != null) {
        final id = suggestion.placeResource ?? suggestion.placeId ?? '';
        if (id.isNotEmpty) {
          final uri = placesPlaceDetailsUri(id);
          final response = await http.get(
            uri,
            headers: placesDetailsHeaders(mapsApiKey),
          );
          if (!mounted) return;
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>?;
            final loc = data?['location'] as Map<String, dynamic>?;
            final lat = (loc?['latitude'] as num?)?.toDouble();
            final lng = (loc?['longitude'] as num?)?.toDouble();
            final addr = data?['formattedAddress'] as String? ?? suggestion.text;
            if (lat != null && lng != null) {
              _skipNextSearchTrigger = true;
              setState(() {
                _lat = lat;
                _lng = lng;
                _address = addr;
                _searchController.text = addr;
                _predictions = [];
                _predictionsLoading = false;
                _locationSet = true;
              });
              return;
            }
          }
        }
      }
      final locations = await locationFromAddress(suggestion.text);
      if (!mounted) return;
      if (locations.isNotEmpty) {
        final loc = locations.first;
        _skipNextSearchTrigger = true;
        setState(() {
          _lat = loc.latitude;
          _lng = loc.longitude;
          _address = suggestion.text;
          _searchController.text = suggestion.text;
          _predictions = [];
          _predictionsLoading = false;
          _locationSet = true;
        });
      } else {
        setState(() => _predictionsLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find location for this address')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _predictionsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find location for this address')),
        );
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    // Prevent autocomplete from reappearing when we programmatically set the text.
    _autocompleteDebounce?.cancel();
    _lastRequestId++; // invalidate in-flight autocomplete requests
    _skipNextSearchTrigger = true;
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
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppConstants.locationPermissionDenied)),
          );
        }
        setState(() => _loadingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      // 1. Try Google Geocoding API (road, mohalla, locality)
      if (mapsApiKey.isNotEmpty) {
        try {
          final uri = geocodeReverseUri(pos.latitude, pos.longitude);
          final response = await http.get(uri);
          if (mounted && response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>?;
            if (data?['status'] == 'OK') {
              final results = data?['results'] as List<dynamic>? ?? [];
              if (results.isNotEmpty) {
                final first = results.first as Map<String, dynamic>?;
                final addr = first?['formatted_address'] as String?;
                if (addr != null && addr.isNotEmpty) _address = addr;
              }
            }
          }
        } catch (_) {}
      }
      // 2. Fallback: OpenStreetMap Nominatim (free, good for India)
      if (_address.isEmpty) {
        try {
          final uri = Uri.https(
            'nominatim.openstreetmap.org',
            'reverse',
            {
              'format': 'json',
              'lat': '${pos.latitude}',
              'lon': '${pos.longitude}',
              'addressdetails': '1',
            },
          );
          final response = await http.get(
            uri,
            headers: {'User-Agent': 'DgYardConnect/1.0'},
          );
          if (mounted && response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>?;
            final addr = data?['display_name'] as String?;
            if (addr != null && addr.isNotEmpty) _address = addr;
          }
        } catch (_) {}
      }
      // 3. Last fallback: native geocoding
      if (_address.isEmpty) {
        try {
          final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (placemarks.isNotEmpty && mounted) {
            final p = placemarks.first;
            final addr = '${p.street ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}'
                .replaceAll(RegExp(r',\s*,'), ',').replaceAll(RegExp(r'^,\s*|\s*,$'), '').trim();
            if (addr.isNotEmpty) _address = addr;
          }
        } catch (_) {}
      }
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _loadingLocation = false;
        _locationSet = true;
        _predictions = [];
        _searchController.text =
            _address.isNotEmpty ? _address : '${pos.latitude}, ${pos.longitude}';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppConstants.locationError} $e')),
        );
      }
      setState(() => _loadingLocation = false);
    }
  }

  void _confirm() {
    if (!_locationSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or set a location first.')),
      );
      return;
    }
    String addr = _address.isNotEmpty ? _address : _searchController.text.trim();
    if (addr.isEmpty) {
      addr = '${_lat.toStringAsFixed(6)}, ${_lng.toStringAsFixed(6)}';
    }
    final result = AddressPickerResult(
      address: addr,
      latitude: _lat,
      longitude: _lng,
      houseFlatShop: _houseFlatShopController.text.trim().isEmpty
          ? null
          : _houseFlatShopController.text.trim(),
      building: _buildingController.text.trim().isEmpty
          ? null
          : _buildingController.text.trim(),
      landmark: _landmarkController.text.trim().isEmpty
          ? null
          : _landmarkController.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _autocompleteDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _houseFlatShopController.dispose();
    _buildingController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: true,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.googleCardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.googleGreyBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search at top - Ola/Uber style, always visible
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search address or location...',
                            filled: true,
                            fillColor: AppColors.googleGreyBg,
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.googleTextSecondary,
                              size: 24,
                            ),
                            suffixIcon: _predictionsLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.googleGreyBorder,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                        if (_predictions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 220),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: _predictions.length,
                              itemBuilder: (_, i) => ListTile(
                                leading: const Icon(
                                  Icons.place_outlined,
                                  size: 24,
                                  color: AppColors.googleBlue,
                                ),
                                title: Text(
                                  _predictions[i].text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15),
                                ),
                                onTap: () => _onSelectPlace(_predictions[i]),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _loadingLocation ? null : _useCurrentLocation,
                          icon: _loadingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location, size: 20),
                          label: const Text('Use current location'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          16 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                          // Map
                          SizedBox(
                            height: 200,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AddressLocationMap(
                                latitude: _lat,
                                longitude: _lng,
                                height: 200,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppConstants.addressDetails,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _houseFlatShopController,
                            textCapitalization: TextCapitalization.none,
                            decoration: InputDecoration(
                              labelText: AppConstants.houseFlatShopNumber,
                              filled: true,
                              fillColor: AppColors.googleGreyBg,
                              prefixIcon: const Icon(
                                Icons.numbers,
                                size: 22,
                                color: AppColors.googleTextSecondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.googleGreyBorder,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _buildingController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: AppConstants.buildingApartment,
                              filled: true,
                              fillColor: AppColors.googleGreyBg,
                              prefixIcon: const Icon(
                                Icons.apartment_outlined,
                                size: 22,
                                color: AppColors.googleTextSecondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.googleGreyBorder,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _landmarkController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: AppConstants.landmark,
                              filled: true,
                              fillColor: AppColors.googleGreyBg,
                              prefixIcon: const Icon(
                                Icons.place_outlined,
                                size: 22,
                                color: AppColors.googleTextSecondary,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.googleGreyBorder,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _confirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.googleBlue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(AppConstants.confirmDetails),
                          ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.text,
    this.placeId,
    this.placeResource,
  });
  final String text;
  final String? placeId;
  final String? placeResource;
}
