import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../features/admin/widgets/admin_embedded_scaffold.dart';
import '../data/bos_repository.dart';
import '../domain/bos_models.dart';
import '../domain/bos_permissions.dart';

class AdminAiOsCrmScreen extends StatefulWidget {
  const AdminAiOsCrmScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminAiOsCrmScreen> createState() => _AdminAiOsCrmScreenState();
}

class _AdminAiOsCrmScreenState extends State<AdminAiOsCrmScreen>
    with SingleTickerProviderStateMixin {
  final _repo = BosRepository();
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  List<BosContact> _contacts = [];
  List<BosCompany> _companies = [];
  List<BosDeal> _deals = [];
  List<BosPipelineStage> _stages = [];
  Map<String, dynamic>? _kpis;
  bool _loading = true;
  bool _dealsPipeline = true;
  String? _contactCompanyFilter;
  bool _filterHasEmail = false;
  bool _filterHasPhone = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final q = _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim();
    final contacts = await _repo.listContacts(
      query: q,
      companyId: _contactCompanyFilter,
    );
    final companies = await _repo.listCompanies(query: q);
    final deals = await _repo.listDeals();
    final stages = await _repo.listPipelineStages();
    final kpis = await _repo.overviewStats();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _companies = companies;
        _deals = deals;
        _stages = stages;
        _kpis = kpis;
        _loading = false;
      });
    }
  }

  List<BosContact> get _filteredContacts {
    var list = _contacts;
    if (_filterHasEmail) {
      list = list.where((c) => (c.email ?? '').trim().isNotEmpty).toList();
    }
    if (_filterHasPhone) {
      list = list.where((c) => (c.phone ?? '').trim().isNotEmpty).toList();
    }
    return list;
  }

  String _contactName(String? id) {
    if (id == null || id.isEmpty) return '—';
    for (final c in _contacts) {
      if (c.id == id) return c.displayName;
    }
    return id;
  }

  String _companyName(String? id) {
    if (id == null || id.isEmpty) return '—';
    for (final co in _companies) {
      if (co.id == id) return co.name;
    }
    return id;
  }

  void _denied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permission denied for this CRM action')),
    );
  }

  Future<String?> _promptNote() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add activity note'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Note')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) return ctrl.text.trim();
    return null;
  }

  Future<void> _addContact() async {
    if (!BosPermissions.canCreate) return _denied();
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    String? companyId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('New contact'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
                DropdownButtonFormField<String?>(
                  initialValue: companyId,
                  decoration: const InputDecoration(labelText: 'Company'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._companies.map((co) => DropdownMenuItem(value: co.id, child: Text(co.name))),
                  ],
                  onChanged: (v) => setS(() => companyId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await _repo.createContact({
        'full_name': name.text.trim(),
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'company_id': companyId,
      });
      _loadData();
    }
  }

  Future<void> _addCompany() async {
    if (!BosPermissions.canCreate) return _denied();
    final name = TextEditingController();
    final industry = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: industry, decoration: const InputDecoration(labelText: 'Industry')),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await _repo.createCompany({
        'name': name.text.trim(),
        'industry': industry.text.trim().isEmpty ? null : industry.text.trim(),
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
      });
      _loadData();
    }
  }

  Future<void> _addDeal() async {
    if (!BosPermissions.canCreate) return _denied();
    final title = TextEditingController();
    final amount = TextEditingController();
    final probability = TextEditingController(text: '20');
    String stage = _stages.isNotEmpty ? _stages.first.code : 'qualification';
    String? contactId;
    String? companyId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('New deal'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (₹)'),
                  ),
                  TextField(
                    controller: probability,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Probability %'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: stage,
                    decoration: const InputDecoration(labelText: 'Stage'),
                    items: (_stages.isEmpty
                            ? [
                                BosPipelineStage(
                                  id: '',
                                  tenantId: '',
                                  code: 'qualification',
                                  label: 'Qualification',
                                  sortOrder: 1,
                                ),
                              ]
                            : _stages)
                        .map((s) => DropdownMenuItem(value: s.code, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setS(() => stage = v ?? stage),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: contactId,
                    decoration: const InputDecoration(labelText: 'Contact'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._contacts.map((c) => DropdownMenuItem(value: c.id, child: Text(c.displayName))),
                    ],
                    onChanged: (v) => setS(() => contactId = v),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: companyId,
                    decoration: const InputDecoration(labelText: 'Company'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._companies.map((co) => DropdownMenuItem(value: co.id, child: Text(co.name))),
                    ],
                    onChanged: (v) => setS(() => companyId = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      final rupees = double.tryParse(amount.text.trim()) ?? 0;
      await _repo.createDeal({
        'title': title.text.trim(),
        'stage': stage,
        'amount_paise': (rupees * 100).round(),
        'probability': int.tryParse(probability.text.trim()) ?? 0,
        'contact_id': contactId,
        'company_id': companyId,
      });
      _loadData();
    }
  }

  Future<void> _openContactProfile(BosContact c) async {
    var activities = await _repo.listContactActivities(c.id);
    final deals = await _repo.listDeals(contactId: c.id);
    final tickets = await _repo.listTicketsForContact(c.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 4,
        child: StatefulBuilder(
          builder: (c2, setS) => AlertDialog(
            title: Text(c.displayName),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Info'),
                      Tab(text: 'Activities'),
                      Tab(text: 'Deals'),
                      Tab(text: 'Tickets'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          children: [
                            ListTile(title: const Text('Email'), subtitle: Text(c.email ?? '—')),
                            ListTile(title: const Text('Phone'), subtitle: Text(c.phone ?? '—')),
                            ListTile(title: const Text('Title'), subtitle: Text(c.title ?? '—')),
                            if (BosPermissions.canEdit)
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _editContact(c);
                                },
                                child: const Text('Edit contact'),
                              ),
                            if (BosPermissions.canEdit)
                              TextButton(
                                onPressed: () async {
                                  await _repo.softDeleteContact(c.id);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadData();
                                },
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                          ],
                        ),
                        Column(
                          children: [
                            if (BosPermissions.canEdit)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () async {
                                    final note = await _promptNote();
                                    if (note == null) return;
                                    await _repo.addActivity(
                                      activityType: 'note',
                                      subject: 'Note',
                                      body: note,
                                      contactId: c.id,
                                    );
                                    activities = await _repo.listContactActivities(c.id);
                                    setS(() {});
                                  },
                                  child: const Text('Add note'),
                                ),
                              ),
                            Expanded(
                              child: ListView(
                                children: activities.isEmpty
                                    ? [const ListTile(title: Text('No activities'))]
                                    : activities
                                        .map(
                                          (a) => ListTile(
                                            dense: true,
                                            title: Text(a.subject ?? a.activityType),
                                            subtitle: Text(a.body ?? ''),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ],
                        ),
                        ListView(
                          children: deals.isEmpty
                              ? [const ListTile(title: Text('No deals'))]
                              : deals
                                  .map(
                                    (d) => ListTile(
                                      dense: true,
                                      title: Text(d.title),
                                      subtitle: Text('${d.stage} · ₹${d.amountRupees.toStringAsFixed(0)}'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _openDealProfile(d);
                                      },
                                    ),
                                  )
                                  .toList(),
                        ),
                        ListView(
                          children: tickets.isEmpty
                              ? [const ListTile(title: Text('No tickets'))]
                              : tickets
                                  .map(
                                    (t) => ListTile(
                                      dense: true,
                                      title: Text(t.subject),
                                      subtitle: Text('${t.status} · ${t.priority}'),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editContact(BosContact c) async {
    if (!BosPermissions.canEdit) return _denied();
    final name = TextEditingController(text: c.fullName ?? c.displayName);
    final email = TextEditingController(text: c.email ?? '');
    final phone = TextEditingController(text: c.phone ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.updateContact(c.id, {
        'full_name': name.text.trim(),
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
      });
      _loadData();
    }
  }

  Future<void> _openCompanyProfile(BosCompany company) async {
    final contacts = await _repo.listContacts(companyId: company.id);
    final deals = await _repo.listDeals(companyId: company.id);
    var activities = await _repo.listCompanyActivities(company.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: StatefulBuilder(
          builder: (c2, setS) => AlertDialog(
            title: Text(company.name),
            content: SizedBox(
              width: 520,
              height: 400,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Info'),
                      Tab(text: 'Contacts'),
                      Tab(text: 'Deals'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          children: [
                            ListTile(title: const Text('Industry'), subtitle: Text(company.industry ?? '—')),
                            ListTile(title: const Text('Email'), subtitle: Text(company.email ?? '—')),
                            ListTile(title: const Text('Phone'), subtitle: Text(company.phone ?? '—')),
                            ListTile(title: const Text('Website'), subtitle: Text(company.website ?? '—')),
                            const Divider(),
                            const ListTile(title: Text('Recent activities'), dense: true),
                            ...activities.take(5).map(
                                  (a) => ListTile(
                                    dense: true,
                                    title: Text(a.subject ?? a.activityType),
                                    subtitle: Text(a.body ?? ''),
                                  ),
                                ),
                            if (BosPermissions.canEdit)
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _editCompany(company);
                                },
                                child: const Text('Edit company'),
                              ),
                            if (BosPermissions.canEdit)
                              TextButton(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Delete company?'),
                                      content: Text(company.name),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await _repo.softDeleteCompany(company.id);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _loadData();
                                  }
                                },
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                          ],
                        ),
                        ListView(
                          children: contacts.isEmpty
                              ? [const ListTile(title: Text('No contacts'))]
                              : contacts
                                  .map((ct) => ListTile(dense: true, title: Text(ct.displayName), subtitle: Text(ct.email ?? '')))
                                  .toList(),
                        ),
                        ListView(
                          children: deals.isEmpty
                              ? [const ListTile(title: Text('No deals'))]
                              : deals
                                  .map(
                                    (d) => ListTile(
                                      dense: true,
                                      title: Text(d.title),
                                      subtitle: Text('${d.stage} · ${d.probability}%'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _openDealProfile(d);
                                      },
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editCompany(BosCompany company) async {
    if (!BosPermissions.canEdit) return _denied();
    final name = TextEditingController(text: company.name);
    final industry = TextEditingController(text: company.industry ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: industry, decoration: const InputDecoration(labelText: 'Industry')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await _repo.updateCompany(company.id, {
        'name': name.text.trim(),
        'industry': industry.text.trim().isEmpty ? null : industry.text.trim(),
      });
      _loadData();
    }
  }

  Future<void> _openDealProfile(BosDeal d) async {
    var deal = d;
    var activities = await _repo.listDealActivities(deal.id);
    var quotes = await _repo.listQuotations(dealId: deal.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: StatefulBuilder(
          builder: (c2, setS) => AlertDialog(
            title: Text(deal.title),
            content: SizedBox(
              width: 540,
              height: 440,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Info'),
                      Tab(text: 'Activities'),
                      Tab(text: 'Quotations'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          children: [
                            ListTile(title: const Text('Stage'), subtitle: Text(deal.stage ?? '—')),
                            ListTile(
                              title: const Text('Amount'),
                              subtitle: Text('₹${deal.amountRupees.toStringAsFixed(0)} · ${deal.probability}%'),
                            ),
                            ListTile(
                              title: const Text('Contact'),
                              subtitle: Text(_contactName(deal.contactId)),
                            ),
                            ListTile(
                              title: const Text('Company'),
                              subtitle: Text(_companyName(deal.companyId)),
                            ),
                            if (BosPermissions.canEdit) ...[
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _editDeal(deal);
                                },
                                child: const Text('Edit deal'),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  try {
                                    final qid = await _repo.createQuotationFromDeal(deal.id);
                                    quotes = await _repo.listQuotations(dealId: deal.id);
                                    activities = await _repo.listDealActivities(deal.id);
                                    setS(() {});
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Quotation created ($qid)'),
                                          action: SnackBarAction(
                                            label: 'Open quotes',
                                            onPressed: () => context.go(RouteNames.adminAiOsQuotations),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                    }
                                  }
                                },
                                icon: const Icon(Icons.request_quote),
                                label: const Text('Create quotation'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Delete deal?'),
                                      content: Text(deal.title),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    await _repo.softDeleteDeal(deal.id);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _loadData();
                                  }
                                },
                                child: const Text('Delete deal', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ],
                        ),
                        Column(
                          children: [
                            if (BosPermissions.canEdit)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () async {
                                    final note = await _promptNote();
                                    if (note == null) return;
                                    await _repo.addActivity(
                                      activityType: 'note',
                                      subject: 'Note',
                                      body: note,
                                      dealId: deal.id,
                                      contactId: deal.contactId,
                                    );
                                    activities = await _repo.listDealActivities(deal.id);
                                    setS(() {});
                                  },
                                  child: const Text('Add note'),
                                ),
                              ),
                            Expanded(
                              child: ListView(
                                children: activities.isEmpty
                                    ? [const ListTile(title: Text('No activities'))]
                                    : activities
                                        .map(
                                          (a) => ListTile(
                                            dense: true,
                                            title: Text(a.subject ?? a.activityType),
                                            subtitle: Text(a.body ?? ''),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ],
                        ),
                        ListView(
                          children: quotes.isEmpty
                              ? [const ListTile(title: Text('No quotations yet'))]
                              : quotes
                                  .map(
                                    (q) => ListTile(
                                      dense: true,
                                      title: Text(q.title ?? q.quoteNumber ?? 'Quote'),
                                      subtitle: Text('${q.quoteNumber ?? ''} · ${q.status} · ₹${(q.totalPaise / 100).toStringAsFixed(0)}'),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
    _loadData();
  }

  Future<void> _editDeal(BosDeal d) async {
    if (!BosPermissions.canEdit) return _denied();
    final title = TextEditingController(text: d.title);
    final amount = TextEditingController(text: d.amountRupees.toStringAsFixed(0));
    final probability = TextEditingController(text: '${d.probability}');
    String stage = d.stage ?? (_stages.isNotEmpty ? _stages.first.code : 'qualification');
    String? contactId = d.contactId;
    String? companyId = d.companyId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text('Edit deal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: amount, decoration: const InputDecoration(labelText: 'Amount (₹)')),
                TextField(controller: probability, decoration: const InputDecoration(labelText: 'Probability %')),
                DropdownButtonFormField<String>(
                  initialValue: stage,
                  items: _stages.map((s) => DropdownMenuItem(value: s.code, child: Text(s.label))).toList(),
                  onChanged: (v) => setS(() => stage = v ?? stage),
                  decoration: const InputDecoration(labelText: 'Stage'),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: contactId,
                  decoration: const InputDecoration(labelText: 'Contact'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._contacts.map((c) => DropdownMenuItem(value: c.id, child: Text(c.displayName))),
                  ],
                  onChanged: (v) => setS(() => contactId = v),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: companyId,
                  decoration: const InputDecoration(labelText: 'Company'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._companies.map((co) => DropdownMenuItem(value: co.id, child: Text(co.name))),
                  ],
                  onChanged: (v) => setS(() => companyId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final rupees = double.tryParse(amount.text.trim()) ?? 0;
      await _repo.updateDeal(d.id, {
        'title': title.text.trim(),
        'stage': stage,
        'amount_paise': (rupees * 100).round(),
        'probability': int.tryParse(probability.text.trim()) ?? 0,
        'contact_id': contactId,
        'company_id': companyId,
      });
      _loadData();
    }
  }

  Widget _empty(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  /// Scrollable empty state tall enough for RefreshIndicator + padded content.
  Widget _emptyScrollable(String message, IconData icon) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 280,
                child: _empty(message, icon),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _manageStages() async {
    final label = TextEditingController();
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add pipeline stage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: label, decoration: const InputDecoration(labelText: 'Label')),
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Code (optional)')),
            const SizedBox(height: 8),
            ..._stages.map(
              (s) => ListTile(
                dense: true,
                title: Text('${s.label} (${s.code})'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await _repo.deletePipelineStage(s.id);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close')),
          FilledButton(
            onPressed: () async {
              if (label.text.trim().isEmpty) return;
              final c = code.text.trim().isEmpty
                  ? label.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                  : code.text.trim();
              await _repo.upsertPipelineStage(
                code: c,
                label: label.text.trim(),
                sortOrder: _stages.length + 1,
              );
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final stageCodes = _stages.isEmpty
        ? const ['qualification', 'discovery', 'proposal', 'negotiation', 'won', 'lost']
        : _stages.map((s) => s.code).toList();

    return AdminEmbeddedScaffold(
      title: 'AI CRM',
      embedded: widget.embedded,
      floatingActionButton: BosPermissions.canCreate
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'stages',
                  onPressed: _manageStages,
                  icon: const Icon(Icons.view_timeline_outlined),
                  label: const Text('Stages'),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'add',
                  onPressed: () {
                    switch (_tabController.index) {
                      case 0:
                        _addContact();
                      case 1:
                        _addCompany();
                      default:
                        _addDeal();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MiniKpi('Customers', '${_kpis?['customers_total'] ?? (_contacts.length + _companies.length)}'),
                _MiniKpi('Leads', '${_kpis?['leads_total'] ?? 0}'),
                _MiniKpi('Open deals', '${_kpis?['deals_open'] ?? 0}'),
                _MiniKpi('Open tickets', '${_kpis?['tickets_open'] ?? 0}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search contacts & companies',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadData,
                    ),
                  ),
                  onSubmitted: (_) => _loadData(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _contactCompanyFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Contact company',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All companies')),
                          ..._companies.map(
                            (co) => DropdownMenuItem(value: co.id, child: Text(co.name, overflow: TextOverflow.ellipsis)),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _contactCompanyFilter = v);
                          _loadData();
                        },
                      ),
                    ),
                    FilterChip(
                      label: const Text('Has email'),
                      selected: _filterHasEmail,
                      onSelected: (v) => setState(() => _filterHasEmail = v),
                    ),
                    FilterChip(
                      label: const Text('Has phone'),
                      selected: _filterHasPhone,
                      onSelected: (v) => setState(() => _filterHasPhone = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Contacts'),
              Tab(text: 'Companies'),
              Tab(text: 'Deals'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildContacts(),
                      _buildCompanies(),
                      _buildDeals(stageCodes),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContacts() {
    final contacts = _filteredContacts;
    if (contacts.isEmpty) {
      return _emptyScrollable(
        'No contacts match filters. Tap Add or clear filters.',
        Icons.person_outline,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (_, i) {
          final c = contacts[i];
          return ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(c.displayName),
            subtitle: Text(
              '${c.email ?? ''} · ${c.phone ?? ''}'
              '${c.companyId != null ? ' · ${_companyName(c.companyId)}' : ''}',
            ),
            onTap: () => _openContactProfile(c),
          );
        },
      ),
    );
  }

  Widget _buildCompanies() {
    if (_companies.isEmpty) {
      return _emptyScrollable(
        'No companies yet. Tap Add to create one.',
        Icons.business,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _companies.length,
        itemBuilder: (_, i) {
          final company = _companies[i];
          return ListTile(
            leading: const Icon(Icons.business),
            title: Text(company.name),
            subtitle: Text(company.industry ?? company.website ?? ''),
            onTap: () => _openCompanyProfile(company),
          );
        },
      ),
    );
  }

  Widget _buildDeals(List<String> stageCodes) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Pipeline'), icon: Icon(Icons.view_kanban)),
                ButtonSegment(value: false, label: Text('List'), icon: Icon(Icons.list)),
              ],
              selected: {_dealsPipeline},
              onSelectionChanged: (s) => setState(() => _dealsPipeline = s.first),
            ),
          ),
        ),
        Expanded(
          child: _deals.isEmpty
              ? _empty('No deals yet. Convert a lead or tap Add.', Icons.handshake_outlined)
              : _dealsPipeline
                  ? _buildKanban(stageCodes)
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        itemCount: _deals.length,
                        itemBuilder: (_, i) {
                          final d = _deals[i];
                          return ListTile(
                            leading: const Icon(Icons.handshake_outlined),
                            title: Text(d.title),
                            subtitle: Text('${d.stage} · ₹${d.amountRupees.toStringAsFixed(0)} · ${d.probability}%'),
                            onTap: () => _openDealProfile(d),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildKanban(List<String> stageCodes) {
    String labelFor(String code) {
      for (final s in _stages) {
        if (s.code == code) return s.label;
      }
      return code;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stageCodes.map((stage) {
          final stageDeals = _deals.where((d) => d.stage == stage).toList();
          return SizedBox(
            width: 240,
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '${labelFor(stage).toUpperCase()} (${stageDeals.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...stageDeals.map(
                    (d) => ListTile(
                      dense: true,
                      title: Text(d.title),
                      subtitle: Text('₹${d.amountRupees.toStringAsFixed(0)} · ${d.probability}%'),
                      onTap: () => _openDealProfile(d),
                      onLongPress: BosPermissions.canEdit
                          ? () async {
                              final next = await showDialog<String>(
                                context: context,
                                builder: (ctx) => SimpleDialog(
                                  title: const Text('Move to stage'),
                                  children: stageCodes
                                      .map(
                                        (s) => SimpleDialogOption(
                                          onPressed: () => Navigator.pop(ctx, s),
                                          child: Text(labelFor(s)),
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                              if (next != null) {
                                await _repo.updateDealStage(d.id, next);
                                _loadData();
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

class _MiniKpi extends StatelessWidget {
  const _MiniKpi(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ],
      ),
    );
  }
}
