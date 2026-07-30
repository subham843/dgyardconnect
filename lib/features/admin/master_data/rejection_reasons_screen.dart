import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../shared/services/firestore_service.dart';

class RejectionReasonsScreen extends StatelessWidget {
  const RejectionReasonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rejection reasons')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejection reasons'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminMasterData),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.rejectionReasonsConfig().snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() ?? {};
          final dealerReasons = (data['dealerReasons'] as List<dynamic>?) ?? [];
          final technicianReasons = (data['technicianReasons'] as List<dynamic>?) ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'These reasons appear when dealer or technician rejects during bidding.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 24),
                _ReasonSection(
                  title: 'Dealer rejection reasons',
                  subtitle: "Shown when dealer rejects technician's bid",
                  reasons: dealerReasons,
                  onAdd: () => _showAddReason(context, 'dealer', dealerReasons, technicianReasons),
                  onEdit: (index) => _showEditReason(context, 'dealer', index, dealerReasons, technicianReasons),
                  onRemove: (index) => _removeReason(context, 'dealer', index, dealerReasons, technicianReasons),
                ),
                const SizedBox(height: 32),
                _ReasonSection(
                  title: 'Technician rejection reasons',
                  subtitle: "Shown when technician rejects dealer's counter",
                  reasons: technicianReasons,
                  onAdd: () => _showAddReason(context, 'technician', dealerReasons, technicianReasons),
                  onEdit: (index) => _showEditReason(context, 'technician', index, dealerReasons, technicianReasons),
                  onRemove: (index) => _removeReason(context, 'technician', index, dealerReasons, technicianReasons),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showAddReason(
    BuildContext context,
    String type,
    List<dynamic> dealerReasons,
    List<dynamic> technicianReasons,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${type == 'dealer' ? 'dealer' : 'technician'} rejection reason'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == true && controller.text.trim().isNotEmpty) {
      final item = {'id': DateTime.now().millisecondsSinceEpoch.toString(), 'text': controller.text.trim()};
      final list = type == 'dealer' ? List<Map<String, dynamic>>.from(dealerReasons.map((e) => Map<String, dynamic>.from(e as Map))) : List<Map<String, dynamic>>.from(technicianReasons.map((e) => Map<String, dynamic>.from(e as Map)));
      list.add(item);
      await FirestoreService.rejectionReasonsConfig().set({
        'dealerReasons': type == 'dealer' ? list : dealerReasons,
        'technicianReasons': type == 'technician' ? list : technicianReasons,
      }, SetOptions(merge: true));
    }
  }

  static Future<void> _showEditReason(
    BuildContext context,
    String type,
    int index,
    List<dynamic> dealerReasons,
    List<dynamic> technicianReasons,
  ) async {
    final list = type == 'dealer' ? dealerReasons : technicianReasons;
    final item = list[index] as Map;
    final controller = TextEditingController(text: item['text'] as String? ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${type == 'dealer' ? 'dealer' : 'technician'} rejection reason'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true && controller.text.trim().isNotEmpty) {
      final newList = List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e as Map)));
      newList[index] = {'id': item['id'], 'text': controller.text.trim()};
      await FirestoreService.rejectionReasonsConfig().set({
        'dealerReasons': type == 'dealer' ? newList : dealerReasons,
        'technicianReasons': type == 'technician' ? newList : technicianReasons,
      }, SetOptions(merge: true));
    }
  }

  static Future<void> _removeReason(
    BuildContext context,
    String type,
    int index,
    List<dynamic> dealerReasons,
    List<dynamic> technicianReasons,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove reason?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      final list = type == 'dealer' ? List<Map<String, dynamic>>.from(dealerReasons.map((e) => Map<String, dynamic>.from(e as Map))) : List<Map<String, dynamic>>.from(technicianReasons.map((e) => Map<String, dynamic>.from(e as Map)));
      list.removeAt(index);
      await FirestoreService.rejectionReasonsConfig().set({
        'dealerReasons': type == 'dealer' ? list : dealerReasons,
        'technicianReasons': type == 'technician' ? list : technicianReasons,
      }, SetOptions(merge: true));
    }
  }
}

class _ReasonSection extends StatelessWidget {
  const _ReasonSection({
    required this.title,
    required this.subtitle,
    required this.reasons,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
  });
  final String title;
  final String subtitle;
  final List<dynamic> reasons;
  final VoidCallback onAdd;
  final void Function(int) onEdit;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
                IconButton.filled(onPressed: onAdd, icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 12),
            if (reasons.isEmpty)
              Text('No reasons added. Add one to show in bidding.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline))
            else
              ...reasons.asMap().entries.map((e) {
                final item = e.value as Map;
                final text = item['text'] as String? ?? '';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(text),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => onEdit(e.key)),
                        IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => onRemove(e.key)),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: e.key * 30)).slideX(begin: 0.02, end: 0);
              }),
          ],
        ),
      ),
    );
  }
}
