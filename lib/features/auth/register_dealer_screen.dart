import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/legal_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/utils/short_codes.dart';
import '../../core/utils/validators.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/models/service_area_result.dart';
import '../../shared/widgets/success_animation_screen.dart';
import '../../shared/widgets/category_subcategory_skills_picker.dart';

abstract final class _RegisterDesign {
  static const double radius = 16.0;
  static const Color textPrimary = Colors.black;
  static const Color textMuted = Color(0xFF64748B);
  static const Color buttonPrimary = AppColors.brandWarm;
  static const Color buttonBorder = AppColors.brandWarmDark;
}

class RegisterDealerScreen extends StatefulWidget {
  const RegisterDealerScreen({
    super.key,
    this.initialServiceArea,
    this.fromPhone = false,
  });

  final ServiceAreaResult? initialServiceArea;
  final bool fromPhone;

  @override
  State<RegisterDealerScreen> createState() => _RegisterDealerScreenState();
}

class _RegisterDealerScreenState extends State<RegisterDealerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeCancellationRefund = false;
  final List<String> _selectedSubSectorIds = [];
  double? _serviceLat;
  double? _serviceLng;
  double _serviceRadiusKm = 25;

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceArea != null) {
      final sa = widget.initialServiceArea!;
      _serviceLat = sa.latitude;
      _serviceLng = sa.longitude;
      _serviceRadiusKm = sa.radiusKm;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _setServiceAreaFromLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      setState(() {
        _serviceLat = pos.latitude;
        _serviceLng = pos.longitude;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service area center set from current location.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppConstants.locationError} $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms || !_agreePrivacy || !_agreeCancellationRefund) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must accept Terms of Service, Privacy Policy, and Cancellation & Refund Policy to create an account.')),
      );
      return;
    }
    if (_selectedSubSectorIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one subcategory you deal in.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      String uid;
      String email;
      if (widget.fromPhone) {
        final user = AuthService().currentUser;
        if (user == null) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please start again from phone number.')),
          );
          return;
        }
        uid = user.uid;
        email = widget.initialServiceArea?.email ?? user.email ?? '';
      } else {
        final cred = await AuthService().signUpWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (!mounted) return;
        if (cred == null) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration failed. Email may already be in use.')),
          );
          return;
        }
        uid = cred.user!.uid;
        email = _emailController.text.trim();
      }
      if (!FirestoreService.isAvailable) {
        setState(() => _isLoading = false);
        context.go(RouteNames.successAnimation, extra: {
          'successType': SuccessType.registerSuccess,
          'nextRoute': RouteNames.dealerHome,
          'extra': null,
        });
        return;
      }
      Map<String, dynamic> serviceArea;
      if (widget.initialServiceArea != null) {
        serviceArea = widget.initialServiceArea!.toFirestore();
      } else if (_serviceLat != null && _serviceLng != null) {
        serviceArea = {
          'latitude': _serviceLat,
          'longitude': _serviceLng,
          'radiusKm': _serviceRadiusKm,
        };
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set your service area from the map or use current location.')),
        );
        return;
      }
      final existingCity = serviceArea['city'] as String?;
      if (existingCity == null || existingCity.isEmpty) {
        final lat = (serviceArea['latitude'] as num?)?.toDouble();
        final lng = (serviceArea['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          try {
            final placemarks = await geo.placemarkFromCoordinates(lat, lng);
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              final city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
              if (city != null && city.isNotEmpty) {
                serviceArea = Map<String, dynamic>.from(serviceArea)..['city'] = city;
              }
            }
          } catch (_) {}
        }
      }
      final profile = <String, dynamic>{
        'name': widget.initialServiceArea?.fullName ?? '',
        'phone': widget.fromPhone ? (AuthService().currentUser?.phoneNumber ?? '') : '',
      };
      if (widget.fromPhone && widget.initialServiceArea != null) {
        profile['buildingApartment'] = widget.initialServiceArea!.buildingApartment;
        profile['houseFlatShopNumber'] = widget.initialServiceArea!.houseFlatShopNumber;
        profile['landmark'] = widget.initialServiceArea!.landmark;
      }
      await FirestoreService.users().doc(uid).set({
        'role': 'dealer',
        'approved': false,
        'online': false,
        'userCode': shortCode('DGYU', uid),
        'profile': profile,
        'email': email,
        'dealerSectors': _selectedSubSectorIds,
        'serviceArea': serviceArea,
        'trustScore': 70,
        'reputationLevel': 'standard',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirestoreService.userTermsAcceptance().add({
        'user_id': uid,
        'user_type': 'dealer',
        'terms_version': LegalConstants.termsVersion,
        'accepted_at': FieldValue.serverTimestamp(),
        'device_ip': null,
      });
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go(RouteNames.successAnimation, extra: {
        'successType': SuccessType.registerSuccess,
        'nextRoute': RouteNames.dealerHome,
        'extra': null,
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    }
  }

  static const _bgLight = Color(0xFFF8FAFC);
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create your Dealer account',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _RegisterDesign.textPrimary,
                        ),
                      ).animate().fadeIn().slideY(begin: 0.03, end: 0, curve: Curves.easeOut),
                      const SizedBox(height: 6),
                      Text(
                        'Select service category & subcategory. You will be notified once approved.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: _RegisterDesign.textMuted,
                        ),
                      ).animate().fadeIn(delay: 30.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOut),
                      const SizedBox(height: 24),
                      if (FirestoreService.isAvailable)
                        CategorySubcategorySkillsPicker(
                          showSkills: false,
                          selectedSubSectorIds: _selectedSubSectorIds,
                          selectedSkillIds: const [],
                          onSubSectorsChanged: (ids) => setState(() {
                            _selectedSubSectorIds.clear();
                            _selectedSubSectorIds.addAll(ids);
                          }),
                          onSkillsChanged: (_) {},
                        ),
                      if (FirestoreService.isAvailable) const SizedBox(height: 16),
                      if (!widget.fromPhone && widget.initialServiceArea == null) _buildServiceAreaSection(),
                      if (!widget.fromPhone && _serviceLat != null && _serviceLng != null) _buildRadiusField(),
                      if (!widget.fromPhone) ...[
                        const SizedBox(height: 14),
                        _buildSolidField(
                          controller: _emailController,
                          label: AppConstants.emailHint,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                        ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOut),
                        const SizedBox(height: 14),
                        _buildSolidField(
                          controller: _passwordController,
                          label: AppConstants.passwordHint,
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          validator: Validators.password,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: _RegisterDesign.buttonPrimary,
                              size: 22,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ).animate().fadeIn(delay: 170.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOut),
                        const SizedBox(height: 14),
                        _buildSolidField(
                          controller: _confirmPasswordController,
                          label: AppConstants.confirmPasswordHint,
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirm,
                          validator: (v) => Validators.confirmPassword(v, _passwordController.text),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: _RegisterDesign.buttonPrimary,
                              size: 22,
                            ),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.03, end: 0, curve: Curves.easeOut),
                      ],
                      const SizedBox(height: 20),
                      _buildLegalConsentSection(),
                      const SizedBox(height: 28),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _RegisterDesign.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        AppConstants.registerAsDealer,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _RegisterDesign.textPrimary,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildLegalConsentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legal consent (required)',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: _RegisterDesign.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Read each document and accept below to continue.',
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _RegisterDesign.textMuted),
        ),
        const SizedBox(height: 10),
        _buildConsentRow(
          value: _agreeTerms,
          onChanged: (v) => setState(() => _agreeTerms = v ?? false),
          label: 'Terms of Service',
          documentId: LegalConstants.termsOfService,
        ),
        _buildConsentRow(
          value: _agreePrivacy,
          onChanged: (v) => setState(() => _agreePrivacy = v ?? false),
          label: 'Privacy Policy',
          documentId: LegalConstants.privacyPolicy,
        ),
        _buildConsentRow(
          value: _agreeCancellationRefund,
          onChanged: (v) => setState(() => _agreeCancellationRefund = v ?? false),
          label: 'Cancellation and Refund Policy',
          documentIds: [LegalConstants.cancellationPolicy, LegalConstants.refundPolicy],
        ),
      ],
    );
  }

  Widget _buildConsentRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    String? documentId,
    List<String>? documentIds,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: _RegisterDesign.buttonPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'I have read and accept the $label',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _RegisterDesign.textPrimary),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (documentId != null)
                      _buildReadLink('Read $label', () => context.push(RouteNames.legalDocumentView(documentId), extra: LegalConstants.defaultTitles[documentId])),
                    if (documentIds != null)
                      ...documentIds.map((id) {
                        final title = LegalConstants.defaultTitles[id] ?? id;
                        return _buildReadLink('Read $title', () => context.push(RouteNames.legalDocumentView(id), extra: title));
                      }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadLink(String label, VoidCallback onTap) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: _RegisterDesign.buttonPrimary,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: _RegisterDesign.buttonPrimary,
          decoration: TextDecoration.underline,
          decorationColor: _RegisterDesign.buttonPrimary,
        ),
      ),
    );
  }

  /// Part 4: Solid input — white, border #E2E8F0, no blur.
  Widget _buildSolidField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_RegisterDesign.radius),
        border: Border.all(color: _cardBorder),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.plusJakartaSans(fontSize: 16, color: _RegisterDesign.textPrimary, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.plusJakartaSans(color: _RegisterDesign.textMuted, fontSize: 14),
          prefixIcon: Icon(icon, color: _RegisterDesign.buttonPrimary, size: 22),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_RegisterDesign.radius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_RegisterDesign.radius),
            borderSide: const BorderSide(color: _cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_RegisterDesign.radius),
            borderSide: const BorderSide(color: _RegisterDesign.buttonPrimary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildServiceAreaSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service area (radius around your location)',
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: _RegisterDesign.textPrimary),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _setServiceAreaFromLocation,
            icon: const Icon(Icons.my_location_rounded, size: 20, color: _RegisterDesign.buttonPrimary),
            label: Text(
              'Set center from current location',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _RegisterDesign.buttonPrimary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _RegisterDesign.buttonPrimary,
              side: const BorderSide(color: _RegisterDesign.buttonBorder),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text('Radius (km):', style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _RegisterDesign.textPrimary)),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: _serviceRadiusKm.toStringAsFixed(0),
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _RegisterDesign.textPrimary),
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) => setState(() => _serviceRadiusKm = double.tryParse(v) ?? 25),
            ),
          ),
        ],
      ),
    );
  }

  /// Part 4: Solid primary CTA — height 52, radius 16.
  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _isLoading ? null : _submit,
      style: FilledButton.styleFrom(
        backgroundColor: _RegisterDesign.buttonPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isLoading
          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(AppConstants.submit, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
  }
}
