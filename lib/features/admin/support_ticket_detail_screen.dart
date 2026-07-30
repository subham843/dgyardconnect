import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';

class AdminSupportTicketDetailScreen extends StatefulWidget {
  const AdminSupportTicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<AdminSupportTicketDetailScreen> createState() =>
      _AdminSupportTicketDetailScreenState();
}

class _AdminSupportTicketDetailScreenState
    extends State<AdminSupportTicketDetailScreen> {
  final _reply = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _setStatus(DocumentReference<Map<String, dynamic>> ref, String s) async {
    setState(() => _saving = true);
    try {
      await ref.update({'status': s, 'updatedAt': FieldValue.serverTimestamp()});
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendReply(DocumentReference<Map<String, dynamic>> ref) async {
    final msg = _reply.text.trim();
    if (msg.isEmpty) return;
    setState(() => _saving = true);
    try {
      final snap = await ref.get();
      final uid = snap.data()?['uid'] as String?;

      await ref.collection('messages').add({
        'senderRole': 'admin',
        'text': msg,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await ref.update({
        'status': 'in_progress',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessagePreview': msg.length > 140 ? '${msg.substring(0, 140)}…' : msg,
      });

      // In-app notification to user
      if (uid != null && uid.isNotEmpty) {
        await FirestoreService.notifications(uid).add({
          'title': 'Support reply',
          'body': msg.length > 120 ? '${msg.substring(0, 120)}…' : msg,
          'type': 'support_reply',
          'ticketId': widget.ticketId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      _reply.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ticket'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(RouteNames.adminSupportTickets),
          ),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }

    final ref = FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(widget.ticketId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminSupportTickets),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text('Ticket not found.'));
          }
          final d = snapshot.data!.data() ?? {};
          final uid = d['uid'] as String? ?? '—';
          final subject = d['subject'] as String? ?? '—';
          final status = d['status'] as String? ?? 'open';
          final createdAt = d['createdAt'] is Timestamp
              ? (d['createdAt'] as Timestamp).toDate()
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Chip(label: Text('STATUS: ${status.toUpperCase()}')),
                          Chip(label: Text('USER: ${uid.substring(0, uid.length >= 8 ? 8 : uid.length)}…')),
                          if (createdAt != null)
                            Chip(label: Text(_fmt(createdAt))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Ticket ID: ${widget.ticketId}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conversation',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 260,
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: ref
                              .collection('messages')
                              .orderBy('createdAt', descending: true)
                              .limit(50)
                              .snapshots(),
                          builder: (context, msgSnap) {
                            final docs = msgSnap.data?.docs ?? const [];
                            // Backward compatibility: show legacy fields if no messages yet.
                            if (docs.isEmpty) {
                              final legacyMsg = d['message'] as String?;
                              final legacyReply = d['adminReply'] as String?;
                              if ((legacyMsg == null || legacyMsg.isEmpty) &&
                                  (legacyReply == null || legacyReply.isEmpty)) {
                                return const Center(child: Text('No messages yet.'));
                              }
                              return ListView(
                                children: [
                                  if (legacyMsg != null && legacyMsg.trim().isNotEmpty)
                                    _Bubble(text: legacyMsg, fromAdmin: false),
                                  if (legacyReply != null && legacyReply.trim().isNotEmpty)
                                    _Bubble(text: legacyReply, fromAdmin: true),
                                ],
                              );
                            }
                            return ListView.builder(
                              reverse: true,
                              itemCount: docs.length,
                              itemBuilder: (context, i) {
                                final m = docs[docs.length - 1 - i].data();
                                final role =
                                    m['senderRole'] as String? ?? 'user';
                                final text = m['text'] as String? ?? '';
                                final rawAtt =
                                    m['attachments'] as List<dynamic>?;
                                final attachments = rawAtt
                                        ?.whereType<Map>()
                                        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                                        .toList() ??
                                    const [];
                                return _Bubble(
                                  text: text,
                                  fromAdmin: role == 'admin',
                                  attachments: attachments,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reply,
                        minLines: 2,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Write a reply',
                          hintText: 'Resolution steps / request details…',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : () => _sendReply(ref),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Save reply'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton(
                            onPressed: _saving ? null : () => _setStatus(ref, 'open'),
                            child: const Text('Open'),
                          ),
                          OutlinedButton(
                            onPressed: _saving ? null : () => _setStatus(ref, 'in_progress'),
                            child: const Text('In progress'),
                          ),
                          FilledButton(
                            onPressed: _saving ? null : () => _setStatus(ref, 'closed'),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.fromAdmin,
    this.attachments = const [],
  });
  final String text;
  final bool fromAdmin;
  final List<Map<String, dynamic>> attachments;

  @override
  Widget build(BuildContext context) {
    final bg = fromAdmin ? Colors.blueGrey.shade50 : Colors.orange.shade50;
    final align = fromAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final urls = attachments
        .map((a) => a['url'] as String?)
        .where((u) => u != null && u.trim().isNotEmpty)
        .map((u) => u!.trim())
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Text(text),
          ),
          if (urls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: urls.take(6).map((u) {
                return TappableImage(
                  imageUrl: u,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      u,
                      width: 110,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 110,
                        height: 80,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_rounded),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

