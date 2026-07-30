import 'dart:async';
import 'dart:convert';
import 'dart:math' show cos, pi;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/config/maps_config.dart';
import '../../core/config/maps_js_loader.dart';
import '../../shared/widgets/glass_container.dart';

/// Premium design tokens for Service Area flow.
abstract final class _ServiceAreaDesign {
  static const Color surfaceBg = AppColors.brandWarmBgMuted;
  static const Color textHeadline = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color saffronPrimary = AppColors.brandWarm;
  static const Color saffronLight = AppColors.brandWarmLight;
  static const Color saffronBorder = AppColors.brandWarmBorder;
}

class ServiceAreaPickerScreen extends StatefulWidget {
  const ServiceAreaPickerScreen({super.key});

  @override
  State<ServiceAreaPickerScreen> createState() => _ServiceAreaPickerScreenState();
}

class _ServiceAreaPickerScreenState extends State<ServiceAreaPickerScreen>
    with SingleTickerProviderStateMixin {
  static const double _defaultLat = 20.5937;
  static const double _defaultLng = 78.9629;
  final _addressController = TextEditingController();
  final _searchFocusNode = FocusNode();

  double _centerLat = _defaultLat;
  double _centerLng = _defaultLng;
  double _radiusKm = 10;
  bool _loadingLocation = false;
  bool _locationSet = false;
  final bool _radiusSet = false;
  List<dynamic> _predictions = [];
  bool _predictionsLoading = false;
  bool _isSelectingPlace = false;
  Timer? _autocompleteDebounce;
  GoogleMapController? _mapController;
  late final AnimationController _radiusAnimController;
  Animation<double>? _radiusAnim;
  double _displayRadiusKm = 10;
  bool _continuePressed = false;

  @override
  void initState() {
    super.initState();
    _displayRadiusKm = _radiusKm;
    _radiusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _radiusAnimController.addListener(() {
      final v = _radiusAnim?.value;
      if (v != null && mounted) {
        setState(() => _displayRadiusKm = v);
      }
    });
    _addressController.addListener(_onAddressChanged);
    if (kIsWeb) {
      ensureGoogleMapsJsLoaded();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentLocation());
    }
  }

  void _onAddressChanged() {
    if (_isSelectingPlace) return;
    _autocompleteDebounce?.cancel();
    final query = _addressController.text.trim();
    if (query.isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    _autocompleteDebounce = Timer(const Duration(milliseconds: 50), () => _fetchPlacesAutocomplete(query));
  }

  Future<void> _fetchPlacesAutocomplete(String query) async {
    if (mapsApiKey.isEmpty) return;
    if (!mounted) return;
    setState(() => _predictionsLoading = true);
    try {
      final uri = placesAutocompleteNewUri;
      final body = jsonEncode(placesAutocompleteRequestBody(query));
      final response = await http.post(
        uri,
        headers: placesApiHeaders(mapsApiKey),
        body: body,
      );
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _predictions = [];
          _predictionsLoading = false;
        });
        return;
      }
      final Object? decoded = jsonDecode(response.body);
      final Map<String, dynamic>? data = decoded is Map<String, dynamic> ? decoded : null;
      if (data == null || data.containsKey('error')) {
        setState(() {
          _predictions = [];
          _predictionsLoading = false;
        });
        return;
      }
      final suggestionsList = data['suggestions'] is List<dynamic> ? data['suggestions'] as List<dynamic> : <dynamic>[];
      final results = <_PlaceSuggestion>[];
      for (final s in suggestionsList) {
        final map = s is Map<String, dynamic> ? s : null;
        if (map == null) continue;
        final placePred = map['placePrediction'] is Map<String, dynamic> ? map['placePrediction'] as Map<String, dynamic> : null;
        final queryPred = map['queryPrediction'] is Map<String, dynamic> ? map['queryPrediction'] as Map<String, dynamic> : null;
        String? text;
        if (placePred != null) {
          final textObj = placePred['text'] is Map<String, dynamic> ? placePred['text'] as Map<String, dynamic> : null;
          text = textObj?['text'] is String ? textObj!['text'] as String : null;
        }
        if (text == null && queryPred != null) {
          final textObj = queryPred['text'] is Map<String, dynamic> ? queryPred['text'] as Map<String, dynamic> : null;
          text = textObj?['text'] is String ? textObj!['text'] as String : null;
        }
        if (text != null && text.trim().isNotEmpty) {
          results.add(_PlaceSuggestion(text.trim()));
        }
      }
      if (!mounted) return;
      setState(() {
        _predictions = results;
        _predictionsLoading = false;
      });
    } catch (e, st) {
      assert(() {
        debugPrint('ServiceAreaPicker autocomplete error: $e $st');
        return true;
      }());
      if (mounted) {
        setState(() {
          _predictions = [];
          _predictionsLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _autocompleteDebounce?.cancel();
    _radiusAnimController.dispose();
    _addressController.removeListener(_onAddressChanged);
    _addressController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
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
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
        _loadingLocation = false;
        _locationSet = true;
        _predictions = [];
      });
      _updateMapCamera();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppConstants.locationError} $e')),
        );
      }
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _onSelectPlace(dynamic prediction) async {
    if (prediction is! _PlaceSuggestion) return;
    final address = prediction.description;
    if (address.isEmpty) return;
    _isSelectingPlace = true;
    if (mounted) {
      setState(() {
        _predictions = [];
        _predictionsLoading = true;
      });
    }
    try {
      final locations = await geo.locationFromAddress(address);
      if (!mounted) return;
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final lat = loc.latitude;
        final lng = loc.longitude;
        if (lat.isFinite && lng.isFinite) {
          setState(() {
            _centerLat = lat;
            _centerLng = lng;
            _addressController.text = address;
            _predictions = [];
            _predictionsLoading = false;
            _locationSet = true;
          });
          _updateMapCamera();
        } else {
          setState(() => _predictionsLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find location for this address')),
          );
        }
      } else {
        setState(() => _predictionsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find location for this address')),
        );
      }
    } catch (e, st) {
      assert(() {
        debugPrint('ServiceAreaPicker geocoding error: $e $st');
        return true;
      }());
      if (mounted) {
        setState(() => _predictionsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find location for this address')),
        );
      }
    } finally {
      _isSelectingPlace = false;
    }
  }

  void _updateMapCamera() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        _boundsFromRadius(_centerLat, _centerLng, _radiusKm),
        80,
      ),
    );
  }

  void _animateRadiusTo(double targetKm) {
    _radiusAnim = Tween<double>(
      begin: _displayRadiusKm,
      end: targetKm,
    ).animate(CurvedAnimation(parent: _radiusAnimController, curve: Curves.easeOutCubic));
    _radiusAnimController
      ..stop()
      ..forward(from: 0);
  }

  LatLngBounds _boundsFromRadius(double lat, double lng, double radiusKm) {
    const kmPerDegreeLat = 111.0;
    final kmPerDegreeLng = 111.0 * cos(lat * pi / 180).clamp(0.01, 1.0);
    final dLat = radiusKm / kmPerDegreeLat;
    final dLng = radiusKm / kmPerDegreeLng;
    return LatLngBounds(
      southwest: LatLng(lat - dLat, lng - dLng),
      northeast: LatLng(lat + dLat, lng + dLng),
    );
  }

  /// Open the details screen (name, email, address). User fills form and confirms → Role Choice.
  Future<void> _goToDetailsScreen() async {
    String cityName = '';
    try {
      final placemarks = await geo.placemarkFromCoordinates(_centerLat, _centerLng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        cityName = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? '';
      }
    } catch (_) {}
    if (!mounted) return;
    final extra = <String, dynamic>{
      'latitude': _centerLat,
      'longitude': _centerLng,
      'radiusKm': _radiusKm,
      'addressLabel': _addressController.text.trim(),
      'city': cityName,
    };
    try {
      context.push(RouteNames.serviceAreaDetails, extra: extra);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not continue: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = !_locationSet ? 1 : (!_radiusSet ? 2 : 3);
    return PopScope(
      canPop: true,
      child: Scaffold(
      backgroundColor: _ServiceAreaDesign.surfaceBg,
      resizeToAvoidBottomInset: false,
      body: Material(
        color: _ServiceAreaDesign.surfaceBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_centerLat, _centerLng),
                zoom: 12,
              ),
              onMapCreated: (c) {
                _mapController = c;
                if (_locationSet) _updateMapCamera();
              },
              circles: {
                Circle(
                  circleId: const CircleId('service_area'),
                  center: LatLng(_centerLat, _centerLng),
                  radius: _displayRadiusKm * 1000,
                  fillColor: _ServiceAreaDesign.saffronPrimary.withValues(alpha: 0.14),
                  strokeColor: _ServiceAreaDesign.saffronPrimary,
                  strokeWidth: 2,
                ),
              },
              markers: {
                Marker(
                  markerId: const MarkerId('service_center'),
                  position: LatLng(_centerLat, _centerLng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                  infoWindow: const InfoWindow(title: 'DG Service Area'),
                ),
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              myLocationEnabled: true,
            ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildAppBar(),
            ),
            _buildSearchBarSection(),
            if (_predictions.isNotEmpty) _buildPredictionsList(),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 0, right: 0, bottom: 16),
                child: _buildBottomSection(step),
              ),
            ),
          ),
          ],
        ),
      ),
    ));
  }

  Widget _buildAppBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    return GlassContainer(
      borderRadius: 0,
      blurSigma: 24,
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 16),
      color: Colors.white.withValues(alpha: 0.28),
      borderColor: Colors.white.withValues(alpha: 0.4),
      borderWidth: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where do you want to serve?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ServiceAreaDesign.textHeadline,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select your service area',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _ServiceAreaDesign.textMuted,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildSearchBarSection() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 100,
      left: 20,
      right: 20,
      child: GlassContainer(
        borderRadius: 20,
        blurSigma: 18,
        padding: EdgeInsets.zero,
        color: Colors.white.withValues(alpha: 0.15),
        borderColor: _ServiceAreaDesign.saffronBorder,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        child: _buildSearchBar(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _addressController,
      focusNode: _searchFocusNode,
      style: GoogleFonts.plusJakartaSans(fontSize: 16, color: _ServiceAreaDesign.textHeadline),
      decoration: InputDecoration(
        hintText: 'Search location',
        hintStyle: GoogleFonts.plusJakartaSans(color: _ServiceAreaDesign.textMuted, fontSize: 15),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: _ServiceAreaDesign.saffronPrimary.withValues(alpha: 0.85),
          size: 22,
        ),
        suffixIcon: _predictionsLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: _ServiceAreaDesign.textMuted),
                onPressed: () {
                  if (mounted) {
                    setState(() {
                    _predictions = [];
                    _addressController.clear();
                  });
                  }
                },
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPredictionsList() {
    final topBarHeight = MediaQuery.of(context).padding.top + 168;
    return Positioned(
      top: topBarHeight,
      left: 20,
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shrinkWrap: true,
          itemCount: _predictions.length,
          itemBuilder: (_, i) {
          final p = _predictions[i];
          final title = p is _PlaceSuggestion ? p.description : '';
          return ListTile(
            leading: Icon(
              Icons.place_rounded,
              size: 20,
              color: _ServiceAreaDesign.saffronPrimary,
            ),
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: _ServiceAreaDesign.textHeadline),
            ),
            onTap: () => _onSelectPlace(p),
          );
          },
        ),
        ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildBottomSection(int step) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      child: SingleChildScrollView(
        child: GlassContainer(
          borderRadius: 20,
          blurSigma: 12,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          color: Colors.white.withValues(alpha: 0.15),
          borderColor: _ServiceAreaDesign.saffronBorder,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepIndicator(step),
              const SizedBox(height: 16),
              if (!_locationSet) _buildLocationStep(),
              if (_locationSet && !_radiusSet) _buildRadiusStep(),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildStepIndicator(int current) {
    return Row(
      children: [
        _StepDot(active: current >= 1, done: current > 1),
        _StepLine(active: current > 1),
        _StepDot(active: current >= 2, done: current > 2),
        _StepLine(active: current > 2),
        _StepDot(active: current >= 3, done: false),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Setting your location',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _loadingLocation
              ? 'Getting your current location...'
              : 'Use the search above to set your location on the map.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildRadiusStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Service radius',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How far are you willing to travel for jobs?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [5.0, 10.0, 20.0].map((preset) {
            final selected = _radiusKm.round() == preset.round();
            return ChoiceChip(
              label: Text('${preset.toStringAsFixed(0)} km'),
              selected: selected,
              showCheckmark: false,
              selectedColor: _ServiceAreaDesign.saffronPrimary,
              backgroundColor: Colors.white.withValues(alpha: 0.65),
              side: BorderSide(
                color: selected
                    ? _ServiceAreaDesign.saffronPrimary
                    : _ServiceAreaDesign.saffronBorder,
              ),
              labelStyle: TextStyle(
                color: selected ? Colors.white : _ServiceAreaDesign.textHeadline,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (_) {
                setState(() => _radiusKm = preset);
                _animateRadiusTo(preset);
                _updateMapCamera();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _ServiceAreaDesign.saffronPrimary,
                  inactiveTrackColor: _ServiceAreaDesign.saffronPrimary.withValues(alpha: 0.22),
                  thumbColor: _ServiceAreaDesign.saffronLight,
                  overlayColor: _ServiceAreaDesign.saffronPrimary.withValues(alpha: 0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                ),
                child: Slider(
                  value: _radiusKm,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  onChanged: (v) {
                    setState(() => _radiusKm = v);
                    _animateRadiusTo(v);
                    _updateMapCamera();
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              child: Text(
                '${_radiusKm.toStringAsFixed(0)} km',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: _loadingLocation ? null : _useCurrentLocation,
            icon: _loadingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Use my current location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
              side: const BorderSide(color: _ServiceAreaDesign.saffronBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedScale(
          scale: _continuePressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    _ServiceAreaDesign.saffronPrimary,
                    _ServiceAreaDesign.saffronLight,
                    Color(0xFFFFF8E6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _ServiceAreaDesign.saffronPrimary.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTapDown: (_) => setState(() => _continuePressed = true),
                  onTapUp: (_) => setState(() => _continuePressed = false),
                  onTapCancel: () => setState(() => _continuePressed = false),
                  onTap: _goToDetailsScreen,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active, required this.done});
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active
            ? _ServiceAreaDesign.saffronPrimary
            : _ServiceAreaDesign.textMuted.withValues(alpha: 0.3),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        color: active
            ? _ServiceAreaDesign.saffronPrimary
            : _ServiceAreaDesign.textMuted.withValues(alpha: 0.2),
      ),
    );
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion(this.description);
  final String description;
}
