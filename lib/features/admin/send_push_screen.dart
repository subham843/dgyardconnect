import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';

class AdminSendPushScreen extends StatefulWidget {
  const AdminSendPushScreen({super.key});

  @override
  State<AdminSendPushScreen> createState() => _AdminSendPushScreenState();
}

class _AdminSendPushScreenState extends State<AdminSendPushScreen> {
  final _uid = TextEditingController();
  final _title = TextEditingController(text: 'Notification');
  final _body = TextEditingController();
  final _jobId = TextEditingController();
  final _imageUrl = TextEditingController();

  String _type = 'general'; // job | chat | offer | general
  String _target = 'auto'; // auto | dealer | technician
  String _audience = 'all'; // all | dealer | technician | uid
  bool _sending = false;

  @override
  void dispose() {
    _uid.dispose();
    _title.dispose();
    _body.dispose();
    _jobId.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final uid = _uid.text.trim();
    if (_audience == 'uid' && uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audience is specific user: enter user UID.')));
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await FirebaseFunctions.instance.httpsCallable('sendAdminPush').call({
        'audience': _audience,
        if (_audience == 'uid') 'uid': uid,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'type': _type,
        if (_jobId.text.trim().isNotEmpty) 'job_id': _jobId.text.trim(),
        if (_target != 'auto') 'target': _target,
        if (_imageUrl.text.trim().isNotEmpty) 'image_url': _imageUrl.text.trim(),
      });
      final data = res.data is Map ? res.data as Map : {};
      final sent = data['sent']?.toString() ?? '0';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to $sent device(s).')));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needJobId = _type == 'job' || _type == 'chat' || _type == 'offer';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send push'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _audience,
                    decoration: const InputDecoration(labelText: 'Audience'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All users')),
                      DropdownMenuItem(value: 'dealer', child: Text('All dealers')),
                      DropdownMenuItem(value: 'technician', child: Text('All technicians')),
                      DropdownMenuItem(value: 'uid', child: Text('Specific user (UID)')),
                    ],
                    onChanged: _sending ? null : (v) => setState(() => _audience = v ?? 'all'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _uid,
                    decoration: const InputDecoration(
                      labelText: 'User UID',
                      hintText: 'Firebase Auth UID',
                    ),
                    enabled: _audience == 'uid' && !_sending,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _target,
                    decoration: const InputDecoration(labelText: 'Target role (optional)'),
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('Auto (use current user role)')),
                      DropdownMenuItem(value: 'dealer', child: Text('Dealer')),
                      DropdownMenuItem(value: 'technician', child: Text('Technician')),
                    ],
                    onChanged: _sending ? null : (v) => setState(() => _target = v ?? 'auto'),
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
                  Text('Payload', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Type / screen'),
                    items: const [
                      DropdownMenuItem(value: 'job', child: Text('job → Job details')),
                      DropdownMenuItem(value: 'chat', child: Text('chat → Chat')),
                      DropdownMenuItem(value: 'offer', child: Text('offer → Offers/Bidding')),
                      DropdownMenuItem(value: 'general', child: Text('general → Home')),
                    ],
                    onChanged: _sending ? null : (v) => setState(() => _type = v ?? 'general'),
                  ),
                  const SizedBox(height: 12),
                  if (needJobId)
                    TextField(
                      controller: _jobId,
                      decoration: const InputDecoration(
                        labelText: 'job_id',
                        hintText: 'Required for job/chat/offer',
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _body,
                    decoration: const InputDecoration(labelText: 'Body'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _imageUrl,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (optional)',
                      hintText: 'https://.../image.png',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send push notification'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If job_id is missing for job/chat, the app opens Home. For offer without job_id, it opens Offers screen.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

