import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/short_codes.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../data/bos_repository.dart';
import '../domain/bos_access.dart';

/// Public trial signup for AI Business OS (Firebase Auth + tenant bootstrap).
class BosTrialSignupScreen extends StatefulWidget {
  const BosTrialSignupScreen({super.key});

  @override
  State<BosTrialSignupScreen> createState() => _BosTrialSignupScreenState();
}

class _BosTrialSignupScreenState extends State<BosTrialSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _repo = BosRepository();
  bool _obscure = true;
  bool _busy = false;
  bool _slugTouched = false;
  String _businessType = 'cctv_integrator';

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _emailCtrl.text = user?.email ?? '';
    _nameCtrl.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _slugCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _gstinCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  String _slugify(String raw) {
    final s = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'company' : s;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      var user = AuthService().currentUser;
      final email = _emailCtrl.text.trim();
      final displayName = _nameCtrl.text.trim();

      if (user == null) {
        final cred = await AuthService().signUpWithEmailPassword(
          email,
          _passwordCtrl.text,
        );
        user = cred?.user;
        if (user == null) {
          throw Exception('Registration failed. Email may already be in use.');
        }
      }

      if (FirestoreService.isAvailable) {
        await FirestoreService.users().doc(user.uid).set({
          'role': 'customer',
          'approved': true,
          'online': false,
          'userCode': shortCode('DGYB', user.uid),
          'email': email,
          'profile': {
            'name': displayName.isEmpty ? _companyCtrl.text.trim() : displayName,
          },
          'bosTrial': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      BosAccess.clearCache();
      final synced = await SupabaseAuthService.instance.syncSessionFromFirebase(
        forceRefresh: true,
      );
      if (!synced) {
        throw Exception('Could not sync session. Try signing in again.');
      }

      final result = await _repo.bootstrapTenant(
        companyName: _companyCtrl.text.trim(),
        slug: _slugCtrl.text.trim().isEmpty ? null : _slugCtrl.text.trim(),
        email: email,
        displayName: displayName.isEmpty ? null : displayName,
      );
      final tenantId = '${result['tenant_id'] ?? ''}';
      if (tenantId.isEmpty) throw Exception('Tenant bootstrap returned no id');

      await _repo.updateTenant(tenantId, {
        if (_gstinCtrl.text.trim().isNotEmpty) 'gstin': _gstinCtrl.text.trim(),
        'business_type': _businessType,
        if (_phoneCtrl.text.trim().isNotEmpty) 'contact_phone': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty) 'contact_email': _emailCtrl.text.trim(),
        if (_addressCtrl.text.trim().isNotEmpty) 'address_line': _addressCtrl.text.trim(),
      });

      await _repo.setActiveTenantId(tenantId);
      await _repo.refreshFeatureFlags();
      BosAccess.clearCache();

      if (!mounted) return;
      context.go(RouteNames.adminAiOsOnboarding);
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
    final existing = AuthService().currentUser != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Start AI Business OS trial'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '14-day Starter trial',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your company workspace. CRM, leads, and settings unlock immediately.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _companyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Company name *',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (v) {
                        if (!_slugTouched) {
                          _slugCtrl.text = _slugify(v);
                        }
                      },
                      validator: (v) =>
                          (v == null || v.trim().length < 2) ? 'Enter company name' : null,
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
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mobile',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gstinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _slugCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Workspace slug',
                        border: OutlineInputBorder(),
                        helperText: 'Used in URLs; auto-filled from company name',
                      ),
                      onChanged: (_) => _slugTouched = true,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      enabled: !existing,
                      decoration: const InputDecoration(
                        labelText: 'Work email *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    if (!existing) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: Validators.password,
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(existing ? 'Create workspace' : 'Create account & start trial'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go(RouteNames.login),
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
