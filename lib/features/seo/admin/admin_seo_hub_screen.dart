import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';

class AdminSeoHubScreen extends StatelessWidget {
  const AdminSeoHubScreen({super.key, this.embedded = false, this.onNavigateRoute});

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  void _go(BuildContext context, String route) {
    if (onNavigateRoute != null) {
      onNavigateRoute!(route);
    } else {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'SEO Engine',
      embedded: embedded,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HubCard(
            title: 'SEO Cities',
            subtitle: 'Add cities — auto-generates all service landing pages',
            icon: Icons.location_city_rounded,
            onTap: () => _go(context, RouteNames.adminSeoCities),
          ),
          const SizedBox(height: 12),
          _HubCard(
            title: 'SEO Services',
            subtitle: 'Manage installation service types and templates',
            icon: Icons.handyman_rounded,
            onTap: () => _go(context, RouteNames.adminSeoServices),
          ),
          const SizedBox(height: 12),
          _HubCard(
            title: 'SEO Blog Posts',
            subtitle: 'Articles linked from service landing pages',
            icon: Icons.article_rounded,
            onTap: () => _go(context, RouteNames.adminSeoBlogPosts),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
