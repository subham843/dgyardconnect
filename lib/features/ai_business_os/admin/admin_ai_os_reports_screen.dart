import 'package:flutter/material.dart';

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
                      _kpi('Quote value', '₹${quoteValue.toStringAsFixed(0)}', Icons.request_quote, Colors.indigo),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Lead funnel by stage', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...byStage.entries.map(
                    (e) => ListTile(
                      title: Text(e.key),
                      trailing: Text('${e.value}'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
