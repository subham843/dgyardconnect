import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/config/maps_js_loader.dart';
import '../../shared/models/job_model.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';
import '../shared/chat_screen.dart' as shared_chat;

const double _defaultLat = 20.5937;
const double _defaultLng = 78.9629;

String _travelModeLabel(String? mode) {
  if (mode == null) return '—';
  switch (mode) {
    case 'bicycling': return 'Bike';
    case 'driving': return 'Car';
    case 'walking': return 'Walk';
    default: return mode;
  }
}

String _executionPhaseLabel(String? phase) {
  if (phase == null) return '—';
  switch (phase) {
    case 'going_to_pickup': return 'Going to pickup';
    case 'at_pickup': return 'At pickup location';
    case 'going_to_job': return 'Going to job';
    case 'at_job': return 'Reached job location';
    default: return phase;
  }
}

/// Embedded dealer view: map with technician live location, call, chat, travel mode, reach status.
class DealerJobTrackingView extends StatefulWidget {
  const DealerJobTrackingView({
    super.key,
    required this.jobId,
    required this.job,
    required this.jobData,
    this.showAsFullScreen = false,
    this.mapHeight = 280,
    this.onBack,
  });
  final String jobId;
  final JobModel job;
  final Map<String, dynamic> jobData;
  final bool showAsFullScreen;
  final double mapHeight;
  final VoidCallback? onBack;

  @override
  State<DealerJobTrackingView> createState() => _DealerJobTrackingViewState();
}

class _DealerJobTrackingViewState extends State<DealerJobTrackingView> {
  GoogleMapController? _mapController;
  double? _lastTechLat;
  double? _lastTechLng;

  @override
  void initState() {
    super.initState();
    ensureGoogleMapsJsLoaded();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _followTechnician(double lat, double lng) {
    _lastTechLat = lat;
    _lastTechLng = lng;
    _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
  }

  List<Widget> _buildLivePhotosSection(BuildContext context, Map<String, dynamic> jobData) {
    final proofPhotos = (jobData['proofPhotos'] as List<dynamic>?) ?? [];
    final pickupMaterialPhotos = (jobData['pickupMaterialPhotos'] as List<dynamic>?) ?? [];
    final beforePhotos = proofPhotos.where((p) => (p as Map)['type'] == 'before').toList();
    var pickupBeforePhotos = proofPhotos.where((p) => (p as Map)['type'] == 'pickup_before').toList();
    if (pickupBeforePhotos.isEmpty && pickupMaterialPhotos.isNotEmpty) {
      pickupBeforePhotos = pickupMaterialPhotos;
    }
    if (beforePhotos.isEmpty && pickupBeforePhotos.isEmpty) return [];

    Widget imageCard(String url, String label, double? lat, double? lng) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => TappableImage.show(context, url: url, latitude: lat, longitude: lng),
          borderRadius: BorderRadius.circular(8),
          child: Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(right: 10.0),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 100,
                    width: 100,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, _, _) => const Icon(Icons.broken_image, size: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 100,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final sections = <Widget>[];
    if (beforePhotos.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 16),
        Text('Photos at job location', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: beforePhotos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10.0),
            itemBuilder: (_, i) {
              final p = beforePhotos[i] as Map;
              final url = p['url'] as String?;
              if (url == null || url.isEmpty) return const SizedBox.shrink();
              return imageCard(url, 'Before', (p['latitude'] as num?)?.toDouble(), (p['longitude'] as num?)?.toDouble());
            },
          ),
        ),
      ]);
    }
    if (pickupBeforePhotos.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 16),
        Text('Photos at pickup location', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: pickupBeforePhotos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10.0),
            itemBuilder: (_, i) {
              final p = pickupBeforePhotos[i] as Map;
              final url = (p['url'] as String?) ?? (p['photoUrl'] as String?);
              if (url == null || url.isEmpty) return const SizedBox.shrink();
              final label = p['itemName'] as String? ?? 'Item ${i + 1}';
              return imageCard(url, label, (p['latitude'] as num?)?.toDouble(), (p['longitude'] as num?)?.toDouble());
            },
          ),
        ),
      ]);
    }
    return sections;
  }

  Future<void> _callTechnician(BuildContext context) async {
    if (Firebase.apps.isEmpty) return;
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connecting...')),
        );
      }
      final result = await FirebaseFunctions.instance
          .httpsCallable('initMaskedCall')
          .call({'jobId': widget.jobId});
      if (context.mounted) {
        final msg = (result.data is Map && (result.data as Map)['message'] != null)
            ? (result.data as Map)['message'] as String
            : 'Call initiated.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveLocation = widget.jobData['technicianLiveLocation'] as Map<String, dynamic>?;
    final techLat = (liveLocation?['latitude'] as num?)?.toDouble();
    final techLng = (liveLocation?['longitude'] as num?)?.toDouble();
    var jobLat = (widget.jobData['jobLat'] as num?)?.toDouble();
    var jobLng = (widget.jobData['jobLng'] as num?)?.toDouble();
    if (jobLat == null || jobLng == null) {
      final loc = widget.jobData['location'] as GeoPoint?;
      jobLat = loc?.latitude;
      jobLng = loc?.longitude;
    }
    final pickupLoc = widget.jobData['pickupLocation'] as GeoPoint?;
    final pickupLat = pickupLoc?.latitude;
    final pickupLng = pickupLoc?.longitude;
    final travelMode = widget.jobData['technicianTravelMode'] as String?;
    final execPhase = widget.jobData['executionPhase'] as String?;

    final centerLat = techLat ?? jobLat ?? _defaultLat;
    final centerLng = techLng ?? jobLng ?? _defaultLng;

    final markers = <Marker>{};
    if (techLat != null && techLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('technician'),
        position: LatLng(techLat, techLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Technician (live)'),
      ));
    }
    if (jobLat != null && jobLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('job'),
        position: LatLng(jobLat, jobLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.job.address ?? 'Job location'),
      ));
    }
    if (pickupLat != null && pickupLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickupLat, pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: widget.jobData['pickupAddress'] as String? ?? 'Pickup',
        ),
      ));
    }

    if (techLat != null && techLng != null && (_lastTechLat != techLat || _lastTechLng != techLng)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followTechnician(techLat, techLng));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.mapHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(centerLat, centerLng),
                zoom: 14,
              ),
              markers: markers,
              onMapCreated: (controller) {
                _mapController = controller;
                if (techLat != null && techLng != null) {
                  _followTechnician(techLat, techLng);
                }
              },
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (travelMode != null || execPhase != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (travelMode != null)
                Chip(
                  avatar: Icon(
                    travelMode == 'bicycling'
                        ? Icons.directions_bike
                        : travelMode == 'walking'
                            ? Icons.directions_walk
                            : Icons.directions_car,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(_travelModeLabel(travelMode)),
                ),
              if (execPhase != null)
                Chip(
                  avatar: Icon(
                    execPhase == 'at_job' ? Icons.check_circle : Icons.navigation,
                    size: 18,
                    color: execPhase == 'at_job' ? Colors.green : Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(_executionPhaseLabel(execPhase)),
                ),
            ],
          ),
        if (travelMode != null || execPhase != null) const SizedBox(height: 12),
        ..._buildLivePhotosSection(context, widget.jobData),
        Text(
          widget.job.address ?? 'Job location',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (techLat != null && techLng != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.gps_fixed, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 6),
                Text(
                  'Technician live',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Technician location will appear when they start.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _callTechnician(context),
                icon: const Icon(Icons.phone, size: 20),
                label: const Text('Call'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            if (widget.job.status != JobStatus.completed && widget.job.technicianId != null && widget.job.technicianId!.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => shared_chat.showChatPopup(context, widget.jobId),
                  icon: const Icon(Icons.chat, size: 20),
                  label: const Text('Chat'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
