import 'package:flutter/material.dart';

class RatingReviewForm extends StatefulWidget {
  const RatingReviewForm({
    super.key,
    this.initialRating = 0,
    this.onSubmit,
  });

  final int initialRating;
  final ValueChanged<({int rating, String review})>? onSubmit;

  @override
  State<RatingReviewForm> createState() => _RatingReviewFormState();
}

class _RatingReviewFormState extends State<RatingReviewForm> {
  late int _rating;
  final _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating > 0 ? widget.initialRating : 0;
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            return IconButton(
              icon: Icon(
                _rating >= star ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 40,
              ),
              onPressed: () => setState(() => _rating = star),
            );
          }),
        ),
        if (_rating > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$_rating of 5',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _reviewController,
          decoration: const InputDecoration(
            labelText: 'Review (optional)',
            hintText: 'Write your review...',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _rating > 0
              ? () => widget.onSubmit?.call((
                    rating: _rating,
                    review: _reviewController.text.trim(),
                  ))
              : null,
          child: const Text('Submit rating'),
        ),
      ],
    );
  }
}
