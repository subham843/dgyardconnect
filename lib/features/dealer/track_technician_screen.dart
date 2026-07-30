import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/firestore_service.dart';
import 'dealer_job_tracking_view.dart';

class TrackTechnicianScreen extends StatelessWidget {
  const TrackTechnicianScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Track technician')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track technician'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dealer/jobs/$jobId/bidding'),
        ),
      ),
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
          final data = doc.data() ?? {};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: DealerJobTrackingView(
              jobId: jobId,
              job: job,
              jobData: data,
              mapHeight: 400,
            ),
          );
        },
      ),
    );
  }
}
