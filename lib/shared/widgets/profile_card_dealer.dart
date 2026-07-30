import 'package:flutter/material.dart';
import 'level_badge.dart';

class ProfileCardDealer extends StatelessWidget {
  const ProfileCardDealer({
    super.key,
    this.name,
    this.level,
    this.rating,
    this.jobsPosted,
    this.paymentSpeed,
  });

  final String? name;
  final String? level;
  final double? rating;
  final int? jobsPosted;
  final String? paymentSpeed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text((name ?? 'D').substring(0, 1).toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name ?? 'Dealer', style: Theme.of(context).textTheme.titleMedium),
                      if (level != null) LevelBadge(label: level!),
                    ],
                  ),
                ),
              ],
            ),
            if (rating != null || jobsPosted != null || paymentSpeed != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (rating != null) Text('★ ${rating!.toStringAsFixed(1)}'),
                  if (jobsPosted != null) Text('$jobsPosted jobs'),
                  if (paymentSpeed != null) Text(paymentSpeed!),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
