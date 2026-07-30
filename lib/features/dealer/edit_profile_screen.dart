import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/utils/validators.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/minimal_app_bar.dart';
import '../../shared/widgets/category_subcategory_skills_picker.dart';
import '../../shared/widgets/address_picker_sheet.dart';

class DealerEditProfileScreen extends StatefulWidget {
  const DealerEditProfileScreen({super.key});

  @override
  State<DealerEditProfileScreen> createState() =>
      _DealerEditProfileScreenState();
}

class _DealerEditProfileScreenState extends State<DealerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  bool _loading = false;
  bool _initialized = false;
  String? _gender;
  DateTime? _dob;
  String? _maritalStatus;
  final List<String> _selectedSubSectorIds = [];
  Map<String, dynamic>? _serviceArea;

  static const List<String> _genderOptions = [
    'Male',
    'Female',
    'Transgender',
    'Other',
    'Prefer not to say',
  ];
  static const List<String> _maritalOptions = [
    'Single',
    'Married',
    'Divorced',
    'Widowed',
    'Separated',
    'Other',
  ];
  static const List<double> _radiusPresets = [10, 15, 25, 50];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    final doc = await FirestoreService.users().doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      _nameController.text = profile['name'] as String? ?? '';
      _phoneController.text = profile['phone'] as String? ?? '';
      _gender = profile['gender'] as String?;
      _maritalStatus = profile['maritalStatus'] as String?;
      final dobStr = profile['dateOfBirth'] as String?;
      if (dobStr != null && dobStr.isNotEmpty) {
        try {
          _dob = DateTime.tryParse(dobStr);
          if (_dob != null) {
            _dobController.text = DateFormat('dd-MM-yyyy').format(_dob!);
          }
        } catch (_) {}
      }
      final sectors = data['dealerSectors'] as List<dynamic>?;
      if (sectors != null) {
        _selectedSubSectorIds.clear();
        _selectedSubSectorIds.addAll(sectors.cast<String>());
      }
      final sa = data['serviceArea'] as Map<String, dynamic>?;
      if (sa != null && sa.isNotEmpty) {
        _serviceArea = Map<String, dynamic>.from(sa);
      }
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    setState(() => _loading = true);
    try {
      final updates = <String, dynamic>{
        'proposedProfile': {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'gender': _gender,
          'dateOfBirth': _dob?.toIso8601String().split('T').first,
          'maritalStatus': _maritalStatus,
        },
        'profilePendingApproval': true,
        'dealerSectors': _selectedSubSectorIds,
      };
      if (_serviceArea != null && _serviceArea!.isNotEmpty) {
        updates['serviceArea'] = _serviceArea;
      }
      await FirestoreService.users().doc(uid).update(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile update submitted for approval.'),
          ),
        );
        context.go(RouteNames.dealerProfile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppConstants.errorGeneric} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildDobField() {
    return TextFormField(
      controller: _dobController,
      decoration:
          const InputDecoration(
            labelText: 'Date of Birth',
            hintText: 'DD-MM-YYYY (type or tap icon for calendar)',
            prefixIcon: Icon(Icons.calendar_today_rounded),
          ).copyWith(
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _dob = picked;
                    _dobController.text = DateFormat(
                      'dd-MM-yyyy',
                    ).format(picked);
                  });
                }
              },
            ),
          ),
      onChanged: (v) {
        final parsed = _parseDob(v);
        if (parsed != null) setState(() => _dob = parsed);
      },
    );
  }

  DateTime? _parseDob(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(RegExp(r'[-/.]'));
    if (parts.length != 3) return null;
    int? d = int.tryParse(parts[0]);
    int? m = int.tryParse(parts[1]);
    int? y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    if (d > 31 || m > 12 || y < 1900 || y > DateTime.now().year) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickServiceArea() async {
    final result = await showAddressPickerSheet(
      context,
      title: 'Service area location',
    );
    if (result == null || !mounted) return;
    String? city;
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        result.latitude,
        result.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
      }
    } catch (_) {}
    if (!mounted) return;
    double chosenRadius = (_serviceArea?['radiusKm'] as num?)?.toDouble() ?? 25;
    if (!_radiusPresets.contains(chosenRadius)) chosenRadius = 25;
    final radius = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Service radius (km)'),
            content: DropdownButtonFormField<double>(
              initialValue: chosenRadius,
              decoration: const InputDecoration(labelText: 'Radius'),
              items: _radiusPresets
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v km')))
                  .toList(),
              onChanged: (v) {
                if (v != null) setDialogState(() => chosenRadius = v);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(chosenRadius),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
    if (radius == null || !mounted) return;
    setState(() {
      _serviceArea = {
        'latitude': result.latitude,
        'longitude': result.longitude,
        'radiusKm': radius,
        'addressLabel': result.address,
        if (city != null && city.isNotEmpty) 'city': city,
      };
    });
  }

  Widget _buildServiceAreaSection() {
    final label = _serviceArea != null
        ? ((_serviceArea!['city'] ?? _serviceArea!['addressLabel'])
                  as String? ??
              'Location set')
        : null;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(label ?? 'Not set'),
        subtitle: label != null && _serviceArea?['radiusKm'] != null
            ? Text(
                '${(_serviceArea!['radiusKm'] as num).toStringAsFixed(0)} km radius',
              )
            : const Text('Tap to set service area'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _pickServiceArea,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: MinimalAppBar(
        title: 'Edit profile',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: AppConstants.nameHint,
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: AppConstants.phoneHint,
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: _genderOptions.contains(_gender)
                          ? _gender
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.wc_rounded),
                      ),
                      items:
                          [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Select'),
                                ),
                              ]
                              .followedBy(
                                _genderOptions.map(
                                  (v) => DropdownMenuItem<String?>(
                                    value: v,
                                    child: Text(v),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 16),
                    _buildDobField(),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: _maritalOptions.contains(_maritalStatus)
                          ? _maritalStatus
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Marital Status',
                        prefixIcon: Icon(Icons.favorite_rounded),
                      ),
                      items:
                          [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Select'),
                                ),
                              ]
                              .followedBy(
                                _maritalOptions.map(
                                  (v) => DropdownMenuItem<String?>(
                                    value: v,
                                    child: Text(v),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _maritalStatus = v),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Service sectors',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (FirestoreService.isAvailable)
                      CategorySubcategorySkillsPicker(
                        showSkills: false,
                        selectedSubSectorIds: _selectedSubSectorIds,
                        selectedSkillIds: const [],
                        onSubSectorsChanged: (ids) {
                          setState(() {
                            _selectedSubSectorIds.clear();
                            _selectedSubSectorIds.addAll(ids);
                          });
                        },
                        onSkillsChanged: (_) {},
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Service area (optional)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildServiceAreaSection(),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(AppConstants.save),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
