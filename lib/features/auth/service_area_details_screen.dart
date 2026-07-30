import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/service_area_result.dart';
import '../../shared/widgets/glass_container.dart';
import '../../shared/widgets/technician_glass_kit.dart';

/// Full-screen form after map selection: name, email, address details. On confirm → Role Choice.
class ServiceAreaDetailsScreen extends StatefulWidget {
  const ServiceAreaDetailsScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.addressLabel,
    this.city = '',
  });

  final double latitude;
  final double longitude;
  final double radiusKm;
  final String addressLabel;
  final String city;

  @override
  State<ServiceAreaDetailsScreen> createState() => _ServiceAreaDetailsScreenState();
}

class _ServiceAreaDetailsScreenState extends State<ServiceAreaDetailsScreen> {
  static const _bgBase = AppColors.brandWarmBgMuted;
  static const _kTextPrimary = Color(0xFF1A1A1A);
  static const _kTextSecondary = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _buildingController = TextEditingController();
  final _houseFlatShopController = TextEditingController();
  final _landmarkController = TextEditingController();
  bool _confirmPressed = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _buildingController.dispose();
    _houseFlatShopController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    if (!_formKey.currentState!.validate()) return;
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final fullName = last.isEmpty ? first : '$first $last';
    final result = ServiceAreaResult(
      latitude: widget.latitude,
      longitude: widget.longitude,
      radiusKm: widget.radiusKm,
      fullName: fullName,
      email: _emailController.text.trim(),
      buildingApartment: _buildingController.text.trim(),
      houseFlatShopNumber: _houseFlatShopController.text.trim(),
      landmark: _landmarkController.text.trim(),
      addressLabel: widget.addressLabel,
      city: widget.city,
    );
    context.go(RouteNames.roleChoice, extra: <String, dynamic>{
      'serviceArea': result.toMap(),
      'fromCompletedFlow': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBase,
      body: TechnicianGlassBackground(
        child: SafeArea(
            child: Column(
              children: [
                GlassContainer(
                  borderRadius: 0,
                  blurSigma: 24,
                  padding: EdgeInsets.zero,
                  color: Colors.white.withValues(alpha: 0.28),
                  borderColor: Colors.white.withValues(alpha: 0.4),
                  borderWidth: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          onPressed: () => context.pop(),
                        ),
                        Expanded(
                          child: Text(
                            AppConstants.userDetails,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          GlassContainer(
                            borderRadius: 20,
                            blurSigma: 16,
                            padding: const EdgeInsets.all(24),
                            color: Colors.white.withValues(alpha: 0.15),
                            borderColor: AppColors.brandWarmBorder,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your details',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _kTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'A few details to complete your profile',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: _kTextSecondary.withValues(alpha: 0.6),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _GlassInputField(
                                  controller: _firstNameController,
                                  label: 'First name',
                                  icon: Icons.person_outline_rounded,
                                  validator: (v) => Validators.required(v, 'First name'),
                                  textCapitalization: TextCapitalization.words,
                                ),
                                const SizedBox(height: 18),
                                _GlassInputField(
                                  controller: _lastNameController,
                                  label: 'Last name (optional)',
                                  icon: Icons.badge_outlined,
                                  validator: (_) => null,
                                  textCapitalization: TextCapitalization.words,
                                ),
                                const SizedBox(height: 18),
                                _GlassInputField(
                                  controller: _emailController,
                                  label: AppConstants.emailHint,
                                  icon: Icons.email_outlined,
                                  validator: Validators.email,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 18),
                                _GlassInputField(
                                  controller: _houseFlatShopController,
                                  label: AppConstants.houseFlatShopNumber,
                                  icon: Icons.numbers_rounded,
                                  validator: (v) => Validators.required(v, 'House/Flat/Shop number'),
                                ),
                                const SizedBox(height: 18),
                                _GlassInputField(
                                  controller: _buildingController,
                                  label: AppConstants.buildingApartment,
                                  icon: Icons.apartment_rounded,
                                  validator: (v) => Validators.required(v, 'Building/Apartment'),
                                  textCapitalization: TextCapitalization.words,
                                ),
                                const SizedBox(height: 18),
                                _GlassInputField(
                                  controller: _landmarkController,
                                  label: AppConstants.landmark,
                                  icon: Icons.place_outlined,
                                  validator: (v) => Validators.required(v, 'Landmark'),
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          AnimatedScale(
                            scale: _confirmPressed ? 0.97 : 1,
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOutCubic,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.brandWarm, AppColors.brandWarmLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brandWarm.withValues(alpha: 0.28),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTapDown: (_) => setState(() => _confirmPressed = true),
                                  onTapUp: (_) => setState(() => _confirmPressed = false),
                                  onTapCancel: () => setState(() => _confirmPressed = false),
                                  onTap: _onConfirm,
                                  child: Container(
                                    height: 54,
                                    alignment: Alignment.center,
                                    child: Text(
                                      AppConstants.confirmDetails,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }

}

class _GlassInputField extends StatefulWidget {
  const _GlassInputField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;

  @override
  State<_GlassInputField> createState() => _GlassInputFieldState();
}

class _GlassInputFieldState extends State<_GlassInputField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: TextFormField(
        controller: widget.controller,
        textCapitalization: widget.textCapitalization,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15.5,
          color: const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF6B7280),
          ),
          prefixIcon: Icon(
            widget.icon,
            size: 22,
            color: _focused ? AppColors.brandWarmSoft : const Color(0xFF6B7280),
          ),
          errorStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFE57373),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.brandWarmBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.brandWarmBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.brandWarmSoft, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }
}
