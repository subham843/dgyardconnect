import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';
import '../../shared/widgets/technician_glass_kit.dart';

/// Camera-only, geo-tagged image capture for before job/pickup.
/// Min 3, max 10 images. Gallery grid with delete. Start job when 3+ images.
class TakeSiteImageScreen extends StatefulWidget {
  const TakeSiteImageScreen({
    super.key,
    required this.jobId,
    required this.jobData,
    required this.imageType,
    required this.onStartJob,
    this.title = 'Take site images',
    this.buttonLabel = 'Start job',
    this.useScaffold = true,
  });

  final String jobId;
  final Map<String, dynamic> jobData;
  /// 'before' for job location, 'pickup_before' for pickup
  final String imageType;
  /// Receives proof photo data; parent handles Firestore update
  final Future<void> Function(List<Map<String, dynamic>> proofPhotos) onStartJob;
  final String title;
  final String buttonLabel;
  /// When false, only body content is shown (for embedding in parent Scaffold)
  final bool useScaffold;

  @override
  State<TakeSiteImageScreen> createState() => _TakeSiteImageScreenState();
}

class _TakeSiteImageScreenState extends State<TakeSiteImageScreen> {
  final List<_ImageItem> _images = [];
  static const int _minImages = 3;
  static const int _maxImages = 10;
  bool _loading = false;

  Future<void> _captureImage() async {
    if (_images.length >= _maxImages) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maximum $_maxImages images allowed.')),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      if (xfile == null || !mounted) {
        setState(() => _loading = false);
        return;
      }
      double? lat;
      double? lng;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
          } catch (_) {
            pos = await Geolocator.getLastKnownPosition();
          }
          if (pos != null) {
            lat = pos.latitude;
            lng = pos.longitude;
          }
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _images.add(_ImageItem(
            filePath: xfile.path,
            latitude: lat,
            longitude: lng,
          ));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _onStartJob() async {
    if (_images.length < _minImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 3 images')),
      );
      return;
    }
    if (!StorageService.isAvailable || !FirestoreService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firebase is not configured.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final proofPhotos = <Map<String, dynamic>>[];
      for (final i in _images) {
        final file = File(i.filePath!);
        final url = await StorageService.uploadProofPhoto(
          jobId: widget.jobId,
          type: widget.imageType,
          file: file,
        );
        if (url == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upload failed. Please try again.')),
            );
            setState(() => _loading = false);
          }
          return;
        }
        final data = <String, dynamic>{
          'url': url,
          'type': widget.imageType,
          'createdAt': DateTime.now(),
        };
        if (i.latitude != null) data['latitude'] = i.latitude;
        if (i.longitude != null) data['longitude'] = i.longitude;
        proofPhotos.add(data);
      }
      await widget.onStartJob(proofPhotos);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildContent() {
    return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Take minimum $_minImages and maximum $_maxImages photos. Camera only. Each photo will be geo-tagged.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: _images.isEmpty && !_loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap below to take your first photo',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final item = _images[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          TappableImage(
                            filePath: item.filePath,
                            latitude: item.latitude,
                            longitude: item.longitude,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(item.filePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image, size: 48),
                              ),
                            ),
                          ),
                          if (item.latitude != null && item.longitude != null)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  // Light glass badge (no dark overlay).
                                  color: Colors.white.withValues(alpha: 0.78),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on,
                                        color: Colors.greenAccent, size: 12),
                                    SizedBox(width: 2),
                                    Text('Geo',
                                        style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.black87,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _captureImage,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      _images.length >= _maxImages
                          ? 'Maximum reached'
                          : 'Take photo (${_images.length}/$_maxImages)',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading || _images.length < _minImages
                        ? () {
                            if (_images.length < _minImages) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Please add at least 3 images')),
                              );
                            }
                          }
                        : _onStartJob,
                    icon: const Icon(Icons.check_circle),
                    label: Text(widget.buttonLabel),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useScaffold) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: TechnicianGlassAppBar(title: widget.title),
        body: _buildContent(),
      );
    }
    return _buildContent();
  }
}

class _ImageItem {
  _ImageItem({this.filePath, this.latitude, this.longitude});
  final String? filePath;
  final double? latitude;
  final double? longitude;
}
