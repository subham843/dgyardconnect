import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';

/// Admin: view trust score change history. Optional filter by userId.
class AdminTrustScoreHistoryScreen extends StatefulWidget {
  const AdminTrustScoreHistoryScreen({super.key, this.userId});

  final String? userId;

  @override
  State<AdminTrustScoreHistoryScreen> createState() => _AdminTrustScoreHistoryScreenState();
}

class _AdminTrustScoreHistoryScreenState extends State<AdminTrustScoreHistoryScreen> {
  final TextEditingController _userIdController = TextEditingController();
  String? _filterUserId;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      _userIdController.text = widget.userId!;
      _filterUserId = widget.userId;
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trust score history')),
        body: const Center(child: Text('Firebase not configured.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trust score history'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
        actions: [
          TextButton(
            onPressed: () => context.push(RouteNames.adminAdjustTrustScore),
            child: const Text('Adjust score'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userIdController,
                    decoration: const InputDecoration(
                      labelText: 'Filter by User ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) => setState(() => _filterUserId = v.trim().isEmpty ? null : v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => setState(() => _filterUserId = _userIdController.text.trim().isEmpty ? null : _userIdController.text.trim()),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.trustScoreHistory()
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                var docs = snapshot.data!.docs;
                if (_filterUserId != null && _filterUserId!.isNotEmpty) {
                  docs = docs.where((d) => (d.data()['userId'] as String?) == _filterUserId).toList();
                }
                if (docs.isEmpty) {
                  return const Center(child: Text('No trust score history.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final userId = d['userId'] as String? ?? '';
                    final role = d['role'] as String? ?? '';
                    final delta = (d['delta'] as num?)?.toInt() ?? 0;
                    final reason = d['reason'] as String? ?? '';
                    final eventType = d['eventType'] as String? ?? '';
                    final jobId = d['jobId'] as String?;
                    final previousScore = (d['previousScore'] as num?)?.toInt();
                    final newScore = (d['newScore'] as num?)?.toInt();
                    final createdAt = d['createdAt'] as Timestamp?;
                    final dateStr = createdAt != null ? DateFormat('MMM d, y HH:mm').format(createdAt.toDate()) : '–';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${delta >= 0 ? "+" : ""}$delta • $reason',
                          style: TextStyle(
                            color: delta >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'User: $userId • $role${jobId != null ? " • Job: $jobId" : ""}\n$eventType • $dateStr${previousScore != null && newScore != null ? " ($previousScore → $newScore)" : ""}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => context.push(RouteNames.adminAdjustTrustScore, extra: userId),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
