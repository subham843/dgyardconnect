import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/seo_admin_repository.dart';
import '../domain/seo_city.dart';

class AdminSeoCitiesScreen extends StatefulWidget {
  const AdminSeoCitiesScreen({super.key, this.embedded = false, this.onNavigateRoute});

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminSeoCitiesScreen> createState() => _AdminSeoCitiesScreenState();
}

class _AdminSeoCitiesScreenState extends State<AdminSeoCitiesScreen> {
  final _repo = SeoAdminRepository();
  List<SeoCity> _items = [];
  bool _loading = true;

  void _go(String route) {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(route);
    } else {
      context.push(route);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _repo.listCities();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
            ? const Center(child: Text('No cities yet. Add Ranchi, Patna, etc.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = _items[i];
                  return ListTile(
                    tileColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text('${c.name}, ${c.state}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '/${c.slug} · priority ${c.priority} · '
                      '${c.isActive && c.serviceAvailable ? 'live' : 'hidden'} · '
                      '${c.nearbyDistricts.length} districts',
                    ),
                    trailing: const Icon(Icons.edit_rounded),
                    onTap: () => _go(RouteNames.adminSeoCityEdit(c.id)),
                  );
                },
              );

    return AdminEmbeddedScaffold(
      title: 'SEO Cities',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _go(RouteNames.adminSeoCityCreate),
        icon: const Icon(Icons.add),
        label: const Text('Add city'),
      ),
      body: body,
    );
  }
}
