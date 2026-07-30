import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_auth_service.dart';
import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';

class AdminAiOsReportsScreen extends StatefulWidget {
  const AdminAiOsReportsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsReportsScreen> createState() => _AdminAiOsReportsScreenState();
}

class _AdminAiOsReportsScreenState extends State<AdminAiOsReportsScreen> {
  final _repo = BosRepository();
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  bool get _isSuperadmin => SupabaseAuthService.instance.currentJwtIsSuperadmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await _repo.fullAnalytics();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final byStage = (_stats['leads_by_stage'] as Map?)?.cast<String, dynamic>() ?? {};
    final quoteValue = ((_stats['quotation_value_paise'] as num?) ?? 0) / 100;
    final usage = (_stats['usage_30d'] as Map?)?.cast<String, dynamic>() ?? {};
    final delivery = (_stats['delivery_breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    final platform = (_stats['platform'] as Map?)?.cast<String, dynamic>();
    final maxStage = byStage.values.fold<num>(0, (a, b) {
      final n = b is num ? b : num.tryParse('$b') ?? 0;
      return n > a ? n : a;
    });

    return AdminEmbeddedScaffold(
      title: 'Reports & Analytics',
      embedded: widget.embedded,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Operations dashboard', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _kpi('Leads', '${_stats['leads_total'] ?? 0}', Icons.leaderboard, Colors.blue),
                      _kpi('Hot', '${_stats['leads_hot'] ?? 0}', Icons.local_fire_department, Colors.orange),
                      _kpi('Open deals', '${_stats['deals_open'] ?? 0}', Icons.handshake, Colors.green),
                      _kpi('Open tickets', '${_stats['tickets_open'] ?? 0}', Icons.confirmation_number, Colors.red),
                      _kpi('Active projects', '${_stats['projects_active'] ?? 0}', Icons.engineering, Colors.teal),
                      _kpi('Campaign sends', '${_stats['campaign_sends'] ?? 0}', Icons.campaign, Colors.purple),
                      _kpi('Campaign failed', '${_stats['campaign_failed'] ?? 0}', Icons.error_outline, Colors.deepOrange),
                      _kpi('Quote value', '₹${quoteValue.toStringAsFixed(0)}', Icons.request_quote, Colors.indigo),
                      _kpi('Delivery %', '${_stats['marketing_delivery_rate'] ?? 0}%', Icons.mark_email_read, Colors.cyan),
                      _kpi('Response %', '${_stats['marketing_response_rate'] ?? 0}%', Icons.reply_all, Colors.brown),
                      _kpi('AI chats', '${_stats['ai_conversations'] ?? 0}', Icons.chat, Colors.blueGrey),
                      _kpi('Conversion', '${_stats['conversion_rate'] ?? 0}%', Icons.trending_up, Colors.green),
                      _kpi('Voice total', '${_stats['voice_total'] ?? 0}', Icons.phone, Colors.teal),
                      _kpi('Voice live', '${_stats['voice_live'] ?? 0}', Icons.phone_in_talk, Colors.green),
                      _kpi('Voice stub', '${_stats['voice_stub'] ?? 0}', Icons.phone_paused, Colors.orange),
                      _kpi('STT live', '${_stats['voice_stt_live'] ?? 0}', Icons.hearing, Colors.deepPurple),
                      _kpi('Inbound', '${_stats['voice_inbound'] ?? 0}', Icons.call_received, Colors.indigo),
                      _kpi('Avg duration', '${_stats['voice_avg_duration_sec'] ?? 0}s', Icons.timer, Colors.brown),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Lead funnel by stage', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (byStage.isEmpty)
                    const Text('No lead stage data')
                  else
                    ...byStage.entries.map((e) {
                      final n = e.value is num ? (e.value as num).toDouble() : double.tryParse('${e.value}') ?? 0;
                      final pct = maxStage <= 0 ? 0.0 : n / maxStage.toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(e.key)),
                                Text('${e.value}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  const Text('Usage (30 days)', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (usage.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No usage events yet'),
                    )
                  else
                    ...usage.entries.map(
                      (e) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.speed, size: 20),
                        title: Text(e.key),
                        trailing: Text('${e.value}'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Marketing delivery breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (delivery.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No campaign recipients yet'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: delivery.entries
                          .map(
                            (e) => Chip(
                              label: Text('${e.key}: ${e.value}'),
                            ),
                          )
                          .toList(),
                    ),
                  if (_isSuperadmin && platform != null) ...[
                    const SizedBox(height: 24),
                    Text('Super Admin platform', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _kpi('Companies', '${platform['companies_total'] ?? 0}', Icons.business, Colors.indigo),
                        _kpi('MRR', '${platform['mrr_paise'] != null ? '₹${((platform['mrr_paise'] as num) / 100).toStringAsFixed(0)}' : '—'}', Icons.currency_rupee, Colors.green),
                        _kpi('AI msgs 30d', '${platform['usage_ai_messages_30d'] ?? 0}', Icons.psychology, Colors.deepPurple),
                        _kpi('Voice 30d', '${platform['usage_voice_minutes_30d'] ?? 0}', Icons.phone, Colors.teal),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
