import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';

class MasterDataHomeScreen extends StatelessWidget {
  const MasterDataHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Manage all master data for job types, sectors, rates, warranty, and config.',
            style: Theme.of(context).textTheme.bodyMedium,
          ).animate().fadeIn(),
          const SizedBox(height: 24),
          _MasterTile(
            title: 'Job types',
            subtitle: 'Fresh work, Repair work, etc.',
            icon: Icons.category,
            route: RouteNames.adminJobTypes,
            delay: 0,
          ),
          _MasterTile(
            title: 'Sectors',
            subtitle: 'CCTV, Computer, Plumbing, etc.',
            icon: Icons.business_center,
            route: RouteNames.adminSectors,
            delay: 50,
          ),
          _MasterTile(
            title: 'Sector sub-options',
            subtitle: 'HD Camera, IP Camera, etc. per sector',
            icon: Icons.list_alt,
            route: RouteNames.adminSectorSubOptions,
            delay: 100,
          ),
          _MasterTile(
            title: 'Skills',
            subtitle: 'Skill title & description per sector sub-option',
            icon: Icons.workspace_premium,
            route: RouteNames.adminSkills,
            delay: 125,
          ),
          _MasterTile(
            title: 'Industry types',
            subtitle: 'Residential, Industrial, etc.',
            icon: Icons.apartment,
            route: RouteNames.adminIndustryTypes,
            delay: 175,
          ),
          _MasterTile(
            title: 'Industry sub-options',
            subtitle: 'Flat, Apartment, House, etc. per industry',
            icon: Icons.category,
            route: RouteNames.adminIndustrySubOptions,
            delay: 200,
          ),
          _MasterTile(
            title: 'Rate matrix',
            subtitle: 'Fixed rates by job type, sector, industry',
            icon: Icons.attach_money,
            route: RouteNames.adminRateMatrix,
            delay: 225,
          ),
          _MasterTile(
            title: 'Default warranty',
            subtitle: 'Warranty days by sector / sub-option',
            icon: Icons.event_available,
            route: RouteNames.adminDefaultWarranty,
            delay: 275,
          ),
          _MasterTile(
            title: 'Wiring types',
            subtitle: 'Open wiring, Conduit wiring, etc.',
            icon: Icons.electrical_services,
            route: RouteNames.adminWiringTypes,
            delay: 325,
          ),
          _MasterTile(
            title: 'Wiring rate config',
            subtitle: 'Included meters, rate per meter',
            icon: Icons.settings_ethernet,
            route: RouteNames.adminWiringRateConfig,
            delay: 375,
          ),
          _MasterTile(
            title: 'Platform charge config',
            subtitle: 'Platform fee (percent or fixed) per job',
            icon: Icons.percent,
            route: RouteNames.adminPlatformChargeConfig,
            delay: 425,
          ),
          _MasterTile(
            title: 'Job limit config',
            subtitle: 'Free jobs limits + acceptance fee',
            icon: Icons.rule_folder_rounded,
            route: RouteNames.adminJobLimitConfig,
            delay: 450,
          ),
          _MasterTile(
            title: 'Travel expense config',
            subtitle: 'Free km, per km rate after limit',
            icon: Icons.directions_car,
            route: RouteNames.adminTravelExpenseConfig,
            delay: 475,
          ),
          _MasterTile(
            title: 'Rejection reasons',
            subtitle: 'Pre-defined reasons when dealer/technician rejects bid',
            icon: Icons.cancel_outlined,
            route: RouteNames.adminRejectionReasons,
            delay: 525,
          ),
          _MasterTile(
            title: 'Warranty claim categories',
            subtitle: 'Claim categories by sector for dealer warranty claims',
            icon: Icons.verified_user_outlined,
            route: RouteNames.adminWarrantyClaimCategories,
            delay: 550,
          ),
        ],
      ),
    );
  }
}

class _MasterTile extends StatelessWidget {
  const _MasterTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.delay,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideX(begin: 0.02, end: 0, curve: Curves.easeOut);
  }
}
