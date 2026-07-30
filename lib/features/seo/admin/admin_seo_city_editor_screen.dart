import 'package:flutter/material.dart';

import '../../shop/data/supabase_repository_base.dart';
import '../../../shared/models/address_picker_result.dart';
import '../../../shared/widgets/address_picker_sheet.dart';
import '../data/seo_admin_repository.dart';
import '../domain/seo_city.dart';
import '../domain/seo_service.dart';
import 'widgets/seo_faq_editor.dart';
import 'widgets/seo_image_url_field.dart';

class AdminSeoCityEditorScreen extends StatefulWidget {
  const AdminSeoCityEditorScreen({super.key, this.cityId});

  final String? cityId;

  @override
  State<AdminSeoCityEditorScreen> createState() => _AdminSeoCityEditorScreenState();
}

class _AdminSeoCityEditorScreenState extends State<AdminSeoCityEditorScreen> {
  final _repo = SeoAdminRepository();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _state = TextEditingController();
  final _slug = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _priority = TextEditingController(text: '0');
  final _description = TextEditingController();
  final _businessDescription = TextEditingController();
  final _districts = TextEditingController();
  final _heroImage = TextEditingController();
  final _image = TextEditingController();
  final _seoTitle = TextEditingController();
  final _metaDescription = TextEditingController();
  final _metaKeywords = TextEditingController();
  final _ogTitle = TextEditingController();
  final _ogDescription = TextEditingController();
  final _canonical = TextEditingController();
  final _robots = TextEditingController(text: 'index, follow');

  bool _serviceAvailable = true;
  bool _isActive = true;
  bool _loading = false;
  bool _saving = false;
  List<SeoCity> _allCities = [];
  final Set<String> _nearbyIds = {};
  List<SeoService> _allServices = [];
  final Set<String> _selectedServiceIds = {};
  AddressPickerResult? _pickedLocation;
  List<SeoFaqItem> _faq = [];

  @override
  void initState() {
    super.initState();
    _name.addListener(_autoSlug);
    _load();
  }

  void _autoSlug() {
    if (widget.cityId != null) return;
    _slug.text = SupabaseRepositoryBase.slugify(_name.text);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _allCities = await _repo.listCities();
    _allServices = await _repo.listServices();
    if (widget.cityId != null) {
      final city = await _repo.getCity(widget.cityId!);
      if (city != null) {
        _name.text = city.name;
        _state.text = city.state;
        _slug.text = city.slug;
        _lat.text = city.latitude?.toString() ?? '';
        _lng.text = city.longitude?.toString() ?? '';
        _priority.text = city.priority.toString();
        _description.text = city.description ?? '';
        _businessDescription.text = city.businessDescription ?? '';
        _districts.text = city.nearbyDistricts.join(', ');
        _heroImage.text = city.heroImageUrl ?? '';
        _image.text = city.imageUrl ?? '';
        _seoTitle.text = city.seoTitle ?? '';
        _metaDescription.text = city.metaDescription ?? '';
        _metaKeywords.text = city.metaKeywords ?? '';
        _ogTitle.text = city.ogTitle ?? '';
        _ogDescription.text = city.ogDescription ?? '';
        _canonical.text = city.canonicalUrl ?? '';
        _robots.text = city.robots;
        _serviceAvailable = city.serviceAvailable;
        _isActive = city.isActive;
        _faq = List<SeoFaqItem>.from(city.faq);
        _nearbyIds.addAll(city.nearbyCities.map((c) => c.id));
        _selectedServiceIds.addAll(await _repo.listServiceIdsForCity(city.id));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickFromMap() async {
    final initialLat = double.tryParse(_lat.text.trim());
    final initialLng = double.tryParse(_lng.text.trim());
    final initial = (initialLat != null && initialLng != null)
        ? AddressPickerResult(
            address: _name.text.trim().isEmpty ? 'Selected location' : _name.text.trim(),
            latitude: initialLat,
            longitude: initialLng,
          )
        : null;

    final result = await showAddressPickerSheet(
      context,
      title: 'Select city location on map',
      initial: initial,
    );
    if (!mounted || result == null) return;
    setState(() {
      _pickedLocation = result;
      _lat.text = result.latitude.toStringAsFixed(6);
      _lng.text = result.longitude.toStringAsFixed(6);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _state.dispose();
    _slug.dispose();
    _lat.dispose();
    _lng.dispose();
    _priority.dispose();
    _description.dispose();
    _businessDescription.dispose();
    _districts.dispose();
    _heroImage.dispose();
    _image.dispose();
    _seoTitle.dispose();
    _metaDescription.dispose();
    _metaKeywords.dispose();
    _ogTitle.dispose();
    _ogDescription.dispose();
    _canonical.dispose();
    _robots.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final city = SeoCity(
        id: widget.cityId ?? '',
        name: _name.text.trim(),
        state: _state.text.trim(),
        slug: _slug.text.trim(),
        latitude: double.tryParse(_lat.text.trim()),
        longitude: double.tryParse(_lng.text.trim()),
        priority: int.tryParse(_priority.text.trim()) ?? 0,
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        serviceAvailable: _serviceAvailable,
        isActive: _isActive,
        nearbyDistricts: _districts.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        businessDescription:
            _businessDescription.text.trim().isEmpty ? null : _businessDescription.text.trim(),
        heroImageUrl: _heroImage.text.trim().isEmpty ? null : _heroImage.text.trim(),
        imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
        faq: _faq.where((f) => f.question.trim().isNotEmpty).toList(),
        seoTitle: _seoTitle.text.trim().isEmpty ? null : _seoTitle.text.trim(),
        metaDescription: _metaDescription.text.trim().isEmpty ? null : _metaDescription.text.trim(),
        metaKeywords: _metaKeywords.text.trim().isEmpty ? null : _metaKeywords.text.trim(),
        ogTitle: _ogTitle.text.trim().isEmpty ? null : _ogTitle.text.trim(),
        ogDescription: _ogDescription.text.trim().isEmpty ? null : _ogDescription.text.trim(),
        canonicalUrl: _canonical.text.trim().isEmpty ? null : _canonical.text.trim(),
        robots: _robots.text.trim(),
      );
      await _repo.upsertCity(
        city,
        id: widget.cityId,
        nearbyCityIds: _nearbyIds.toList(),
        serviceIds: _selectedServiceIds.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cityId == null ? 'Add SEO City' : 'Edit SEO City'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('City'),
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'City name *'), validator: _req),
                  TextFormField(controller: _state, decoration: const InputDecoration(labelText: 'State *'), validator: _req),
                  TextFormField(controller: _slug, decoration: const InputDecoration(labelText: 'Slug *'), validator: _req),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lat,
                          decoration: const InputDecoration(labelText: 'Latitude'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lng,
                          decoration: const InputDecoration(labelText: 'Longitude'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFromMap,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Pick from map'),
                      ),
                      const SizedBox(width: 12),
                      if (_pickedLocation != null)
                        Expanded(
                          child: Text(
                            _pickedLocation!.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                  TextFormField(controller: _priority, decoration: const InputDecoration(labelText: 'Priority'), keyboardType: TextInputType.number),
                  TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                  TextFormField(controller: _businessDescription, decoration: const InputDecoration(labelText: 'Business description'), maxLines: 3),
                  TextFormField(controller: _districts, decoration: const InputDecoration(labelText: 'Nearby districts (comma-separated)')),
                  SwitchListTile(title: const Text('Service available'), value: _serviceAvailable, onChanged: (v) => setState(() => _serviceAvailable = v)),
                  SwitchListTile(title: const Text('Active'), value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
                  _section('Services offered in this city'),
                  Text(
                    'Only checked services appear in the navbar for this city.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (_allServices.isEmpty)
                    const Text('Add services first under SEO Services.')
                  else
                    for (final service in _allServices)
                      CheckboxListTile(
                        title: Text(service.name),
                        subtitle: Text('/${service.slug}'),
                        value: _selectedServiceIds.contains(service.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedServiceIds.add(service.id);
                            } else {
                              _selectedServiceIds.remove(service.id);
                            }
                          });
                        },
                      ),
                  _section('Images'),
                  SeoImageUrlField(label: 'Hero image URL', controller: _heroImage),
                  SeoImageUrlField(label: 'OG / card image URL', controller: _image),
                  _section('FAQ (city-level — merged on every service page)'),
                  SeoFaqEditor(
                    items: _faq,
                    onChanged: (v) => setState(() => _faq = v),
                    templateHint: 'Use {{city}}, {{state}}, {{service}} in questions/answers.',
                  ),
                  _section('Nearby cities (internal linking)'),
                  ..._allCities.where((c) => c.id != widget.cityId).map(
                        (c) => CheckboxListTile(
                          title: Text('${c.name}, ${c.state}'),
                          value: _nearbyIds.contains(c.id),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _nearbyIds.add(c.id);
                              } else {
                                _nearbyIds.remove(c.id);
                              }
                            });
                          },
                        ),
                      ),
                  _section('SEO overrides (optional — auto-generated when empty)'),
                  TextFormField(controller: _seoTitle, decoration: const InputDecoration(labelText: 'SEO title')),
                  TextFormField(controller: _metaDescription, decoration: const InputDecoration(labelText: 'Meta description'), maxLines: 2),
                  TextFormField(controller: _metaKeywords, decoration: const InputDecoration(labelText: 'Meta keywords')),
                  TextFormField(controller: _ogTitle, decoration: const InputDecoration(labelText: 'OG title')),
                  TextFormField(controller: _ogDescription, decoration: const InputDecoration(labelText: 'OG description'), maxLines: 2),
                  TextFormField(controller: _canonical, decoration: const InputDecoration(labelText: 'Canonical URL')),
                  TextFormField(controller: _robots, decoration: const InputDecoration(labelText: 'Robots')),
                  const SizedBox(height: 24),
                  if (widget.cityId == null)
                    Text(
                      'Select which services are available in this city. '
                      'Landing pages are created only for checked services '
                      '(e.g. /${_slug.text.isEmpty ? 'patna' : _slug.text}/cctv-installation).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}
