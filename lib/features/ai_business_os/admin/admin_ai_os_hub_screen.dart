import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_auth_service.dart';
import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';

class AdminAiOsHubScreen extends StatefulWidget {
  const AdminAiOsHubScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsHubScreen> createState() => _AdminAiOsHubScreenState();
}

class _AdminAiOsHubScreenState extends State<AdminAiOsHubScreen> {
  final _repo = BosRepository();
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _platform;
  bool _loading = true;
  bool _onboardingDone = true;
  bool _isSuperadmin = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final stats = await _repo.aiSalesStats();
    await _repo.refreshFeatureFlags();
    final done = await _repo.isOnboardingCompleted();
    final superadmin = SupabaseAuthService.instance.currentJwtIsSuperadmin;
    Map<String, dynamic>? platform;
    if (superadmin) {
      try {
        platform = await _repo.superAdminPlatformStats();
      } catch (_) {
        platform = null;
      }
    }
    if (mounted) {
      setState(() {
        _stats = stats;
        _platform = platform;
        _onboardingDone = done;
        _isSuperadmin = superadmin;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'AI Business OS — Overview',
      embedded: widget.embedded,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_onboardingDone) ...[
                      Card(
                        color: const Color(0xFFEEF2FF),
                        child: ListTile(
                          leading: const Icon(Icons.rocket_launch_outlined),
                          title: const Text('Finish workspace setup'),
                          subtitle: const Text('Branding, invite teammate, catalog preference'),
                          trailing: FilledButton(
                            onPressed: () => context.go(RouteNames.adminAiOsOnboarding),
                            child: const Text('Continue'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_isSuperadmin && _platform != null) ...[
                      Text('Super Admin — Platform', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _KpiCard(
                            title: 'Companies',
                            value: '${_platform?['companies_total'] ?? 0}',
                            icon: Icons.business,
                            color: Colors.indigo,
                            onTap: () => context.go(RouteNames.adminAiOsBilling),
                          ),
                          _KpiCard(
                            title: 'Active / Trial',
                            value: '${_platform?['companies_active'] ?? 0}',
                            icon: Icons.verified_outlined,
                            color: Colors.teal,
                            onTap: () => context.go(RouteNames.adminAiOsBilling),
                          ),
                          _KpiCard(
                            title: 'MRR',
                            value: '₹${_platform?['mrr_inr'] ?? ((_platform?['mrr_paise'] as num?)?.toInt() ?? 0) ~/ 100}',
                            icon: Icons.payments_outlined,
                            color: Colors.green,
                            onTap: () => context.go(RouteNames.adminAiOsBilling),
                          ),
                          _KpiCard(
                            title: 'Users',
                            value: '${_platform?['users_total'] ?? 0}',
                            icon: Icons.people_outline,
                            color: Colors.blueGrey,
                            onTap: () => context.go(RouteNames.adminAiOsSettings),
                          ),
                          _KpiCard(
                            title: 'AI msgs (30d)',
                            value: '${_platform?['usage_ai_messages_30d'] ?? 0}',
                            icon: Icons.smart_toy_outlined,
                            color: Colors.deepPurple,
                            onTap: () => context.go(RouteNames.adminAiOsBilling),
                          ),
                          _KpiCard(
                            title: 'Voice min (30d)',
                            value: '${_platform?['usage_voice_minutes_30d'] ?? 0}',
                            icon: Icons.phone_in_talk_outlined,
                            color: Colors.orange,
                            onTap: () => context.go(RouteNames.adminAiOsBilling),
                          ),
                          _KpiCard(
                            title: 'API calls (30d)',
                            value: '${_platform?['usage_api_calls_30d'] ?? 0}',
                            icon: Icons.api,
                            color: Colors.brown,
                            onTap: () => context.go(RouteNames.adminAiOsBilling),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage plans / suspend on Billing. Switch company workspace in Settings.',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Add contact'),
                          onPressed: () => context.go(RouteNames.adminAiOsCrm),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.leaderboard, size: 18),
                          label: const Text('Add lead'),
                          onPressed: () => context.go(RouteNames.adminAiOsLeads),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.smart_toy_outlined, size: 18),
                          label: const Text('AI Queue'),
                          onPressed: () => context.go(RouteNames.adminAiOsLeads),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.mail_outline, size: 18),
                          label: const Text('Invite teammate'),
                          onPressed: () => context.go(RouteNames.adminAiOsSettings),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.settings_outlined, size: 18),
                          label: const Text('Settings'),
                          onPressed: () => context.go(RouteNames.adminAiOsSettings),
                        ),
                        if (!_onboardingDone)
                          ActionChip(
                            avatar: const Icon(Icons.checklist, size: 18),
                            label: const Text('Complete setup'),
                            onPressed: () => context.go(RouteNames.adminAiOsOnboarding),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('AI Sales Agent', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _KpiCard(
                          title: 'AI Conversations',
                          value: '${_stats?['ai_conversations'] ?? 0}',
                          icon: Icons.chat_bubble_outline,
                          color: Colors.teal,
                          onTap: () => context.go(RouteNames.adminAiOsWhatsapp),
                        ),
                        _KpiCard(
                          title: 'Web/App chats',
                          value: '${_stats?['ai_conversations_web'] ?? 0}',
                          icon: Icons.language,
                          color: Colors.cyan,
                          onTap: () => context.go(RouteNames.adminAiOsWhatsapp),
                        ),
                        _KpiCard(
                          title: 'AI Calls',
                          value: '${_stats?['ai_calls'] ?? 0}',
                          icon: Icons.phone_in_talk_outlined,
                          color: Colors.deepPurple,
                          onTap: () => context.go(RouteNames.adminAiOsVoice),
                        ),
                        _KpiCard(
                          title: 'Handover / Hot',
                          value: '${_stats?['handover_ready'] ?? _stats?['leads_hot'] ?? 0}',
                          icon: Icons.local_fire_department,
                          color: Colors.orange,
                          onTap: () => context.go(RouteNames.adminAiOsLeads),
                        ),
                        _KpiCard(
                          title: 'Follow-ups due',
                          value: '${_stats?['followups_pending'] ?? 0}',
                          icon: Icons.schedule,
                          color: Colors.blueGrey,
                          onTap: () => context.go(RouteNames.adminAiOsLeads),
                        ),
                        _KpiCard(
                          title: 'Follow-ups done',
                          value: '${_stats?['followups_done'] ?? 0}',
                          icon: Icons.done_all,
                          color: Colors.indigo,
                          onTap: () => context.go(RouteNames.adminAiOsLeads),
                        ),
                        _KpiCard(
                          title: 'Qualified',
                          value: '${_stats?['leads_qualified'] ?? 0}',
                          icon: Icons.verified_outlined,
                          color: Colors.lightGreen,
                          onTap: () => context.go(RouteNames.adminAiOsLeads),
                        ),
                        _KpiCard(
                          title: 'Conversion %',
                          value: '${_stats?['conversion_rate'] ?? 0}%',
                          icon: Icons.trending_up,
                          color: Colors.green,
                          onTap: () => context.go(RouteNames.adminAiOsLeads),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Marketing', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _KpiCard(
                          title: 'Messages sent',
                          value: '${_stats?['marketing_messages'] ?? 0}',
                          icon: Icons.send_outlined,
                          color: Colors.pink,
                          onTap: () => context.go(RouteNames.adminAiOsCampaigns),
                        ),
                        _KpiCard(
                          title: 'Delivery %',
                          value: '${_stats?['marketing_delivery_rate'] ?? 0}%',
                          icon: Icons.mark_email_read_outlined,
                          color: Colors.deepOrange,
                          onTap: () => context.go(RouteNames.adminAiOsCampaigns),
                        ),
                        _KpiCard(
                          title: 'Response %',
                          value: '${_stats?['marketing_response_rate'] ?? 0}%',
                          icon: Icons.reply_all,
                          color: Colors.brown,
                          onTap: () => context.go(RouteNames.adminAiOsCampaigns),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('CRM dashboard', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Tenant-scoped KPIs from contacts, leads, deals, and tickets.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _KpiCard(
                          title: 'Customers',
                          value: '${_stats?['customers_total'] ?? 0}',
                          icon: Icons.people_outline,
                          color: Colors.indigo,
                          onTap: () => context.go(RouteNames.adminAiOsCrm),
                        ),
                        _KpiCard(
                          title: 'Total Leads',
                          value: '${_stats?['leads_total'] ?? 0}',
                          icon: Icons.leaderboard_rounded,
                          color: Colors.blue,
                          onTap: () => context.go(RouteNames.adminAiOsLeads),
                        ),
                        _KpiCard(
                          title: 'Hot Leads',
                          value: '${_stats?['leads_hot'] ?? 0}',
                          icon: Icons.local_fire_department_rounded,
                          color: Colors.orange,
                          onTap: () => context.go(RouteNames.adminAiOsLeads),
                        ),
                        _KpiCard(
                          title: 'Open Deals',
                          value: '${_stats?['deals_open'] ?? 0}',
                          icon: Icons.handshake_rounded,
                          color: Colors.green,
                          onTap: () => context.go(RouteNames.adminAiOsCrm),
                        ),
                        _KpiCard(
                          title: 'Open Tickets',
                          value: '${_stats?['tickets_open'] ?? 0}',
                          icon: Icons.confirmation_number_outlined,
                          color: Colors.teal,
                          onTap: () => context.go(RouteNames.adminAiOsTickets),
                        ),
                        _KpiCard(
                          title: 'Total Deals',
                          value: '${_stats?['deals_total'] ?? 0}',
                          icon: Icons.analytics_rounded,
                          color: Colors.purple,
                          onTap: () => context.go(RouteNames.adminAiOsCrm),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
