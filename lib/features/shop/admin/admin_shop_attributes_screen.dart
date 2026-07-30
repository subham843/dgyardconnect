import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_auth_service.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import '../data/shop_catalog_repository.dart';
import '../domain/attribute_data_type.dart';
import '../domain/shop_attribute.dart';
import 'shop_admin_crud_actions.dart';

class AdminShopAttributeMasterScreen extends StatefulWidget {
  const AdminShopAttributeMasterScreen({super.key, this.embedded = false, this.onNavigateRoute});

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<AdminShopAttributeMasterScreen> createState() => _AdminShopAttributeMasterScreenState();
}

class _AdminShopAttributeMasterScreenState extends State<AdminShopAttributeMasterScreen> {
  final _repo = ShopCatalogRepository();
  List<ShopAttributeMaster> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _items = await _repo.listAttributeMaster();
    if (mounted) setState(() => _loading = false);
  }

  void _openEditor([String? id]) {
    final target = id == null ? RouteNames.adminShopAttributeCreate : RouteNames.adminShopAttributeEdit(id);
    if (widget.embedded && widget.onNavigateRoute != null) {
      widget.onNavigateRoute!(target);
      return;
    }
    context.push(target).then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Attribute master',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Attribute'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final a = _items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(a.label),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${a.key} · ${AttributeDataType.labelFor(a.dataType)}'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (a.isRequired) _chip('Required', Colors.orange),
                            if (a.useInFilter) _chip('Filter', Colors.blue),
                            if (a.useInCalculator) _chip('Calculator', Colors.purple),
                            _chip(a.isActive ? 'Active' : 'Hidden', a.isActive ? Colors.green : Colors.grey),
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () => _openEditor(a.id),
                    trailing: ShopAdminRowActions(
                      isActive: a.isActive,
                      onEdit: () => _openEditor(a.id),
                      onToggleActive: () async {
                        await _repo.updateAttributeMaster(
                          a.id,
                          key: a.key,
                          label: a.label,
                          dataType: a.dataType,
                          isActive: !a.isActive,
                        );
                        _load();
                      },
                      onDelete: () => ShopAdminCrudActions.deleteAttributeMaster(context, a, _load),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _chip(String label, Color color) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}

class AdminShopAttributeGroupsScreen extends StatefulWidget {
  const AdminShopAttributeGroupsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminShopAttributeGroupsScreen> createState() => _AdminShopAttributeGroupsScreenState();
}

class _AdminShopAttributeGroupsScreenState extends State<AdminShopAttributeGroupsScreen> {
  final _repo = ShopCatalogRepository();
  List<ShopAttributeGroup> _groups = [];
  List<ShopAttributeMaster> _attrs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await SupabaseAuthService.instance.ensureSuperadminWriteAccess();
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.listAttributeGroups(),
        _repo.listAttributeMaster(activeOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = results[0] as List<ShopAttributeGroup>;
        _attrs = results[1] as List<ShopAttributeMaster>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }

  ShopAttributeGroup _groupWithoutLink(ShopAttributeGroup group, String attributeId) {
    return ShopAttributeGroup(
      id: group.id,
      name: group.name,
      description: group.description,
      isActive: group.isActive,
      linkedAttributes: group.linkedAttributes.where((l) => l.attributeId != attributeId).toList(),
    );
  }

  Future<void> _addGroup() async {
    final name = TextEditingController();
    final selectedAttrIds = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('New attribute group'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Group name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Link attributes',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _attrs.isEmpty
                        ? 'No attributes yet. Create attributes in Attribute master first.'
                        : 'Select one or more attributes to include in this group.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                  ),
                  if (_attrs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setDialog(() {
                            if (selectedAttrIds.length == _attrs.length) {
                              selectedAttrIds.clear();
                            } else {
                              selectedAttrIds.addAll(_attrs.map((a) => a.id));
                            }
                          });
                        },
                        child: Text(
                          selectedAttrIds.length == _attrs.length ? 'Clear all' : 'Select all',
                        ),
                      ),
                    ),
                    ..._attrs.map(
                      (a) => CheckboxListTile(
                        value: selectedAttrIds.contains(a.id),
                        onChanged: (on) {
                          setDialog(() {
                            if (on == true) {
                              selectedAttrIds.add(a.id);
                            } else {
                              selectedAttrIds.remove(a.id);
                            }
                          });
                        },
                        title: Text(a.label),
                        subtitle: Text('${a.key} · ${AttributeDataType.labelFor(a.dataType)}'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Create group'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final groupId = await _repo.createAttributeGroup(name: name.text.trim());
      if (groupId != null && selectedAttrIds.isNotEmpty) {
        var order = 0;
        final links = <({String attributeId, int sortOrder, bool isRequired})>[];
        for (final attr in _attrs) {
          if (!selectedAttrIds.contains(attr.id)) continue;
          links.add((attributeId: attr.id, sortOrder: order++, isRequired: attr.isRequired));
        }
        await _repo.linkAttributesToGroup(groupId: groupId, links: links);
      }
      if (mounted) {
        final linked = selectedAttrIds.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              linked > 0 ? 'Group created with $linked attribute${linked == 1 ? '' : 's'}' : 'Group created',
            ),
          ),
        );
      }
      await _load();
    }
    name.dispose();
  }

  Future<void> _linkAttr(ShopAttributeGroup group) async {
    final linkedIds = group.linkedAttributes.map((l) => l.attributeId).toSet();
    final available = _attrs.where((a) => !linkedIds.contains(a.id)).toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All attributes are already linked to this group')),
        );
      }
      return;
    }

    final selectedAttrIds = <String>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Link attributes to ${group.name}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Select one or more attributes to link to this group.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setDialog(() {
                          if (selectedAttrIds.length == available.length) {
                            selectedAttrIds.clear();
                          } else {
                            selectedAttrIds.addAll(available.map((a) => a.id));
                          }
                        });
                      },
                      child: Text(
                        selectedAttrIds.length == available.length ? 'Clear all' : 'Select all',
                      ),
                    ),
                  ),
                  ...available.map(
                    (a) => CheckboxListTile(
                      value: selectedAttrIds.contains(a.id),
                      onChanged: (on) {
                        setDialog(() {
                          if (on == true) {
                            selectedAttrIds.add(a.id);
                          } else {
                            selectedAttrIds.remove(a.id);
                          }
                        });
                      },
                      title: Text(a.label),
                      subtitle: Text('${a.key} · ${AttributeDataType.labelFor(a.dataType)}'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: selectedAttrIds.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: Text(selectedAttrIds.isEmpty ? 'Link' : 'Link ${selectedAttrIds.length}'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && selectedAttrIds.isNotEmpty) {
      var nextOrder = group.linkedAttributes.isEmpty
          ? 0
          : group.linkedAttributes.map((l) => l.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      final links = <({String attributeId, int sortOrder, bool isRequired})>[];
      for (final attr in available) {
        if (!selectedAttrIds.contains(attr.id)) continue;
        links.add((attributeId: attr.id, sortOrder: nextOrder++, isRequired: attr.isRequired));
      }
      await _repo.linkAttributesToGroup(groupId: group.id, links: links);
      if (mounted) {
        final n = links.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$n attribute${n == 1 ? '' : 's'} linked')),
        );
      }
      await _load();
    }
  }

  Future<void> _unlinkAttr(ShopAttributeGroup group, ShopAttributeGroupLink link) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink attribute?'),
        content: Text(
          'Remove "${link.master.label}" from group "${group.name}"?\n\n'
          'Products keep existing values; new products in sub-categories using this group will no longer show this field.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.unlinkAttributeFromGroup(groupId: group.id, attributeId: link.attributeId);
      if (!mounted) return;
      setState(() {
        _groups = _groups
            .map((g) => g.id == group.id ? _groupWithoutLink(g, link.attributeId) : g)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${link.master.label} unlinked')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unlink failed: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }

  Future<void> _deleteGroup(ShopAttributeGroup group) async {
    if (!await ShopAdminCrudActions.confirmDelete(context, group.name)) return;
    try {
      await _repo.deleteAttributeGroup(group.id);
      if (!mounted) return;
      setState(() => _groups = _groups.where((g) => g.id != group.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${group.name} deleted')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red.shade800),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Attribute groups',
      embedded: widget.embedded,
      floatingActionButton: FloatingActionButton.extended(onPressed: _addGroup, icon: const Icon(Icons.add), label: const Text('Group')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length,
              itemBuilder: (_, i) {
                final g = _groups[i];
                return Card(
                  key: ValueKey('${g.id}-${g.linkedAttributes.length}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${g.isActive ? 'Active' : 'Hidden'} · ${g.linkedAttributes.length} linked attribute${g.linkedAttributes.length == 1 ? '' : 's'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.link),
                              tooltip: 'Link attributes',
                              onPressed: () => _linkAttr(g),
                            ),
                            ShopAdminRowActions(
                              isActive: g.isActive,
                              onEdit: () => ShopAdminCrudActions.editAttributeGroup(context, g, _load),
                              onToggleActive: () async {
                                await _repo.updateAttributeGroup(g.id, name: g.name, isActive: !g.isActive);
                                _load();
                              },
                              onDelete: () => _deleteGroup(g),
                            ),
                          ],
                        ),
                      ),
                      if (g.linkedAttributes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            'No linked attributes. Tap link icon to select attributes.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                          ),
                        )
                      else
                        ...g.linkedAttributes.map(
                          (link) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.tune, size: 20),
                            title: Text(link.master.label),
                            subtitle: Text(
                              '${link.master.key} · ${AttributeDataType.labelFor(link.master.dataType)}'
                              '${link.isRequiredInGroup ? ' · Required in group' : ''}',
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.link_off, color: Theme.of(context).colorScheme.error),
                              tooltip: 'Unlink attribute',
                              onPressed: () => _unlinkAttr(g, link),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
