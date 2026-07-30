import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_auth_service.dart';
import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';

class AdminAiOsAcceptInviteScreen extends StatefulWidget {
  const AdminAiOsAcceptInviteScreen({
    super.key,
    this.token,
    this.embedded = false,
  });

  final String? token;
  final bool embedded;

  @override
  State<AdminAiOsAcceptInviteScreen> createState() => _AdminAiOsAcceptInviteScreenState();
}

class _AdminAiOsAcceptInviteScreenState extends State<AdminAiOsAcceptInviteScreen> {
  final _repo = BosRepository();
  final _emailCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _ok;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _emailCtrl.text = user?.email?.trim() ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final token = (widget.token ?? '').trim();
    final email = _emailCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Missing invite token');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Email is required (must match invite)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _ok = null;
    });
    try {
      final result = await _repo.acceptInvite(token: token, email: email);
      final tenantId = '${result['tenant_id'] ?? ''}';
      if (tenantId.isNotEmpty) {
        await _repo.setActiveTenantId(tenantId);
      } else {
        final prefsTenant = await _repo.activeTenantId;
        await SupabaseAuthService.instance.setActiveBosTenant(prefsTenant);
      }
      await _repo.refreshFeatureFlags();
      if (mounted) {
        setState(() => _ok = 'Invite accepted. You can open AI Business OS.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token ?? '';
    return AdminEmbeddedScaffold(
      title: 'Accept invite',
      embedded: widget.embedded,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            token.isEmpty
                ? 'Open this page from an invite link that includes ?token=…'
                : 'Token: ${token.substring(0, token.length.clamp(0, 8))}…',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Your email (must match invite)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_ok != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_ok!, style: const TextStyle(color: Colors.green)),
            ),
          FilledButton(
            onPressed: _busy ? null : _accept,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Accept invite'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go(RouteNames.adminAiOsHome),
            child: const Text('Go to AI Business OS'),
          ),
        ],
      ),
    );
  }
}
