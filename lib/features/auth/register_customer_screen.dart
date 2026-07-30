import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/legal_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/short_codes.dart';
import '../../core/utils/validators.dart';
import '../../shared/services/auth_post_login.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/firestore_service.dart';

class RegisterCustomerScreen extends StatefulWidget {
  const RegisterCustomerScreen({super.key});

  @override
  State<RegisterCustomerScreen> createState() => _RegisterCustomerScreenState();
}

class _RegisterCustomerScreenState extends State<RegisterCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _redirectAfter(BuildContext context) {
    final raw = GoRouterState.of(context).uri.queryParameters['redirect'];
    if (raw == null || raw.isEmpty || !raw.startsWith('/') || raw.startsWith('//')) {
      return null;
    }
    return raw;
  }

  Future<void> _saveCustomerProfile({
    required String uid,
    required String email,
  }) async {
    if (!FirestoreService.isAvailable) return;

    await FirestoreService.users().doc(uid).set({
      'role': 'customer',
      'approved': true,
      'online': false,
      'userCode': shortCode('DGYC', uid),
      'profile': {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : (AuthService().currentUser?.phoneNumber ?? ''),
      },
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirestoreService.userTermsAcceptance().add({
      'user_id': uid,
      'user_type': 'customer',
      'terms_version': LegalConstants.termsVersion,
      'accepted_at': FieldValue.serverTimestamp(),
      'device_ip': null,
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms || !_agreePrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept Terms and Privacy Policy.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final redirect = _redirectAfter(context);
      final existing = AuthService().currentUser;

      if (existing != null) {
        final email = existing.email ?? _emailController.text.trim();
        await _saveCustomerProfile(uid: existing.uid, email: email);
        if (!mounted) return;
        await AuthPostLogin.finishExistingUser(
          context,
          existing.uid,
          redirectAfterLogin: redirect,
          useSuccessAnimation: true,
        );
        return;
      }

      final cred = await AuthService().signUpWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (cred?.user == null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration failed. Email may already be in use.')),
        );
        return;
      }

      await _saveCustomerProfile(
        uid: cred!.user!.uid,
        email: _emailController.text.trim(),
      );
      if (!mounted) return;

      await AuthPostLogin.complete(
        context,
        cred,
        useSuccessAnimation: true,
        redirectAfterLogin: redirect,
        onLoadingEnd: () {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = AuthService().currentUser != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create customer account'),
        backgroundColor: AppColors.brandWarm,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Shop CCTV, networking and security products. Track orders, reorder, and manage your account.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 12),
              if (!loggedIn) ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _agreeTerms,
                onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                title: const Text('I agree to Terms of Service'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: _agreePrivacy,
                onChanged: (v) => setState(() => _agreePrivacy = v ?? false),
                title: const Text('I agree to Privacy Policy'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandWarm,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(RouteNames.login),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
