import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/widgets/squircle_avatar.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import 'edit_profile_design.dart';

class TechnicianEditProfileScreen extends StatefulWidget {
  const TechnicianEditProfileScreen({super.key});

  @override
  State<TechnicianEditProfileScreen> createState() =>
      _TechnicianEditProfileScreenState();
}

class _TechnicianEditProfileScreenState
    extends State<TechnicianEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  bool _loading = false;
  bool _initialized = false;
  String? _photoUrl;
  String? _uid;
  bool _phoneVerified = false;
  bool _emailVerified = false;
  bool _alternatePhoneVerified = false;
  String _loadedAlternatePhone = '';

  String? _gender;
  DateTime? _dob;
  final _dobController = TextEditingController();
  String? _maritalStatus;

  static const List<String> _genderOptions = ['Male', 'Female', 'Transgender', 'Other', 'Prefer not to say'];
  static const List<String> _maritalOptions = ['Single', 'Married', 'Divorced', 'Widowed', 'Separated', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _alternatePhoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  static String _normalizePhone(String? s) {
    if (s == null || s.isEmpty) return '';
    final digits = s.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final authUser = FirebaseAuth.instance.currentUser;
    if (uid == null || !FirestoreService.isAvailable) return;
    _uid = uid;
    final doc = await FirestoreService.users().doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      _nameController.text = profile['name'] as String? ?? '';
      _phoneController.text = profile['phone'] as String? ?? '';
      _emailController.text =
          data['email'] as String? ??
          authUser?.email ??
          '';
      final alt = profile['alternatePhone'] as String? ?? '';
      _alternatePhoneController.text = alt;
      _loadedAlternatePhone = alt;
      _photoUrl = profile['photoUrl'] as String?;
      _gender = profile['gender'] as String?;
      _maritalStatus = profile['maritalStatus'] as String?;
      final dobStr = profile['dateOfBirth'] as String?;
      if (dobStr != null && dobStr.isNotEmpty) {
        try {
          _dob = DateTime.tryParse(dobStr);
          if (_dob != null) _dobController.text = DateFormat('dd-MM-yyyy').format(_dob!);
        } catch (_) {}
      }
      final storedPhone = _normalizePhone(profile['phone'] as String?);
      final authPhone = _normalizePhone(authUser?.phoneNumber);
      _phoneVerified = storedPhone.isNotEmpty && authPhone.isNotEmpty && storedPhone == authPhone;
      _emailVerified = authUser?.emailVerified ?? false;
      _alternatePhoneVerified = profile['alternatePhoneVerified'] == true;
    }
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (file == null || _uid == null) return;
    setState(() => _loading = true);
    try {
      final url = await StorageService.uploadProfilePhoto(
        userId: _uid!,
        file: File(file.path),
      );
      if (url == null || !mounted) return;
      final doc = await FirestoreService.users().doc(_uid).get();
      final profile = Map<String, dynamic>.from(
        doc.data()?['profile'] as Map<String, dynamic>? ?? {},
      );
      profile['photoUrl'] = url;
      await FirestoreService.users().doc(_uid).update({'profile': profile});
      if (mounted) {
        setState(() {
          _photoUrl = url;
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppConstants.errorGeneric} $e')),
        );
      }
    }
  }

  Future<void> _verifyMobile() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter mobile number first.')),
      );
      return;
    }
    if (Validators.phone(phone) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit mobile number.')),
      );
      return;
    }
    await _showOtpSheet(context: context, phone: phone, isEmail: false);
  }

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter email first.')));
      return;
    }
    if (Validators.email(email) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Check your inbox.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send verification: $e')),
        );
      }
    }
  }

  Future<void> _verifyAlternateNumber() async {
    final phone = _alternatePhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter alternate number first.')),
      );
      return;
    }
    await _showOtpSheet(
      context: context,
      phone: phone,
      isEmail: false,
      isAlternate: true,
    );
  }

  Future<void> _showOtpSheet({
    required BuildContext context,
    required String phone,
    required bool isEmail,
    bool isAlternate = false,
  }) async {
    final codeController = TextEditingController();
    String? verificationId;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          margin: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: EditProfileDesign.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(EditProfileDesign.radiusXl)),
            boxShadow: [
              BoxShadow(color: EditProfileDesign.shadowMedium, blurRadius: 24, offset: Offset(0, -4)),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: EditProfileDesign.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isAlternate ? 'Verify alternate number' : 'Verify mobile number',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: EditProfileDesign.textHeadline),
              ),
              const SizedBox(height: 6),
              Text('OTP will be sent to $phone', style: const TextStyle(fontSize: 14, color: EditProfileDesign.textMuted)),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: EditProfileDesign.inputDecoration(ctx, label: 'Enter OTP', icon: Icons.pin_rounded),
              ),
              const SizedBox(height: 20),
              FilledButton(
                  onPressed: () async {
                    if (verificationId == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Send OTP first.')),
                      );
                      return;
                    }
                    final code = codeController.text.trim();
                    if (code.length != 6) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Enter 6-digit OTP.')),
                      );
                      return;
                    }
                    try {
                      final credential = PhoneAuthProvider.credential(
                        verificationId: verificationId!,
                        smsCode: code,
                      );
                      if (isAlternate) {
                        if (_uid != null && FirestoreService.isAvailable) {
                          await FirestoreService.users().doc(_uid).update({
                            'profile.alternatePhone': phone,
                            'profile.alternatePhoneVerified': true,
                          });
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                        if (mounted) {
                          setState(() {
                            _alternatePhoneVerified = true;
                            _loadedAlternatePhone = phone;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Alternate number verified.'),
                            ),
                          );
                        }
                      } else {
                        await FirebaseAuth.instance.currentUser
                            ?.updatePhoneNumber(credential);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
                          setState(() => _phoneVerified = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mobile number verified.'),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Verification failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Verify OTP'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.verifyPhoneNumber(
                      phoneNumber: phone.length >= 10 ? '+91$phone' : phone,
                      verificationCompleted: (_) {},
                      verificationFailed: (_) {},
                      codeSent: (id, _) {
                        verificationId = id;
                        setModalState(() {});
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('OTP sent.')),
                        );
                      },
                      codeAutoRetrievalTimeout: (_) {},
                    );
                  },
                  child: const Text('Send OTP'),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    setState(() => _loading = true);
    try {
      await FirestoreService.users().doc(uid).update({
        'proposedProfile': {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'alternatePhone': _alternatePhoneController.text.trim().isEmpty
              ? null
              : _alternatePhoneController.text.trim(),
          'gender': _gender,
          'dateOfBirth': _dob?.toIso8601String().split('T').first,
          'maritalStatus': _maritalStatus,
        },
        'profilePendingApproval': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile update submitted for approval.'),
          ),
        );
        context.go(RouteNames.technicianProfile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppConstants.errorGeneric} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = (FirebaseAuth.instance.currentUser?.email ?? '').trim();
    final emailVerified =
        _emailVerified && _emailController.text.trim() == currentEmail;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Edit profile',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: _initialized
          ? AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.viewInsetsOf(context).bottom +
                    MediaQuery.paddingOf(context).bottom +
                    12,
              ),
              child: _buildStickySaveButton(),
            )
          : null,
      body: TechnicianGlassBackground(
        child: !_initialized
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandWarmSoft))
            : SafeArea(
                top: false,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    children: [
                      _buildPhotoSection(),
                      const SizedBox(height: 18),
                      _SectionTitle('Basic Info'),
                      _buildFloatingCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildInput(
                              controller: _nameController,
                              label: 'Name',
                              icon: Icons.person_outline_rounded,
                              validator: Validators.name,
                            ),
                            const SizedBox(height: 14),
                            _buildInput(
                              controller: _phoneController,
                              label: 'Phone',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: Validators.phone,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (_phoneVerified && _normalizePhone(_phoneController.text) == _normalizePhone(FirebaseAuth.instance.currentUser?.phoneNumber))
                                  ? 'Verified'
                                  : 'Not verified',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (_phoneVerified && _normalizePhone(_phoneController.text) == _normalizePhone(FirebaseAuth.instance.currentUser?.phoneNumber))
                                    ? AppColors.success
                                    : const Color(0xFFC62828),
                              ),
                            ),
                            if (!(_phoneVerified && _normalizePhone(_phoneController.text) == _normalizePhone(FirebaseAuth.instance.currentUser?.phoneNumber)))
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _verifyMobile,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.brandWarmSoft,
                                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                                  ),
                                  child: const Text('Verify now'),
                                ),
                              ),
                            const SizedBox(height: 8),
                            _buildInput(
                              controller: _alternatePhoneController,
                              label: 'Alternate phone',
                              icon: Icons.phone_iphone_rounded,
                              keyboardType: TextInputType.phone,
                            ),
                            if (_alternatePhoneController.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                (_alternatePhoneVerified &&
                                        _alternatePhoneController.text.trim() == _loadedAlternatePhone.trim())
                                    ? 'Verified'
                                    : 'Not verified',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (_alternatePhoneVerified &&
                                          _alternatePhoneController.text.trim() == _loadedAlternatePhone.trim())
                                      ? AppColors.success
                                      : const Color(0xFFC62828),
                                ),
                              ),
                              if (!(_alternatePhoneVerified &&
                                  _alternatePhoneController.text.trim() == _loadedAlternatePhone.trim()))
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: _verifyAlternateNumber,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.brandWarmSoft,
                                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                                    ),
                                    child: const Text('Verify alternate number'),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionTitle('Contact Info'),
                      _buildFloatingCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildInput(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              emailVerified ? 'Verified' : 'Not verified',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: emailVerified ? AppColors.success : const Color(0xFFC62828),
                              ),
                            ),
                            if (!emailVerified)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: _verifyEmail,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.brandWarmSoft,
                                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                                  ),
                                  child: const Text('Verify now'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionTitle('Personal Details'),
                      _buildFloatingCard(
                        child: Column(
                          children: [
                            _buildGenderDropdown(),
                            const SizedBox(height: 14),
                            _buildDobField(),
                            const SizedBox(height: 14),
                            _buildMaritalStatusDropdown(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: GestureDetector(
        onTap: _loading ? null : _pickProfilePhoto,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandWarmSoft.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              ClipOval(
                child: SquircleAvatar(
                  size: 104,
                  photoUrl: _photoUrl,
                  backgroundColor: EditProfileDesign.surfaceBg,
                  fallback: Icon(Icons.person_rounded, size: 48, color: EditProfileDesign.textMuted),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.brandWarmSoft,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandWarmSoft.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _loading ? Icons.hourglass_empty_rounded : Icons.add_a_photo_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutCubic);
  }

  Widget _buildFloatingCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: EditProfileDesign.floatingCard().copyWith(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandWarmSoft.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _genderOptions.contains(_gender) ? _gender : null,
      decoration: EditProfileDesign.inputDecoration(context, label: 'Gender', icon: Icons.wc_rounded),
      items: _genderOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() => _gender = v),
    );
  }

  Widget _buildDobField() {
    return TextFormField(
      controller: _dobController,
      decoration: EditProfileDesign.inputDecoration(
        context,
        label: 'Date of Birth',
        icon: Icons.calendar_today_rounded,
      ).copyWith(
        hintText: 'DD-MM-YYYY (type or tap icon for calendar)',
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_month_rounded),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dob ?? DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null && mounted) {
              setState(() {
                _dob = picked;
                _dobController.text = DateFormat('dd-MM-yyyy').format(picked);
              });
            }
          },
        ),
      ),
      onChanged: (v) {
        final parsed = _parseDob(v);
        if (parsed != null) setState(() => _dob = parsed);
      },
    );
  }

  DateTime? _parseDob(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(RegExp(r'[-/.]'));
    if (parts.length != 3) return null;
    int? d = int.tryParse(parts[0]);
    int? m = int.tryParse(parts[1]);
    int? y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    if (d > 31 || m > 12 || y < 1900 || y > DateTime.now().year) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  Widget _buildMaritalStatusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _maritalOptions.contains(_maritalStatus) ? _maritalStatus : null,
      decoration: EditProfileDesign.inputDecoration(context, label: 'Marital Status', icon: Icons.favorite_rounded),
      items: _maritalOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() => _maritalStatus = v),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: EditProfileDesign.inputDecoration(context, label: label, icon: icon).copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
          borderSide: const BorderSide(color: AppColors.brandWarmSoft, width: 1.4),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildStickySaveButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : _submit,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandWarmSoft.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    AppConstants.save,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF7A6A47),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
