import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../shared/services/firestore_service.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import '../../shared/widgets/rating_review_form.dart';

class TechnicianRateDealerScreen extends StatefulWidget {
  const TechnicianRateDealerScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<TechnicianRateDealerScreen> createState() => _TechnicianRateDealerScreenState();
}

class _TechnicianRateDealerScreenState extends State<TechnicianRateDealerScreen> {
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return TechnicianLightScope(
      child: Scaffold(
      appBar: TechnicianGlassAppBar(
        title: 'Rate dealer',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/technician/jobs/${widget.jobId}'),
        ),
      ),
      backgroundColor: Colors.transparent,
      body: TechnicianGlassBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.jobs().doc(widget.jobId).snapshots(),
          builder: (context, snap) {
            if (snap.hasData && snap.data!.exists) {
              final d = snap.data!.data() ?? {};
              final existingRating = d['technicianRatingToDealer'];
              final existingReview = d['technicianReviewToDealer'] as String?;
              if (existingRating != null) {
                return _AlreadyRatedContent(
                  rating: (existingRating as num).toInt(),
                  review: existingReview,
                  onBack: () => context.go('/technician/jobs/${widget.jobId}'),
                );
              }
            }
            return _buildBody();
          },
        ),
      ),
    ),
    );
  }

  Widget _buildBody() {
    if (_submitted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Thank you. Your rating has been submitted.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/technician/jobs/${widget.jobId}'),
              child: const Text('Back to job'),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rate the dealer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          RatingReviewForm(
            onSubmit: (value) async {
              try {
                if (Firebase.apps.isNotEmpty) {
                  await FirebaseFunctions.instance.httpsCallable('onRatingSubmitted').call({
                    'jobId': widget.jobId,
                    'raterRole': 'technician',
                    'rating': value.rating,
                    'review': value.review.isNotEmpty ? value.review : null,
                  });
                } else {
                  await FirestoreService.jobs().doc(widget.jobId).update({
                    'technicianRatingToDealer': value.rating,
                    'technicianReviewToDealer': value.review,
                  });
                }
              } catch (_) {
                await FirestoreService.jobs().doc(widget.jobId).update({
                  'technicianRatingToDealer': value.rating,
                  'technicianReviewToDealer': value.review,
                });
              }
              if (mounted) setState(() => _submitted = true);
            },
          ),
        ],
      ),
    );
  }
}

class _AlreadyRatedContent extends StatelessWidget {
  const _AlreadyRatedContent({
    required this.rating,
    required this.review,
    required this.onBack,
  });
  final int rating;
  final String? review;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your rating', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    )),
                  ),
                  if (review != null && review!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(review!, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onBack,
            child: const Text('Back to job'),
          ),
        ],
      ),
    );
  }
}
