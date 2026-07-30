import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:vibration/vibration.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/legal_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/account_completion_guard.dart';
import '../../shared/services/fcm_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/rejection_reason_dialog.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';

class IncomingJobScreen extends StatefulWidget {
  const IncomingJobScreen({super.key, this.jobId});
  final String? jobId;

  @override
  State<IncomingJobScreen> createState() => _IncomingJobScreenState();
}

class _IncomingJobScreenState extends State<IncomingJobScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _triggerVibration();
  }

  Future<void> _triggerVibration() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobId = widget.jobId ??
        (GoRouterState.of(context).uri.queryParameters['jobId']) ??
        '';
    if (jobId.isEmpty || !FirestoreService.isAvailable) {
      return TechnicianLightScope(
        child: Scaffold(
        appBar: TechnicianGlassAppBar(title: 'Incoming job'),
        body: TechnicianGlassBackground(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No job specified or Firebase not configured.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(RouteNames.technicianHome),
                  child: const Text('Back to home'),
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }
    return TechnicianLightScope(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: TechnicianGlassBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.jobs().doc(jobId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: CircularProgressIndicator(color: TechnicianUiTokens.accent, strokeWidth: 2),
              );
            }
            final doc = snapshot.data!;
            if (!doc.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Job no longer available.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go(RouteNames.technicianHome),
                      child: const Text('Back to home'),
                    ),
                  ],
                ),
              );
            }
            final job = JobModel.fromFirestore(doc);
            final data = doc.data() ?? {};
            return _IncomingJobContent(
              jobId: jobId,
              job: job,
              jobData: data,
              pulseController: _pulseController,
            );
          },
        ),
      ),
      ),
    );
  }
}

class _IncomingJobContent extends StatelessWidget {
  const _IncomingJobContent({
    required this.jobId,
    required this.job,
    required this.jobData,
    required this.pulseController,
  });
  final String jobId;
  final JobModel job;
  final Map<String, dynamic> jobData;
  final AnimationController pulseController;

  @override
  Widget build(BuildContext context) {
    var amount = job.technicianPayoutAmount ?? job.dealerRate ?? job.fixedRate ?? 0.0;
    final materialList = (jobData['materialList'] as List<dynamic>?) ?? [];
    if ((jobData['materialOption'] as String?) == 'material_by_technician' && materialList.isNotEmpty) {
      var materialTotal = 0.0;
      for (final e in materialList) {
        final m = e is Map ? Map<String, dynamic>.from(Map.from(e)) : <String, dynamic>{};
        final qty = (m['qty'] as num?)?.toInt() ?? 1;
        final itemRate = (m['rate'] as num?)?.toDouble() ?? 0.0;
        materialTotal += qty * itemRate;
      }
      amount = amount + materialTotal;
    }
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'New job request',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ).animate().fadeIn().slideY(begin: -0.2, end: 0),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              return Container(
                width: 160 + (pulseController.value * 20),
                height: 160 + (pulseController.value * 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: TechnicianUiTokens.accent.withValues(
                        alpha: 0.3 + (pulseController.value * 0.4)),
                    width: 6,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.work_outline,
                    size: 72,
                    color: TechnicianUiTokens.accent,
                  ),
                ),
              );
            },
          ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        job.title ?? 'Job',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 200.ms),
                      if (job.isEmergency)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Chip(
                            label: const Text('Emergency'),
                            backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                          ),
                        ).animate().fadeIn(delay: 250.ms),
                      if (job.description != null && job.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          job.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ).animate().fadeIn(delay: 260.ms),
                      ],
                      const SizedBox(height: 16),
                      _ResolvedAddressRow(
                        label: 'Job location (area)',
                        address: job.address,
                        addressToArea: _addressToArea,
                      ),
                      const SizedBox(height: 12),
                      _MaterialHandlingRow(
                        label: 'Material handling',
                        materialText: _buildMaterialText(context),
                        pickupAddress: job.pickupAddress ?? jobData['pickupAddress'] as String?,
                        materialOption: job.materialOption ?? jobData['materialOption'] as String?,
                        addressToArea: _addressToArea,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: TechnicianUiTokens.accent,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 350.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Reject'),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),
                ),
                const SizedBox(width: 8),
                if (job.biddingEnabled)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goToBidding(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Bid'),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05, end: 0),
                if (job.biddingEnabled) const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => _accept(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(job.biddingEnabled ? 'Accept rate' : 'Accept'),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Extract area/road/mohalla only — no landmark, no building name.
  /// Strips Building:, Landmark:, Shop/Flat/House no: and returns locality from Google.
  String _addressToArea(String? addr) {
    if (addr == null || addr.trim().isEmpty) return '—';
    final parts = addr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return addr;
    // Remove building, landmark, shop/flat/house — dealer-added details
    final filtered = parts.where((p) {
      final lower = p.toLowerCase();
      return !lower.startsWith('building:') &&
          !lower.startsWith('landmark:') &&
          !lower.startsWith('shop/flat/house no:');
    }).toList();
    if (filtered.isEmpty) return '—';
    // Return last 2–3 parts (area, road, mohalla) — locality from Google Maps
    final n = filtered.length <= 3 ? filtered.length : 3;
    return filtered.sublist(filtered.length - n).join(', ');
  }

  String _buildMaterialText(BuildContext context) {
    final opt = job.materialOption ?? jobData['materialOption'] as String?;
    if (opt == null || opt == 'no_pickup') return 'No material required';
    if (opt == 'pickup') {
      final addr = job.pickupAddress ?? jobData['pickupAddress'] as String? ?? '';
      final listRaw = job.pickupMaterialList ?? (jobData['pickupMaterialList'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final list = listRaw ?? [];
      final items = list.map((i) {
        final name = i['itemName'] as String? ?? 'Item';
        final qty = (i['qty'] as num?)?.toInt() ?? 1;
        return '$name x$qty';
      }).join(', ');
      return '${_addressToArea(addr)}\nItems: ${items.isNotEmpty ? items : '—'}';
    }
    if (opt == 'material_by_technician') return 'Technician arranges materials';
    return 'No material required';
  }

  Future<void> _goToBidding(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FcmService.cancelJobNotification();
    try {
      await FirestoreService.jobs().doc(jobId).update({
        'technicianId': uid,
        'status': 'bidding',
        'offeredToTechnicianIds': FieldValue.arrayUnion([uid]),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job accepted. Submit your bid.')),
        );
        context.go('/technician/jobs/$jobId/bidding');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _accept(BuildContext context) async {
    final canAccept = await AccountCompletionGuard.ensureTechnicianCanAcceptJob(context);
    if (!canAccept || !context.mounted) return;

    // Preview free accept limit / acceptance fee
    if (Firebase.apps.isNotEmpty) {
      try {
        final preview = await FirebaseFunctions.instance
            .httpsCallable('previewTechnicianAcceptLimit')
            .call({});
        final p = preview.data as Map<dynamic, dynamic>?;
        final applies = p?['chargeApplies'] == true;
        final fee = (p?['acceptanceFeeAmount'] as num?)?.toDouble() ?? 0;
        final remaining = (p?['remaining'] as num?)?.toInt() ?? 0;
        final msg = applies
            ? 'Free accept limit exhausted. Acceptance fee will be deducted: ₹${fee.toStringAsFixed(0)}'
            : 'Free accepts remaining: $remaining';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      } catch (_) {}
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm job acceptance'),
        content: Text(LegalConstants.technicianJobAcceptDisclaimer),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FcmService.cancelJobNotification();
    var rate = job.technicianPayoutAmount ?? job.dealerRate ?? job.fixedRate ?? 0.0;
    final materialList = (jobData['materialList'] as List<dynamic>?) ?? [];
    if ((jobData['materialOption'] as String?) == 'material_by_technician' && materialList.isNotEmpty) {
      var materialTotal = 0.0;
      for (final e in materialList) {
        final m = e is Map ? Map<String, dynamic>.from(Map.from(e)) : <String, dynamic>{};
        final qty = (m['qty'] as num?)?.toInt() ?? 1;
        final itemRate = (m['rate'] as num?)?.toDouble() ?? 0.0;
        materialTotal += qty * itemRate;
      }
      rate = rate + materialTotal;
    }
    try {
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase is not configured.');
      }
      await FirebaseFunctions.instance.httpsCallable('acceptJobWithLimit').call({
        'jobId': jobId,
        'agreedAmount': rate,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job accepted. Waiting for payment.')),
        );
        context.go('/technician/jobs/$jobId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e')),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final reason = await showRejectionReasonDialog(context, type: 'technician');
    if (reason == null) return;
    await FcmService.cancelJobNotification();
    try {
      await FirestoreService.jobs().doc(jobId).update({
        'offeredToTechnicianIds': FieldValue.arrayUnion([uid]),
        if (job.technicianId == uid) 'technicianId': null,
        'lastRejectedBy': 'technician',
        'lastRejectionReason': reason,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job declined. Next technician will be notified.')),
        );
        context.go(RouteNames.technicianHome);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e')),
        );
        context.go(RouteNames.technicianHome);
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// Address row — resolves lat,lng to area when address is stored as coordinates.
class _ResolvedAddressRow extends StatelessWidget {
  const _ResolvedAddressRow({
    required this.label,
    required this.address,
    required this.addressToArea,
  });
  final String label;
  final String? address;
  final String Function(String?) addressToArea;

  @override
  Widget build(BuildContext context) {
    if (address == null || !_MaterialHandlingRow._isLatLngFormat(address)) {
      return _DetailRow(label: label, value: addressToArea(address));
    }
    return FutureBuilder<String>(
      future: _MaterialHandlingRow._resolveLatLngToAddress(address!),
      builder: (context, snapshot) {
        final value = snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty
            ? addressToArea(snapshot.data)
            : snapshot.connectionState == ConnectionState.waiting
                ? 'Loading…'
                : addressToArea(address);
        return _DetailRow(label: label, value: value);
      },
    );
  }
}

/// Material handling row — resolves lat,lng to address when pickup address is stored as coordinates.
class _MaterialHandlingRow extends StatelessWidget {
  const _MaterialHandlingRow({
    required this.label,
    required this.materialText,
    required this.pickupAddress,
    required this.materialOption,
    required this.addressToArea,
  });
  final String label;
  final String materialText;
  final String? pickupAddress;
  final String? materialOption;
  final String Function(String?) addressToArea;

  static bool _isLatLngFormat(String? s) {
    if (s == null || s.trim().isEmpty) return false;
    final parts = s.split(',').map((e) => e.trim()).toList();
    if (parts.length != 2) return false;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    return lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  static Future<String> _resolveLatLngToAddress(String latLng) async {
    final parts = latLng.split(',').map((e) => e.trim()).toList();
    if (parts.length != 2) return latLng;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return latLng;
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        'reverse',
        {'format': 'json', 'lat': '$lat', 'lon': '$lng', 'addressdetails': '1'},
      );
      final response = await http.get(uri, headers: {'User-Agent': 'DgYardConnect/1.0'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final addr = data?['display_name'] as String?;
        if (addr != null && addr.isNotEmpty) return addr;
      }
    } catch (_) {}
    return latLng;
  }

  @override
  Widget build(BuildContext context) {
    final isPickupWithLatLng = materialOption == 'pickup' &&
        pickupAddress != null &&
        _isLatLngFormat(pickupAddress!.split('\n').first.trim());

    if (!isPickupWithLatLng) {
      return _DetailRow(label: label, value: materialText);
    }

    final lines = materialText.split('\n');
    final firstLine = lines.first.trim();
    final rest = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    return FutureBuilder<String>(
      future: _resolveLatLngToAddress(firstLine),
      builder: (context, snapshot) {
        String displayValue;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          final resolved = addressToArea(snapshot.data);
          displayValue = rest.isEmpty ? resolved : '$resolved\n$rest';
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          displayValue = rest.isEmpty ? 'Loading…' : 'Loading…\n$rest';
        } else {
          displayValue = materialText;
        }
        return _DetailRow(label: label, value: displayValue);
      },
    );
  }
}
