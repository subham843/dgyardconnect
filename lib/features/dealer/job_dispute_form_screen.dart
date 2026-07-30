import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/analytics_events.dart';
import '../../core/constants/legal_constants.dart';
import '../../shared/services/analytics_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';

/// Dealer raises a dispute before auto-approval. Payment stays in escrow until admin resolves.
class JobDisputeFormScreen extends StatefulWidget {
  const JobDisputeFormScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<JobDisputeFormScreen> createState() => _JobDisputeFormScreenState();
}

class _JobDisputeFormScreenState extends State<JobDisputeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final List<String> _photoUrls = [];
  String? _videoUrl;
  bool _loading = false;
  bool _uploading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    for (var i = 0; i < files.length; i++) {
      final url = await StorageService.uploadJobDisputePhoto(
        jobId: widget.jobId,
        index: _photoUrls.length + i,
        file: File(files[i].path),
      );
      if (url != null && mounted) setState(() => _photoUrls.add(url));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    final url = await StorageService.uploadJobDisputeVideo(
      jobId: widget.jobId,
      file: File(file.path),
    );
    if (mounted) setState(() { _videoUrl = url; _uploading = false; });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final dealerId = FirebaseAuth.instance.currentUser?.uid;
    if (dealerId == null) return;
    setState(() => _loading = true);
    try {
      final jobSnap = await FirestoreService.jobs().doc(widget.jobId).get();
      final techId = jobSnap.data()?['technicianId'] as String?;
      await FirestoreService.jobDisputes().add({
        'jobId': widget.jobId,
        'dealerId': dealerId,
        'technicianId': techId,
        'description': _descriptionController.text.trim(),
        'photoUrls': _photoUrls,
        'videoUrl': _videoUrl,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await AnalyticsService.logEvent(AnalyticsEvents.jobDisputeCreated, params: {
        AnalyticsEvents.paramJobId: widget.jobId,
        AnalyticsEvents.paramHasPhotos: _photoUrls.isNotEmpty,
        AnalyticsEvents.paramHasVideo: _videoUrl != null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute submitted. Payment will stay in escrow until admin decision.')),
        );
        context.go('/dealer/jobs/${widget.jobId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raise dispute'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${LegalConstants.disputeNotice}\n\nRaising a dispute keeps the payment in escrow until admin reviews. You can provide description and evidence (photos, optional video).',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Describe the issue with the job completion',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              const Text('Photo evidence', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickPhotos,
                icon: _uploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_photo_alternate),
                label: Text(_photoUrls.isEmpty ? 'Add photos' : 'Add more (${_photoUrls.length})'),
              ),
              if (_photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _photoUrls.map((url) => Image.network(url, width: 72, height: 72, fit: BoxFit.cover)).toList(),
                ),
              ],
              const SizedBox(height: 12),
              const Text('Video (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickVideo,
                icon: const Icon(Icons.videocam),
                label: Text(_videoUrl != null ? 'Video added' : 'Add video'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.orange,
                ),
                child: _loading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit dispute'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
