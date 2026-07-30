import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';

/// Admin panel: view legal/evidence logs with search by job ID or user ID.
class AdminLegalLogsScreen extends StatefulWidget {
  const AdminLegalLogsScreen({super.key});

  @override
  State<AdminLegalLogsScreen> createState() => _AdminLegalLogsScreenState();
}

class _AdminLegalLogsScreenState extends State<AdminLegalLogsScreen> {
  final _searchController = TextEditingController();
  String _logType = 'terms';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal & evidence logs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _logType,
                  decoration: const InputDecoration(
                    labelText: 'Log type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'terms', child: Text('Terms acceptance')),
                    DropdownMenuItem(value: 'payments', child: Text('Payment transactions')),
                    DropdownMenuItem(value: 'disputes', child: Text('Dispute records')),
                    DropdownMenuItem(value: 'cancellations', child: Text('Cancellation records')),
                    DropdownMenuItem(value: 'job_photos', child: Text('Jobs with photo uploads')),
                  ],
                  onChanged: (v) => setState(() => _logType = v ?? 'terms'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Job ID or User ID',
                          hintText: 'Optional filter',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (v) => setState(() => _query = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => setState(() => _query = _searchController.text.trim()),
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _LogList(
              logType: _logType,
              query: _query,
            ),
          ),
        ],
      ),
    );
  }
}

String _displayId(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return '—';
  return v.length <= 8 ? v : v.substring(0, 8).toUpperCase();
}

class _LogList extends StatelessWidget {
  const _LogList({required this.logType, required this.query});
  final String logType;
  final String query;

  @override
  Widget build(BuildContext context) {
    switch (logType) {
      case 'terms':
        return _TermsAcceptanceList(query: query);
      case 'payments':
        return _PaymentLogList(query: query);
      case 'disputes':
        return _DisputeLogList(query: query);
      case 'cancellations':
        return _CancellationLogList(query: query);
      case 'job_photos':
        return _JobPhotosList(query: query);
      default:
        return const Center(child: Text('Select a log type'));
    }
  }
}

class _TermsAcceptanceList extends StatelessWidget {
  const _TermsAcceptanceList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirestoreService.userTermsAcceptance()
        .orderBy('accepted_at', descending: true)
        .limit(300);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        var docs = snapshot.data!.docs;
        if (query.isNotEmpty) {
          docs = docs.where((d) => (d.data()['user_id'] as String? ?? '').toLowerCase().contains(query.toLowerCase())).toList();
        }
        if (docs.isEmpty) return const Center(child: Text('No terms acceptance records.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final acceptedAt = (d['accepted_at'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('User: ${_displayId(d['user_id'] as String?)}'),
                subtitle: Text('Type: ${d['user_type'] ?? ''} • Version: ${d['terms_version'] ?? ''}${acceptedAt != null ? ' • ${DateFormat('MMM d, y HH:mm').format(acceptedAt)}' : ''}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _PaymentLogList extends StatelessWidget {
  const _PaymentLogList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.dealerPaymentReceipts()
          .orderBy('paymentDate', descending: true)
          .limit(300)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        var docs = snapshot.data!.docs;
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          docs = docs.where((d) {
            final data = d.data();
            return (data['jobId'] as String? ?? '').toLowerCase().contains(q) ||
                (data['dealerId'] as String? ?? '').toLowerCase().contains(q);
          }).toList();
        }
        if (docs.isEmpty) return const Center(child: Text('No payment records.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final date = (data['paymentDate'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('Job: ${_displayId(data['jobId'] as String?)} • ₹${(data['paymentAmount'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                subtitle: Text('Dealer: ${_displayId(data['dealerId'] as String?)}${date != null ? ' • ${DateFormat('MMM d, y').format(date)}' : ''}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _DisputeLogList extends StatelessWidget {
  const _DisputeLogList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.jobDisputes()
          .orderBy('createdAt', descending: true)
          .limit(300)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        var docs = snapshot.data!.docs;
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          docs = docs.where((d) {
            final data = d.data();
            return (data['jobId'] as String? ?? '').toLowerCase().contains(q) ||
                (data['dealerId'] as String? ?? '').toLowerCase().contains(q);
          }).toList();
        }
        if (docs.isEmpty) return const Center(child: Text('No dispute records.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final desc = (data['description'] as String? ?? '');
            final descShort = desc.length > 60 ? '${desc.substring(0, 60)}...' : desc;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${data['status'] ?? ''} • Job: ${_displayId(data['jobId'] as String?)}'),
                subtitle: Text('$descShort${createdAt != null ? ' • ${DateFormat('MMM d, y').format(createdAt)}' : ''}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _CancellationLogList extends StatelessWidget {
  const _CancellationLogList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.cancellationCompensations().orderBy('paidAt', descending: true).limit(200).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        var docs = snapshot.data!.docs;
        if (query.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data();
            return (data['jobId'] as String? ?? '').contains(query) || (data['technicianId'] as String? ?? '').contains(query);
          }).toList();
        }
        if (docs.isEmpty) return const Center(child: Text('No cancellation compensation records.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final paidAt = (data['paidAt'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('Job: ${_displayId(data['jobId'] as String?)} • ${data['type'] ?? ''} • ₹${(data['amount'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                subtitle: Text('Tech: ${_displayId(data['technicianId'] as String?)}${paidAt != null ? ' • ${DateFormat('MMM d, y').format(paidAt)}' : ''}'),
              ),
            );
          },
        );
      },
    );
  }
}

class _JobPhotosList extends StatelessWidget {
  const _JobPhotosList({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirestoreService.jobs()
        .orderBy('createdAt', descending: true)
        .limit(300);
    if (query.isNotEmpty) {
      q = FirestoreService.jobs().where(FieldPath.documentId, isEqualTo: query).limit(1);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        var docs = snapshot.data!.docs;
        docs = docs.where((d) {
          final proofPhotos = (d.data()['proofPhotos'] as List<dynamic>?) ?? [];
          if (proofPhotos.isEmpty) return false;
          if (query.isNotEmpty) {
            return d.id.contains(query) || (d.data()['dealerId'] as String? ?? '').contains(query) || (d.data()['technicianId'] as String? ?? '').contains(query);
          }
          return true;
        }).toList();
        if (docs.isEmpty) return const Center(child: Text('No jobs with photo uploads.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final proofCount = (data['proofPhotos'] as List<dynamic>?)?.length ?? 0;
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('Job: ${_displayId(docs[i].id)} • $proofCount photo(s)'),
                subtitle: Text('${data['title'] ?? ''}${createdAt != null ? ' • ${DateFormat('MMM d, y').format(createdAt)}' : ''}'),
              ),
            );
          },
        );
      },
    );
  }
}
