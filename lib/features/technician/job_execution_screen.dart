import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/maps_config.dart';
import '../../core/config/maps_js_loader.dart';
import '../../core/utils/date_utils.dart';

import '../../shared/models/job_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import 'take_site_image_screen.dart';
import '../shared/chat_screen.dart' as shared_chat;

class JobExecutionScreen extends StatefulWidget {
  const JobExecutionScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<JobExecutionScreen> createState() => _JobExecutionScreenState();
}

class _JobExecutionScreenState extends State<JobExecutionScreen> {
  Timer? _locationTimer;
  bool _locationUpdatesStarted = false;
  final _totalTravelKmController = TextEditingController();

  @override
  void dispose() {
    _locationTimer?.cancel();
    _totalTravelKmController.dispose();
    super.dispose();
  }

  void _startLocationUpdates() {
    if (_locationUpdatesStarted) return;
    _locationUpdatesStarted = true;
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _updateLiveLocation(),
    );
    _updateLiveLocation();
  }

  Future<void> _updateLiveLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.jobId.isEmpty || !FirestoreService.isAvailable) {
      return;
    }
    final isTechnician = await _isAssignedTechnician();
    if (!isTechnician) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      await FirestoreService.jobs().doc(widget.jobId).update({
        'technicianLiveLocation': {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
    } catch (_) {}
  }

  Future<bool> _isAssignedTechnician() async {
    final doc = await FirestoreService.jobs().doc(widget.jobId).get();
    final data = doc.data();
    return data?['technicianId'] == FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _markReachedPickupWithProof(List<Map<String, dynamic>> proofPhotos) async {
    await FirestoreService.jobs().doc(widget.jobId).update({
      'proofPhotos': FieldValue.arrayUnion(proofPhotos),
      'executionPhase': 'at_pickup',
    });
    if (mounted) setState(() {});
  }

  Future<void> _callCustomer(BuildContext context, String jobId) async {
    if (Firebase.apps.isEmpty) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecting...')),
      );
      final result = await FirebaseFunctions.instance
          .httpsCallable('initMaskedCall')
          .call({'jobId': jobId});
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

  Future<void> _requestOtp(BuildContext context, String purpose, {void Function()? onSuccess}) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('sendOtp').call({
        'jobId': widget.jobId,
        'purpose': purpose,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to contact.')));
        onSuccess?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send OTP: $e')));
      }
    }
  }

  void _showVerifyOtpDialog(BuildContext context, String purpose) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
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
                      'purpose': purpose,
                      'code': code,
                    });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('OTP verified.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Verification failed: $e')),
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
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: const TechnicianGlassAppBar(title: 'Job execution'),
        body: const TechnicianGlassBackground(
          child: Center(child: Text('Firebase is not configured.')),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: TechnicianGlassAppBar(
        title: 'Job execution',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/technician/jobs/${widget.jobId}'),
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
          final job = JobModel.fromFirestore(doc);
          final jobData = doc.data() ?? {};
          final materialOpt = jobData['materialOption'] as String?;
          final execPhase = jobData['executionPhase'] as String?;
          if (job.status == JobStatus.inProgress && _locationTimer == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _startLocationUpdates(),
            );
          }
          final showPickupMap = materialOpt == 'pickup' &&
              (execPhase == null || execPhase == 'going_to_pickup');
          if (showPickupMap) {
            return _PickupPhaseGoingTo(
              jobId: widget.jobId,
              jobData: jobData,
              onStartJobWithProof: _markReachedPickupWithProof,
            );
          }
          // No-pickup: show directions map directly (same as Directions button)
          final showJobMap = execPhase == 'going_to_job' ||
              (execPhase == null && materialOpt != 'pickup');
          if (showJobMap) {
            return _JobLocationMapFullScreen(
              jobId: widget.jobId,
              jobData: jobData,
              onStartJobWithProof: (proofPhotos) async {
                final updateData = <String, dynamic>{
                  'proofPhotos': FieldValue.arrayUnion(proofPhotos),
                  'executionPhase': 'at_job',
                  'jobStartedAt': FieldValue.serverTimestamp(),
                };
                if (job.status == JobStatus.paid) {
                  updateData['status'] = 'in_progress';
                }
                await FirestoreService.jobs().doc(widget.jobId).update(updateData);
                if (mounted) setState(() {});
              },
            );
          }
          if (materialOpt == 'pickup' && execPhase == 'at_pickup') {
            return _PickupPhaseAtPickupWithMap(
              jobId: widget.jobId,
              jobData: jobData,
              onRequestOtp: () => _requestOtp(context, 'pickup', onSuccess: () => _showVerifyOtpDialog(context, 'pickup')),
              onVerifyOtp: () => _showVerifyOtpDialog(context, 'pickup'),
            );
          }
          // Show handover phase only after job complete OTP (status != in_progress)
          if (jobData['materialReturnRequested'] == true &&
              jobData['materialHandoverLocation'] != null &&
              job.status != JobStatus.inProgress) {
            return _MaterialReturnHandoverPhase(
              jobId: widget.jobId,
              jobData: jobData,
              onRequestOtp: () => _requestOtp(context, 'material_return_confirm'),
            );
          }
          final atJobInProgress =
              execPhase == 'at_job' && job.status == JobStatus.inProgress;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (atJobInProgress) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Your activities share with dealer msg',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  _JobAtLocationContent(
                    jobId: widget.jobId,
                    jobData: jobData,
                    totalTravelKmController: _totalTravelKmController,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              shared_chat.showChatPopup(context, widget.jobId),
                          icon: const Icon(Icons.chat),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callCustomer(context, widget.jobId),
                          icon: const Icon(Icons.phone),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  if (materialOpt == 'material_by_technician') ...[
                    _MaterialListCard(jobData: jobData),
                    const SizedBox(height: 16),
                  ],
                  if (materialOpt == 'pickup')
                    _StepTile(
                      title: 'Material pickup',
                      subtitle: execPhase == 'going_to_job' || execPhase == 'at_job'
                          ? 'Done – going to job'
                          : 'Photo + OTP confirmation',
                      done: execPhase == 'going_to_job' || execPhase == 'at_job' ||
                          jobData['pickupConfirmed'] == true,
                    ),
                  if (materialOpt == 'pickup' &&
                      (execPhase == 'going_to_job' || execPhase == 'at_job'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Pickup confirmed. Proceed to job location.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green),
                      ),
                    ),
                  if (job.status == JobStatus.paid) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _updateStatus(context, job.status),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Start job'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              shared_chat.showChatPopup(context, widget.jobId),
                          icon: const Icon(Icons.chat),
                          label: const Text('Chat'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callCustomer(context, widget.jobId),
                          icon: const Icon(Icons.phone),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      )),
    );
  }

  Future<void> _updateStatus(BuildContext context, JobStatus current) async {
    if (current == JobStatus.paid) {
      final doc = await FirestoreService.jobs().doc(widget.jobId).get();
      final data = doc.data() ?? {};
      final materialOpt = data['materialOption'] as String?;
      final updateData = <String, dynamic>{
        'status': 'in_progress',
      };
      if (materialOpt == 'pickup') {
        updateData['executionPhase'] = 'going_to_pickup';
      } else {
        updateData['executionPhase'] = 'going_to_job';
      }
      await FirestoreService.jobs().doc(widget.jobId).update(updateData);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Job started.')));
      }
    } else if (current == JobStatus.inProgress) {
      _locationTimer?.cancel();
      if (mounted) setState(() => _locationTimer = null);
      final totalTravelKm = double.tryParse(
        _totalTravelKmController.text.trim(),
      );
      final updateData = <String, dynamic>{
        'status': 'pending_dealer_confirm',
        'completedAt': FieldValue.serverTimestamp(),
      };
      if (totalTravelKm != null && totalTravelKm > 0) {
        updateData['totalTravelKm'] = totalTravelKm;
      }
      await FirestoreService.jobs().doc(widget.jobId).update(updateData);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job submitted for dealer confirmation.'),
          ),
        );
        context.go('/technician/jobs/${widget.jobId}');
      }
    }
  }
}

/// Content shown when technician is at job location (execPhase == at_job)
class _JobAtLocationContent extends StatefulWidget {
  const _JobAtLocationContent({
    required this.jobId,
    required this.jobData,
    required this.totalTravelKmController,
  });
  final String jobId;
  final Map<String, dynamic> jobData;
  final TextEditingController totalTravelKmController;

  @override
  State<_JobAtLocationContent> createState() => _JobAtLocationContentState();
}

class _JobAtLocationContentState extends State<_JobAtLocationContent> {
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

  int _elapsedSeconds() {
    final started = widget.jobData['jobStartedAt'] as Timestamp?;
    if (started == null) return 0;
    final paused = widget.jobData['isJobPaused'] as bool? ?? false;
    final pausedDuration = (widget.jobData['jobPausedDurationSeconds'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();
    final startMs = started.toDate().millisecondsSinceEpoch;
    final nowMs = now.millisecondsSinceEpoch;
    int elapsed = ((nowMs - startMs) / 1000).floor() - pausedDuration;
    if (paused) {
      final pausedAt = widget.jobData['jobPausedAt'] as Timestamp?;
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

  Future<void> _togglePause() async {
    final paused = widget.jobData['isJobPaused'] as bool? ?? false;
    if (paused) {
      final pausedAt = widget.jobData['jobPausedAt'] as Timestamp?;
      final currentPaused = (widget.jobData['jobPausedDurationSeconds'] as num?)?.toInt() ?? 0;
      int addSec = 0;
      if (pausedAt != null) {
        addSec = DateTime.now().difference(pausedAt.toDate()).inSeconds;
      }
      await FirestoreService.jobs().doc(widget.jobId).update({
        'isJobPaused': false,
        'jobPausedAt': FieldValue.delete(),
        'jobPausedDurationSeconds': currentPaused + addSec,
      });
    } else {
      await FirestoreService.jobs().doc(widget.jobId).update({
        'isJobPaused': true,
        'jobPausedAt': FieldValue.serverTimestamp(),
      });
    }
    if (mounted) setState(() {});
  }

  void _showJobDetails(BuildContext context) {
    final job = widget.jobData;
    final dealerId = job['dealerId'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 1,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: _JobDetailsContent(jobId: widget.jobId, jobData: job, dealerId: dealerId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paused = widget.jobData['isJobPaused'] as bool? ?? false;
    final elapsed = _elapsedSeconds();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Elapsed time', style: Theme.of(context).textTheme.labelMedium),
                    Text(_formatDuration(elapsed), style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _togglePause,
                  icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                  label: Text(paused ? 'Resume job' : 'Job pause'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showJobDetails(context),
          icon: const Icon(Icons.info_outline, size: 18),
          label: const Text('View job details'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        FilledButton.icon(
          onPressed: () async {
            final paused = widget.jobData['isJobPaused'] as bool? ?? false;
            if (!paused) {
              await FirestoreService.jobs().doc(widget.jobId).update({
                'isJobPaused': true,
                'jobPausedAt': FieldValue.serverTimestamp(),
              });
            }
            if (mounted) context.push('/technician/jobs/${widget.jobId}/finish');
          },
          icon: const Icon(Icons.check_circle),
          label: const Text('Finish job'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ],
    );
  }
}

class _MaterialListCard extends StatelessWidget {
  const _MaterialListCard({required this.jobData});
  final Map<String, dynamic> jobData;

  @override
  Widget build(BuildContext context) {
    final list = (jobData['materialList'] as List<dynamic>?) ?? [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Material by technician', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...list.map((e) {
              final m = e as Map<String, dynamic>;
              final amt = (m['amount'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${m['itemName'] ?? ''} × ${m['qty'] ?? 1} @ ₹${m['rate'] ?? 0} = ₹${amt.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

String _formatGeoPoint(dynamic loc) {
  if (loc is GeoPoint) {
    return '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}';
  }
  return '—';
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Text(value.isEmpty ? '—' : value)),
      ],
    ),
  );
}

class _JobDetailsContent extends StatelessWidget {
  const _JobDetailsContent({
    required this.jobId,
    required this.jobData,
    required this.dealerId,
  });
  final String jobId;
  final Map<String, dynamic> jobData;
  final String dealerId;

  @override
  Widget build(BuildContext context) {
    final job = jobData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Job details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _detailRow('Title', job['title'] as String? ?? '—'),
        _detailRow('Description', job['description'] as String? ?? '—'),
        _detailRow('Status', (job['status'] as String?) ?? '—'),
        _detailRow('Execution phase', (job['executionPhase'] as String?) ?? '—'),
        _detailRow('Created', AppDateUtils.formatDateTime((job['createdAt'] as Timestamp?)?.toDate())),
        const Divider(height: 24),
        Text('Dealer details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (dealerId.isNotEmpty)
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.users().doc(dealerId).snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData || !snap.data!.exists) {
                return _detailRow('Dealer', 'Loading...');
              }
              final d = snap.data!.data() ?? {};
              final profile = d['profile'] as Map<String, dynamic>?;
              final name = profile?['name'] as String? ?? '—';
              final businessName = profile?['businessName'] as String? ?? '—';
              final dealerAddr = profile?['address'] as String? ?? '—';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _detailRow('Name', name),
                  if (businessName.isNotEmpty) _detailRow('Business', businessName),
                  if (dealerAddr.isNotEmpty) _detailRow('Dealer address', dealerAddr),
                  _detailRow('Level', (d['dealerLevel'] as String?) ?? '—'),
                  _detailRow('Rating', (d['avgRating'] as num?)?.toStringAsFixed(1) ?? '—'),
                ],
              );
            },
          )
        else
          _detailRow('Dealer', '—'),
        const Divider(height: 24),
        Text('Price & bidding', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _detailRow('Dealer rate', '₹${(job['dealerRate'] as num?)?.toStringAsFixed(0) ?? '—'}'),
        _detailRow('Agreed amount', '₹${(job['agreedAmount'] as num?)?.toStringAsFixed(0) ?? '—'}'),
        _detailRow('Your payout', () {
          final amt = (job['technicianPayoutAmount'] as num?) ?? (job['agreedAmount'] as num?);
          return amt != null ? '₹${amt.toStringAsFixed(0)}' : '—';
        }()),
        _detailRow('Platform charge', '₹${(job['platformChargeAmount'] as num?)?.toStringAsFixed(0) ?? '—'}'),
        _detailRow('Last technician bid', (job['lastTechnicianBidAmount'] != null) ? '₹${(job['lastTechnicianBidAmount'] as num).toStringAsFixed(0)}' : '—'),
        _detailRow('Dealer counter', (job['dealerCounterAmount'] != null) ? '₹${(job['dealerCounterAmount'] as num).toStringAsFixed(0)}' : '—'),
        _detailRow('Warranty period', (job['warrantyPeriod'] != null) ? '${job['warrantyPeriod']} days' : (job['warrantyPeriodDays'] != null) ? '${job['warrantyPeriodDays']} days' : '—'),
        const Divider(height: 24),
        Text('Job location', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _detailRow('Address', job['address'] as String? ?? '—'),
        _detailRow('Coordinates', _formatGeoPoint(job['location'])),
        _detailRow('Site contact', job['siteContactName'] as String? ?? '—'),
        const Divider(height: 24),
        Text('Material handling', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _detailRow('Option', (job['materialOption'] as String?) ?? '—'),
        if ((job['pickupAddress'] as String?)?.isNotEmpty == true) ...[
          _detailRow('Pickup address', job['pickupAddress'] as String? ?? '—'),
          _detailRow('Pickup contact', job['pickupContactName'] as String? ?? '—'),
        ],
        if ((job['pickupMaterialList'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text('Pickup materials', style: Theme.of(context).textTheme.titleSmall),
          ...((job['pickupMaterialList'] as List).map((e) {
            final m = e as Map;
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• ${m['itemName'] ?? ''} × ${m['qty'] ?? 1}'),
            );
          })),
        ],
        if ((job['materialList'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text('Material by technician', style: Theme.of(context).textTheme.titleSmall),
          ...((job['materialList'] as List).map((e) {
            final m = e as Map;
            final rate = (m['rate'] as num?)?.toDouble();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• ${m['itemName'] ?? ''} × ${m['qty'] ?? 1}${rate != null ? ' @ ₹${rate.toStringAsFixed(0)}' : ''}',
              ),
            );
          })),
        ],
        if (job['materialHandoverAddress'] != null) ...[
          const SizedBox(height: 8),
          _detailRow('Handover address', job['materialHandoverAddress'] as String? ?? '—'),
        ],
        const Divider(height: 24),
        Text('Job timing', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _detailRow('Job started at', AppDateUtils.formatDateTime((job['jobStartedAt'] as Timestamp?)?.toDate())),
        _detailRow('Technician navigation started', AppDateUtils.formatDateTime((job['technicianNavigationStartedAt'] as Timestamp?)?.toDate())),
        _detailRow('Completed at', AppDateUtils.formatDateTime((job['completedAt'] as Timestamp?)?.toDate())),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.title,
    required this.subtitle,
    required this.done,
  });
  final String title;
  final String subtitle;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: done
              ? Colors.green
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            done ? Icons.check : Icons.pending,
            color: done ? Colors.white : null,
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

List<LatLng> _decodePolyline(String encoded) {
  final points = <LatLng>[];
  int index = 0;
  int lat = 0;
  int lng = 0;
  while (index < encoded.length) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;
    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}

class _RouteStep {
  _RouteStep(this.instruction, this.distanceText);
  final String instruction;
  final String distanceText;
}

String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .trim();
}

/// Distance in meters within which technician is considered "at location"
const _arrivalThresholdMeters = 100.0;

/// Full-screen job location map (Directions with Car/Bike/Walk) - shown when no pickup
/// When within 100m, shows Take Site Image screen instead of reach button
class _JobLocationMapFullScreen extends StatefulWidget {
  const _JobLocationMapFullScreen({
    required this.jobId,
    required this.jobData,
    required this.onStartJobWithProof,
  });
  final String jobId;
  final Map<String, dynamic> jobData;
  final Future<void> Function(List<Map<String, dynamic>> proofPhotos) onStartJobWithProof;

  @override
  State<_JobLocationMapFullScreen> createState() => _JobLocationMapFullScreenState();
}

class _JobLocationMapFullScreenState extends State<_JobLocationMapFullScreen> {
  bool _isNearJobLocation = false;
  double? _distanceToJobMeters;
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    _locationSub?.cancel();
    final destLoc = widget.jobData['location'] as GeoPoint?;
    if (destLoc == null) {
      if (mounted) setState(() => _isNearJobLocation = true);
      return;
    }
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      final distM = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        destLoc.latitude, destLoc.longitude,
      );
      if (mounted) {
        setState(() {
          _distanceToJobMeters = distM;
          if (distM <= _arrivalThresholdMeters) _isNearJobLocation = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isNearJobLocation) {
      return TakeSiteImageScreen(
        jobId: widget.jobId,
        jobData: widget.jobData,
        imageType: 'before',
        onStartJob: widget.onStartJobWithProof,
        title: 'Take site images',
        buttonLabel: 'Start job',
        useScaffold: false,
      );
    }
    final loc = widget.jobData['location'] as GeoPoint?;
    final lat = loc?.latitude ?? 20.5937;
    final lng = loc?.longitude ?? 78.9629;
    final addr = widget.jobData['address'] as String? ?? 'Job location';
    return Column(
      children: [
        Expanded(
          child: _MapWithRouteSheet(
            jobId: widget.jobId,
            destLat: lat,
            destLng: lng,
            address: addr,
            title: 'Job location',
            markerTitle: 'Job site',
            hideHeader: true,
          ),
        ),
        SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  _distanceToJobMeters != null
                      ? 'Reach within ${_arrivalThresholdMeters.toInt()}m to continue (${(_distanceToJobMeters! / 1000).toStringAsFixed(1)} km away)'
                      : 'Tracking your location...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Material return handover: navigate to location, add after images, get OTP
class _MaterialReturnHandoverPhase extends StatefulWidget {
  const _MaterialReturnHandoverPhase({
    required this.jobId,
    required this.jobData,
    required this.onRequestOtp,
  });
  final String jobId;
  final Map<String, dynamic> jobData;
  final VoidCallback onRequestOtp;

  @override
  State<_MaterialReturnHandoverPhase> createState() => _MaterialReturnHandoverPhaseState();
}

class _MaterialReturnHandoverPhaseState extends State<_MaterialReturnHandoverPhase> {
  bool _isNearHandover = false;
  double? _distanceMeters;
  StreamSubscription<Position>? _locationSub;
  final Map<int, String> _afterPhotoUrls = {};

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    final loc = widget.jobData['materialHandoverLocation'];
    if (loc is! GeoPoint) {
      if (mounted) setState(() => _isNearHandover = true);
      return;
    }
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      final distM = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        loc.latitude, loc.longitude,
      );
      if (mounted) {
        setState(() {
          _distanceMeters = distM;
          if (distM <= _arrivalThresholdMeters) _isNearHandover = true;
        });
      }
    });
  }

  Future<void> _markReachedHandover() async {
    await FirestoreService.jobs().doc(widget.jobId).update({
      'executionPhase': 'at_handover',
    });
    if (mounted) setState(() {});
  }

  Future<void> _addAfterPhoto(int index) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      if (xfile == null || !mounted) return;
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
      final file = File(xfile.path);
      final url = await StorageService.uploadMaterialReturnAfterPhoto(
        jobId: widget.jobId,
        index: index,
        file: file,
      );
      if (url != null && mounted) {
        setState(() => _afterPhotoUrls[index] = url);
        final items = List<Map<String, dynamic>>.from(
            (widget.jobData['materialReturnItems'] as List<dynamic>?) ?? []);
        if (index < items.length) {
          final update = {...items[index], 'afterPhotoUrl': url};
          if (lat != null) update['afterPhotoLat'] = lat;
          if (lng != null) update['afterPhotoLng'] = lng;
          items[index] = update;
          await FirestoreService.jobs().doc(widget.jobId).update({
            'materialReturnItems': items,
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final execPhase = widget.jobData['executionPhase'] as String?;
    final atHandover = execPhase == 'at_handover';
    final items = (widget.jobData['materialReturnItems'] as List<dynamic>?) ?? [];
    final allHaveAfter = items.asMap().entries.every((e) {
      final m = e.value as Map;
      return _afterPhotoUrls.containsKey(e.key) || m['afterPhotoUrl'] != null;
    });

    if (!atHandover) {
      final loc = widget.jobData['materialHandoverLocation'];
      GeoPoint? gp;
      if (loc is GeoPoint) gp = loc;
      final lat = gp?.latitude ?? 20.5937;
      final lng = gp?.longitude ?? 78.9629;
      final addr = widget.jobData['materialHandoverAddress'] as String? ?? 'Handover location';

      Future<void> openReturnDirection() async {
        final uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Return material at', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(addr, style: Theme.of(context).textTheme.bodyLarge),
              ),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Materials to return', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...items.map<Widget>((e) {
                final m = e as Map;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${m['name'] ?? ''} x${m['qty'] ?? 1}'),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            if (!_isNearHandover)
              FilledButton.icon(
                onPressed: openReturnDirection,
                icon: const Icon(Icons.navigation),
                label: const Text('Get return direction'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            if (_isNearHandover) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _markReachedHandover,
                icon: const Icon(Icons.location_on),
                label: const Text('Reached at handover location'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _distanceMeters != null
                          ? 'Reach within ${_arrivalThresholdMeters.toInt()}m (${(_distanceMeters! / 1000).toStringAsFixed(1)} km away)'
                          : 'Tracking...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add after image for each material',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...List.generate(items.length, (i) {
            final item = items[i] as Map<String, dynamic>;
            final afterUrl = _afterPhotoUrls[i] ?? item['afterPhotoUrl'] as String?;
            final afterLat = (item['afterPhotoLat'] as num?)?.toDouble();
            final afterLng = (item['afterPhotoLng'] as num?)?.toDouble();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['name'] ?? ''} x${item['qty'] ?? 1}'),
                    const SizedBox(height: 8),
                    if (afterUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: SizedBox(
                          height: 80,
                          width: 80,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: GestureDetector(
                              onTap: () => TappableImage.show(context,
                                  url: afterUrl,
                                  latitude: afterLat,
                                  longitude: afterLng),
                              child: Image.network(afterUrl, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () => _addAfterPhoto(i),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Add after image'),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: allHaveAfter
                ? () {
                    widget.onRequestOtp();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('OTP sent to dealer. Dealer will verify to complete return.')),
                    );
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add after image for each material')),
                    );
                  },
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Get return confirm OTP'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}

class _PickupPhaseGoingTo extends StatefulWidget {
  const _PickupPhaseGoingTo({
    required this.jobId,
    required this.jobData,
    required this.onStartJobWithProof,
  });
  final String jobId;
  final Map<String, dynamic> jobData;
  final Future<void> Function(List<Map<String, dynamic>> proofPhotos) onStartJobWithProof;

  @override
  State<_PickupPhaseGoingTo> createState() => _PickupPhaseGoingToState();
}

class _PickupPhaseGoingToState extends State<_PickupPhaseGoingTo> {
  Set<Polyline> _polylines = {};
  List<_RouteStep> _steps = [];
  List<LatLng> _routePoints = [];
  bool _loadingRoute = true;
  bool _routeFailed = false;
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _locationSub;
  int _currentStepIndex = 0;
  Position? _lastPosition;
  LatLng? _initialUserPosition;
  LatLngBounds? _pendingRouteBounds;
  bool _isNearPickupLocation = false;
  bool _hasMarkedReached = false;
  double? _distanceToPickupMeters;

  @override
  void initState() {
    super.initState();
    ensureGoogleMapsJsLoaded();
    _startLocationTrackingForReachCheck();
    _fetchRoute();
  }

  void _startLocationTrackingForReachCheck() {
    _locationSub?.cancel();
    final destLoc = widget.jobData['pickupLocation'] as GeoPoint?;
    if (destLoc == null) {
      if (mounted) {
        setState(() => _isNearPickupLocation = true);
        if (!_hasMarkedReached) {
          _hasMarkedReached = true;
          widget.onStartJobWithProof([]);
        }
      }
      return;
    }
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      _lastPosition = pos;
      final distM = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        destLoc.latitude, destLoc.longitude,
      );
      if (mounted) {
        final justReached = !_isNearPickupLocation && distM <= _arrivalThresholdMeters;
        setState(() {
          _distanceToPickupMeters = distM;
          if (distM <= _arrivalThresholdMeters) _isNearPickupLocation = true;
        });
        if (justReached && !_hasMarkedReached) {
          _hasMarkedReached = true;
          widget.onStartJobWithProof([]);
        }
      }
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
      if (_routePoints.isNotEmpty && _steps.isNotEmpty) {
        int nearestIdx = 0;
        double minDist = double.infinity;
        for (int i = 0; i < _routePoints.length; i++) {
          final p = _routePoints[i];
          final d = (p.latitude - pos.latitude) * (p.latitude - pos.latitude) +
              (p.longitude - pos.longitude) * (p.longitude - pos.longitude);
          if (d < minDist) {
            minDist = d;
            nearestIdx = i;
          }
        }
        final stepIndex = (nearestIdx * _steps.length / _routePoints.length).floor().clamp(0, _steps.length - 1);
        if (stepIndex != _currentStepIndex && mounted) {
          setState(() => _currentStepIndex = stepIndex);
        }
      }
    });
  }

  Future<void> _fetchRoute() async {
    setState(() => _routeFailed = false);
    final loc = widget.jobData['pickupLocation'] as GeoPoint?;
    final destLat = loc?.latitude ?? 20.5937;
    final destLng = loc?.longitude ?? 78.9629;
    double? originLat;
    double? originLng;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      originLat = pos.latitude;
      originLng = pos.longitude;
      _lastPosition = pos;
      _initialUserPosition = LatLng(pos.latitude, pos.longitude);
    } catch (_) {}
    if (originLat == null || originLng == null || mapsApiKey.isEmpty) {
      if (mounted) {
        setState(() {
        _loadingRoute = false;
        _routeFailed = true;
      });
      }
      return;
    }
    try {
      final uri = directionsUri(originLat, originLng, destLat, destLng);
      final response = await http.get(uri);
      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final status = data?['status'] as String? ?? '';
        if (status != 'OK') {
          if (mounted) {
            setState(() {
            _loadingRoute = false;
            _routeFailed = true;
          });
          }
          return;
        }
        final routes = data?['routes'] as List<dynamic>? ?? [];
        if (routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final overview = route['overview_polyline'] as Map?;
          final encoded = overview?['points'] as String?;
          if (encoded != null && encoded.isNotEmpty) {
            final decoded = _decodePolyline(encoded);
            if (decoded.isNotEmpty) {
              final steps = <_RouteStep>[];
              final legs = route['legs'] as List<dynamic>? ?? [];
              for (final leg in legs) {
                final legSteps = (leg as Map)['steps'] as List<dynamic>? ?? [];
                for (final s in legSteps) {
                  final step = s as Map<String, dynamic>;
                  final html = step['html_instructions'] as String? ?? '';
                  final dist = step['distance'] as Map?;
                  final distText = dist?['text'] as String? ?? '';
                  steps.add(_RouteStep(_stripHtml(html), distText));
                }
              }
              if (mounted) {
                setState(() {
                  _routePoints = decoded;
                  _polylines = {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: decoded,
                      color: Colors.blue,
                      width: 6,
                    ),
                  };
                  _steps = steps;
                  _loadingRoute = false;
                });
                _pendingRouteBounds = _boundsFromPoints(decoded, originLat, originLng);
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngBounds(_pendingRouteBounds!, 80),
                );
              }
              return;
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
      _loadingRoute = false;
      _routeFailed = _polylines.isEmpty;
    });
    }
  }

  LatLngBounds _boundsFromPoints(List<LatLng> points, double originLat, double originLng) {
    double minLat = originLat, maxLat = originLat;
    double minLng = originLng, maxLng = originLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.jobData['pickupLocation'] as GeoPoint?;
    final lat = loc?.latitude ?? 20.5937;
    final lng = loc?.longitude ?? 78.9629;
    final addr = widget.jobData['pickupAddress'] as String? ?? 'Pickup location';
    final initialTarget = _initialUserPosition ??
        (_lastPosition != null
            ? LatLng(_lastPosition!.latitude, _lastPosition!.longitude)
            : LatLng(lat, lng));
    return Column(
      children: [
        if (_steps.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.navigation, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[_currentStepIndex].instruction,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_steps[_currentStepIndex].distanceText.isNotEmpty)
                        Text(
                          'in ${_steps[_currentStepIndex].distanceText}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (_steps.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Going to pickup location',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: 16,
                ),
                onMapCreated: (c) {
                  _mapController = c;
                  if (_pendingRouteBounds != null) {
                    c.animateCamera(CameraUpdate.newLatLngBounds(_pendingRouteBounds!, 80));
                  } else if (_lastPosition != null) {
                    c.animateCamera(CameraUpdate.newLatLng(
                      LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
                    ));
                  }
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: LatLng(lat, lng),
                    infoWindow: InfoWindow(title: 'Pickup', snippet: addr),
                  ),
                },
                polylines: _polylines,
                myLocationButtonEnabled: true,
                myLocationEnabled: true,
                zoomControlsEnabled: true,
              ),
              if (_loadingRoute)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x1AFFFFFF),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              if (_routeFailed && !_loadingRoute)
                Positioned(
                  bottom: 8,
                  left: 16,
                  right: 16,
                  child: OutlinedButton.icon(
                    onPressed: _fetchRoute,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry route'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              Positioned(
                bottom: _routeFailed && !_loadingRoute ? 56 : 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'follow_job',
                  onPressed: () async {
                    try {
                      final pos = await Geolocator.getCurrentPosition(
                        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                      );
                      _lastPosition = pos;
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
                      );
                    } catch (_) {}
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        if (_isNearPickupLocation)
          Expanded(
            child: TakeSiteImageScreen(
              jobId: widget.jobId,
              jobData: widget.jobData,
              imageType: 'pickup_before',
              onStartJob: widget.onStartJobWithProof,
              title: 'Take pickup site images',
              buttonLabel: 'Reach pickup location',
              useScaffold: false,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(addr, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showPickupMapSheet(context, widget.jobData),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Directions (Car/Bike/Walk)'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _distanceToPickupMeters != null
                            ? 'Reach within ${_arrivalThresholdMeters.toInt()}m to continue (${(_distanceToPickupMeters! / 1000).toStringAsFixed(1)} km away)'
                            : 'Tracking your location...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PickupPhaseAtPickup extends StatefulWidget {
  const _PickupPhaseAtPickup({
    required this.jobId,
    required this.jobData,
    required this.onRequestOtp,
    required this.onVerifyOtp,
  });
  final String jobId;
  final Map<String, dynamic> jobData;
  final VoidCallback onRequestOtp;
  final VoidCallback onVerifyOtp;

  @override
  State<_PickupPhaseAtPickup> createState() => _PickupPhaseAtPickupState();
}

class _PickupPhaseAtPickupWithMap extends StatelessWidget {
  const _PickupPhaseAtPickupWithMap({
    required this.jobId,
    required this.jobData,
    required this.onRequestOtp,
    required this.onVerifyOtp,
  });
  final String jobId;
  final Map<String, dynamic> jobData;
  final VoidCallback onRequestOtp;
  final VoidCallback onVerifyOtp;

  @override
  Widget build(BuildContext context) {
    return _PickupPhaseAtPickup(
      jobId: jobId,
      jobData: jobData,
      onRequestOtp: onRequestOtp,
      onVerifyOtp: onVerifyOtp,
    );
  }
}

class _PickupMapWithRoute extends StatefulWidget {
  const _PickupMapWithRoute({required this.jobData});
  final Map<String, dynamic> jobData;

  @override
  State<_PickupMapWithRoute> createState() => _PickupMapWithRouteState();
}

class _PickupMapWithRouteState extends State<_PickupMapWithRoute> {
  Set<Polyline> _polylines = {};
  bool _loadingRoute = true;

  @override
  void initState() {
    super.initState();
    ensureGoogleMapsJsLoaded();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final loc = widget.jobData['pickupLocation'] as GeoPoint?;
    final destLat = loc?.latitude ?? 20.5937;
    final destLng = loc?.longitude ?? 78.9629;
    double? originLat;
    double? originLng;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      originLat = pos.latitude;
      originLng = pos.longitude;
    } catch (_) {}
    if (originLat == null || originLng == null || mapsApiKey.isEmpty) {
      if (mounted) setState(() => _loadingRoute = false);
      return;
    }
    try {
      final uri = directionsUri(originLat, originLng, destLat, destLng);
      final response = await http.get(uri);
      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final status = data?['status'] as String? ?? '';
        if (status != 'OK') {
          if (mounted) setState(() => _loadingRoute = false);
          return;
        }
        final routes = data?['routes'] as List<dynamic>? ?? [];
        if (routes.isNotEmpty) {
          final overview = (routes.first as Map)['overview_polyline'] as Map?;
          final encoded = overview?['points'] as String?;
          if (encoded != null && encoded.isNotEmpty) {
            final decoded = _decodePolyline(encoded);
            if (decoded.isNotEmpty) {
              setState(() {
                _polylines = {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: decoded,
                    color: Colors.blue,
                    width: 5,
                  ),
                };
                _loadingRoute = false;
              });
              return;
            }
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingRoute = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.jobData['pickupLocation'] as GeoPoint?;
    final lat = loc?.latitude ?? 20.5937;
    final lng = loc?.longitude ?? 78.9629;
    final addr = widget.jobData['pickupAddress'] as String? ?? 'Pickup location';
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 14),
          markers: {
            Marker(
              markerId: const MarkerId('pickup'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: 'Pickup', snippet: addr),
            ),
          },
          polylines: _polylines,
          myLocationButtonEnabled: true,
          myLocationEnabled: true,
          zoomControlsEnabled: true,
        ),
        if (_loadingRoute)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x1AFFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Text(
            'Going to pickup location',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)
                  ],
                ),
          ),
        ),
      ],
    );
  }
}

void _showPickupMapSheet(BuildContext context, Map<String, dynamic> jobData) {
  final loc = jobData['pickupLocation'] as GeoPoint?;
  final lat = loc?.latitude ?? 20.5937;
  final lng = loc?.longitude ?? 78.9629;
  final addr = jobData['pickupAddress'] as String? ?? 'Pickup location';
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1,
      expand: false,
      builder: (_, scrollController) => _MapWithRouteSheet(
        destLat: lat,
        destLng: lng,
        address: addr,
        title: 'Pickup location',
        markerTitle: 'Pickup',
      ),
    ),
  );
}

class _RouteInfo {
  _RouteInfo({
    required this.distanceText,
    required this.durationText,
    required this.points,
    required this.steps,
  });
  final String distanceText;
  final String durationText;
  final List<LatLng> points;
  final List<_RouteStep> steps;
}

class _MapWithRouteSheet extends StatefulWidget {
  const _MapWithRouteSheet({
    this.jobId,
    required this.destLat,
    required this.destLng,
    required this.address,
    required this.title,
    required this.markerTitle,
    this.hideHeader = false,
  });
  final String? jobId;
  final double destLat;
  final double destLng;
  final String address;
  final String title;
  final String markerTitle;
  final bool hideHeader;

  @override
  State<_MapWithRouteSheet> createState() => _MapWithRouteSheetState();
}

class _MapWithRouteSheetState extends State<_MapWithRouteSheet> {
  final Map<String, _RouteInfo> _routes = {};
  String _selectedMode = 'driving';
  bool _loadingRoute = true;
  bool _isNavigating = false;
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _locationSub;
  int _currentStepIndex = 0;
  final FlutterTts _tts = FlutterTts();
  int _lastSpokenStep = -1;

  static const _modes = [
    ('bicycling', 'Bike', Icons.directions_bike),
    ('driving', 'Car', Icons.directions_car),
    ('walking', 'Walk', Icons.directions_walk),
  ];

  @override
  void initState() {
    super.initState();
    ensureGoogleMapsJsLoaded();
    _tts.setLanguage('en-IN');
    _tts.setSpeechRate(0.5);
    _fetchAllRoutes();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _fetchAllRoutes() async {
    double? originLat;
    double? originLng;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      originLat = pos.latitude;
      originLng = pos.longitude;
    } catch (_) {}
    if (originLat == null || originLng == null || mapsApiKey.isEmpty) {
      if (mounted) setState(() => _loadingRoute = false);
      return;
    }
    final results = <String, _RouteInfo>{};
    _RouteInfo? drivingFallback;
    for (final m in _modes) {
      final mode = m.$1;
      try {
        final uri = directionsUri(
          originLat,
          originLng,
          widget.destLat,
          widget.destLng,
          mode: mode,
        );
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>?;
          if (data?['status'] == 'OK') {
            final routes = data?['routes'] as List<dynamic>? ?? [];
            if (routes.isNotEmpty) {
              final route = routes.first as Map<String, dynamic>;
              final overview = route['overview_polyline'] as Map?;
              final encoded = overview?['points'] as String?;
              if (encoded != null && encoded.isNotEmpty) {
                final decoded = _decodePolyline(encoded);
                if (decoded.isNotEmpty) {
                  final legs = route['legs'] as List<dynamic>? ?? [];
                  String distText = '';
                  String durText = '';
                  final steps = <_RouteStep>[];
                  for (final leg in legs) {
                    final legMap = leg as Map;
                    distText = (legMap['distance'] as Map?)?['text'] as String? ?? '';
                    durText = (legMap['duration'] as Map?)?['text'] as String? ?? '';
                    for (final s in (legMap['steps'] as List<dynamic>? ?? [])) {
                      final step = s as Map<String, dynamic>;
                      final html = step['html_instructions'] as String? ?? '';
                      final dist = (step['distance'] as Map?)?['text'] as String? ?? '';
                      steps.add(_RouteStep(_stripHtml(html), dist));
                    }
                  }
                  final info = _RouteInfo(
                    distanceText: distText,
                    durationText: durText,
                    points: decoded,
                    steps: steps,
                  );
                  results[mode] = info;
                  if (mode == 'driving') drivingFallback = info;
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    if (!results.containsKey('bicycling') && drivingFallback != null) {
      results['bicycling'] = drivingFallback;
    }
    if (mounted) {
      setState(() {
        _routes.addAll(results);
        _loadingRoute = false;
        if (results.isEmpty) {
          _selectedMode = 'bicycling';
        } else if (!results.containsKey(_selectedMode)) {
          for (final m in _modes) {
            if (results.containsKey(m.$1)) {
              _selectedMode = m.$1;
              break;
            }
          }
        }
      });
      final info = results[_selectedMode];
      if (info != null && info.points.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitRouteBounds(info.points);
        });
      }
    }
  }

  void _fitRouteBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  void _startNavigation() async {
    if (_routes[_selectedMode] == null) return;
    setState(() => _isNavigating = true);
    if (widget.jobId != null && widget.jobId!.isNotEmpty && FirestoreService.isAvailable) {
      try {
        await FirestoreService.jobs().doc(widget.jobId).update({
          'technicianTravelMode': _selectedMode,
          'technicianNavigationStartedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
    _locationSub?.cancel();
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 17),
        );
      }
    } catch (_) {}
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
      final info = _routes[_selectedMode];
      if (info != null && info.points.isNotEmpty && info.steps.isNotEmpty) {
        int nearestIdx = 0;
        double minDist = double.infinity;
        for (int i = 0; i < info.points.length; i++) {
          final p = info.points[i];
          final d = (p.latitude - pos.latitude) * (p.latitude - pos.latitude) +
              (p.longitude - pos.longitude) * (p.longitude - pos.longitude);
          if (d < minDist) {
            minDist = d;
            nearestIdx = i;
          }
        }
        final stepIdx = (nearestIdx * info.steps.length / info.points.length)
            .floor()
            .clamp(0, info.steps.length - 1);
        if (stepIdx != _currentStepIndex && mounted) {
          setState(() => _currentStepIndex = stepIdx);
          if (stepIdx != _lastSpokenStep) {
            _lastSpokenStep = stepIdx;
            _tts.speak(info.steps[stepIdx].instruction);
          }
        }
      }
    });
  }

  void _stopNavigation() {
    _locationSub?.cancel();
    setState(() {
      _isNavigating = false;
      _lastSpokenStep = -1;
    });
    _tts.stop();
  }

  Set<Polyline> _buildPolylines() {
    final info = _routes[_selectedMode];
    if (info == null || info.points.isEmpty) return {};
    final isWalk = _selectedMode == 'walking';
    return {
      isWalk
          ? Polyline(
              polylineId: const PolylineId('route'),
              points: info.points,
              color: Colors.blue,
              width: 6,
              patterns: [PatternItem.dot, PatternItem.gap(12)],
            )
          : Polyline(
              polylineId: const PolylineId('route'),
              points: info.points,
              color: Colors.blue,
              width: 5,
            ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final info = _routes[_selectedMode];
    return Column(
      children: [
        if (!widget.hideHeader)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isNavigating ? Icons.close : Icons.arrow_back),
                  onPressed: () {
                    if (_isNavigating) {
                      _stopNavigation();
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                Expanded(
                  child: Text(
                    _isNavigating ? 'Navigation' : widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.destLat, widget.destLng),
                  zoom: 14,
                ),
                onMapCreated: (c) => _mapController = c,
                markers: {
                  Marker(
                    markerId: MarkerId(widget.markerTitle),
                    position: LatLng(widget.destLat, widget.destLng),
                    infoWindow: InfoWindow(title: widget.markerTitle, snippet: widget.address),
                  ),
                },
                polylines: _buildPolylines(),
                myLocationButtonEnabled: true,
                myLocationEnabled: true,
                zoomControlsEnabled: true,
              ),
              if (_loadingRoute)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x1AFFFFFF),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (_isNavigating && info != null && info.steps.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.navigation, color: Theme.of(context).colorScheme.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info.steps[_currentStepIndex].instruction,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (info.steps[_currentStepIndex].distanceText.isNotEmpty)
                                Text(
                                  'in ${info.steps[_currentStepIndex].distanceText}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!_isNavigating) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(widget.address, style: Theme.of(context).textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: _modes.map((m) {
                    final isSelected = _selectedMode == m.$1;
                    final hasRoute = _routes.containsKey(m.$1);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Material(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: hasRoute
                                ? () => setState(() => _selectedMode = m.$1)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Icon(m.$3, size: 24, color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.grey),
                                  const SizedBox(height: 4),
                                  Text(
                                    m.$2,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.grey.shade700,
                                        ),
                                  ),
                                  if (hasRoute && _routes[m.$1] != null)
                                    Text(
                                      _routes[m.$1]!.durationText,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            fontSize: 10,
                                            color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : Colors.grey.shade600,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (info != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.straighten, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(info.distanceText, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 16),
                      Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(info.durationText, style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: info != null
                      ? _startNavigation
                      : null,
                  icon: const Icon(Icons.navigation, size: 22),
                  label: const Text('Start'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ] else
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: _stopNavigation,
                icon: const Icon(Icons.stop),
                label: const Text('Stop navigation'),
              ),
            ),
          ),
      ],
    );
  }
}

class _PickupItemPhotoLocal {
  _PickupItemPhotoLocal({
    required this.filePath,
    this.partNumber,
    this.latitude,
    this.longitude,
  });
  final String filePath;
  final String? partNumber;
  final double? latitude;
  final double? longitude;
}

class _PickupPhaseAtPickupState extends State<_PickupPhaseAtPickup> {
  final Map<int, String> _itemPhotos = {};
  final Map<int, _PickupItemPhotoLocal> _itemLocalPhotos = {};
  bool _loading = false;
  bool _uploaded = false;
  String _uploadStatusText = '';
  int _uploadProgress = 0; // 0..100

  bool _hasPhoto(int slNo) =>
      (_itemPhotos[slNo] != null && _itemPhotos[slNo]!.isNotEmpty) ||
      _itemLocalPhotos.containsKey(slNo);

  Future<void> _addPhotoForItem(int slNo, String itemName) async {
    String? partNumber;
    if (mounted) {
      partNumber = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final c = TextEditingController();
          return AlertDialog(
            title: Text('Add photo: $itemName'),
            content: TextField(
              controller: c,
              decoration: const InputDecoration(
                labelText: 'Part no. / Serial no.',
                hintText: 'e.g. CBL-001',
              ),
              onSubmitted: (v) {
                if (v.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please add part or serial number')),
                  );
                } else {
                  Navigator.pop(ctx, v.trim());
                }
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
              FilledButton(
                onPressed: () {
                  final v = c.text.trim();
                  if (v.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please add part or serial number')),
                    );
                  } else {
                    Navigator.pop(ctx, v);
                  }
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    }
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (xfile == null || !mounted) return;
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
        _itemLocalPhotos[slNo] = _PickupItemPhotoLocal(
          filePath: xfile.path,
          partNumber: partNumber?.isNotEmpty == true ? partNumber : null,
          latitude: lat,
          longitude: lng,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo added. Tap Upload to save.')),
      );
    }
  }

  void _removeLocalPhoto(int slNo) {
    setState(() => _itemLocalPhotos.remove(slNo));
  }

  Future<void> _uploadPickupPhotos() async {
    final list = (widget.jobData['pickupMaterialList'] as List<dynamic>?) ?? [];
    final toUpload = list
        .map((e) => ((e as Map<String, dynamic>)['slNo'] as num?)?.toInt())
        .whereType<int>()
        .where((slNo) => _itemLocalPhotos.containsKey(slNo))
        .toList();
    if (toUpload.isEmpty) return;
    if (!StorageService.isAvailable || !FirestoreService.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firebase is not configured.')),
        );
      }
      return;
    }
    setState(() {
      _loading = true;
      _uploadProgress = 0;
      _uploadStatusText = 'Image upload in process…';
    });
    try {
      final total = toUpload.length;
      var done = 0;
      for (final slNo in toUpload) {
        if (mounted) {
          setState(() {
            final pct = total == 0
                ? 0
                : ((done / total) * 100).clamp(0, 100).toInt();
            _uploadProgress = pct;
            _uploadStatusText = 'Image upload in process… ($pct%)';
          });
        }
        final local = _itemLocalPhotos[slNo]!;
        final m = list.firstWhere(
          (e) => ((e as Map)['slNo'] as num?)?.toInt() == slNo,
          orElse: () => <String, dynamic>{},
        ) as Map<String, dynamic>;
        final itemName = m['itemName'] as String? ?? '';
        final file = File(local.filePath);
        File fileToUpload = file;
        try {
          final targetPath = '${Directory.systemTemp.path}/pickup_${slNo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final compressed = await FlutterImageCompress.compressAndGetFile(
            file.absolute.path,
            targetPath,
            quality: 50,
            minWidth: 1024,
            minHeight: 1024,
          );
          if (compressed != null) fileToUpload = File(compressed.path);
        } catch (_) {}
        final url = await StorageService.uploadMaterialPickupPhoto(
          jobId: widget.jobId,
          slNo: slNo,
          itemName: itemName,
          partNumber: local.partNumber?.isNotEmpty == true ? local.partNumber : null,
          file: fileToUpload,
        );
        if (url != null && mounted) {
          final newEntry = <String, dynamic>{
            'slNo': slNo,
            'itemName': itemName,
            if (local.partNumber != null && local.partNumber!.isNotEmpty) 'partNumber': local.partNumber,
            'url': url,
            if (local.latitude != null) 'latitude': local.latitude,
            if (local.longitude != null) 'longitude': local.longitude,
            'createdAt': DateTime.now(),
          };
          await FirestoreService.jobs().doc(widget.jobId).update({
            'pickupMaterialPhotos': FieldValue.arrayUnion([newEntry]),
          });
          setState(() {
            _itemPhotos[slNo] = url;
            _itemLocalPhotos.remove(slNo);
          });
        }
        done++;
      }
      if (mounted) {
        final list = (widget.jobData['pickupMaterialList'] as List<dynamic>?) ?? [];
        final allUploaded = list.isNotEmpty &&
            list.every((e) {
              final sl = ((e as Map)['slNo'] as num?)?.toInt();
              return sl != null && _itemPhotos[sl] != null && _itemPhotos[sl]!.isNotEmpty;
            });
        setState(() {
          _loading = false;
          _uploaded = allUploaded;
          _uploadProgress = 100;
          _uploadStatusText = allUploaded ? 'Upload complete.' : '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pickup photos uploaded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
        setState(() {
          _loading = false;
          _uploadStatusText = '';
          _uploadProgress = 0;
        });
      }
    }
  }

  void _syncPhotosFromJobData() {
    final existing = (widget.jobData['pickupMaterialPhotos'] as List<dynamic>?) ?? [];
    final list = (widget.jobData['pickupMaterialList'] as List<dynamic>?) ?? [];
    for (final e in existing) {
      final m = e as Map<String, dynamic>;
      final sl = (m['slNo'] as num?)?.toInt();
      if (sl != null) _itemPhotos[sl] = m['url'] as String? ?? '';
    }
    _uploaded = list.isNotEmpty &&
        list.every((e) {
          final sl = ((e as Map)['slNo'] as num?)?.toInt();
          return sl != null && _itemPhotos[sl] != null && _itemPhotos[sl]!.isNotEmpty;
        });
  }

  @override
  void initState() {
    super.initState();
    _syncPhotosFromJobData();
  }

  @override
  void didUpdateWidget(_PickupPhaseAtPickup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPhotosFromJobData();
  }

  @override
  Widget build(BuildContext context) {
    final list = (widget.jobData['pickupMaterialList'] as List<dynamic>?) ?? [];
    final allHavePhotos = list.isNotEmpty &&
        list.every((e) {
          final sl = ((e as Map<String, dynamic>)['slNo'] as num?)?.toInt();
          return sl != null && _hasPhoto(sl);
        });
    final hasLocalPhotos = _itemLocalPhotos.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Material pickup – add 1 photo per item (camera only)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (list.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No pickup items in this job. Contact dealer or proceed to job location.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...list.map((e) {
            final m = e as Map<String, dynamic>;
            final slNo = (m['slNo'] as num?)?.toInt() ?? 0;
            final itemName = m['itemName'] as String? ?? '';
            final qty = m['qty'] ?? 1;
            final hasPhoto = _hasPhoto(slNo);
            final isLocal = _itemLocalPhotos.containsKey(slNo);
            final url = _itemPhotos[slNo];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$slNo. $itemName × $qty', style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(
                                hasPhoto ? (isLocal ? 'Photo added (tap Upload)' : 'Uploaded ✓') : 'Photo required',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (hasPhoto && !isLocal)
                          const Icon(Icons.check_circle, color: Colors.green, size: 28)
                        else
                          IconButton(
                            icon: Icon(hasPhoto && isLocal ? Icons.refresh : Icons.camera_alt),
                            onPressed: () => _addPhotoForItem(slNo, itemName),
                            tooltip: hasPhoto && isLocal ? 'Replace photo' : 'Add photo',
                          ),
                      ],
                    ),
                    if (hasPhoto) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isLocal
                              ? Image.file(
                                  File(_itemLocalPhotos[slNo]!.filePath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                                )
                              : (url != null && url.isNotEmpty)
                                  ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image))
                                  : const SizedBox.shrink(),
                        ),
                      ),
                      if (isLocal)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: GestureDetector(
                            onTap: () => _removeLocalPhoto(slNo),
                            child: Text('Remove', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red)),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          if (allHavePhotos && hasLocalPhotos)
            FilledButton.icon(
              onPressed: _loading ? null : _uploadPickupPhotos,
              icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload),
              label: Text(_loading ? 'Uploading...' : 'Upload pickup photos'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          if (_loading) const SizedBox(height: 8),
          if (_loading) LinearProgressIndicator(value: (_uploadProgress.clamp(0, 100)) / 100),
          if (_loading) const SizedBox(height: 10),
          if (_loading)
            Text(
              _uploadStatusText.isEmpty ? 'Image upload in process…' : _uploadStatusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          if (allHavePhotos && _uploaded) ...[
            if (hasLocalPhotos) const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onRequestOtp,
              icon: const Icon(Icons.sms_outlined, size: 20),
              label: const Text('Request OTP'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 8),
            Text(
              'OTP will be sent to pickup contact. Enter code in the popup to confirm.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (!allHavePhotos)
            Text(
              'Add photo for each item, then tap Upload.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
            )
          else if (allHavePhotos && hasLocalPhotos)
            Text(
              'Tap Upload to save photos, then request OTP.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
