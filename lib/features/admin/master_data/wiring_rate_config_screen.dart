import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/services/firestore_service.dart';

class WiringRateConfigScreen extends StatelessWidget {
  const WiringRateConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wiring rate config')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wiring rate config'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminMasterData),
        ),
      ),
      body: StreamBuilder(
        stream: FirestoreService.wiringRateConfig().snapshots(),
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
              final perMeter = (d['perMeter'] as num?)?.toDouble() ?? 0.0;
              final includedMeters = (d['includedMeters'] as num?)?.toInt() ?? 0;
              final wiringTypeId = d['wiringTypeId'] as String?;
              final industryTypeId = d['industryTypeId'] as String?;
              final sectorSubOptionId = d['sectorSubOptionId'] as String?;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('₹${perMeter.toStringAsFixed(0)} per meter'),
                  subtitle: Text(
                    'Included: ${includedMeters}m · Wiring: $wiringTypeId · Industry: $industryTypeId · Sub: $sectorSubOptionId',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _delete(context, id),
                  ),
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: index * 30)).slideX(begin: 0.02, end: 0);
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
    final perMeterController = TextEditingController();
    final includedMetersController = TextEditingController(text: '0');
    String? wiringTypeId;
    String? industryTypeId;
    String? sectorSubOptionId;
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
                    Text('Add wiring rate', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreService.wiringTypes().orderBy('name').snapshots(),
                      builder: (c, snap) {
                        final docs = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          initialValue: wiringTypeId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Wiring type'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Select')),
                            ...docs.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text((d.data()['name'] as String?) ?? d.id),
                                )),
                          ],
                          onChanged: (v) => setModalState(() => wiringTypeId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreService.industryTypes().orderBy('name').snapshots(),
                      builder: (c, snap) {
                        final docs = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          initialValue: industryTypeId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Industry'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Select')),
                            ...docs.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text((d.data()['name'] as String?) ?? d.id),
                                )),
                          ],
                          onChanged: (v) => setModalState(() => industryTypeId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirestoreService.sectorSubOptions().snapshots(),
                      builder: (c, snap) {
                        final allDocs = snap.data?.docs ?? [];
                        final docs = allDocs.where((doc) => doc.data()['wiringEnabled'] == true).toList();
                        docs.sort((a, b) => ((a.data()['name'] as String?) ?? '')
                            .compareTo((b.data()['name'] as String?) ?? ''));
                        return DropdownButtonFormField<String>(
                          initialValue: sectorSubOptionId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sector sub-option (wiring enabled only)',
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Select')),
                            ...docs.map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text((d.data()['name'] as String?) ?? d.id),
                                )),
                          ],
                          onChanged: (v) => setModalState(() => sectorSubOptionId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: includedMetersController,
                      decoration: const InputDecoration(
                        labelText: 'Included meters (free)',
                        hintText: '0',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: perMeterController,
                      decoration: const InputDecoration(labelText: 'Per meter (₹)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        final perMeter = double.tryParse(perMeterController.text.trim());
                        final included = int.tryParse(includedMetersController.text.trim()) ?? 0;
                        if (perMeter == null || perMeter < 0 || wiringTypeId == null ||
                            industryTypeId == null || sectorSubOptionId == null) {
                          return;
                        }
                        await FirestoreService.wiringRateConfig().add({
                          'wiringTypeId': wiringTypeId,
                          'industryTypeId': industryTypeId,
                          'sectorSubOptionId': sectorSubOptionId,
                          'includedMeters': included,
                          'perMeter': perMeter,
                        });
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
        title: const Text('Delete wiring rate?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await FirestoreService.wiringRateConfig().doc(id).delete();
  }
}
