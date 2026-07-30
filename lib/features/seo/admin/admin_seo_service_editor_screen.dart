import 'package:flutter/material.dart';

import '../../shop/data/supabase_repository_base.dart';
import '../data/seo_admin_repository.dart';
import '../domain/seo_city.dart';
import '../domain/seo_service.dart';
import 'widgets/seo_faq_editor.dart';
import 'widgets/seo_image_url_field.dart';

class AdminSeoServiceEditorScreen extends StatefulWidget {
  const AdminSeoServiceEditorScreen({super.key, this.serviceId});

  /// `null` = create new service.
  final String? serviceId;

  @override
  State<AdminSeoServiceEditorScreen> createState() => _AdminSeoServiceEditorScreenState();
}

class _AdminSeoServiceEditorScreenState extends State<AdminSeoServiceEditorScreen> {
  final _repo = SeoAdminRepository();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _sortOrder = TextEditingController(text: '100');
  final _shortDesc = TextEditingController();
  final _description = TextEditingController();
  final _pricingCta = TextEditingController(text: 'Get a free quote');
  final _features = TextEditingController();
  final _whyChoose = TextEditingController();
  final _relatedSlugs = TextEditingController();
  final _areasTemplate = TextEditingController();
  final _heroImage = TextEditingController();
  final _seoTitleTpl = TextEditingController();
  final _metaDescTpl = TextEditingController();
  final _h1Tpl = TextEditingController();
  final _h2Tpl = TextEditingController();
  final _schemaType = TextEditingController();

  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  List<SeoFaqItem> _faq = [];
  List<SeoProcessStep> _processSteps = [];
  List<SeoCity> _allCities = [];
  final Set<String> _selectedCityIds = {};

  bool get _isCreate => widget.serviceId == null;

  @override
  void initState() {
    super.initState();
    if (_isCreate) _name.addListener(_autoSlug);
    _load();
  }

  void _autoSlug() {
    if (!_isCreate) return;
    _slug.text = SupabaseRepositoryBase.slugify(_name.text);
  }

  Future<void> _load() async {
    _allCities = await _repo.listCities();
    if (!_isCreate) {
      final s = await _repo.getService(widget.serviceId!);
      if (s != null) {
        _name.text = s.name;
        _slug.text = s.slug;
        _sortOrder.text = s.sortOrder.toString();
        _shortDesc.text = s.shortDescription ?? '';
        _description.text = s.description ?? '';
        _pricingCta.text = s.pricingCtaText;
        _features.text = s.features.join('\n');
        _whyChoose.text = s.whyChoose.join('\n');
        _relatedSlugs.text = s.relatedProductCategorySlugs.join(', ');
        _areasTemplate.text = s.areasCoveredTemplate ?? '';
        _heroImage.text = s.heroImageUrl ?? '';
        _seoTitleTpl.text = s.seoTitleTemplate ?? '';
        _metaDescTpl.text = s.metaDescriptionTemplate ?? '';
        _h1Tpl.text = s.h1Template ?? '';
        _h2Tpl.text = s.h2FeaturesTemplate ?? '';
        _schemaType.text = s.schemaServiceType ?? '';
        _isActive = s.isActive;
        _faq = List<SeoFaqItem>.from(s.faqTemplate);
        _processSteps = List<SeoProcessStep>.from(s.processSteps);
        _selectedCityIds.addAll(await _repo.listCityIdsForService(s.id));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _name, _slug, _sortOrder, _shortDesc, _description, _pricingCta, _features, _whyChoose,
      _relatedSlugs, _areasTemplate, _heroImage, _seoTitleTpl, _metaDescTpl,
      _h1Tpl, _h2Tpl, _schemaType,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(TextEditingController c) =>
      c.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _slug.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and slug are required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final existing = _isCreate ? null : await _repo.getService(widget.serviceId!);
      final service = SeoService(
        id: existing?.id ?? '',
        name: _name.text.trim(),
        slug: _slug.text.trim(),
        shortDescription: _shortDesc.text.trim().isEmpty ? null : _shortDesc.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        heroImageUrl: _heroImage.text.trim().isEmpty ? null : _heroImage.text.trim(),
        iconName: existing?.iconName ?? 'build_rounded',
        features: _lines(_features),
        processSteps: _processSteps.where((s) => s.title.trim().isNotEmpty).toList(),
        whyChoose: _lines(_whyChoose),
        areasCoveredTemplate: _areasTemplate.text.trim().isEmpty ? null : _areasTemplate.text.trim(),
        pricingCtaText: _pricingCta.text.trim(),
        relatedProductCategorySlugs: _relatedSlugs.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        sortOrder: int.tryParse(_sortOrder.text.trim()) ?? existing?.sortOrder ?? 100,
        isActive: _isActive,
        seoTitleTemplate: _seoTitleTpl.text.trim().isEmpty ? null : _seoTitleTpl.text.trim(),
        metaDescriptionTemplate: _metaDescTpl.text.trim().isEmpty ? null : _metaDescTpl.text.trim(),
        h1Template: _h1Tpl.text.trim().isEmpty ? null : _h1Tpl.text.trim(),
        h2FeaturesTemplate: _h2Tpl.text.trim().isEmpty ? null : _h2Tpl.text.trim(),
        faqTemplate: _faq.where((f) => f.question.trim().isNotEmpty).toList(),
        schemaServiceType: _schemaType.text.trim().isEmpty ? null : _schemaType.text.trim(),
      );

      final savedId = await _repo.upsertService(service, id: _isCreate ? null : widget.serviceId);
      if (savedId == null) throw Exception('Could not save service');

      await _repo.setCitiesForService(savedId, _selectedCityIds.toList());

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addProcessStep() {
    setState(() => _processSteps.add(const SeoProcessStep(title: '', description: '')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? 'Add SEO Service' : 'Edit SEO Service'),
        actions: [TextButton(onPressed: _saving ? null : _save, child: const Text('Save'))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(controller: _slug, decoration: const InputDecoration(labelText: 'Slug *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sortOrder,
                  decoration: const InputDecoration(labelText: 'Sort order', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _shortDesc, decoration: const InputDecoration(labelText: 'Short description', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 4),
                const SizedBox(height: 12),
                TextFormField(controller: _pricingCta, decoration: const InputDecoration(labelText: 'Pricing CTA', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                SeoImageUrlField(label: 'Hero image URL', controller: _heroImage),
                const SizedBox(height: 16),
                _section('Available in cities'),
                Text(
                  'Only selected cities appear in the navbar menu for this service.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (_allCities.isEmpty)
                  const Text('Add cities first under SEO Cities.')
                else
                  for (final city in _allCities)
                    CheckboxListTile(
                      title: Text('${city.name}, ${city.state}'),
                      subtitle: Text('/${city.slug}'),
                      value: _selectedCityIds.contains(city.id),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedCityIds.add(city.id);
                          } else {
                            _selectedCityIds.remove(city.id);
                          }
                        });
                      },
                    ),
                const SizedBox(height: 16),
                const Text('Features (one per line)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(controller: _features, maxLines: 6, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 12),
                const Text('Why choose (one per line)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(controller: _whyChoose, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _relatedSlugs,
                  decoration: const InputDecoration(
                    labelText: 'Related store category slugs',
                    border: OutlineInputBorder(),
                    helperText: 'Comma-separated — links to /store/category/{slug}',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _areasTemplate, decoration: const InputDecoration(labelText: 'Areas covered template', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 16),
                const Text('Process steps', style: TextStyle(fontWeight: FontWeight.w700)),
                for (var i = 0; i < _processSteps.length; i++) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('Step ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(() => _processSteps.removeAt(i)),
                              ),
                            ],
                          ),
                          TextFormField(
                            initialValue: _processSteps[i].title,
                            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                            onChanged: (v) => _processSteps[i] = SeoProcessStep(title: v, description: _processSteps[i].description),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _processSteps[i].description,
                            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                            maxLines: 2,
                            onChanged: (v) => _processSteps[i] = SeoProcessStep(title: _processSteps[i].title, description: v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                OutlinedButton.icon(onPressed: _addProcessStep, icon: const Icon(Icons.add), label: const Text('Add process step')),
                const SizedBox(height: 16),
                const Text('FAQ template', style: TextStyle(fontWeight: FontWeight.w700)),
                SeoFaqEditor(
                  items: _faq,
                  onChanged: (v) => setState(() => _faq = v),
                  templateHint: 'Variables: {{city}}, {{state}}, {{service}}',
                ),
                const SizedBox(height: 16),
                const Text('SEO templates', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextFormField(controller: _seoTitleTpl, decoration: const InputDecoration(labelText: 'SEO title template', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextFormField(controller: _metaDescTpl, decoration: const InputDecoration(labelText: 'Meta description template', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 8),
                TextFormField(controller: _h1Tpl, decoration: const InputDecoration(labelText: 'H1 template', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextFormField(controller: _h2Tpl, decoration: const InputDecoration(labelText: 'H2 features template', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextFormField(controller: _schemaType, decoration: const InputDecoration(labelText: 'Schema.org service type', border: OutlineInputBorder())),
                SwitchListTile(title: const Text('Active'), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
              ],
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}
