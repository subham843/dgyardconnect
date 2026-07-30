import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/config/maps_config.dart';
import '../../core/config/maps_js_loader.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import 'edit_profile_design.dart';

class TechnicianServiceAreaEditScreen extends StatefulWidget {
  const TechnicianServiceAreaEditScreen({super.key});

  @override
  State<TechnicianServiceAreaEditScreen> createState() =>
      _TechnicianServiceAreaEditScreenState();
}

class _TechnicianServiceAreaEditScreenState
    extends State<TechnicianServiceAreaEditScreen> {
  static const double _defaultLat = 20.5937;
  static const double _defaultLng = 78.9629;

  final _addressController = TextEditingController();
  final _searchFocusNode = FocusNode();
  double _centerLat = _defaultLat;
  double _centerLng = _defaultLng;
  double _radiusKm = 25;
  bool _loadingLocation = false;
  bool _saving = false;
  List<_PlaceSuggestion> _predictions = [];
  bool _predictionsLoading = false;
  bool _skipNextAutocomplete = false;
  bool _ignoreNextAutocompleteResult = false;
  Timer? _autocompleteDebounce;
  GoogleMapController? _mapController;
  bool _searchFocused = false;

  static const List<double> _radiusPresets = [5, 10, 20];

  @override
  void initState() {
    super.initState();
    ensureGoogleMapsJsLoaded();
    _loadCurrentServiceArea();
    _addressController.addListener(_onAddressChanged);
    _searchFocusNode.addListener(() {
      setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
  }

  void _onAddressChanged() {
    if (_skipNextAutocomplete) {
      _skipNextAutocomplete = false;
      setState(() => _predictions = []);
      return;
    }
    _autocompleteDebounce?.cancel();
    final query = _addressController.text.trim();
    if (query.isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    _autocompleteDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _fetchPlacesAutocomplete(query),
    );
  }

  void _moveMapToCenter() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(_centerLat, _centerLng), 14),
    );
  }

  Future<void> _fetchPlacesAutocomplete(String query) async {
    if (mapsApiKey.isEmpty) return;
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
      if (_ignoreNextAutocompleteResult) {
        _ignoreNextAutocompleteResult = false;
        setState(() => _predictionsLoading = false);
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final suggestionsList = data?['suggestions'] as List<dynamic>? ?? [];
      final results = <_PlaceSuggestion>[];
      for (final s in suggestionsList) {
        final map = s as Map<String, dynamic>?;
        if (map == null) continue;
        final placePred = map['placePrediction'] as Map<String, dynamic>?;
        final queryPred = map['queryPrediction'] as Map<String, dynamic>?;
        String? text;
        if (placePred != null) {
          final textObj = placePred['text'] as Map<String, dynamic>?;
          text = textObj?['text'] as String?;
        } else if (queryPred != null) {
          final textObj = queryPred['text'] as Map<String, dynamic>?;
          text = textObj?['text'] as String?;
        }
        if (text != null && text.isNotEmpty) {
          results.add(_PlaceSuggestion(text));
        }
      }
      setState(() {
        _predictions = results;
        _predictionsLoading = false;
      });
    } catch (_) {
      if (mounted) {
        if (_ignoreNextAutocompleteResult) _ignoreNextAutocompleteResult = false;
        setState(() {
          _predictions = [];
          _predictionsLoading = false;
        });
      }
    }
  }

  Future<void> _loadCurrentServiceArea() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    final doc = await FirestoreService.users().doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final sa = doc.data()!['serviceArea'] as Map<String, dynamic>?;
      if (sa != null) {
        final lat = (sa['latitude'] as num?)?.toDouble();
        final lng = (sa['longitude'] as num?)?.toDouble();
        final radius = (sa['radiusKm'] as num?)?.toDouble();
        final addressLabel = sa['addressLabel'] as String?;
        final city = sa['city'] as String?;
        if (lat != null && lng != null) {
          setState(() {
            _centerLat = lat;
            _centerLng = lng;
            _radiusKm = radius ?? 25;
            if (addressLabel != null && addressLabel.isNotEmpty) {
              _addressController.text = addressLabel;
            } else if (city != null && city.isNotEmpty) {
              _addressController.text = city;
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _autocompleteDebounce?.cancel();
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
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      setState(() {
        _centerLat = pos.latitude;
        _centerLng = pos.longitude;
        _loadingLocation = false;
        _predictions = [];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveMapToCenter();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location set from GPS. Adjust radius below and save.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppConstants.locationError} $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _onSelectPlace(_PlaceSuggestion prediction) async {
    setState(() => _predictionsLoading = true);
    try {
      final locations = await geo.locationFromAddress(prediction.description);
      if (!mounted) return;
      if (locations.isNotEmpty) {
        final loc = locations.first;
        _autocompleteDebounce?.cancel();
        _skipNextAutocomplete = true;
        _ignoreNextAutocompleteResult = true;
        setState(() {
          _centerLat = loc.latitude;
          _centerLng = loc.longitude;
          _predictions = [];
          _predictionsLoading = false;
        });
        _addressController.text = prediction.description;
        _searchFocusNode.unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _moveMapToCenter();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location set. Adjust radius below.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() => _predictionsLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find location for this address'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _predictionsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find location for this address'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    setState(() => _saving = true);
    try {
      String? cityName;
      try {
        final placemarks = await geo.placemarkFromCoordinates(_centerLat, _centerLng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          cityName = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
        }
      } catch (_) {}
      final addressLabel = _addressController.text.trim();
      await FirestoreService.users().doc(uid).update({
        'serviceArea': {
          'latitude': _centerLat,
          'longitude': _centerLng,
          'radiusKm': _radiusKm,
          if (cityName != null && cityName.isNotEmpty) 'city': cityName,
          if (addressLabel.isNotEmpty) 'addressLabel': addressLabel,
        },
      });
      if (mounted) {
        context.pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service area updated.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppConstants.errorGeneric} $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechnicianLightScope(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: TechnicianGlassBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_centerLat, _centerLng),
                    zoom: 12,
                  ),
                  circles: {
                    Circle(
                      circleId: const CircleId('service_area'),
                      center: LatLng(_centerLat, _centerLng),
                      radius: _radiusKm * 1000,
                      fillColor: AppColors.brandWarm.withValues(alpha: 0.14),
                      strokeColor: AppColors.brandWarm,
                      strokeWidth: 2,
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  myLocationEnabled: true,
                  onCameraMove: (pos) {
                    _centerLat = pos.target.latitude;
                    _centerLng = pos.target.longitude;
                    if (mounted) setState(() {});
                  },
                  onMapCreated: (c) => _mapController = c,
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 10),
                    _buildSearchBar(),
                    if (_predictions.isNotEmpty) _buildSuggestionsList(),
                  ],
                ),
              ),
              // Center pin remains fixed while map moves.
              IgnorePointer(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded, color: AppColors.brandWarmSoft, size: 42),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.brandWarmSoft,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandWarmLight.withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 270,
                child: _buildLocationFab(),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.3,
                minChildSize: 0.23,
                maxChildSize: 0.62,
                builder: (context, scrollController) {
                  return _buildBottomSheet(scrollController);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              ),
              Text(
                'Service Area',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: EditProfileDesign.textHeadline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(EditProfileDesign.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: EditProfileDesign.glassWhite,
            borderRadius: BorderRadius.circular(EditProfileDesign.radiusLg),
            border: Border.all(
              color: _searchFocused
                  ? AppColors.brandWarm.withValues(alpha: 0.55)
                  : AppColors.brandWarmBorder,
              width: _searchFocused ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: EditProfileDesign.shadowSoft,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: EditProfileDesign.shadowMedium,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _addressController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search city or address...',
              hintStyle: TextStyle(
                color: EditProfileDesign.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: Colors.transparent,
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _searchFocused
                    ? AppColors.brandWarmSoft
                    : EditProfileDesign.textMuted,
                size: 24,
              ),
              suffixIcon: _predictionsLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandWarm,
                        ),
                      ),
                    )
                  : _addressController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            size: 20,
                            color: EditProfileDesign.textMuted,
                          ),
                          onPressed: () {
                            _addressController.clear();
                            setState(() => _predictions = []);
                          },
                        )
                      : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: EditProfileDesign.cardBg,
        borderRadius: BorderRadius.circular(EditProfileDesign.radiusLg),
        boxShadow: [
          BoxShadow(
            color: EditProfileDesign.shadowSoft,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: EditProfileDesign.shadowMedium,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(EditProfileDesign.radiusLg),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: _predictions.length,
          itemBuilder: (_, i) {
            final p = _predictions[i];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onSelectPlace(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brandWarm.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.place_rounded,
                          size: 22,
                          color: AppColors.brandWarmSoft,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          p.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: EditProfileDesign.textHeadline,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: EditProfileDesign.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideY(begin: -0.02, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildLocationFab() {
    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: InkWell(
        onTap: _loadingLocation ? null : _useCurrentLocation,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: _loadingLocation
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandWarm,
                  ),
                )
              : Icon(
                  Icons.my_location_rounded,
                  size: 26,
                  color: AppColors.brandWarmSoft,
                ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8));
  }

  Widget _buildBottomSheet(ScrollController scrollController) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.brandWarmBorder),
        boxShadow: [
          BoxShadow(
            color: EditProfileDesign.shadowSoft,
            blurRadius: 32,
            offset: const Offset(0, -12),
          ),
          BoxShadow(
            color: EditProfileDesign.shadowMedium,
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EditProfileDesign.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Radius section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Service radius: ${_radiusKm.toStringAsFixed(0)} km',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: EditProfileDesign.textHeadline,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.brandWarmLight,
                          AppColors.brandWarm,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandWarmLight.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '${_radiusKm.toStringAsFixed(0)} km',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Covering nearby areas automatically',
                style: TextStyle(
                  fontSize: 13,
                  color: EditProfileDesign.textMuted,
                ),
              ),
              const SizedBox(height: 14),

              // Preset chips
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _radiusPresets.map((r) {
                  final isSelected = (_radiusKm - r).abs() < 1;
                  return GestureDetector(
                    onTap: () => setState(() => _radiusKm = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandWarmLight
                            : Colors.white.withValues(alpha: 0.74),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.brandWarm
                              : AppColors.brandWarmBorder,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '${r.toInt()} km',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : EditProfileDesign.textBody,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.brandWarm,
                  inactiveTrackColor: AppColors.brandWarm.withValues(alpha: 0.28),
                  thumbColor: AppColors.brandWarm,
                  overlayColor: AppColors.brandWarm.withValues(alpha: 0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                ),
                child: Slider(
                  value: _radiusKm,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  onChanged: (v) => setState(() => _radiusKm = v),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadingLocation ? null : _useCurrentLocation,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandWarmSoft,
                  side: BorderSide(color: AppColors.brandWarm.withValues(alpha: 0.75)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                label: const Text('Use my current location'),
              ),
              const SizedBox(height: 24),

              // Save button
              Material(
                elevation: 0,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.brandWarm,
                          AppColors.brandWarmLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandWarmLight.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Set Service Area',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

class _PlaceSuggestion {
  const _PlaceSuggestion(this.description);
  final String description;
}
