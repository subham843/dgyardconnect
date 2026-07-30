import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';
import '../domain/bos_permissions.dart';

/// Short post-signup onboarding wizard (company → branding → invite → catalog).
class AdminAiOsOnboardingScreen extends StatefulWidget {
  const AdminAiOsOnboardingScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsOnboardingScreen> createState() => _AdminAiOsOnboardingScreenState();
}

class _AdminAiOsOnboardingScreenState extends State<AdminAiOsOnboardingScreen> {
  final _repo = BosRepository();
  final _nameCtrl = TextEditingController();
  final _primaryCtrl = TextEditingController(text: '#0F172A');
  final _accentCtrl = TextEditingController(text: '#2563EB');
  final _inviteEmailCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();
  BosTenant? _tenant;
  bool _loading = true;
  bool _busy = false;
  int _step = 0;
  String _catalogSeed = 'empty';
  String? _inviteLink;
  String _businessType = 'cctv_integrator';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _primaryCtrl.dispose();
    _accentCtrl.dispose();
    _inviteEmailCtrl.dispose();
    _gstinCtrl.dispose();
    _logoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tid = await _repo.activeTenantId;
    final tenant = await _repo.getTenant(tid);
    if (mounted) {
      _tenant = tenant;
      _nameCtrl.text = tenant?.name ?? '';
      _primaryCtrl.text = tenant?.brandPrimary ?? '#0F172A';
      _accentCtrl.text = tenant?.brandAccent ?? '#2563EB';
      _gstinCtrl.text = tenant?.gstin ?? '';
      _logoCtrl.text = tenant?.logoUrl ?? '';
      _businessType = tenant?.businessType ?? 'cctv_integrator';
      final done = tenant?.settings?['onboarding_completed'] == true;
      setState(() {
        _loading = false;
        if (done) _step = 3;
      });
    }
  }

  Future<void> _saveProfile() async {
    final t = _tenant;
    if (t == null) return;
    setState(() => _busy = true);
    try {
      await _repo.updateTenant(t.id, {
        'name': _nameCtrl.text.trim(),
        'brand_primary': _primaryCtrl.text.trim(),
        'brand_accent': _accentCtrl.text.trim(),
        'gstin': _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
        'business_type': _businessType,
        'logo_url': _logoCtrl.text.trim().isEmpty ? null : _logoCtrl.text.trim(),
        'settings': {
          ...?t.settings,
          'onboarding_step': _step + 1,
        },
      });
      await _repo.upsertTenantSettings(
        tenantId: t.id,
        settings: {
          'timezone': 'Asia/Kolkata',
          'currency': 'INR',
          'onboarding_completed': false,
        },
      );
      await _load();
      if (mounted) setState(() => _step = 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveBranding() async {
    final t = _tenant;
    if (t == null) return;
    setState(() => _busy = true);
    try {
      await _repo.updateTenant(t.id, {
        'brand_primary': _primaryCtrl.text.trim(),
        'brand_accent': _accentCtrl.text.trim(),
        'settings': {
          ...?t.settings,
          'onboarding_step': 2,
        },
      });
      await _load();
      if (mounted) setState(() => _step = 2);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createInvite() async {
    if (!BosPermissions.canManageMembers) return;
    final email = _inviteEmailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _step = 3);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _repo.createInvite(email: email, role: 'sales');
      final link = (result.email['link'] as String?)?.isNotEmpty == true
          ? result.email['link'] as String
          : '${Uri.base.origin}${RouteNames.adminAiOsAcceptInvite}?token=${result.invite.token}';
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) {
        setState(() {
          _inviteLink = link;
          _step = 3;
        });
        final sent = result.email['sent'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sent
                  ? 'Invite emailed to $email'
                  : 'Invite stub — link copied (set Resend for live email)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await _repo.completeOnboarding(catalogSeed: _catalogSeed);
      await _repo.refreshFeatureFlags();
      if (!mounted) return;
      context.go(RouteNames.adminAiOsHome);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Setup your workspace',
      embedded: widget.embedded,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Step ${_step + 1} of 4', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (_step + 1) / 4),
                const SizedBox(height: 24),
                if (_step == 0) ...[
                  Text('Company profile', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Company name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _businessType,
                    decoration: const InputDecoration(
                      labelText: 'Business type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cctv_integrator', child: Text('CCTV / Security')),
                      DropdownMenuItem(value: 'education', child: Text('Education')),
                      DropdownMenuItem(value: 'retail', child: Text('Retail')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _businessType = v ?? 'cctv_integrator'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _gstinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _logoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Logo URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Slug: ${_tenant?.slug ?? '—'}', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _saveProfile,
                    child: const Text('Continue'),
                  ),
                ] else if (_step == 1) ...[
                  Text('Branding', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _primaryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Primary color',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _accentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Accent color',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(onPressed: () => setState(() => _step = 0), child: const Text('Back')),
                      const Spacer(),
                      FilledButton(
                        onPressed: _busy ? null : _saveBranding,
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ] else if (_step == 2) ...[
                  Text('Invite a teammate', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Optional — you can skip and invite later from Settings.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inviteEmailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teammate email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (_inviteLink != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(_inviteLink!),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(onPressed: () => setState(() => _step = 1), child: const Text('Back')),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _step = 3),
                        child: const Text('Skip'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy ? null : _createInvite,
                        child: const Text('Invite & continue'),
                      ),
                    ],
                  ),
                ] else ...[
                  Text('Catalog seed', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('How do you want to start your product catalog?'),
                  const SizedBox(height: 12),
                  RadioListTile<String>(
                    value: 'empty',
                    groupValue: _catalogSeed,
                    onChanged: (v) => setState(() => _catalogSeed = v!),
                    title: const Text('Start empty'),
                    subtitle: const Text('Add products later'),
                  ),
                  RadioListTile<String>(
                    value: 'csv',
                    groupValue: _catalogSeed,
                    onChanged: (v) => setState(() => _catalogSeed = v!),
                    title: const Text('CSV import later'),
                    subtitle: const Text('Remember preference for Catalog phase'),
                  ),
                  RadioListTile<String>(
                    value: 'marketplace',
                    groupValue: _catalogSeed,
                    onChanged: (v) => setState(() => _catalogSeed = v!),
                    title: const Text('Industry pack later'),
                    subtitle: const Text('Use Marketplace templates when ready'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(onPressed: () => setState(() => _step = 2), child: const Text('Back')),
                      const Spacer(),
                      FilledButton(
                        onPressed: _busy ? null : _finish,
                        child: const Text('Finish setup'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
