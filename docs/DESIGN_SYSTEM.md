## DG Yard Connect — Design System (Quick Reference)

### Colors
- **Source**: `lib/core/theme/app_colors.dart`
- **Primary**: `AppColors.primary` (`0xFF0D47A1`)
- **Secondary**: `AppColors.secondary` (`0xFF00838F`)
- **Success / Warning / Error**: `AppColors.success`, `AppColors.warning`, `AppColors.error`

### Motion
- **Source**: `lib/core/theme/motion_tokens.dart`
- **Durations**: `MotionTokens.fast/base/slow/slower`
- **Curves**: `MotionTokens.inCurve/outCurve/emphasized`
- **List stagger**: `MotionTokens.listStaggerMs`

### Navigation patterns
- **Dealer/Technician**: Floating dock nav (`lib/shared/widgets/floating_dock_nav.dart`)
- **Admin**: Responsive rail/dashboard (`lib/features/admin/admin_home_screen.dart`)
- **Routing**: GoRouter single source (`lib/core/constants/route_names.dart`, `lib/shared/router/app_router.dart`)

### Hero headers
- **Dealer**: `DealerHeroContent` (`lib/features/dealer/dealer_hero_section.dart`)
- **Technician**: `TechnicianHeroProfileContent` (`lib/features/technician/technician_profile_section.dart`)
- **Collapsible container**: `PremiumCollapsibleHero` (`lib/shared/widgets/premium_collapsible_hero.dart`)

### Empty/Error states
- **Widgets**: `EmptyStateWidget`, `ErrorStateWidget`
- **Source**: `lib/shared/widgets/empty_error_states.dart`

### Analytics (events)
- **Wrapper**: `AnalyticsService` (`lib/shared/services/analytics_service.dart`)
- **Event/param constants**: `lib/core/constants/analytics_events.dart` (use these to avoid typos)
- **Schema & KPIs**: `docs/ANALYTICS_SCHEMA.md`
- **Screen tracking**: via GoRouter observer in `lib/shared/router/app_router.dart`
- **Key events** (current): `job_posted`, `payment_completed`, `warranty_claim_created`, `job_dispute_created`, `support_ticket_created`

