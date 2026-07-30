import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../admin/widgets/admin_embedded_scaffold.dart';
import 'calculator_admin_ui.dart';

class AdminCalculatorHubScreen extends StatelessWidget {
  const AdminCalculatorHubScreen({
    super.key,
    this.embedded = false,
    this.onNavigateRoute,
  });

  final bool embedded;
  final ValueChanged<String>? onNavigateRoute;

  void _go(BuildContext context, String route) {
    if (onNavigateRoute != null) {
      onNavigateRoute!(route);
    } else {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Calculator', style: CalcAdminUi.largeTitle).calcPageEnter(),
        const SizedBox(height: 6),
        Text(
          SupabaseBootstrap.isInitialized
              ? 'Supabase ready · follow the checklist, then open each area below'
              : 'Supabase not configured',
          style: CalcAdminUi.body,
        ).calcPageEnter(delayMs: 40),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: CalcAdminUi.softCardDeco,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Setup checklist', style: CalcAdminUi.sectionTitle),
              const SizedBox(height: 8),
              Text(
                '1. Shop attrs  →  2. Family  →  3. Groups  →  4. Options  →  5. Rules',
                style: CalcAdminUi.body.copyWith(height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'Create calculator attributes in Shop first, then wire them into a family and add rules that suggest products or charges.',
                style: CalcAdminUi.body.copyWith(
                  color: CalcAdminUi.subtle,
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ).calcPageEnter(delayMs: 50),
        const SizedBox(height: 20),
        _hubCard(
          icon: Icons.family_restroom_rounded,
          title: 'Families',
          subtitle: 'Name and shop attributes',
          onTap: () => _go(context, RouteNames.adminCalculatorFamilies),
          index: 0,
        ),
        _hubCard(
          icon: Icons.view_agenda_outlined,
          title: 'Question groups',
          subtitle: 'Order sections customers see',
          onTap: () => _go(context, RouteNames.adminCalculatorQuestionGroups),
          index: 1,
        ),
        _hubCard(
          icon: Icons.quiz_outlined,
          title: 'Options & questions',
          subtitle: 'Customer choices and follow-up questions',
          onTap: () => _go(context, RouteNames.adminCalculatorOptions),
          index: 2,
        ),
        _hubCard(
          icon: Icons.rule_rounded,
          title: 'Rules',
          subtitle: 'Suggest products and scale quantities',
          onTap: () => _go(context, RouteNames.adminCalculatorRules),
          index: 3,
        ),
      ],
    );

    return AdminEmbeddedScaffold(
      title: 'Calculator module',
      embedded: embedded,
      body: body,
    );
  }

  Widget _hubCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CalcAdminUi.cardDeco,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CalcAdminUi.softBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: CalcAdminUi.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: CalcAdminUi.sectionTitle),
                      const SizedBox(height: 2),
                      Text(subtitle, style: CalcAdminUi.body),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: CalcAdminUi.faint),
              ],
            ),
          ),
        ),
      ),
    ).calcStagger(index);
  }
}
