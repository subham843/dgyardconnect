import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/seo_admin_repository.dart';
import '../domain/seo_service.dart';

class AdminSeoServicesScreen extends StatefulWidget {
  const AdminSeoServicesScreen({super.key, this.embedded = false, this.onNavigateRoute});

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminSeoServicesScreen> createState() => _AdminSeoServicesScreenState();
}

class _AdminSeoServicesScreenState extends State<AdminSeoServicesScreen> {
  final _repo = SeoAdminRepository();
  List<SeoService> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _repo.listServices();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit(SeoService service) {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(RouteNames.adminSeoServiceEdit(service.id));
      return Future.value();
    }
    return context.push(RouteNames.adminSeoServiceEdit(service.id)).then((_) => _load());
  }

  void _addService() {
    if (widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(RouteNames.adminSeoServiceCreate);
      return;
    }
    context.push(RouteNames.adminSeoServiceCreate).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = _items[i];
              return ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('/${s.slug} · order ${s.sortOrder}${s.isActive ? ' · live' : ' · hidden'}'),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () => _edit(s),
              );
            },
          );

    return AdminEmbeddedScaffold(
      title: 'SEO Services',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addService,
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      ),
      body: body,
    );
  }
}
