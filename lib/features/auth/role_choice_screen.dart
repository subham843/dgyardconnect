import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/service_area_result.dart';
import '../../shared/widgets/technician_glass_kit.dart';

class RoleChoiceScreen extends StatefulWidget {
  const RoleChoiceScreen({
    super.key,
    required this.serviceArea,
    this.fromCompletedFlow = false,
  });

  final ServiceAreaResult serviceArea;
  final bool fromCompletedFlow;

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen> {
  static const _headline = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF6B7280);
  String? _selectedRole;
  bool _continuePressed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TechnicianGlassBackground(
        child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  if (!widget.fromCompletedFlow)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                        onPressed: () => context.go(RouteNames.serviceAreaPicker),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'How do you want to use ${AppConstants.appName}?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: _headline,
                        ),
                  ).animate().fadeIn(duration: 180.ms),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: 0.6,
                    child: Text(
                      'Pick your role to continue. Same sign-in for both.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _textSecondary,
                          ),
                    ),
                  ).animate().fadeIn(delay: 50.ms),
                  const SizedBox(height: 24),
                  _RoleCard(
                    icon: Icons.storefront_rounded,
                    title: AppConstants.registerAsDealer,
                    subtitle: 'Post jobs and manage technicians',
                    selected: _selectedRole == 'dealer',
                    onTap: () => setState(() => _selectedRole = 'dealer'),
                    delay: 100,
                  ),
                  const SizedBox(height: 18),
                  _RoleCard(
                    icon: Icons.engineering_rounded,
                    title: AppConstants.registerAsTechnician,
                    subtitle: 'Accept jobs and serve in your area',
                    selected: _selectedRole == 'technician',
                    onTap: () => setState(() => _selectedRole = 'technician'),
                    delay: 160,
                  ),
                  const SizedBox(height: 18),
                  _RoleCard(
                    icon: Icons.shopping_bag_rounded,
                    title: 'Shop as customer',
                    subtitle: 'Buy products, track orders, reorder anytime',
                    selected: _selectedRole == 'customer',
                    onTap: () => setState(() => _selectedRole = 'customer'),
                    delay: 220,
                  ),
                  const SizedBox(height: 20),
                  Divider(color: AppColors.brandWarmBorder.withValues(alpha: 0.7)),
                  const SizedBox(height: 20),
                  AnimatedScale(
                    scale: _continuePressed ? 0.97 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _selectedRole == null
                            ? LinearGradient(
                                colors: [
                                  Colors.grey.shade400,
                                  Colors.grey.shade500,
                                ],
                              )
                            : const LinearGradient(
                                colors: [AppColors.brandWarm, AppColors.brandWarmLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _selectedRole == null
                            ? const []
                            : [
                                BoxShadow(
                                  color: AppColors.brandWarm.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTapDown: (_) => setState(() => _continuePressed = true),
                          onTapUp: (_) => setState(() => _continuePressed = false),
                          onTapCancel: () => setState(() => _continuePressed = false),
                          onTap: _selectedRole == null
                              ? null
                              : () {
                                  if (_selectedRole == 'customer') {
                                    context.push(RouteNames.registerCustomer);
                                    return;
                                  }
                                  final route = _selectedRole == 'dealer'
                                      ? RouteNames.registerDealer
                                      : RouteNames.registerTechnician;
                                  context.push(
                                    route,
                                    extra: <String, dynamic>{
                                      'serviceArea': widget.serviceArea,
                                      'fromPhone': true,
                                    },
                                  );
                                },
                          child: const SizedBox(
                            height: 54,
                            child: Center(
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
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
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.delay,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final int delay;

  static const _cardBorder = AppColors.brandWarmBorder;
  static const _headline = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: selected
                  ? AppColors.brandWarmBg.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: selected ? AppColors.brandWarmSoft : _cardBorder,
                width: selected ? 1.6 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
                if (selected)
                  BoxShadow(
                    color: AppColors.brandWarmSoft.withValues(alpha: 0.24),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.brandWarm.withValues(alpha: 0.16)
                        : const Color(0xFF6B7280).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 27,
                    color: selected ? AppColors.brandWarm : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _headline,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Opacity(
                        opacity: 0.6,
                        child: Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6B7280),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                  size: selected ? 22 : 14,
                  color: selected ? AppColors.brandWarmSoft : const Color(0xFF6B7280),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, delay: Duration(milliseconds: delay))
        .slideY(
            begin: 0.04,
            end: 0,
            duration: 220.ms,
            delay: Duration(milliseconds: delay),
            curve: Curves.easeOutCubic);
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(20),
          child: widget.child,
        ),
      ),
    );
  }
}
