import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/services/firestore_service.dart';

class IndustrySubOptionsScreen extends StatelessWidget {
  const IndustrySubOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Industry sub-options')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Industry sub-options'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminMasterData),
        ),
      ),
      body: StreamBuilder(
        stream: FirestoreService.industrySubOptions().snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          final sorted = List.of(docs)
            ..sort((a, b) =>
                ((a.data()['name'] as String?) ?? '')
                    .compareTo((b.data()['name'] as String?) ?? ''));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final d = sorted[index].data();
              final id = sorted[index].id;
              final name = d['name'] as String? ?? '—';
              final industryTypeId = d['industryTypeId'] as String? ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(name),
                  subtitle: industryTypeId.isNotEmpty
                      ? FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirestoreService.industryTypes()
                              .doc(industryTypeId)
                              .get(),
                          builder: (_, s) {
                            if (!s.hasData || !s.data!.exists) {
                              return const Text('Industry');
                            }
                            return Text(
                              'Industry: ${s.data!.data()?['name'] ?? industryTypeId}',
                            );
                          },
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showForm(
                          context,
                          id: id,
                          initialName: name,
                          industryTypeId: industryTypeId,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(context, id),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: index * 30))
                  .slideX(begin: 0.02, end: 0);
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

  void _showForm(
    BuildContext context, {
    String? id,
    String initialName = '',
    String industryTypeId = '',
  }) {
    final nameController = TextEditingController(text: initialName);
    String? selectedIndustryTypeId =
        industryTypeId.isEmpty ? null : industryTypeId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreService.industryTypes()
                    .orderBy('name')
                    .snapshots(),
                builder: (context, industrySnap) {
                  final industries = industrySnap.data?.docs ?? [];
                  if (selectedIndustryTypeId == null && industries.isNotEmpty) {
                    setModalState(() => selectedIndustryTypeId = industries.first.id);
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        id == null ? 'Add sub-option' : 'Edit sub-option',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedIndustryTypeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Industry type',
                        ),
                        items: industries
                            .map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(
                                    (e.data()['name'] as String?) ?? e.id,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setModalState(() => selectedIndustryTypeId = v),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty || selectedIndustryTypeId == null) {
                            return;
                          }
                          if (id == null) {
                            await FirestoreService.industrySubOptions().add({
                              'name': name,
                              'industryTypeId': selectedIndustryTypeId,
                            });
                          } else {
                            await FirestoreService
                                .industrySubOptions()
                                .doc(id)
                                .update({
                              'name': name,
                              'industryTypeId': selectedIndustryTypeId,
                            });
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(id == null ? 'Add' : 'Save'),
                      ),
                    ],
                  );
                },
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
        title: const Text('Delete sub-option?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirestoreService.industrySubOptions().doc(id).delete();
    }
  }
}
