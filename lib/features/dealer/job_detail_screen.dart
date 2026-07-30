import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/trust_reputation_constants.dart';
import '../../core/theme/dealer_ui_tokens.dart';
import '../../shared/models/job_model.dart';
import '../../shared/models/service_completion_record_model.dart';
import '../../shared/services/fcm_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/profile_card_technician.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';
import '../../shared/widgets/address_picker_sheet.dart';
import '../shared/chat_screen.dart' as shared_chat;

bool _hasLivePhotos(Map<String, dynamic> jobData) {
  final proofPhotos = (jobData['proofPhotos'] as List<dynamic>?) ?? [];
  final pickupMaterialPhotos =
      (jobData['pickupMaterialPhotos'] as List<dynamic>?) ?? [];
  final hasBefore = proofPhotos.any((p) => (p as Map)['type'] == 'before');
  final hasPickupBefore =
      proofPhotos.any((p) => (p as Map)['type'] == 'pickup_before') ||
      pickupMaterialPhotos.isNotEmpty;
  return hasBefore || hasPickupBefore;
}

List<Widget> _buildProofSections(
  BuildContext context,
  Map<String, dynamic> jobData,
) {
  final proofPhotos = (jobData['proofPhotos'] as List<dynamic>?) ?? [];
  final materialReturnItems =
      (jobData['materialReturnItems'] as List<dynamic>?) ?? [];
  final pickupMaterialPhotos =
      (jobData['pickupMaterialPhotos'] as List<dynamic>?) ?? [];

  final beforePhotos = proofPhotos
      .where((p) => (p as Map)['type'] == 'before')
      .toList();
  final afterPhotos = proofPhotos
      .where((p) => (p as Map)['type'] == 'after')
      .toList();
  var pickupBeforePhotos = proofPhotos
      .where((p) => (p as Map)['type'] == 'pickup_before')
      .toList();
  if (pickupBeforePhotos.isEmpty && pickupMaterialPhotos.isNotEmpty) {
    pickupBeforePhotos = pickupMaterialPhotos;
  }

  final materialBeforeUrls = <Map<String, dynamic>>[];
  final materialAfterUrls = <Map<String, dynamic>>[];
  for (var i = 0; i < materialReturnItems.length; i++) {
    final m = materialReturnItems[i] as Map<String, dynamic>;
    final name = m['name'] ?? 'Item ${i + 1}';
    final beforeUrl = m['photoUrl'] as String?;
    final afterUrl = m['afterPhotoUrl'] as String?;
    if (beforeUrl != null && beforeUrl.isNotEmpty) {
      materialBeforeUrls.add({
        'url': beforeUrl,
        'name': name,
        'lat': m['latitude'],
        'lng': m['longitude'],
      });
    }
    if (afterUrl != null && afterUrl.isNotEmpty) {
      materialAfterUrls.add({
        'url': afterUrl,
        'name': name,
        'lat': m['afterPhotoLat'],
        'lng': m['afterPhotoLng'],
      });
    }
  }

  Widget imageCard(String url, String label, double? lat, double? lng) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => TappableImage.show(
          context,
          url: url,
          latitude: lat,
          longitude: lng,
        ),
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
                      placeholder: (_, _) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.broken_image, size: 32),
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
      const Text(
        'Before (site)',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          itemCount: beforePhotos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10.0),
          itemBuilder: (_, i) {
            final p = beforePhotos[i] as Map;
            final url = p['url'] as String?;
            if (url == null || url.isEmpty) return const SizedBox.shrink();
            return imageCard(
              url,
              'Before',
              (p['latitude'] as num?)?.toDouble(),
              (p['longitude'] as num?)?.toDouble(),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  if (afterPhotos.isNotEmpty) {
    sections.addAll([
      const Text(
        'After (site)',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          itemCount: afterPhotos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10.0),
          itemBuilder: (_, i) {
            final p = afterPhotos[i] as Map;
            final url = p['url'] as String?;
            if (url == null || url.isEmpty) return const SizedBox.shrink();
            return imageCard(
              url,
              'After',
              (p['latitude'] as num?)?.toDouble(),
              (p['longitude'] as num?)?.toDouble(),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  if (pickupBeforePhotos.isNotEmpty) {
    sections.addAll([
      const Text(
        'Material pickup – Before',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          itemCount: pickupBeforePhotos.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10.0),
          itemBuilder: (_, i) {
            final p = pickupBeforePhotos[i] as Map;
            final url = (p['url'] as String?) ?? (p['photoUrl'] as String?);
            if (url == null || url.isEmpty) return const SizedBox.shrink();
            final itemName = p['itemName'] as String? ?? 'Item ${i + 1}';
            return imageCard(
              url,
              itemName,
              (p['latitude'] as num?)?.toDouble(),
              (p['longitude'] as num?)?.toDouble(),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  if (materialBeforeUrls.isNotEmpty) {
    sections.addAll([
      const Text(
        'Material return – Before',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          itemCount: materialBeforeUrls.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10.0),
          itemBuilder: (_, i) {
            final m = materialBeforeUrls[i];
            return imageCard(
              m['url'] as String,
              m['name'] as String,
              (m['lat'] as num?)?.toDouble(),
              (m['lng'] as num?)?.toDouble(),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  if (materialAfterUrls.isNotEmpty) {
    sections.addAll([
      const Text(
        'Material return – After',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          itemCount: materialAfterUrls.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10.0),
          itemBuilder: (_, i) {
            final m = materialAfterUrls[i];
            return imageCard(
              m['url'] as String,
              m['name'] as String,
              (m['lat'] as num?)?.toDouble(),
              (m['lng'] as num?)?.toDouble(),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  return sections;
}

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  void _proceedToPayment(BuildContext context, double amount) {
    context.push(
      '/dealer/jobs/$jobId/pay',
      extra: <String, double>{'amount': amount},
    );
  }

  Future<void> _showSetHandoverLocation(
    BuildContext context,
    String jobId,
    Map<String, dynamic> jobData,
  ) async {
    final location = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select handover location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Job location'),
              leading: const Icon(Icons.home_work),
              onTap: () {
                final loc = jobData['location'] as GeoPoint?;
                if (loc != null) {
                  Navigator.pop(ctx, {
                    'latitude': loc.latitude,
                    'longitude': loc.longitude,
                    'address': jobData['address'] ?? 'Job location',
                    'type': 'job',
                  });
                }
              },
            ),
            if (jobData['pickupLocation'] != null)
              ListTile(
                title: const Text('Pickup location'),
                leading: const Icon(Icons.inventory),
                onTap: () {
                  final loc = jobData['pickupLocation'] as GeoPoint?;
                  if (loc != null) {
                    Navigator.pop(ctx, {
                      'latitude': loc.latitude,
                      'longitude': loc.longitude,
                      'address': jobData['pickupAddress'] ?? 'Pickup location',
                      'type': 'pickup',
                    });
                  }
                },
              ),
            ListTile(
              title: const Text('Dealer location'),
              leading: const Icon(Icons.store),
              subtitle: const Text('Pick your location on map'),
              onTap: () =>
                  Navigator.pop(ctx, {'pickOnMap': true, 'type': 'dealer'}),
            ),
            ListTile(
              title: const Text('Pick on map'),
              leading: const Icon(Icons.map),
              onTap: () => Navigator.pop(ctx, {'pickOnMap': true}),
            ),
          ],
        ),
      ),
    );
    if (location != null && context.mounted) {
      if (location['pickOnMap'] == true) {
        final result = await showAddressPickerSheet(
          context,
          title: 'Handover location',
        );
        if (result != null && context.mounted) {
          final locType = location['type'] as String? ?? 'custom';
          await _saveHandoverLocation(
            context,
            jobId,
            result.latitude,
            result.longitude,
            result.address,
            locType == 'dealer' ? 'dealer' : 'custom',
          );
        }
      } else {
        await _saveHandoverLocation(
          context,
          jobId,
          location['latitude'] as double,
          location['longitude'] as double,
          location['address'] as String,
          location['type'] as String,
        );
      }
    }
  }

  Future<void> _saveHandoverLocation(
    BuildContext context,
    String jobId,
    double lat,
    double lng,
    String address,
    String type,
  ) async {
    await FirestoreService.jobs().doc(jobId).update({
      'materialHandoverLocation': GeoPoint(lat, lng),
      'materialHandoverAddress': address,
      'materialHandoverLocationType': type,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Handover location set. Technician notified.'),
        ),
      );
    }
  }

  void _showVerifyReturnOtpDialog(BuildContext context, String jobId) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter return confirm OTP'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'OTP code',
            hintText: '6 digits (sent to your phone)',
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
                      'jobId': jobId,
                      'purpose': 'material_return_confirm',
                      'code': code,
                    });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Material return confirmed. Job closed.'),
                    ),
                  );
                  context.go(RouteNames.dealerMyJobs);
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
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

  Future<void> _callCustomer(BuildContext context, String jobId) async {
    if (Firebase.apps.isEmpty) return;
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connecting...')));
      final result = await FirebaseFunctions.instance
          .httpsCallable('initMaskedCall')
          .call({'jobId': jobId});
      if (context.mounted) {
        final msg =
            (result.data is Map && (result.data as Map)['message'] != null)
            ? (result.data as Map)['message'] as String
            : 'Call initiated.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Call failed: $e')));
      }
    }
  }

  Future<void> _repostJob(BuildContext context, String jobId) async {
    if (Firebase.apps.isEmpty) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sending job to technicians...')),
      );
      await FirebaseFunctions.instance.httpsCallable('requestMoreBids').call({
        'jobId': jobId,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job reposted. Technicians will be notified.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Repost failed: $e')));
      }
    }
  }

  Future<void> _cancelJob(BuildContext context, String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel job?'),
        content: const Text(
          'This job will be marked as cancelled. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, cancel job'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await FirestoreService.jobs().doc(jobId).update({'status': 'cancelled'});
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Job cancelled.')));
        context.go(RouteNames.dealerMyJobs);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to cancel: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        backgroundColor: DealerUiTokens.pageBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Job detail',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: DealerUiTokens.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      backgroundColor: DealerUiTokens.pageBg,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobs().doc(jobId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data!;
          if (!doc.exists) {
            return const Center(child: Text('Job not found.'));
          }
          final job = JobModel.fromFirestore(doc);
          final jobData = doc.data() ?? {};

          final actions = _DealerJobActions.build(
            context: context,
            jobId: jobId,
            job: job,
            jobData: jobData,
            onProceedToPayment: (amount) => _proceedToPayment(context, amount),
            onSetHandoverLocation: () =>
                _showSetHandoverLocation(context, jobId, jobData),
            onVerifyReturnOtp: () => _showVerifyReturnOtpDialog(context, jobId),
            onCallCustomer: () => _callCustomer(context, jobId),
            onRepost: () => _repostJob(context, jobId),
            onCancel: () => _cancelJob(context, jobId),
          );

          return Stack(
            children: [
              const _DealerJobDetailBackground(),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        child: _TopBar(
                          title: 'Job detail',
                          onBack: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(RouteNames.dealerMyJobs);
                            }
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _HeroHeader(
                          title: job.title ?? 'Job',
                          status: job.status.name,
                          isEmergency: job.isEmergency,
                          duplicateFlag: job.duplicateJobFlag,
                          subtitle: job.description ?? '—',
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: _SectionCard(
                          title: 'Job details',
                          child: Column(
                            children: [
                              _Row(label: 'Address', value: job.address ?? '—'),
                              const SizedBox(height: 10),
                              _Row(
                                label: 'Rate',
                                value: '₹${job.dealerRate ?? 0}',
                              ),
                              _Row(
                                label: 'Agreed',
                                value: '₹${job.agreedAmount ?? 0}',
                              ),
                              _Row(
                                label: 'Technician payout',
                                value:
                                    '₹${(job.technicianPayoutAmount ?? 0).toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (job.technicianId != null &&
                        job.technicianId!.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _SectionCard(
                            title: 'Assigned technician',
                            child:
                                StreamBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>
                                >(
                                  stream: FirestoreService.users()
                                      .doc(job.technicianId!)
                                      .snapshots(),
                                  builder: (context, userSnap) {
                                    if (!userSnap.hasData ||
                                        !userSnap.data!.exists) {
                                      return const SizedBox.shrink();
                                    }
                                    final d = userSnap.data!.data() ?? {};
                                    final profile =
                                        d['profile'] as Map<String, dynamic>?;
                                    return ProfileCardTechnician(
                                      name: profile?['name'] as String?,
                                      level:
                                          (d['technicianLevel'] as String?) !=
                                              null
                                          ? TrustReputationConstants.labelForTechnicianLevel(
                                              d['technicianLevel'] as String?,
                                            )
                                          : null,
                                      rating: (d['avgRating'] as num?)
                                          ?.toDouble(),
                                      jobsCompleted:
                                          d['totalJobsCompleted'] as int?,
                                      onTimeRate: (d['onTimeRate'] as num?)
                                          ?.toDouble(),
                                    );
                                  },
                                ),
                          ),
                        ),
                      ),
                    if ((job.status == JobStatus.paid ||
                            job.status == JobStatus.inProgress) &&
                        _hasLivePhotos(jobData)) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _SectionCard(
                            title: 'Proofs',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _buildProofSections(context, jobData),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (job.status == JobStatus.completed &&
                        (job.warrantyStatus != null ||
                            job.warrantyEndDate != null))
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _SectionCard(
                            title: 'Warranty',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _WarrantyBadge(job: job),
                                StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>
                                >(
                                  stream: FirestoreService.warrantyClaims()
                                      .where('jobId', isEqualTo: jobId)
                                      // Use current auth UID to avoid any mismatch with job.dealerId parsing/stale data.
                                      .where(
                                        'dealerId',
                                        isEqualTo: FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid,
                                      )
                                      .limit(1)
                                      .snapshots(),
                                  builder: (context, snap) {
                                    final hasJobClaims =
                                        (snap.data?.docs.isNotEmpty ?? false);
                                    final status = (job.warrantyStatus ?? '')
                                        .trim();
                                    final isActiveFlag = status == 'active';
                                    final shouldShowRaise =
                                        (isActiveFlag ||
                                            job.hasActiveWarranty) &&
                                        !hasJobClaims;
                                    if (!shouldShowRaise) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: FilledButton.icon(
                                        onPressed: () => context.push(
                                          RouteNames.dealerWarrantyClaimForm(
                                            jobId,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 20,
                                        ),
                                        label: const Text(
                                          'Raise warranty claim',
                                        ),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size.fromHeight(
                                            48,
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (job.warrantyStatus == 'claim_open' ||
                                    job.warrantyEndDate != null) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => context.push(
                                      RouteNames.dealerJobWarrantyClaims(jobId),
                                    ),
                                    icon: const Icon(Icons.list_alt, size: 20),
                                    label: const Text('View warranty claims'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                        child: _SectionCard(title: 'Actions', child: actions),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  // For completed jobs, the actions widget contains large cards (service record, rating).
                  // Keeping it sticky can visually "cover" other sections (e.g., warranty) while scrolling.
                  child: job.status == JobStatus.completed
                      ? const SizedBox.shrink()
                      : _StickyActionBar(child: actions),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DealerJobDetailBackground extends StatelessWidget {
  const _DealerJobDetailBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.7, -0.9),
            radius: 1.2,
            colors: [
              const Color(0xFF93C5FD).withValues(alpha: 0.10),
              const Color(0xFFF8FAFF),
              DealerUiTokens.pageBg,
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DealerUiTokens.border),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: DealerUiTokens.textPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.title,
    required this.status,
    required this.isEmergency,
    required this.duplicateFlag,
    required this.subtitle,
  });

  final String title;
  final String status;
  final bool isEmergency;
  final bool duplicateFlag;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                const Color(0xFFF1F5F9).withValues(alpha: 0.78),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        letterSpacing: -0.4,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _StatusChip(text: status),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isEmergency)
                    const _Pill(label: 'Emergency', color: Colors.orange),
                  if (duplicateFlag)
                    const _Pill(
                      label: 'Possible duplicate',
                      color: Colors.orange,
                    ),
                  const _Pill(label: 'Ultra Pro', color: Color(0xFF2563EB)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DealerUiTokens.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: DealerUiTokens.textPrimary,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.95),
            border: Border.all(color: DealerUiTokens.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: DealerUiTokens.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyActionBar extends StatelessWidget {
  const _StickyActionBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DealerJobActions {
  static Widget build({
    required BuildContext context,
    required String jobId,
    required JobModel job,
    required Map<String, dynamic> jobData,
    required ValueChanged<double> onProceedToPayment,
    required VoidCallback onSetHandoverLocation,
    required VoidCallback onVerifyReturnOtp,
    required VoidCallback onCallCustomer,
    required VoidCallback onRepost,
    required VoidCallback onCancel,
  }) {
    final children = <Widget>[];

    // Primary actions by state
    if (job.status == JobStatus.pendingDealerConfirm) {
      if (job.dealerApprovalDeadline != null) {
        children.add(
          _DealerApprovalCountdown(deadline: job.dealerApprovalDeadline!),
        );
        children.add(const SizedBox(height: 10));
      }
      children.add(
        Text(
          'Review proofs (photos + OTP) before confirming.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
      children.add(const SizedBox(height: 12));
      children.addAll(_buildProofSections(context, jobData));
      children.add(const SizedBox(height: 12));
      children.add(
        FilledButton.icon(
          onPressed: () async {
            await FcmService.cancelJobNotification();
            await FirestoreService.jobs().doc(jobId).update({
              'status': 'completed',
            });
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Job confirmed.')));
              context.go(RouteNames.dealerMyJobs);
            }
          },
          icon: const Icon(Icons.check_circle),
          label: const Text('Confirm job'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: Colors.green,
          ),
        ),
      );
      children.add(const SizedBox(height: 10));
      children.add(
        OutlinedButton.icon(
          onPressed: () => context.push(RouteNames.dealerJobDispute(jobId)),
          icon: const Icon(Icons.report_problem_outlined),
          label: const Text('Raise dispute'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    if (job.status == JobStatus.paymentPending) {
      final amount = job.technicianPayoutAmount ?? job.agreedAmount ?? 0;
      children.add(
        FilledButton.icon(
          onPressed: () => onProceedToPayment(amount.toDouble()),
          icon: const Icon(Icons.payment),
          label: Text(
            'Pay for on-site service (₹${amount.toStringAsFixed(0)})',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: Colors.green,
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    if (job.status == JobStatus.bidding) {
      children.add(
        FilledButton.icon(
          onPressed: () => context.push('/dealer/jobs/$jobId/bidding'),
          icon: const Icon(Icons.gavel),
          label: const Text('Open bidding'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    if (job.status == JobStatus.paid || job.status == JobStatus.inProgress) {
      children.add(
        FilledButton.icon(
          onPressed: () => context.go('/dealer/jobs/$jobId/bidding'),
          icon: const Icon(Icons.map_rounded),
          label: const Text('Track technician'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      );
      if (jobData['siteContactPhone'] != null &&
          (jobData['siteContactPhone'] as String).trim().isNotEmpty) {
        children.add(const SizedBox(height: 10));
        children.add(
          OutlinedButton.icon(
            onPressed: onCallCustomer,
            icon: const Icon(Icons.phone),
            label: const Text('Call customer'),
          ),
        );
      }
      children.add(const SizedBox(height: 10));
      children.add(
        OutlinedButton.icon(
          onPressed: () => shared_chat.showChatPopup(context, jobId),
          icon: const Icon(Icons.chat),
          label: const Text('Chat'),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    if (job.status == JobStatus.posted || job.status == JobStatus.bidding) {
      children.add(
        _UltraStatRow(
          items: [
            ('Notified', '${job.techniciansNotifiedCount ?? 0}'),
            ('Bids', '${job.bidsReceivedCount ?? 0}'),
            ('Rejected', '${job.techniciansRejectedCount ?? 0}'),
            (
              job.biddingEnabled == true ? 'Bid round' : 'Round',
              '${job.bidRound ?? job.notificationRound ?? 1}',
            ),
          ],
        ),
      );
      if ((job.techniciansNotifiedCount ?? 0) == 0) {
        children.add(const SizedBox(height: 10));
        children.add(
          FilledButton.icon(
            onPressed: onRepost,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Repost – send to technicians'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Colors.orange,
            ),
          ),
        );
      }
      children.add(const SizedBox(height: 10));
      children.add(
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.cancel_outlined, size: 20),
          label: const Text('Cancel job'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: Colors.red,
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    if (jobData['materialReturnRequested'] == true) {
      children.add(
        Text(
          'Material return',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      );
      children.add(const SizedBox(height: 10));
      if (jobData['materialHandoverLocation'] == null) {
        children.add(
          FilledButton.icon(
            onPressed: onSetHandoverLocation,
            icon: const Icon(Icons.location_on),
            label: const Text('Set handover location'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Colors.orange,
            ),
          ),
        );
      } else {
        children.add(
          OutlinedButton.icon(
            onPressed: onVerifyReturnOtp,
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Verify return OTP'),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    if (job.status == JobStatus.completed) {
      children.add(_ServiceCompletionRecordCard(jobId: jobId, isDealer: true));
      children.add(const SizedBox(height: 10));
      final hasRating =
          (jobData['dealerRatingToTechnician'] != null) ||
          (jobData['technicianRatingToDealer'] != null);
      if (hasRating) {
        children.add(
          _RatingDisplayCard(
            rating:
                (jobData['dealerRatingToTechnician'] ??
                        jobData['technicianRatingToDealer'])
                    as num?,
            review:
                (jobData['dealerReviewToTechnician'] ??
                        jobData['technicianReviewToDealer'])
                    as String?,
            label: jobData['dealerRatingToTechnician'] != null
                ? 'Your rating'
                : 'Technician rated you',
          ),
        );
      } else {
        children.add(
          OutlinedButton.icon(
            onPressed: () => context.push('/dealer/jobs/$jobId/rate'),
            icon: const Icon(Icons.star),
            label: const Text('Rate technician'),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    // Fallback
    if (job.technicianId != null && job.technicianId!.isNotEmpty) {
      children.add(
        OutlinedButton.icon(
          onPressed: () => shared_chat.showChatPopup(context, jobId),
          icon: const Icon(Icons.chat),
          label: const Text('Chat'),
        ),
      );
    }
    if (children.isEmpty) {
      return Text(
        'No actions available.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _UltraStatRow extends StatelessWidget {
  const _UltraStatRow({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final it in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: DealerUiTokens.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  it.$1,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DealerUiTokens.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  it.$2,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: DealerUiTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WarrantyBadge extends StatelessWidget {
  const _WarrantyBadge({required this.job});
  final JobModel job;

  @override
  Widget build(BuildContext context) {
    final status =
        job.warrantyStatus ??
        (job.warrantyEndDate != null &&
                job.warrantyEndDate!.isAfter(DateTime.now())
            ? 'active'
            : 'expired');
    final isActive = status == 'active';
    final isClaimOpen = status == 'claim_open';
    final isExpired =
        status == 'expired' ||
        (job.warrantyEndDate != null &&
            !job.warrantyEndDate!.isAfter(DateTime.now()));
    String label;
    Color color;
    if (isClaimOpen) {
      label = 'Warranty claim open';
      color = Colors.orange;
    } else if (isActive) {
      label = 'Warranty active';
      color = Colors.green;
    } else {
      label = 'Warranty expired';
      color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (job.warrantyEndDate != null && !isExpired) ...[
            const SizedBox(width: 8),
            Text(
              'until ${job.warrantyEndDate!.day}/${job.warrantyEndDate!.month}/${job.warrantyEndDate!.year}',
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceCompletionRecordCard extends StatelessWidget {
  const _ServiceCompletionRecordCard({
    required this.jobId,
    required this.isDealer,
  });
  final String jobId;
  final bool isDealer;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.serviceCompletionRecords()
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final record = ServiceCompletionRecordModel.fromFirestore(
          snapshot.data!.docs.first,
        );
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Completion Record',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _Row(label: 'Record ID', value: record.displayRecordId),
                _Row(label: 'Job ID', value: record.displayJobId),
                _Row(label: 'Service type', value: record.serviceType ?? '—'),
                _Row(label: 'Technician', value: record.technicianName),
                _Row(
                  label: 'Completion date',
                  value: record.completionDate != null
                      ? '${record.completionDate!.day}/${record.completionDate!.month}/${record.completionDate!.year}'
                      : '—',
                ),
                _Row(
                  label: 'Warranty status',
                  value: record.warrantyStatusLabel,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () =>
                      context.push(RouteNames.dealerServiceRecord(jobId)),
                  icon: const Icon(Icons.visibility, size: 20),
                  label: const Text('View record'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isDealer
                      ? 'View, download PDF, or print from the record screen.'
                      : '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RatingDisplayCard extends StatelessWidget {
  const _RatingDisplayCard({
    required this.rating,
    required this.review,
    required this.label,
  });
  final num? rating;
  final String? review;
  final String label;

  @override
  Widget build(BuildContext context) {
    final stars = rating != null ? rating!.toInt() : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < stars ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
            ),
            if (review != null && review!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _DealerApprovalCountdown extends StatefulWidget {
  const _DealerApprovalCountdown({required this.deadline});
  final DateTime deadline;

  @override
  State<_DealerApprovalCountdown> createState() =>
      _DealerApprovalCountdownState();
}

class _DealerApprovalCountdownState extends State<_DealerApprovalCountdown> {
  @override
  void initState() {
    super.initState();
    _updateRemaining();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    if (widget.deadline.isBefore(now)) return;
    Future.delayed(const Duration(minutes: 1), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = widget.deadline.difference(now);
    if (remaining.isNegative) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Auto-approval window passed. Payment will be released shortly.',
          ),
        ),
      );
    }
    final minutes = remaining.inMinutes;
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Auto payment release in $minutes minute${minutes == 1 ? '' : 's'} if you do not confirm.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
