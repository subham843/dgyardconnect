import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/firestore_service.dart';

class ProfileApprovalsScreen extends StatelessWidget {
  const ProfileApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile approvals')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile approvals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.users()
            .where('profilePendingApproval', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${AppConstants.errorGeneric} ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No profile change requests',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final user = UserModel.fromFirestore(docs[index]);
              final ref = docs[index].reference;
              return _ProfileApprovalCard(
                user: user,
                onApprove: () => _approveProfile(ref),
                onReject: () => _rejectProfile(ref),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: index * 50))
                  .slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }

  Future<void> _approveProfile(DocumentReference<Map<String, dynamic>> ref) async {
    final doc = await ref.get();
    final d = doc.data();
    if (d == null) return;
    final proposed = d['proposedProfile'] as Map<String, dynamic>?;
    if (proposed != null) {
      await ref.update({
        'profile': proposed,
        'proposedProfile': FieldValue.delete(),
        'profilePendingApproval': false,
      });
    }
  }

  Future<void> _rejectProfile(DocumentReference<Map<String, dynamic>> ref) async {
    await ref.update({
      'proposedProfile': FieldValue.delete(),
      'profilePendingApproval': false,
    });
  }
}

class _ProfileApprovalCard extends StatelessWidget {
  const _ProfileApprovalCard({
    required this.user,
    required this.onApprove,
    required this.onReject,
  });

  final UserModel user;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(user.displayName.substring(0, 1).toUpperCase())),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName, style: Theme.of(context).textTheme.titleMedium),
                      Text(user.email ?? '', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Profile change pending review', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
