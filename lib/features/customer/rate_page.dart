import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';

class CustomerRatePage extends StatefulWidget {
  const CustomerRatePage({super.key, this.jobId, this.token});

  final String? jobId;
  final String? token;

  @override
  State<CustomerRatePage> createState() => _CustomerRatePageState();
}

class _CustomerRatePageState extends State<CustomerRatePage> {
  bool _submitted = false;
  bool _loading = true;
  bool _invalidToken = false;
  int _dealerRating = 0;
  final _dealerReviewController = TextEditingController();
  int _technicianRating = 0;
  final _technicianReviewController = TextEditingController();

  @override
  void dispose() {
    _dealerReviewController.dispose();
    _technicianReviewController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _jobData;

  Future<void> _checkToken() async {
    if (widget.jobId == null || widget.jobId!.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    if (!FirestoreService.isAvailable) {
      setState(() => _loading = false);
      return;
    }
    final doc = await FirestoreService.jobs().doc(widget.jobId).get();
    _jobData = doc.data();
    final ratingToken = _jobData?['customerRatingToken'] as String?;
    final valid = ratingToken != null && ratingToken == widget.token;
    setState(() {
      _loading = false;
      _invalidToken = !valid && widget.token != null && widget.token!.isNotEmpty;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _submit() async {
    if (widget.jobId == null || widget.jobId!.isEmpty) return;
    if (_dealerRating < 1 && _technicianRating < 1) return;
    if (Firebase.apps.isNotEmpty && widget.token != null && widget.token!.isNotEmpty) {
      try {
        await FirebaseFunctions.instance.httpsCallable('submitCustomerRating').call({
          'jobId': widget.jobId,
          'token': widget.token,
          if (_dealerRating >= 1) 'dealerRating': _dealerRating,
          if (_dealerReviewController.text.trim().isNotEmpty) 'dealerReview': _dealerReviewController.text.trim(),
          if (_technicianRating >= 1) 'technicianRating': _technicianRating,
          if (_technicianReviewController.text.trim().isNotEmpty) 'technicianReview': _technicianReviewController.text.trim(),
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit: $e')),
          );
        }
        return;
      }
    } else if (FirestoreService.isAvailable) {
      await FirestoreService.jobs().doc(widget.jobId).update({
        if (_dealerRating >= 1) 'customerRatingToDealer': _dealerRating,
        if (_dealerReviewController.text.trim().isNotEmpty) 'customerReviewToDealer': _dealerReviewController.text.trim(),
        if (_technicianRating >= 1) 'customerRatingToTechnician': _technicianRating,
        if (_technicianReviewController.text.trim().isNotEmpty) 'customerReviewToTechnician': _technicianReviewController.text.trim(),
      });
    }
    if (mounted) setState(() => _submitted = true);
  }

  static const _bgLight = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _bgLight,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (widget.jobId == null || widget.jobId!.isEmpty) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Rate your experience', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Invalid link. Please use the link sent to you.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
          ),
        ),
      );
    }
    if (_invalidToken) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Rate your experience', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('This link has expired or is invalid.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
          ),
        ),
      );
    }
    if (_submitted) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Rate your experience', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 72),
              const SizedBox(height: 16),
              Text('Thank you. Your ratings have been submitted.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF0F172A)))
                  .animate()
                  .fadeIn()
                  .slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      );
    }
    // Already rated – show existing ratings instead of form
    final dealerRating = _jobData?['customerRatingToDealer'];
    final technicianRating = _jobData?['customerRatingToTechnician'];
    if (dealerRating != null || technicianRating != null) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Rate your experience', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (dealerRating != null)
                _CustomerRatingCard(
                  title: 'Your rating for dealer',
                  rating: (dealerRating as num).toInt(),
                  review: _jobData?['customerReviewToDealer'] as String?,
                ),
              if (dealerRating != null && technicianRating != null) const SizedBox(height: 16),
              if (technicianRating != null)
                _CustomerRatingCard(
                  title: 'Your rating for technician',
                  rating: (technicianRating as num).toInt(),
                  review: _jobData?['customerReviewToTechnician'] as String?,
                ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Rate your experience', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Please rate the dealer and technician for this job.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF64748B)),
            )
                .animate()
                .fadeIn()
                .slideX(begin: -0.05, end: 0),
            const SizedBox(height: 24),
            _RatingSection(
              title: 'Rate the dealer',
              rating: _dealerRating,
              onRatingChanged: (v) => setState(() => _dealerRating = v),
              reviewController: _dealerReviewController,
            ),
            const SizedBox(height: 24),
            _RatingSection(
              title: 'Rate the technician',
              rating: _technicianRating,
              onRatingChanged: (v) => setState(() => _technicianRating = v),
              reviewController: _technicianReviewController,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: (_dealerRating >= 1 || _technicianRating >= 1) ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Submit all ratings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.title,
    required this.rating,
    required this.onRatingChanged,
    required this.reviewController,
  });

  final String title;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController reviewController;

  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF0F172A))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return IconButton(
                icon: Icon(
                  rating >= star ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 40,
                ),
                onPressed: () => onRatingChanged(star),
              );
            }),
          ),
          if (rating > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('$rating of 5', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B))),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: reviewController,
            decoration: InputDecoration(
              labelText: 'Review (optional)',
              hintText: 'Write your review...',
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _CustomerRatingCard extends StatelessWidget {
  const _CustomerRatingCard({
    required this.title,
    required this.rating,
    required this.review,
  });
  final String title;
  final int rating;
  final String? review;

  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: const Color(0xFF0F172A))),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) => Icon(
              i < rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: Colors.amber,
              size: 32,
            )),
          ),
          if (review != null && review!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(review!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF334155))),
          ],
        ],
      ),
    );
  }
}
