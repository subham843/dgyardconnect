import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/analytics_events.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/warranty_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/warranty_claim_category_model.dart';
import '../../shared/services/analytics_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/widgets/minimal_app_bar.dart';

class WarrantyClaimFormScreen extends StatefulWidget {
  const WarrantyClaimFormScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<WarrantyClaimFormScreen> createState() => _WarrantyClaimFormScreenState();
}

class _WarrantyClaimFormScreenState extends State<WarrantyClaimFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemController = TextEditingController();
  final List<String> _photoUrls = [];
  String? _videoUrl;
  String? _categoryId;
  String? _categoryTitle;
  bool _loading = false;
  bool _uploading = false;
  List<WarrantyClaimCategoryModel> _categories = [];
  Map<String, dynamic>? _jobData;
  String? _jobCode;

  @override
  void initState() {
    super.initState();
    _loadJobAndCategories();
  }

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  Future<void> _loadJobAndCategories() async {
    final jobSnap = await FirestoreService.jobs().doc(widget.jobId).get();
    if (!jobSnap.exists || !mounted) return;
    final data = jobSnap.data();
    setState(() {
      _jobData = data;
      _jobCode = (data?['jobCode'] as String?)?.trim();
    });
    final job = _jobData!;
    final sectorId = job['sectorId'] as String?;
    final subOptionId = job['subOptionId'] as String?;
    var query = FirestoreService.warrantyClaimCategories().orderBy('sortOrder');
    final snap = await query.get();
    var list = snap.docs.map((d) => WarrantyClaimCategoryModel.fromFirestore(d)).toList();
    if (sectorId != null) {
      list = list.where((c) => c.sectorId == null || c.sectorId == sectorId).toList();
      if (subOptionId != null) {
        list = list.where((c) => c.subOptionId == null || c.subOptionId == subOptionId).toList();
      }
    }
    if (mounted) setState(() => _categories = list);
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 80);
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    for (var i = 0; i < files.length; i++) {
      final file = File(files[i].path);
      final url = await StorageService.uploadWarrantyClaimPhoto(
        jobId: widget.jobId,
        index: _photoUrls.length + i,
        file: file,
      );
      if (url != null && mounted) {
        setState(() => _photoUrls.add(url));
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    final url = await StorageService.uploadWarrantyClaimVideo(
      jobId: widget.jobId,
      file: File(file.path),
    );
    if (mounted) {
      setState(() {
      _videoUrl = url;
      _uploading = false;
    });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final dealerId = FirebaseAuth.instance.currentUser?.uid;
    if (dealerId == null) return;
    final job = _jobData;
    if (job == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job not found.')));
      return;
    }
    final technicianId = job['technicianId'] as String?;
    if (technicianId == null || technicianId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No technician assigned to this job.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final deadline = DateTime.now().add(const Duration(hours: 24));
      final claimRef = FirestoreService.warrantyClaims().doc();
      await claimRef.set({
        'jobId': widget.jobId,
        'jobCode': (job['jobCode'] as String?)?.trim().isEmpty == true ? null : job['jobCode'],
        'dealerId': dealerId,
        'technicianId': technicianId,
        'problemDescription': _problemController.text.trim(),
        'photoUrls': _photoUrls,
        'videoUrl': _videoUrl,
        'categoryId': _categoryId,
        'categoryTitle': _categoryTitle,
        'claimStatus': 'pending',
        'claimTime': FieldValue.serverTimestamp(),
        'claimResponseDeadline': Timestamp.fromDate(deadline),
        'holdPaymentAmount': (job['holdPaymentAmount'] as num?)?.toDouble(),
      });
      await FirestoreService.jobs().doc(widget.jobId).update({
        'warrantyStatus': 'claim_open',
      });
      await AnalyticsService.logEvent(AnalyticsEvents.warrantyClaimCreated, params: {
        AnalyticsEvents.paramJobId: widget.jobId,
        AnalyticsEvents.paramClaimId: claimRef.id,
        AnalyticsEvents.paramHasPhotos: _photoUrls.isNotEmpty,
        AnalyticsEvents.paramHasVideo: _videoUrl != null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warranty claim submitted. Technician has been notified.')),
        );
        context.go(RouteNames.dealerWarrantyClaims);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit claim: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: MinimalAppBar(
        title: 'Raise warranty claim',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Job ID',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  (_jobCode != null && _jobCode!.isNotEmpty) ? _jobCode! : widget.jobId,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _problemController,
                decoration: const InputDecoration(
                  labelText: 'Problem description *',
                  hintText: 'Describe the issue that needs warranty support',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please describe the problem.';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Upload photos',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._photoUrls.asMap().entries.map((e) => _PhotoChip(
                    url: e.value,
                    onRemove: () => setState(() => _photoUrls.removeAt(e.key)),
                  )),
                  if (_uploading)
                    const SizedBox(
                      width: 80,
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    GestureDetector(
                      onTap: _pickPhotos,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Video (optional)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (_videoUrl != null)
                ListTile(
                  leading: const Icon(Icons.videocam, color: AppColors.primary),
                  title: const Text('Video added'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _videoUrl = null),
                  ),
                )
              else if (!_uploading)
                OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.video_library_outlined, size: 20),
                  label: const Text('Add video'),
                ),
              const SizedBox(height: 20),
              if (_categories.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId != null && _categories.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Claim category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Select category')),
                    ..._categories.map((c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.title),
                    )),
                  ],
                  onChanged: (v) {
                    final c = _categories.cast<WarrantyClaimCategoryModel?>().firstWhere(
                      (x) => x?.id == v,
                      orElse: () => null,
                    );
                    setState(() {
                      _categoryId = v;
                      _categoryTitle = c?.title;
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],
              const SizedBox(height: 8),
              Text(
                WarrantyConstants.disclaimer,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit claim'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoChip extends StatelessWidget {
  const _PhotoChip({required this.url, required this.onRemove});
  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 80,
              height: 80,
              child: Icon(Icons.broken_image),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.error,
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
