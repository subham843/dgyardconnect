import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

/// Admin: Platform performance dashboard – real-time metrics.
class AdminPlatformDashboardScreen extends StatelessWidget {
  const AdminPlatformDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Platform dashboard')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Real-time metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.jobs()
                  .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
                  .snapshots(),
              builder: (context, jobsSnap) {
                final jobsToday = jobsSnap.hasData ? jobsSnap.data!.docs.length : 0;
                return _MetricCard(
                  title: 'Jobs posted today',
                  value: '$jobsToday',
                  icon: Icons.work,
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.users()
                  .where('role', isEqualTo: 'technician')
                  .where('online', isEqualTo: true)
                  .where('approved', isEqualTo: true)
                  .snapshots(),
              builder: (context, techSnap) {
                final activeTechs = techSnap.hasData ? techSnap.data!.docs.length : 0;
                return _MetricCard(
                  title: 'Active technicians online',
                  value: '$activeTechs',
                  icon: Icons.engineering,
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.jobs().where('status', isEqualTo: 'completed').snapshots(),
              builder: (context, completedSnap) {
                final completed = completedSnap.hasData ? completedSnap.data!.docs.length : 0;
                return _MetricCard(
                  title: 'Total completed jobs',
                  value: '$completed',
                  icon: Icons.check_circle,
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.warrantyClaims().snapshots(),
              builder: (context, claimsSnap) {
                final claims = claimsSnap.hasData ? claimsSnap.data!.docs.length : 0;
                return _MetricCard(
                  title: 'Warranty claims',
                  value: '$claims',
                  icon: Icons.verified_user_outlined,
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.jobDisputes().where('status', isEqualTo: 'open').snapshots(),
              builder: (context, disputesSnap) {
                final openDisputes = disputesSnap.hasData ? disputesSnap.data!.docs.length : 0;
                return _MetricCard(
                  title: 'Open disputes',
                  value: '$openDisputes',
                  icon: Icons.gavel,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
