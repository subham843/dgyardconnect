import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/route_names.dart';

/// Offers hub screen (deep-link target for push notifications).
///
/// If a specific `jobId` is provided (via query param), this screen redirects
/// to the right bidding/details flow based on role.
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key, this.jobId});

  final String? jobId;

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  @override
  void initState() {
    super.initState();
    // If deep-linked with jobId, redirect after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRedirect());
  }

  Future<void> _maybeRedirect() async {
    final jobId = widget.jobId?.trim() ?? '';
    if (jobId.isEmpty || !mounted) return;

    String role = 'technician';
    try {
      final prefs = await SharedPreferences.getInstance();
      role = (prefs.getString('fcm_current_user_role') ?? 'technician').toLowerCase();
    } catch (_) {}

    if (!mounted) return;
    if (role == 'dealer') {
      context.go('/dealer/jobs/$jobId/bidding');
    } else {
      context.go('/technician/jobs/$jobId/bidding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.splash),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text('Open notification center'),
              subtitle: const Text('See all job updates and messages'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                // Use saved role (dealer/technician) to open correct notifications screen.
                String role = 'technician';
                try {
                  final prefs = await SharedPreferences.getInstance();
                  role = (prefs.getString('fcm_current_user_role') ?? 'technician').toLowerCase();
                } catch (_) {}
                if (!context.mounted) return;
                if (role == 'dealer') {
                  context.go(RouteNames.dealerNotifications);
                } else {
                  context.go(RouteNames.technicianNotifications);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.work_outline_rounded),
              title: const Text('Go to home'),
              subtitle: const Text('Browse current jobs and activity'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go(RouteNames.splash),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tip: If a push notification includes a job_id, we’ll take you directly to that job’s bidding screen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

