import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/route_names.dart';
import '../../../core/supabase/supabase_auth_service.dart';
import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';
import '../domain/bos_permissions.dart';

/// Board columns: new → contacted → qualified → converted (`won`) + lost.
const _boardStages = [
  ('new', 'New'),
  ('contacted', 'Contacted'),
  ('qualified', 'Qualified'),
  ('won', 'Converted'),
  ('lost', 'Lost'),
];

class AdminAiOsLeadsScreen extends StatefulWidget {
  const AdminAiOsLeadsScreen({super.key, this.embedded = false, this.focusLeadId});

  final bool embedded;
  final String? focusLeadId;

  @override
  State<AdminAiOsLeadsScreen> createState() => _AdminAiOsLeadsScreenState();
}

class _AdminAiOsLeadsScreenState extends State<AdminAiOsLeadsScreen> {
  final _repo = BosRepository();
  List<BosLead> _leads = [];
  List<BosTenantMember> _members = [];
  bool _loading = true;
  String? _filterStage;
  String? _filterScore;
  String? _filterSource; // voice_inbound | inbox | campaign | null=all
  bool _boardView = true;
  bool _overdueOnly = false;
  bool _aiQueueOnly = false;
  bool _openedFocusLead = false;

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    setState(() => _loading = true);
    var leads = await _repo.listLeads(stage: _filterStage, score: _filterScore);
    if (_overdueOnly) {
      final now = DateTime.now();
      leads = leads
          .where(
            (l) =>
                l.nextFollowUpAt != null &&
                l.nextFollowUpAt!.isBefore(now) &&
                l.stage != 'won' &&
                l.stage != 'lost',
          )
          .toList();
    }
    if (_aiQueueOnly) {
      leads = leads
          .where(
            (l) =>
                (l.handoverReady || l.score == 'hot') &&
                l.stage != 'won' &&
                l.stage != 'lost',
          )
          .toList();
    }
    if (_filterSource != null) {
      leads = leads.where((l) => _matchesSourceFilter(l.source, _filterSource!)).toList();
    }
    final tid = await _repo.activeTenantId;
    final members = await _repo.listMembers(tid);
    if (mounted) {
      setState(() {
        _leads = leads;
        _members = members;
        _loading = false;
      });
      if (!_openedFocusLead &&
          widget.focusLeadId != null &&
          widget.focusLeadId!.isNotEmpty) {
        _openedFocusLead = true;
        BosLead? match;
        for (final l in leads) {
          if (l.id == widget.focusLeadId) {
            match = l;
            break;
          }
        }
        if (match == null) {
          try {
            final all = await _repo.listLeads();
            for (final l in all) {
              if (l.id == widget.focusLeadId) {
                match = l;
                break;
              }
            }
          } catch (_) {}
        }
        if (match != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showLeadDetail(match!);
          });
        }
      }
    }
  }

  bool _matchesSourceFilter(String? source, String filter) {
    final s = (source ?? '').toLowerCase().trim();
    switch (filter) {
      case 'voice_inbound':
        return s == 'voice_inbound' || s.startsWith('voice_');
      case 'inbox':
        return s.startsWith('inbox_') || s == 'whatsapp' || s == 'web' || s == 'app';
      case 'campaign':
        return s == 'campaign' || s.startsWith('campaign_') || s.contains('campaign');
      default:
        return true;
    }
  }

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permission denied')),
    );
  }

  Future<void> _showAddLeadDialog() async {
    if (!BosPermissions.canCreate) return _denied();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => const _AddLeadDialog(),
    );
    if (result != null) {
      try {
        await _repo.createLead(result);
        _loadLeads();
      } catch (e) {
        if (!mounted) return;
        final msg = '$e';
        if (msg.contains('duplicate')) {
          final force = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Possible duplicate'),
              content: Text(msg),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Create anyway'),
                ),
              ],
            ),
          );
          if (force == true) {
            await _repo.createLead({...result, 'allow_duplicate': true});
            _loadLeads();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    }
  }

  Future<void> _mergeSelected(BosLead keep) async {
    final others = _leads.where((l) => l.id != keep.id).take(20).toList();
    if (others.isEmpty) return;
    BosLead? merge;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text('Merge into ${keep.displayName}'),
          content: SizedBox(
            width: 360,
            height: 280,
            child: ListView(
              children: others
                  .map(
                    (l) => ListTile(
                      selected: merge?.id == l.id,
                      title: Text(l.displayName),
                      subtitle: Text('${l.phone ?? ''} ${l.email ?? ''}'),
                      onTap: () => setS(() => merge = l),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Merge')),
          ],
        ),
      ),
    );
    if (ok == true && merge != null) {
      await _repo.mergeLeads(keepId: keep.id, mergeId: merge!.id);
      _loadLeads();
    }
  }

  Future<void> _showImportCsvDialog() async {
    if (!BosPermissions.canCreate) return _denied();
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Import Leads CSV'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Paste CSV',
              hintText: 'full_name,email,phone,company_name,requirements',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Import')),
        ],
      ),
    );
    if (confirmed == true && controller.text.isNotEmpty) {
      final lines = controller.text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final result = await _repo.importLeadsCsv(lines);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${result.imported}, skipped ${result.skipped} duplicates')),
        );
      }
      _loadLeads();
    }
  }

  Future<void> _showLeadDetail(BosLead lead) async {
    await showDialog(
      context: context,
      builder: (c) => _LeadDetailDialog(lead: lead, repo: _repo, members: _members),
    );
    _loadLeads();
  }

  Color _scoreColor(String? score) {
    switch (score) {
      case 'hot':
        return Colors.orange;
      case 'warm':
        return Colors.blue;
      case 'cold':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminEmbeddedScaffold(
      title: 'Leads',
      embedded: widget.embedded,
      floatingActionButton: BosPermissions.canCreate
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'import',
                  onPressed: _showImportCsvDialog,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import CSV'),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.extended(
                  heroTag: 'add',
                  onPressed: _showAddLeadDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Lead'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Board'), icon: Icon(Icons.view_kanban)),
                      ButtonSegment(value: false, label: Text('List'), icon: Icon(Icons.list)),
                    ],
                    selected: {_boardView},
                    onSelectionChanged: (s) => setState(() => _boardView = s.first),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String?>(
                    value: _filterStage,
                    hint: const Text('Stage'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All stages')),
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
                      DropdownMenuItem(value: 'qualified', child: Text('Qualified')),
                      DropdownMenuItem(value: 'proposal', child: Text('Proposal')),
                      DropdownMenuItem(value: 'won', child: Text('Converted')),
                      DropdownMenuItem(value: 'lost', child: Text('Lost')),
                    ],
                    onChanged: (v) {
                      setState(() => _filterStage = v);
                      _loadLeads();
                    },
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String?>(
                    value: _filterScore,
                    hint: const Text('Score'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All scores')),
                      DropdownMenuItem(value: 'hot', child: Text('Hot')),
                      DropdownMenuItem(value: 'warm', child: Text('Warm')),
                      DropdownMenuItem(value: 'cold', child: Text('Cold')),
                    ],
                    onChanged: (v) {
                      setState(() => _filterScore = v);
                      _loadLeads();
                    },
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String?>(
                    value: _filterSource,
                    hint: const Text('Source'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All sources')),
                      DropdownMenuItem(value: 'voice_inbound', child: Text('Voice inbound')),
                      DropdownMenuItem(value: 'inbox', child: Text('Inbox / chat')),
                      DropdownMenuItem(value: 'campaign', child: Text('Campaign')),
                    ],
                    onChanged: (v) {
                      setState(() => _filterSource = v);
                      _loadLeads();
                    },
                  ),
                  const SizedBox(width: 16),
                  FilterChip(
                    label: const Text('Overdue follow-ups'),
                    selected: _overdueOnly,
                    onSelected: (v) {
                      setState(() => _overdueOnly = v);
                      _loadLeads();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('AI Queue'),
                    selected: _aiQueueOnly,
                    avatar: const Icon(Icons.smart_toy_outlined, size: 18),
                    onSelected: (v) {
                      setState(() => _aiQueueOnly = v);
                      _loadLeads();
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      try {
                        final r = await _repo.runSalesFollowups();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Follow-ups processed: ${r['processed'] ?? 0}')),
                          );
                        }
                        _loadLeads();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
                    child: const Text('Run AI follow-ups'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _boardView
                    ? _buildBoard()
                    : RefreshIndicator(
                        onRefresh: _loadLeads,
                        child: ListView.builder(
                          itemCount: _leads.length,
                          itemBuilder: (c, i) {
                            final lead = _leads[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _scoreColor(lead.score),
                                child: Text(
                                  (lead.score ?? '?').substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                          title: Text(lead.displayName),
                          subtitle: Text(
                            '${lead.email ?? ''} · ${lead.companyName ?? 'No company'}'
                            '${lead.nextFollowUpAt != null ? ' · FU ${lead.nextFollowUpAt!.toLocal().toString().substring(0, 16)}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (lead.nextFollowUpAt != null &&
                                  lead.nextFollowUpAt!.isBefore(DateTime.now()))
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: Text('Overdue'),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Color(0xFFFFE0E0),
                                  ),
                                ),
                              Chip(
                                label: Text(
                                  lead.stage == 'won' ? 'converted' : (lead.stage ?? 'new'),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Merge duplicates',
                                icon: const Icon(Icons.merge_type),
                                onPressed: () => _mergeSelected(lead),
                              ),
                            ],
                          ),
                          onTap: () => _showLeadDetail(lead),
                        );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _boardStages.map((col) {
          final stageLeads = _leads.where((l) {
            final s = l.stage ?? 'new';
            if (col.$1 == 'won') return s == 'won';
            if (col.$1 == 'qualified') {
              return s == 'qualified' || s == 'proposal' || s == 'negotiation';
            }
            return s == col.$1;
          }).toList();
          return SizedBox(
            width: 260,
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${col.$2} (${stageLeads.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...stageLeads.map(
                    (lead) => ListTile(
                      dense: true,
                      title: Text(lead.displayName),
                      subtitle: Text(lead.companyName ?? lead.email ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.merge_type, size: 18),
                        onPressed: () => _mergeSelected(lead),
                      ),
                      onTap: () => _showLeadDetail(lead),
                      onLongPress: BosPermissions.canEdit
                          ? () async {
                              final next = await showDialog<String>(
                                context: context,
                                builder: (ctx) => SimpleDialog(
                                  title: const Text('Move stage'),
                                  children: _boardStages
                                      .map(
                                        (s) => SimpleDialogOption(
                                          onPressed: () => Navigator.pop(ctx, s.$1),
                                          child: Text(s.$2),
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                              if (next != null) {
                                await _repo.updateLead(lead.id, {'stage': next});
                                _loadLeads();
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AddLeadDialog extends StatefulWidget {
  const _AddLeadDialog();

  @override
  State<_AddLeadDialog> createState() => _AddLeadDialogState();
}

class _AddLeadDialogState extends State<_AddLeadDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _requirementsCtrl = TextEditingController();
  String _source = 'manual';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _requirementsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Lead'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: _companyCtrl, decoration: const InputDecoration(labelText: 'Company')),
              DropdownButtonFormField<String>(
                initialValue: _source,
                decoration: const InputDecoration(labelText: 'Source'),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('Manual')),
                  DropdownMenuItem(value: 'website', child: Text('Website')),
                  DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                  DropdownMenuItem(value: 'facebook', child: Text('Facebook')),
                  DropdownMenuItem(value: 'google', child: Text('Google')),
                  DropdownMenuItem(value: 'api', child: Text('API')),
                  DropdownMenuItem(value: 'csv', child: Text('CSV')),
                ],
                onChanged: (v) => setState(() => _source = v ?? 'manual'),
              ),
              TextField(
                controller: _requirementsCtrl,
                decoration: const InputDecoration(labelText: 'Requirements'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'full_name': _nameCtrl.text.trim(),
              'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
              'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
              'company_name': _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
              'requirements': _requirementsCtrl.text.trim().isEmpty ? null : _requirementsCtrl.text.trim(),
              'source': _source,
              'stage': 'new',
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _LeadDetailDialog extends StatefulWidget {
  const _LeadDetailDialog({
    required this.lead,
    required this.repo,
    required this.members,
  });

  final BosLead lead;
  final BosRepository repo;
  final List<BosTenantMember> members;

  @override
  State<_LeadDetailDialog> createState() => _LeadDetailDialogState();
}

class _LeadDetailDialogState extends State<_LeadDetailDialog> {
  bool _busy = false;
  String? _aiResult;
  List<BosActivity> _activities = [];
  late bool _doNotCall;

  @override
  void initState() {
    super.initState();
    _doNotCall = widget.lead.doNotCall;
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final list = await widget.repo.listLeadActivities(widget.lead.id);
    if (mounted) setState(() => _activities = list);
  }

  Future<void> _qualifyWithAi() async {
    if (!BosPermissions.canEdit) return;
    setState(() => _busy = true);
    try {
      final token = SupabaseAuthService.instance.accessToken;
      final response = await http.post(
        Uri.parse(widget.repo.aiQualifyLeadUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lead_id': widget.lead.id,
          'full_name': widget.lead.fullName,
          'email': widget.lead.email,
          'phone': widget.lead.phone,
          'company_name': widget.lead.companyName,
          'requirements': widget.lead.requirements,
        }),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        await widget.repo.updateLead(widget.lead.id, {
          'score': result['score'],
          'ai_summary': result['summary'],
          'ai_next_questions': result['questions'] ?? [],
          'stage': 'qualified',
        });
        await widget.repo.addLeadActivity(
          leadId: widget.lead.id,
          activityType: 'ai_qualify',
          subject: 'AI qualification',
          body: result['summary'] as String?,
        );
        setState(() => _aiResult = 'Score: ${result['score']}\n${result['summary']}');
        _loadActivities();
      } else {
        setState(() => _aiResult = 'Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      setState(() => _aiResult = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _convert({required bool withDeal}) async {
    if (!BosPermissions.canConvert) return;
    setState(() => _busy = true);
    try {
      await widget.repo.convertLead(
        leadId: widget.lead.id,
        dealTitle: '${widget.lead.displayName} deal',
        createDeal: withDeal,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign() async {
    if (!BosPermissions.canAssign) return;
    String? uid = widget.lead.ownerFirebaseUid;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Assign lead'),
          content: DropdownButtonFormField<String?>(
            initialValue: uid,
            items: [
              const DropdownMenuItem(value: null, child: Text('Unassigned')),
              ...widget.members.map(
                (m) => DropdownMenuItem(
                  value: m.firebaseUid,
                  child: Text(m.displayName ?? m.firebaseUid),
                ),
              ),
            ],
            onChanged: (v) => setS(() => uid = v),
            decoration: const InputDecoration(labelText: 'Assignee'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign')),
          ],
        ),
      ),
    );
    if (ok == true && uid != null) {
      await widget.repo.assignLead(leadId: widget.lead.id, assigneeFirebaseUid: uid!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead assigned')));
      }
    }
  }

  Future<void> _addNote() async {
    if (!BosPermissions.canEdit) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add note'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Note')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await widget.repo.addLeadActivity(
        leadId: widget.lead.id,
        activityType: 'note',
        subject: 'Note',
        body: ctrl.text.trim(),
      );
      _loadActivities();
    }
  }

  Future<void> _setFollowUp() async {
    if (!BosPermissions.canEdit) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.lead.nextFollowUpAt ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.lead.nextFollowUpAt ?? now.add(const Duration(hours: 1))),
    );
    if (!mounted) return;
    final when = DateTime(
      picked.year,
      picked.month,
      picked.day,
      time?.hour ?? 10,
      time?.minute ?? 0,
    );
    await widget.repo.setLeadFollowUp(widget.lead.id, when);
    await _loadActivities();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Follow-up set for ${when.toLocal()}')),
      );
    }
  }

  Future<void> _queueAiCall() async {
    if (!BosPermissions.canCreate) return;
    if ((widget.lead.phone ?? '').trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead needs a phone number to queue a call')),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      String? script;
      try {
        script = await widget.repo.generateVoiceScript(widget.lead.id);
      } catch (_) {}
      if (!mounted) return;
      final ctrl = TextEditingController(text: script ?? '');
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Queue AI call'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Script', border: OutlineInputBorder()),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Queue')),
          ],
        ),
      );
      if (confirm != true) return;
      await widget.repo.queueFollowUpCall(
        leadId: widget.lead.id,
        generateScript: false,
        scriptOverride: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
        scheduledAt: widget.lead.nextFollowUpAt ?? DateTime.now(),
      );
      await _loadActivities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI call queued — open AI Voice to complete')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.lead.displayName),
      content: SizedBox(
        width: 520,
        height: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${widget.lead.email ?? 'N/A'}'),
              Text('Phone: ${widget.lead.phone ?? 'N/A'}'),
              Text('Company: ${widget.lead.companyName ?? 'N/A'}'),
              Text('Source: ${widget.lead.source ?? 'manual'}'),
              Text(
                'Stage: ${widget.lead.stage == 'won' ? 'converted' : (widget.lead.stage ?? 'new')}',
              ),
              Text('Score: ${widget.lead.score ?? 'Not scored'}'),
              Text('Owner: ${widget.lead.ownerFirebaseUid ?? 'Unassigned'}'),
              Text(
                'Follow-up: ${widget.lead.nextFollowUpAt?.toLocal().toString().substring(0, 16) ?? 'Not set'}',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Do not call'),
                subtitle: Text(
                  _doNotCall
                      ? 'Missed-call auto-callbacks skipped for this lead'
                      : 'Allow auto-callback on missed inbound',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _doNotCall,
                onChanged: !BosPermissions.canEdit || _busy
                    ? null
                    : (v) async {
                        setState(() {
                          _doNotCall = v;
                          _busy = true;
                        });
                        try {
                          await widget.repo.setLeadDoNotCall(widget.lead.id, v);
                          await _loadActivities();
                        } catch (e) {
                          if (mounted) {
                            setState(() => _doNotCall = !v);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
              ),
              if (widget.lead.requirements != null) ...[
                const SizedBox(height: 12),
                const Text('Requirements', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.lead.requirements!),
              ],
              const SizedBox(height: 12),
              Card(
                color: widget.lead.handoverReady ? const Color(0xFFFFF7ED) : const Color(0xFFF0F9FF),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.smart_toy_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            widget.lead.handoverReady ? 'AI · Handover ready' : 'AI Sales summary',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(widget.lead.aiSummary ?? 'Not qualified yet — run AI agent.'),
                      if (widget.lead.intent != null) Text('Intent: ${widget.lead.intent}'),
                      if (widget.lead.meta?['last_channel'] != null)
                        Text('Last channel: ${widget.lead.meta!['last_channel']}'),
                      if (widget.lead.aiRecommendation != null)
                        Text('Recommendation: ${widget.lead.aiRecommendation}'),
                      if (widget.lead.aiNextQuestions != null && widget.lead.aiNextQuestions!.isNotEmpty)
                        Text('Next Q: ${widget.lead.aiNextQuestions!.take(2).join(' · ')}'),
                    ],
                  ),
                ),
              ),
              if (_aiResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.green.shade50,
                  child: Text(_aiResult!),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Activities', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (BosPermissions.canEdit)
                    TextButton(onPressed: _addNote, child: const Text('Add note')),
                ],
              ),
              ..._activities.map(
                (a) => ListTile(
                  dense: true,
                  leading: a.activityType == 'voice_callback_skipped'
                      ? const Icon(Icons.phone_disabled, size: 18, color: Colors.orange)
                      : a.activityType == 'dnd_on'
                          ? const Icon(Icons.do_not_disturb_on, size: 18, color: Colors.orange)
                          : a.linksToVoiceCall
                              ? const Icon(Icons.phone_in_talk, size: 18, color: Colors.teal)
                              : null,
                  title: Text(a.subject ?? a.activityType),
                  subtitle: Text(
                    a.voiceCallId != null
                        ? '${a.body ?? ''}${a.body != null && a.body!.isNotEmpty ? '\n' : ''}Open Voice · Reschedule'
                        : (a.body ?? ''),
                  ),
                  trailing: a.voiceCallId == null
                      ? null
                      : PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (v) async {
                            if (v == 'open') {
                              Navigator.pop(context);
                              context.go(
                                '${RouteNames.adminAiOsVoice}?call=${a.voiceCallId}',
                              );
                              return;
                            }
                            if (v == 'reschedule') {
                              final choice = await showDialog<String>(
                                context: context,
                                builder: (ctx) => SimpleDialog(
                                  title: const Text('Reschedule callback'),
                                  children: [
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(ctx, '+1h'),
                                      child: const Text('+1 hour'),
                                    ),
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(ctx, 'tomorrow'),
                                      child: const Text('Tomorrow 10:00'),
                                    ),
                                    SimpleDialogOption(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                  ],
                                ),
                              );
                              if (choice == null || !mounted) return;
                              final now = DateTime.now();
                              final when = choice == '+1h'
                                  ? now.add(const Duration(hours: 1))
                                  : () {
                                      final t = now.add(const Duration(days: 1));
                                      return DateTime(t.year, t.month, t.day, 10);
                                    }();
                              try {
                                await widget.repo.rescheduleVoiceCall(a.voiceCallId!, when);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Rescheduled · ${when.toLocal().toString().substring(0, 16)}',
                                      ),
                                    ),
                                  );
                                }
                                await _loadActivities();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'open', child: Text('Open Voice call')),
                            PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
                          ],
                        ),
                  onTap: a.voiceCallId == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          context.go(
                            '${RouteNames.adminAiOsVoice}?call=${a.voiceCallId}',
                          );
                        },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        if (!_busy) ...[
          if (BosPermissions.canEdit)
            TextButton(
              onPressed: () async {
                setState(() => _busy = true);
                try {
                  final r = await widget.repo.orchestrateLead(widget.lead.id);
                  setState(() => _aiResult = 'AI agent: ${(r['actions'] as List?)?.join(', ') ?? 'ok'} · ${r['score']}');
                  await _loadActivities();
                } catch (e) {
                  setState(() => _aiResult = '$e');
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
              child: const Text('Run AI agent'),
            ),
          if (BosPermissions.canEdit)
            TextButton(onPressed: _setFollowUp, child: const Text('Follow-up')),
          if (BosPermissions.canCreate)
            TextButton(onPressed: _queueAiCall, child: const Text('Queue AI call')),
          if (BosPermissions.canAssign)
            TextButton(onPressed: _assign, child: const Text('Assign')),
          if (BosPermissions.canAssign)
            TextButton(
              onPressed: () async {
                final uid = SupabaseAuthService.instance.accessToken != null
                    ? SupabaseAuthService.jwtClaim(
                        SupabaseAuthService.instance.accessToken,
                        'sub',
                      )
                    : null;
                if (uid == null || uid.isEmpty) return;
                await widget.repo.assignLead(leadId: widget.lead.id, assigneeFirebaseUid: uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assigned to you')),
                  );
                }
              },
              child: const Text('Assign to me'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final choice = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Add attachment'),
                    content: const Text('Upload a file to storage, or paste an external URL.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, 'link'), child: const Text('URL link')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, 'file'), child: const Text('Upload file')),
                    ],
                  ),
                );
                if (choice == null || !mounted) return;
                if (choice == 'link') {
                  final url = TextEditingController(text: 'https://');
                  final name = TextEditingController(text: 'attachment.pdf');
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Add attachment link'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: name, decoration: const InputDecoration(labelText: 'Filename')),
                          TextField(controller: url, decoration: const InputDecoration(labelText: 'URL')),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await widget.repo.registerAttachmentLink(
                      filename: name.text.trim(),
                      url: url.text.trim(),
                      leadId: widget.lead.id,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Attachment link saved')),
                      );
                    }
                  }
                  return;
                }
                final picked = await FilePicker.platform.pickFiles(
                  withData: true,
                  type: FileType.any,
                );
                if (picked == null || picked.files.isEmpty) return;
                final file = picked.files.first;
                final bytes = file.bytes;
                if (bytes == null || bytes.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not read file bytes')),
                    );
                  }
                  return;
                }
                try {
                  await widget.repo.uploadAttachment(
                    bytes: bytes,
                    filename: file.name,
                    mimeType: file.extension != null ? null : 'application/octet-stream',
                    leadId: widget.lead.id,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Uploaded ${file.name}')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('Add attachment'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // parent merge via callback — open from list
                Navigator.pop(context);
              },
              icon: const Icon(Icons.merge_type),
              label: const Text('Close (use Merge from list)'),
            ),
          if (BosPermissions.canConvert) ...[
            TextButton(onPressed: () => _convert(withDeal: false), child: const Text('To customer')),
            TextButton(onPressed: () => _convert(withDeal: true), child: const Text('To deal')),
          ],
          if (BosPermissions.canEdit)
            FilledButton.icon(
              onPressed: _qualifyWithAi,
              icon: const Icon(Icons.psychology),
              label: const Text('AI Qualify'),
            ),
        ] else
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }
}
