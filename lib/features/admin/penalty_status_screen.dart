import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';

class AdminPenaltyStatusScreen extends StatelessWidget {
  const AdminPenaltyStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Penalty & status')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penalty & status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: StreamBuilder(
        stream: FirestoreService.users()
            .where('role', whereIn: ['dealer', 'technician'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final id = docs[index].id;
              final name = d['profile'] is Map ? (d['profile'] as Map)['name'] : d['name'] ?? id;
              final role = d['role'] as String? ?? '—';
              final dealerPoints = d['dealerPenaltyPoints'] as int? ?? 0;
              final techPoints = d['technicianPenaltyPoints'] as int? ?? 0;
              final status = d['accountStatus'] as String? ?? 'active';
              final points = role == 'dealer' ? dealerPoints : techPoints;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(name.toString()),
                  subtitle: Text('$role · Penalty: $points · Status: $status'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditDialog(context, id, role, points, status),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, String uid, String role, int points, String status) {
    final pointsController = TextEditingController(text: points.toString());
    String newStatus = status;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit penalty & status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(labelText: 'Penalty points'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: newStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Account status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'warning', child: Text('Warning')),
                  DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: (v) => setState(() => newStatus = v ?? newStatus),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final p = int.tryParse(pointsController.text.trim()) ?? 0;
                if (role == 'dealer') {
                  await FirestoreService.users().doc(uid).update({'dealerPenaltyPoints': p, 'accountStatus': newStatus});
                } else {
                  await FirestoreService.users().doc(uid).update({'technicianPenaltyPoints': p, 'accountStatus': newStatus});
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
