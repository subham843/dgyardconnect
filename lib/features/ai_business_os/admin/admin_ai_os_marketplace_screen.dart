import 'package:flutter/material.dart';

import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';

class AdminAiOsMarketplaceScreen extends StatefulWidget {
  const AdminAiOsMarketplaceScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsMarketplaceScreen> createState() => _AdminAiOsMarketplaceScreenState();
}

class _AdminAiOsMarketplaceScreenState extends State<AdminAiOsMarketplaceScreen> {
  final _repo = BosRepository();
  List<BosMarketplaceItem> _items = [];
  List<Map<String, dynamic>> _installs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tenantId = await _repo.activeTenantId;
    final items = await _repo.listMarketplaceItems();
    final installs = await _repo.listInstalls(tenantId);
    if (mounted) {
      setState(() {
        _items = items;
        _installs = installs;
        _loading = false;
      });
    }
  }

  Future<void> _install(BosMarketplaceItem item) async {
    try {
      await _repo.applyMarketplaceInstall(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Installed ${item.name}')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'SaaS Marketplace',
      embedded: widget.embedded,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final installed = _installs.any((inst) => inst['item_id'] == item.id);
                  return ListTile(
                    leading: Icon(
                      item.category == 'kb' ? Icons.menu_book : Icons.extension,
                    ),
                    title: Text(item.name),
                    subtitle: Text('${item.category ?? 'template'} · ${item.description ?? ''}'),
                    trailing: installed
                        ? const Chip(label: Text('Installed'))
                        : FilledButton(
                            onPressed: () => _install(item),
                            child: const Text('Install'),
                          ),
                  );
                },
              ),
            ),
    );
  }
}
