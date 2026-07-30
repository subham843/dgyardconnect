import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/services/firestore_service.dart';

class DefaultWarrantyScreen extends StatelessWidget {
  const DefaultWarrantyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Default warranty')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Default warranty'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminMasterData),
        ),
      ),
      body: StreamBuilder(
        stream: FirestoreService.defaultWarranty().snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final id = docs[index].id;
              final days = d['days'] as int? ?? 0;
              final sectorId = d['sectorId'] as String?;
              final sectorSubOptionId = d['sectorSubOptionId'] as String?;
              final industryTypeId = d['industryTypeId'] as String?;
              final industrySubOptionId = d['industrySubOptionId'] as String?;
              final scopeLabel = _buildScopeLabel(
                context,
                sectorId: sectorId,
                sectorSubOptionId: sectorSubOptionId,
                industryTypeId: industryTypeId,
                industrySubOptionId: industrySubOptionId,
              );
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('$days days'),
                  subtitle: scopeLabel != null ? Text(scopeLabel, style: Theme.of(context).textTheme.bodySmall) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showForm(
                          context,
                          id: id,
                          initialDays: days,
                          initialSectorId: sectorId,
                          initialSectorSubOptionId: sectorSubOptionId,
                          initialIndustryTypeId: industryTypeId,
                          initialIndustrySubOptionId: industrySubOptionId,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(context, id),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideX(begin: 0.02, end: 0);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String? _buildScopeLabel(
    BuildContext context, {
    String? sectorId,
    String? sectorSubOptionId,
    String? industryTypeId,
    String? industrySubOptionId,
  }) {
    if (sectorId == null && industryTypeId == null) return null;
    final parts = <String>[];
    if (sectorId != null) parts.add('Sector');
    if (sectorSubOptionId != null) parts.add('Sector sub');
    if (industryTypeId != null) parts.add('Industry');
    if (industrySubOptionId != null) parts.add('Industry sub');
    return parts.isEmpty ? null : 'Scope: ${parts.join(', ')}';
  }

  void _showForm(
    BuildContext context, {
    String? id,
    int initialDays = 30,
    String? initialSectorId,
    String? initialSectorSubOptionId,
    String? initialIndustryTypeId,
    String? initialIndustrySubOptionId,
  }) {
    final daysController = TextEditingController(text: initialDays.toString());
    String? sectorId = initialSectorId;
    String? sectorSubOptionId = initialSectorSubOptionId;
    String? industryTypeId = initialIndustryTypeId;
    String? industrySubOptionId = initialIndustrySubOptionId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(id == null ? 'Add warranty' : 'Edit warranty', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Leave sector/industry empty for global warranty (applies to all).',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: daysController,
                      decoration: const InputDecoration(labelText: 'Days'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder(
                      stream: FirestoreService.sectors().snapshots(),
                      builder: (context, snap) {
                        final sectors = List.from(snap.data?.docs ?? [])
                          ..sort((a, b) {
                            final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
                            final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
                            if (oa != ob) return oa.compareTo(ob);
                            return (a.data()['name'] as String? ?? '').compareTo(b.data()['name'] as String? ?? '');
                          });
                        return DropdownButtonFormField<String>(
                          initialValue: sectorId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Sector (optional)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All sectors')),
                            ...sectors.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.data()['name'] as String? ?? d.id),
                                )),
                          ],
                          onChanged: (v) => setModalState(() {
                            sectorId = v;
                            sectorSubOptionId = null;
                          }),
                        );
                      },
                    ),
                    if (sectorId != null) ...[
                      const SizedBox(height: 12),
                      StreamBuilder(
                        stream: FirestoreService.sectorSubOptions()
                            .where('sectorId', isEqualTo: sectorId)
                            .snapshots(),
                        builder: (context, snap) {
                          final subs = List.from(snap.data?.docs ?? [])
                            ..sort((a, b) {
                              final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
                              final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
                              if (oa != ob) return oa.compareTo(ob);
                              return ((a.data()['name'] as String?) ?? '').compareTo((b.data()['name'] as String?) ?? '');
                            });
                          return DropdownButtonFormField<String>(
                            initialValue: sectorSubOptionId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Sector sub-option (optional)'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All sub-options')),
                              ...subs.map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.data()['name'] as String? ?? d.id),
                                  )),
                            ],
                            onChanged: (v) => setModalState(() => sectorSubOptionId = v),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    StreamBuilder(
                      stream: FirestoreService.industryTypes().orderBy('name').snapshots(),
                      builder: (context, snap) {
                        final industries = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          initialValue: industryTypeId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Industry type (optional)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All industries')),
                            ...industries.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.data()['name'] as String? ?? d.id),
                                )),
                          ],
                          onChanged: (v) => setModalState(() {
                            industryTypeId = v;
                            industrySubOptionId = null;
                          }),
                        );
                      },
                    ),
                    if (industryTypeId != null) ...[
                      const SizedBox(height: 12),
                      StreamBuilder(
                        stream: FirestoreService.industrySubOptions()
                            .where('industryTypeId', isEqualTo: industryTypeId)
                            .snapshots(),
                        builder: (context, snap) {
                          final subs = snap.data?.docs ?? [];
                          subs.sort((a, b) =>
                              ((a.data()['name'] as String?) ?? '').compareTo((b.data()['name'] as String?) ?? ''));
                          return DropdownButtonFormField<String>(
                            initialValue: industrySubOptionId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Industry sub-option (optional)'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All sub-types')),
                              ...subs.map((d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.data()['name'] as String? ?? d.id),
                                  )),
                            ],
                            onChanged: (v) => setModalState(() => industrySubOptionId = v),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        final days = int.tryParse(daysController.text.trim());
                        if (days == null || days < 0) return;
                        final data = <String, dynamic>{
                          'days': days,
                          'sectorId': ?sectorId,
                          'sectorSubOptionId': ?sectorSubOptionId,
                          'industryTypeId': ?industryTypeId,
                          'industrySubOptionId': ?industrySubOptionId,
                        };
                        if (id == null) {
                          await FirestoreService.defaultWarranty().add(data);
                        } else {
                          await FirestoreService.defaultWarranty().doc(id).update(data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(id == null ? 'Add' : 'Save'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete warranty?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await FirestoreService.defaultWarranty().doc(id).delete();
  }
}
