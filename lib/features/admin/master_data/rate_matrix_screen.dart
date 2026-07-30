import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/services/firestore_service.dart';

class RateMatrixScreen extends StatelessWidget {
  const RateMatrixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rate matrix')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate matrix'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminMasterData),
        ),
      ),
      body: StreamBuilder(
        stream: FirestoreService.rateMatrix().snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final id = docs[index].id;
              final fixedRate = (d['fixedRate'] as num?)?.toDouble() ?? 0.0;
              final subOpt = d['sectorSubOptionId'] as String?;
              final industrySub = d['industrySubOptionId'] as String?;
              return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Rate: ₹${fixedRate.toStringAsFixed(0)}'),
                      subtitle: Text(
                        'Job: ${d['jobTypeId']} · Sector: ${d['sectorId']}'
                        '${subOpt != null ? ' · Sub: $subOpt' : ''} · Industry: ${d['industryTypeId'] ?? d['industryId']}'
                        '${industrySub != null ? ' · IndSub: $industrySub' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(context, id),
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
        onPressed: () => _showAddForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddForm(BuildContext context) {
    final fixedRateController = TextEditingController();
    String? jobTypeId;
    String? sectorId;
    String? sectorSubOptionId;
    String? industryTypeId;
    String? industrySubOptionId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Add rate', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    StreamBuilder(
                      stream: FirestoreService.jobTypes()
                          .orderBy('name')
                          .snapshots(),
                      builder: (c, snap) {
                        final docs = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          initialValue: jobTypeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Job type',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Select'),
                            ),
                            ...docs.map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  (d.data() as Map)['name'] as String? ?? d.id,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setModalState(() => jobTypeId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder(
                      stream: FirestoreService.sectors()
                          .orderBy('name')
                          .snapshots(),
                      builder: (c, snap) {
                        final docs = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          initialValue: sectorId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sector',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Select'),
                            ),
                            ...docs.map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  (d.data() as Map)['name'] as String? ?? d.id,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setModalState(() {
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
                        builder: (c, snap) {
                          final raw = snap.data?.docs ?? [];
                          raw.sort((a, b) =>
                              ((a.data()['name'] as String?) ?? '')
                                  .compareTo((b.data()['name'] as String?) ?? ''));
                          return DropdownButtonFormField<String>(
                            initialValue: sectorSubOptionId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sector sub-category (optional)',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('None / any'),
                              ),
                              ...raw.map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    (d.data() as Map)['name'] as String? ?? d.id,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setModalState(() => sectorSubOptionId = v),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    StreamBuilder(
                      stream: FirestoreService.industryTypes()
                          .orderBy('name')
                          .snapshots(),
                      builder: (c, snap) {
                        final docs = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          initialValue: industryTypeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Industry',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Select'),
                            ),
                            ...docs.map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  (d.data() as Map)['name'] as String? ?? d.id,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setModalState(() {
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
                        builder: (c, snap) {
                          final raw = snap.data?.docs ?? [];
                          raw.sort((a, b) =>
                              ((a.data()['name'] as String?) ?? '')
                                  .compareTo((b.data()['name'] as String?) ?? ''));
                          return DropdownButtonFormField<String>(
                            initialValue: industrySubOptionId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Industry sub-option (optional)',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('None / any'),
                              ),
                              ...raw.map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    (d.data() as Map)['name'] as String? ?? d.id,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setModalState(() => industrySubOptionId = v),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: fixedRateController,
                      decoration: const InputDecoration(
                        labelText: 'Fixed rate (₹)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        final rate = double.tryParse(
                          fixedRateController.text.trim(),
                        );
                        if (rate == null || rate < 0) return;
                        final map = <String, dynamic>{
                          'fixedRate': rate,
                          'jobTypeId': jobTypeId,
                          'sectorId': sectorId,
                          'industryTypeId': industryTypeId,
                        };
                        if (sectorSubOptionId != null) {
                          map['sectorSubOptionId'] = sectorSubOptionId;
                        }
                        if (industrySubOptionId != null) {
                          map['industrySubOptionId'] = industrySubOptionId;
                        }
                        await FirestoreService.rateMatrix().add(map);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Add'),
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
        title: const Text('Delete rate?'),
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
    if (ok == true) await FirestoreService.rateMatrix().doc(id).delete();
  }
}
