import 'package:flutter/material.dart';
import 'level_badge.dart';

class ProfileCardTechnician extends StatelessWidget {
  const ProfileCardTechnician({
    super.key,
    this.name,
    this.level,
    this.rating,
    this.jobsCompleted,
    this.onTimeRate,
  });

  final String? name;
  final String? level;
  final double? rating;
  final int? jobsCompleted;
  final double? onTimeRate;

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
                  child: Text((name ?? 'T').substring(0, 1).toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name ?? 'Technician', style: Theme.of(context).textTheme.titleMedium),
                      if (level != null) LevelBadge(label: level!,),
                    ],
                  ),
                ),
              ],
            ),
            if (rating != null || jobsCompleted != null || onTimeRate != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (rating != null) Text('★ ${rating!.toStringAsFixed(1)}'),
                  if (jobsCompleted != null) Text('$jobsCompleted jobs'),
                  if (onTimeRate != null) Text('${onTimeRate!.toStringAsFixed(0)}% on time'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
