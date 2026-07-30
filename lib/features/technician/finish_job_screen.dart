import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';
import '../../shared/widgets/technician_glass_kit.dart';

/// Finish job screen: after images (before-photo style), total job time, upload on button click.
/// After upload: Need material return, Get job finish OTP.
class FinishJobScreen extends StatefulWidget {
  const FinishJobScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<FinishJobScreen> createState() => _FinishJobScreenState();
}

class _FinishJobScreenState extends State<FinishJobScreen> {
  final List<_ImageItem> _afterImages = [];
  static const int _minImages = 3;
  static const int _maxImages = 10;
  bool _loading = false;
  bool _uploaded = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _elapsedSeconds(Map<String, dynamic> jobData) {
    final started = jobData['jobStartedAt'] as Timestamp?;
    if (started == null) return 0;
    final paused = jobData['isJobPaused'] as bool? ?? false;
    final pausedDuration = (jobData['jobPausedDurationSeconds'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();
    final startMs = started.toDate().millisecondsSinceEpoch;
    final nowMs = now.millisecondsSinceEpoch;
    int elapsed = ((nowMs - startMs) / 1000).floor() - pausedDuration;
    if (paused) {
      final pausedAt = jobData['jobPausedAt'] as Timestamp?;
      if (pausedAt != null) {
        final pauseMs = pausedAt.toDate().millisecondsSinceEpoch;
        elapsed -= ((nowMs - pauseMs) / 1000).floor();
      }
    }
    return elapsed > 0 ? elapsed : 0;
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> _captureImage() async {
    if (_afterImages.length >= _maxImages) {
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
          _afterImages.add(_ImageItem(
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
    setState(() => _afterImages.removeAt(index));
  }

  Future<void> _uploadAfterImages() async {
    if (_afterImages.length < _minImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 3 after images')),
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
      for (final i in _afterImages) {
        final file = File(i.filePath!);
        final url = await StorageService.uploadProofPhoto(
          jobId: widget.jobId,
          type: 'after',
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
          'type': 'after',
          'createdAt': DateTime.now(),
        };
        if (i.latitude != null) data['latitude'] = i.latitude;
        if (i.longitude != null) data['longitude'] = i.longitude;
        proofPhotos.add(data);
      }
      await FirestoreService.jobs().doc(widget.jobId).update({
        'proofPhotos': FieldValue.arrayUnion(proofPhotos),
      });
      if (mounted) {
        setState(() {
          _uploaded = true;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('After images uploaded successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _requestOtp() async {
    setState(() => _loading = true);
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('sendOtp').call({
        'jobId': widget.jobId,
        'purpose': 'job_complete',
      });
      final data = result.data;
      final devOtp = data is Map ? data['devOtp'] as String? : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              devOtp != null
                  ? 'OTP: $devOtp (SMS/FCM se nahi aaya to yahi use karein)'
                  : 'OTP sent to site contact.',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
        _showVerifyOtpDialog(devOtp: devOtp);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $msg')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showVerifyOtpDialog({String? devOtp}) {
    final codeController = TextEditingController(text: devOtp ?? '');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter OTP'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'OTP code',
            hintText: '6 digits',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              try {
                await FirebaseFunctions.instance
                    .httpsCallable('verifyOtp')
                    .call({
                  'jobId': widget.jobId,
                  'purpose': 'job_complete',
                  'code': code,
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  await FirestoreService.jobs().doc(widget.jobId).update({
                    'status': 'pending_dealer_confirm',
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Job submitted for dealer confirmation.')),
                    );
                    context.go('/technician/jobs/${widget.jobId}');
                  }
                }
              } catch (e) {
                if (ctx.mounted) {
                  final msg = e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Verification failed: $msg')),
                  );
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Finish job',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/technician/jobs/${widget.jobId}/execute'),
        ),
      ),
      body: TechnicianGlassBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobs().doc(widget.jobId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          if (!doc.exists) return const Center(child: Text('Job not found.'));
          final jobData = doc.data() ?? {};
          final elapsed = _elapsedSeconds(jobData);
          final proofPhotos = (jobData['proofPhotos'] as List<dynamic>?) ?? [];
          final hasAfterInFirestore = proofPhotos.any((p) => (p as Map)['type'] == 'after');
          final materialOpt = jobData['materialOption'] as String?;
          final hasMaterialPickup = materialOpt == 'pickup' &&
              (jobData['pickupMaterialList'] as List?)?.isNotEmpty == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Total job finish time (stopwatch)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer, color: Theme.of(context).colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total job time',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            Text(
                              _formatDuration(elapsed),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (!hasAfterInFirestore) ...[
                // After images section (before-photo style) – only when not already uploaded
                Text(
                  'Take minimum $_minImages and maximum $_maxImages after photos.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (_afterImages.isEmpty && !_loading)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap below to take your first after photo',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (_afterImages.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _afterImages.length,
                    itemBuilder: (context, index) {
                      final item = _afterImages[index];
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
                                  // Light glass badge (avoid dark overlay).
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
                                            color: Colors.black87, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          if (!_uploaded)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    // Light glass close circle.
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
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
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _captureImage,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    _afterImages.length >= _maxImages
                        ? 'Maximum reached'
                        : 'Take photo (${_afterImages.length}/$_maxImages)',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                // Upload after image button - uploads to Firebase only on click
                FilledButton.icon(
                  onPressed: _loading || _afterImages.length < _minImages
                      ? () {
                          if (_afterImages.length < _minImages) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please add at least 3 after images')),
                            );
                          }
                        }
                      : _uploadAfterImages,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload after image'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                ] else ...[
                  Card(
                    color: Colors.green.withValues(alpha: 0.1),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'After images already uploaded.',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Need material return & Get OTP - only after upload (or already in Firestore)
                // Need material return: only for jobs with material pickup added by dealer
                if (_uploaded || hasAfterInFirestore) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (hasMaterialPickup)
                    OutlinedButton.icon(
                      onPressed: () => context.push('/technician/jobs/${widget.jobId}/material-return'),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Need material return'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  if (hasMaterialPickup) const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _requestOtp,
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Get job finish OTP'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      )),
    );
  }
}

class _ImageItem {
  _ImageItem({this.filePath, this.latitude, this.longitude});
  final String? filePath;
  final double? latitude;
  final double? longitude;
}
