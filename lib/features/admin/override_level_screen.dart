import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/trust_reputation_constants.dart';
import '../../shared/services/firestore_service.dart';

class AdminOverrideLevelScreen extends StatelessWidget {
  const AdminOverrideLevelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Override level')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Override level'),
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
              final override = d['adminOverrideLevel'] as String?;
              final manualOverride = d['manual_level_override'] as bool? ?? false;
              final defaultLevel = role == 'technician'
                  ? (d['technicianLevel'] as String?)
                  : (d['dealerLevel'] as String?);
              final effectiveLevel = override ?? defaultLevel ?? '—';
              final isTechnician = role == 'technician';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(name.toString())),
                      if (isTechnician && manualOverride)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Override', style: TextStyle(fontSize: 10, color: Colors.orange.shade900)),
                        ),
                    ],
                  ),
                  subtitle: Text('$role · ${isTechnician ? TrustReputationConstants.labelForTechnicianLevel(effectiveLevel.isEmpty ? null : effectiveLevel) : _capitalize(effectiveLevel)}'),
                  trailing: DropdownButton<String>(
                    value: _dropdownValue(override, isTechnician),
                    items: [
                      const DropdownMenuItem(value: 'none', child: Text('None (auto)')),
                      if (isTechnician) ...[
                        const DropdownMenuItem(value: 'bronze', child: Text('Bronze')),
                        const DropdownMenuItem(value: 'silver', child: Text('Silver')),
                        const DropdownMenuItem(value: 'gold', child: Text('Gold')),
                        const DropdownMenuItem(value: 'elite', child: Text('Elite')),
                      ] else ...[
                        const DropdownMenuItem(value: 'basic', child: Text('Basic')),
                        const DropdownMenuItem(value: 'trusted', child: Text('Trusted')),
                        const DropdownMenuItem(value: 'premium', child: Text('Premium')),
                        const DropdownMenuItem(value: 'enterprise', child: Text('Enterprise')),
                      ],
                    ],
                    onChanged: (v) => _onLevelChanged(context, id, role, v),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Future<void> _onLevelChanged(BuildContext context, String userId, String role, String? value) async {
    if (value == null) return;
    final isTechnician = role == 'technician';
    try {
      if (value == 'none') {
        if (isTechnician) {
          await FirebaseFunctions.instance.httpsCallable('recalculateTechnicianLevel').call({'uid': userId});
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Override removed; level set from trust score.')));
          }
        } else {
          await FirestoreService.users().doc(userId).update({'adminOverrideLevel': null});
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Override removed.')));
          }
        }
      } else {
        if (isTechnician) {
          await FirestoreService.users().doc(userId).update({
            'technicianLevel': value,
            'adminOverrideLevel': value,
            'manual_level_override': true,
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Technician level overridden. Auto-update paused.')));
          }
        } else {
          await FirestoreService.users().doc(userId).update({'adminOverrideLevel': value});
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Level overridden.')));
          }
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Ensures dropdown value is always in the items list (avoids assertion for legacy e.g. 'platinum').
  static String _dropdownValue(String? override, bool isTechnician) {
    if (override == null || override.isEmpty) return 'none';
    if (isTechnician) {
      const valid = ['bronze', 'silver', 'gold', 'elite'];
      if (override == 'platinum') return 'elite';
      return valid.contains(override) ? override : 'none';
    }
    const valid = ['basic', 'trusted', 'premium', 'enterprise'];
    return valid.contains(override) ? override : 'none';
  }

  static String _capitalize(String s) {
    if (s.isEmpty || s == '—') return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
