import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/legal_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dealer_ui_tokens.dart';
import '../../core/utils/validators.dart';
import '../../core/constants/analytics_events.dart';
import '../../shared/models/address_picker_result.dart';
import '../../shared/services/analytics_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/address_location_map.dart';
import '../../shared/widgets/address_picker_sheet.dart';

/// Post job uses [AppColors.brandWarm] (dealer bottom nav accent), not legacy saffron.
const _kPostJobAppBarTop = Color(0xFFFFFFFF);
const _kPostJobAppBarBottom = Color(0xFFFFF6ED);
const _kPostJobAppBarInk = Color(0xFF1A1A1A);

enum MaterialOption { noPickup, pickup, materialByTechnician }

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  Timer? _draftDebounce;
  bool _draftLoadedOnce = false;
  bool _draftApplying = false;

  // Controllers
  final _descriptionController = TextEditingController();
  final _rateController = TextEditingController();
  final _expectedTimeController = TextEditingController(text: '60');
  final _siteContactNameController = TextEditingController();
  final _siteContactPhoneController = TextEditingController();
  final _pickupContactNameController = TextEditingController();
  final _pickupContactPhoneController = TextEditingController();
  // State
  bool _emergency = false;
  bool _biddingEnabled = true;
  bool _loading = false;
  String? _jobTypeId;
  String? _sectorId;
  String? _sectorSubOptionId;
  String? _industryTypeId;
  String? _industrySubOptionId;
  String? _warrantyId;
  int _warrantyPeriodDays = 0;
  MaterialOption _materialOption = MaterialOption.noPickup;
  AddressPickerResult? _jobAddress;
  AddressPickerResult? _pickupAddress;
  final List<Map<String, dynamic>> _pickupMaterialList = [];
  final List<Map<String, dynamic>> _materialByTechList = [];

  @override
  void initState() {
    super.initState();
    // Auto-save draft as user types.
    for (final c in [
      _descriptionController,
      _rateController,
      _expectedTimeController,
      _siteContactNameController,
      _siteContactPhoneController,
      _pickupContactNameController,
      _pickupContactPhoneController,
    ]) {
      c.addListener(_scheduleDraftSave);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferResumeDraft());
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    for (final c in [
      _descriptionController,
      _rateController,
      _expectedTimeController,
      _siteContactNameController,
      _siteContactPhoneController,
      _pickupContactNameController,
      _pickupContactPhoneController,
    ]) {
      c.removeListener(_scheduleDraftSave);
    }
    _pageController.dispose();
    _descriptionController.dispose();
    _rateController.dispose();
    _expectedTimeController.dispose();
    _siteContactNameController.dispose();
    _siteContactPhoneController.dispose();
    _pickupContactNameController.dispose();
    _pickupContactPhoneController.dispose();
    super.dispose();
  }

  String? _draftKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return 'dealer_post_job_draft_$uid';
  }

  Future<void> _maybeOfferResumeDraft() async {
    if (_draftLoadedOnce) return;
    _draftLoadedOnce = true;
    final key = _draftKey();
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) return;
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Resume draft job?'),
          content: const Text('We found an unfinished job. Do you want to continue where you left off?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Resume'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await _applyDraft(raw);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft restored.')));
        }
      } else {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  Future<void> _applyDraft(String raw) async {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _draftApplying = true;
      setState(() {
        _currentStep = (m['step'] as num?)?.toInt().clamp(0, 2) ?? 0;
        _emergency = m['emergency'] == true;
        _biddingEnabled = m['biddingEnabled'] != false;
        _jobTypeId = m['jobTypeId'] as String?;
        _sectorId = m['sectorId'] as String?;
        _sectorSubOptionId = m['sectorSubOptionId'] as String?;
        _industryTypeId = m['industryTypeId'] as String?;
        _industrySubOptionId = m['industrySubOptionId'] as String?;
        _warrantyId = m['warrantyId'] as String?;
        _warrantyPeriodDays = (m['warrantyPeriodDays'] as num?)?.toInt() ?? 0;
        final mo = (m['materialOption'] as String?) ?? 'noPickup';
        _materialOption = mo == 'pickup'
            ? MaterialOption.pickup
            : mo == 'materialByTechnician'
                ? MaterialOption.materialByTechnician
                : MaterialOption.noPickup;
        _jobAddress = _decodeAddress(m['jobAddress']);
        _pickupAddress = _decodeAddress(m['pickupAddress']);
        _pickupMaterialList
          ..clear()
          ..addAll(((m['pickupMaterialList'] as List<dynamic>?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        _materialByTechList
          ..clear()
          ..addAll(((m['materialByTechList'] as List<dynamic>?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      });

      _descriptionController.text = (m['description'] as String?) ?? '';
      _rateController.text = (m['rate'] as String?) ?? '';
      _expectedTimeController.text = (m['expectedTime'] as String?) ?? '60';
      _siteContactNameController.text = (m['siteContactName'] as String?) ?? '';
      _siteContactPhoneController.text = (m['siteContactPhone'] as String?) ?? '';
      _pickupContactNameController.text = (m['pickupContactName'] as String?) ?? '';
      _pickupContactPhoneController.text = (m['pickupContactPhone'] as String?) ?? '';

      _pageController.jumpToPage(_currentStep);
    } catch (_) {
    } finally {
      _draftApplying = false;
    }
  }

  Map<String, dynamic>? _encodeAddress(AddressPickerResult? a) {
    if (a == null) return null;
    return {
      'address': a.address,
      'lat': a.latitude,
      'lng': a.longitude,
      'house': a.houseFlatShop,
      'building': a.building,
      'landmark': a.landmark,
    };
  }

  AddressPickerResult? _decodeAddress(dynamic v) {
    if (v is! Map) return null;
    final m = Map<String, dynamic>.from(v);
    final addr = (m['address'] as String?)?.trim() ?? '';
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    if (addr.isEmpty || lat == null || lng == null) return null;
    return AddressPickerResult(
      address: addr,
      latitude: lat,
      longitude: lng,
      houseFlatShop: (m['house'] as String?)?.trim().isEmpty == true ? null : m['house'] as String?,
      building: (m['building'] as String?)?.trim().isEmpty == true ? null : m['building'] as String?,
      landmark: (m['landmark'] as String?)?.trim().isEmpty == true ? null : m['landmark'] as String?,
    );
  }

  void _scheduleDraftSave() {
    if (_draftApplying) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 400), () async {
      final key = _draftKey();
      if (key == null) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final payload = <String, dynamic>{
          'step': _currentStep,
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
          'emergency': _emergency,
          'biddingEnabled': _biddingEnabled,
          'jobTypeId': _jobTypeId,
          'sectorId': _sectorId,
          'sectorSubOptionId': _sectorSubOptionId,
          'industryTypeId': _industryTypeId,
          'industrySubOptionId': _industrySubOptionId,
          'warrantyId': _warrantyId,
          'warrantyPeriodDays': _warrantyPeriodDays,
          'materialOption': _materialOption == MaterialOption.pickup
              ? 'pickup'
              : _materialOption == MaterialOption.materialByTechnician
                  ? 'materialByTechnician'
                  : 'noPickup',
          'jobAddress': _encodeAddress(_jobAddress),
          'pickupAddress': _encodeAddress(_pickupAddress),
          'pickupMaterialList': _pickupMaterialList,
          'materialByTechList': _materialByTechList,
          'description': _descriptionController.text,
          'rate': _rateController.text,
          'expectedTime': _expectedTimeController.text,
          'siteContactName': _siteContactNameController.text,
          'siteContactPhone': _siteContactPhoneController.text,
          'pickupContactName': _pickupContactNameController.text,
          'pickupContactPhone': _pickupContactPhoneController.text,
        };
        await prefs.setString(key, jsonEncode(payload));
      } catch (_) {}
    });
  }

  Future<void> _clearDraft() async {
    final key = _draftKey();
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  void _goToStep(int step) {
    if (step >= 0 && step <= 2) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = step);
      _scheduleDraftSave();
    }
  }

  void _showAddMaterialByTechItemsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _BatchAddMaterialDialog(
        hasRate: true,
        onSave: (items) {
          setState(() => _materialByTechList.addAll(items));
          Navigator.pop(ctx);
          _scheduleDraftSave();
        },
      ),
    );
  }

  void _showAddPickupMaterialItemsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _BatchAddMaterialDialog(
        hasRate: false,
        onSave: (items) {
          setState(() => _pickupMaterialList.addAll(items));
          Navigator.pop(ctx);
          _scheduleDraftSave();
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final jobAddr = _jobAddress?.fullAddress ?? '';
    if (jobAddr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select job location.')),
      );
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    setState(() => _loading = true);
    try {
      final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;
      final emergencyCharge = _emergency ? rate * 0.2 : 0.0;
      final materialOptionStr = _materialOption == MaterialOption.noPickup
          ? 'no_pickup'
          : _materialOption == MaterialOption.pickup
          ? 'pickup'
          : 'material_by_technician';
      final data = <String, dynamic>{
        'dealerId': uid,
        'title': _descriptionController.text.trim().isEmpty
            ? 'Job'
            : _descriptionController.text.trim().length > 80
            ? '${_descriptionController.text.trim().substring(0, 80)}...'
            : _descriptionController.text.trim(),
        'description': _descriptionController.text.trim(),
        'address': jobAddr,
        'dealerRate': rate,
        'agreedAmount': rate + emergencyCharge,
        'priority': _emergency ? 'emergency' : 'normal',
        'emergencyChargeAmount': emergencyCharge,
        'status': 'posted',
        // NOTE: This job payload is sent to a Cloud Function (callable), so it must be JSON-serializable.
        // Server timestamps must be set inside the function, not on the client.
        'rollTechnicianIds': [],
        'offeredToTechnicianIds': [],
        'jobTypeId': _jobTypeId,
        'sectorId': _sectorId,
        if (_sectorSubOptionId != null) 'sectorSubOptionId': _sectorSubOptionId,
        'industryTypeId': _industryTypeId,
        if (_industrySubOptionId != null)
          'industrySubOptionId': _industrySubOptionId,
        'warrantyPeriod': _warrantyPeriodDays,
        'materialOption': materialOptionStr,
        'biddingEnabled': _biddingEnabled,
        'expectedTimeMinutes':
            int.tryParse(_expectedTimeController.text.trim()) ?? 60,
        if (_siteContactNameController.text.trim().isNotEmpty)
          'siteContactName': _siteContactNameController.text.trim(),
        if (_siteContactPhoneController.text.trim().isNotEmpty)
          'siteContactPhone': _siteContactPhoneController.text.trim(),
      };
      if (_jobAddress != null) {
        data['jobLat'] = _jobAddress!.latitude;
        data['jobLng'] = _jobAddress!.longitude;
        // NOTE: Don't send Firestore GeoPoint to callable Cloud Functions (not JSON-serializable).
      }
      if (_materialOption == MaterialOption.pickup) {
        if (_pickupAddress == null ||
            _pickupContactPhoneController.text.trim().isEmpty ||
            _pickupMaterialList.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Pickup material: Enter pickup address, contact phone, and add at least one material item.',
                ),
              ),
            );
          }
          setState(() => _loading = false);
          return;
        }
        final p = _pickupAddress!;
        data['pickupAddress'] = p.fullAddress;
        data['pickupHouseFlatShop'] = p.houseFlatShop;
        data['pickupBuilding'] = p.building;
        data['pickupLandmark'] = p.landmark;
        data['pickupContactName'] =
            _pickupContactNameController.text.trim().isEmpty
            ? null
            : _pickupContactNameController.text.trim();
        data['pickupContactPhone'] = _pickupContactPhoneController.text.trim();
        // NOTE: Don't send Firestore GeoPoint to callable Cloud Functions (not JSON-serializable).
        data['pickupLat'] = p.latitude;
        data['pickupLng'] = p.longitude;
        data['pickupMaterialList'] = _pickupMaterialList
            .asMap()
            .entries
            .map(
              (e) => {
                'slNo': e.key + 1,
                'itemName': e.value['itemName'] as String? ?? '',
                'qty': (e.value['qty'] as num?)?.toInt() ?? 1,
              },
            )
            .toList();
      }
      if (_materialOption == MaterialOption.materialByTechnician) {
        if (_materialByTechList.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Material by technician: Add at least one material item with rate.',
                ),
              ),
            );
          }
          setState(() => _loading = false);
          return;
        }
        data['materialList'] = _materialByTechList.asMap().entries.map((e) {
          final item = e.value;
          final qty = (item['qty'] as num?)?.toInt() ?? 1;
          final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
          return {
            'slNo': e.key + 1,
            'itemName': item['itemName'] as String? ?? '',
            'qty': qty,
            'rate': rate,
            'amount': qty * rate,
          };
        }).toList();
      }
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase is not configured.');
      }

      // Preview limit & charge (informational)
      try {
        final preview = await FirebaseFunctions.instance
            .httpsCallable('previewDealerJobLimit')
            .call({'amount': data['dealerRate']});
        final p = preview.data as Map<dynamic, dynamic>?;
        final applies = p?['chargeApplies'] == true;
        final charge = (p?['platformChargeAmount'] as num?)?.toDouble() ?? 0;
        if (applies && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Free limit exhausted. Platform charge will apply: ₹${charge.toStringAsFixed(0)}'),
            ),
          );
        }
      } catch (_) {}

      final result = await FirebaseFunctions.instance
          .httpsCallable('createJobWithLimit')
          .call({'job': data});
      final res = result.data as Map<dynamic, dynamic>?;
      final jobId = res?['jobId'] as String? ?? '';
      if (jobId.isEmpty) {
        throw Exception('Failed to create job.');
      }
      await AnalyticsService.logEvent(AnalyticsEvents.jobPosted, params: {
        AnalyticsEvents.paramJobId: jobId,
        AnalyticsEvents.paramBiddingEnabled: _biddingEnabled,
        AnalyticsEvents.paramEmergency: _emergency,
      });
      if (mounted) {
        final nav = GoRouter.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job posted. Technicians will be notified.'),
          ),
        );
        await _clearDraft();
        nav.go(
          _biddingEnabled
              ? '/dealer/jobs/$jobId/bidding'
              : '/dealer/jobs/$jobId',
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandWarmBgMuted,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _kPostJobAppBarInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: _kPostJobAppBarInk),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kPostJobAppBarTop, _kPostJobAppBarBottom],
            ),
            border: Border(
              bottom: BorderSide(
                color: AppColors.brandWarmSoft.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: const Text(
          'Post job',
          style: TextStyle(
            fontSize: DealerUiTokens.titleNav,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: _kPostJobAppBarInk,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: _kPostJobAppBarInk,
          ),
          onPressed: () {
            if (_currentStep > 0) {
              _goToStep(_currentStep - 1);
            } else {
              context.pop();
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _StepChips(currentStep: _currentStep),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.brandWarmSurfaceTop, AppColors.brandWarmBgMuted],
          ),
        ),
        child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _GlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(14),
                child: Text(
                  LegalConstants.jobCreationDisclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _PostJobStep1(
                    jobTypeId: _jobTypeId,
                    sectorId: _sectorId,
                    sectorSubOptionId: _sectorSubOptionId,
                    onChanged: (jobTypeId, sectorId, sectorSubOptionId) {
                      setState(() {
                        _jobTypeId = jobTypeId;
                        _sectorId = sectorId;
                        _sectorSubOptionId = sectorSubOptionId;
                      });
                      _scheduleDraftSave();
                    },
                    onComplete: () => _goToStep(1),
                  ),
                  _PostJobStep2(
                    sectorId: _sectorId ?? '',
                    sectorSubOptionId: _sectorSubOptionId,
                    industryTypeId: _industryTypeId,
                    industrySubOptionId: _industrySubOptionId,
                    warrantyId: _warrantyId,
                    warrantyPeriodDays: _warrantyPeriodDays,
                    materialOption: _materialOption,
                    pickupAddress: _pickupAddress,
                    pickupMaterialList: _pickupMaterialList,
                    materialByTechList: _materialByTechList,
                    pickupContactNameController: _pickupContactNameController,
                    pickupContactPhoneController: _pickupContactPhoneController,
                    onChanged:
                        (
                          industryTypeId,
                          industrySubOptionId,
                          warrantyId,
                          warrantyPeriodDays,
                          materialOption,
                          pickupAddress,
                          pickupList,
                          materialByTechList,
                        ) {
                          setState(() {
                            _industryTypeId = industryTypeId;
                            _industrySubOptionId = industrySubOptionId;
                            _warrantyId = warrantyId;
                            _warrantyPeriodDays = warrantyPeriodDays;
                            _materialOption = materialOption;
                            _pickupAddress = pickupAddress;
                            _pickupMaterialList
                              ..clear()
                              ..addAll(pickupList);
                            _materialByTechList
                              ..clear()
                              ..addAll(materialByTechList);
                          });
                          _scheduleDraftSave();
                        },
                    onAddPickupItem: _showAddPickupMaterialItemsDialog,
                    onAddMaterialByTechItem: _showAddMaterialByTechItemsDialog,
                    onBack: () => _goToStep(0),
                    onNext: () => _goToStep(2),
                  ),
                  _PostJobStep3(
                    biddingEnabled: _biddingEnabled,
                    onBiddingEnabledChanged: (v) =>
                        setState(() {
                          _biddingEnabled = v;
                          _scheduleDraftSave();
                        }),
                    jobAddress: _jobAddress,
                    expectedTimeController: _expectedTimeController,
                    siteContactNameController: _siteContactNameController,
                    siteContactPhoneController: _siteContactPhoneController,
                    rateController: _rateController,
                    descriptionController: _descriptionController,
                    emergency: _emergency,
                    loading: _loading,
                    jobTypeId: _jobTypeId,
                    sectorId: _sectorId,
                    sectorSubOptionId: _sectorSubOptionId,
                    industryTypeId: _industryTypeId,
                    industrySubOptionId: _industrySubOptionId,
                    onJobAddressChanged: (v) {
                      setState(() => _jobAddress = v);
                      _scheduleDraftSave();
                    },
                    onEmergencyChanged: (v) {
                      setState(() => _emergency = v);
                      _scheduleDraftSave();
                    },
                    onBack: () => _goToStep(1),
                    onSubmit: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _BatchAddMaterialDialog extends StatefulWidget {
  const _BatchAddMaterialDialog({required this.hasRate, required this.onSave});

  final bool hasRate;
  final void Function(List<Map<String, dynamic>> items) onSave;

  @override
  State<_BatchAddMaterialDialog> createState() =>
      _BatchAddMaterialDialogState();
}

class _BatchAddMaterialDialogState extends State<_BatchAddMaterialDialog> {
  final List<_MaterialRowControllers> _rows = [
    _MaterialRowControllers(
      TextEditingController(),
      TextEditingController(text: '1'),
      TextEditingController(text: '0'),
    ),
  ];

  @override
  void dispose() {
    for (final r in _rows) {
      r.name.dispose();
      r.qty.dispose();
      r.rate.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(
        _MaterialRowControllers(
          TextEditingController(),
          TextEditingController(text: '1'),
          TextEditingController(text: '0'),
        ),
      );
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[index].name.dispose();
      _rows[index].qty.dispose();
      _rows[index].rate.dispose();
      _rows.removeAt(index);
    });
  }

  void _save() {
    final items = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final name = r.name.text.trim();
      if (name.isEmpty) continue;
      final qty = int.tryParse(r.qty.text.trim()) ?? 1;
      final rate = widget.hasRate
          ? (double.tryParse(r.rate.text.trim()) ?? 0.0)
          : 0.0;
      items.add({'itemName': name, 'qty': qty, 'rate': rate});
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item with a name.')),
      );
      return;
    }
    widget.onSave(items);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hasRate ? 'Add material items' : 'Add material items'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.hasRate
                    ? 'Add multiple items (name, qty, rate). Leave empty rows to skip.'
                    : 'Add multiple items (name, qty). Leave empty rows to skip.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ...List.generate(_rows.length, (i) {
                final r = _rows[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: r.name,
                          decoration: const InputDecoration(
                            labelText: 'Item name',
                            hintText: 'e.g. Cable, Switch',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: r.qty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            isDense: true,
                          ),
                        ),
                      ),
                      if (widget.hasRate) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: r.rate,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '₹',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 22),
                        onPressed: _rows.length > 1
                            ? () => _removeRow(i)
                            : null,
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add another item'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add all')),
      ],
    );
  }
}

class _MaterialRowControllers {
  _MaterialRowControllers(this.name, this.qty, this.rate);
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController rate;
}

class _PostJobStep1 extends StatefulWidget {
  const _PostJobStep1({
    required this.jobTypeId,
    required this.sectorId,
    required this.sectorSubOptionId,
    required this.onChanged,
    required this.onComplete,
  });

  final String? jobTypeId;
  final String? sectorId;
  final String? sectorSubOptionId;
  final void Function(
    String? jobTypeId,
    String? sectorId,
    String? sectorSubOptionId,
  )
  onChanged;
  final VoidCallback onComplete;

  @override
  State<_PostJobStep1> createState() => _PostJobStep1State();
}

class _PostJobStep1State extends State<_PostJobStep1> {
  void _checkAndNavigate() {
    if (widget.jobTypeId != null && widget.sectorId != null) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) widget.onComplete();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return const Center(child: Text('Firebase is not configured.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeroCard(
            title: 'Step 1 of 3',
            subtitle: 'Choose job type and sector',
            icon: Icons.category_rounded,
          ),
          const SizedBox(height: 14),
          _GlassCard(
            borderRadius: 22,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select job type and sector',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                ).animate().fadeIn().slideY(
                      begin: -0.05,
                      end: 0,
                      curve: Curves.easeOut,
                    ),
                const SizedBox(height: 8),
                Text(
                  'Choose the type of work and sector for your job.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                )
                    .animate()
                    .fadeIn(delay: 50.ms)
                    .slideY(begin: -0.03, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 24),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.jobTypes().orderBy('name').snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Job type',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: docs.map((d) {
                      final id = d.id;
                      final name = d.data()['name'] as String? ?? id;
                      final selected = widget.jobTypeId == id;
                      return FilterChip(
                        label: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        selected: selected,
                        onSelected: (v) {
                          widget.onChanged(
                            v ? id : null,
                            widget.sectorId,
                            widget.sectorSubOptionId,
                          );
                          if (v && widget.sectorId != null) {
                            _checkAndNavigate();
                          }
                        },
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: selected ? AppColors.brandWarm : const Color(0xFFE5E7EB),
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.brandWarm.withValues(alpha: 0.9),
                        showCheckmark: false,
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(
                              milliseconds: 120 + docs.indexOf(d) * 30,
                            ),
                          )
                          .slideX(begin: 0.02, end: 0, curve: Curves.easeOut);
                    }).toList(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.sectors().snapshots(),
            builder: (context, snap) {
              final docs = List.from(snap.data?.docs ?? [])
                ..sort((a, b) {
                  final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
                  final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
                  if (oa != ob) return oa.compareTo(ob);
                  return (a.data()['name'] as String? ?? '').compareTo(
                    b.data()['name'] as String? ?? '',
                  );
                });
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sector',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: docs.map((d) {
                      final id = d.id;
                      final name = d.data()['name'] as String? ?? id;
                      final selected = widget.sectorId == id;
                      return FilterChip(
                        label: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        selected: selected,
                        onSelected: (v) {
                          widget.onChanged(
                            widget.jobTypeId,
                            v ? id : null,
                            null,
                          );
                          if (v && widget.jobTypeId != null) {
                            _checkAndNavigate();
                          }
                        },
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: selected ? AppColors.brandWarm : const Color(0xFFE5E7EB),
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.brandWarm.withValues(alpha: 0.9),
                        showCheckmark: false,
                      )
                          .animate()
                          .fadeIn(
                            delay: Duration(
                              milliseconds: 180 + docs.indexOf(d) * 30,
                            ),
                          )
                          .slideX(begin: 0.02, end: 0, curve: Curves.easeOut);
                    }).toList(),
                  ),
                ],
              );
            },
          ),
                if (widget.sectorId != null) ...[
                  const SizedBox(height: 24),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.sectorSubOptions()
                  .where('sectorId', isEqualTo: widget.sectorId)
                  .snapshots(),
              builder: (context, snap) {
                final docs = List.from(snap.data?.docs ?? [])
                  ..sort((a, b) {
                    final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
                    final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
                    if (oa != ob) return oa.compareTo(ob);
                    return ((a.data()['name'] as String?) ?? '').compareTo(
                      (b.data()['name'] as String?) ?? '',
                    );
                  });
                if (docs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sector sub-category (optional)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: Text(
                            'None',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.sectorSubOptionId == null ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          selected: widget.sectorSubOptionId == null,
                          onSelected: (v) {
                            widget.onChanged(
                              widget.jobTypeId,
                              widget.sectorId,
                              null,
                            );
                            if (widget.jobTypeId != null && v) {
                              _checkAndNavigate();
                            }
                          },
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: widget.sectorSubOptionId == null ? AppColors.brandWarm : const Color(0xFFE5E7EB),
                              width: widget.sectorSubOptionId == null ? 1.6 : 1,
                            ),
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.brandWarm.withValues(alpha: 0.9),
                          showCheckmark: false,
                        )
                            .animate()
                            .fadeIn(delay: 220.ms)
                            .slideX(begin: 0.02, end: 0, curve: Curves.easeOut),
                        ...docs.map((d) {
                          final id = d.id;
                          final name = d.data()['name'] as String? ?? id;
                          final selected = widget.sectorSubOptionId == id;
                          return FilterChip(
                            label: Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            selected: selected,
                            onSelected: (v) {
                              widget.onChanged(
                                widget.jobTypeId,
                                widget.sectorId,
                                v ? id : null,
                              );
                              if (v && widget.jobTypeId != null) {
                                _checkAndNavigate();
                              }
                            },
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: selected ? AppColors.brandWarm : const Color(0xFFE5E7EB),
                                width: selected ? 1.6 : 1,
                              ),
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: AppColors.brandWarm.withValues(alpha: 0.9),
                            showCheckmark: false,
                          )
                              .animate()
                              .fadeIn(
                                delay: Duration(
                                  milliseconds: 250 + docs.indexOf(d) * 30,
                                ),
                              )
                              .slideX(
                                begin: 0.02,
                                end: 0,
                                curve: Curves.easeOut,
                              );
                        }),
                      ],
                    ),
                  ],
                );
              },
                  ),
                ],
              ],
            ),
          ),
          if (widget.jobTypeId != null && widget.sectorId != null) ...[
            const SizedBox(height: 24),
            _SfGradientButton(
              onPressed: widget.onComplete,
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
            )
                .animate()
                .fadeIn(delay: 300.ms)
                .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
          ],
        ],
      ),
    );
  }
}

class _PostJobStep2 extends StatelessWidget {
  const _PostJobStep2({
    required this.sectorId,
    required this.sectorSubOptionId,
    required this.industryTypeId,
    required this.industrySubOptionId,
    required this.warrantyId,
    required this.warrantyPeriodDays,
    required this.materialOption,
    required this.pickupAddress,
    required this.pickupMaterialList,
    required this.materialByTechList,
    required this.pickupContactNameController,
    required this.pickupContactPhoneController,
    required this.onChanged,
    required this.onAddPickupItem,
    required this.onAddMaterialByTechItem,
    required this.onBack,
    required this.onNext,
  });

  final String sectorId;
  final String? sectorSubOptionId;
  final String? industryTypeId;
  final String? industrySubOptionId;
  final String? warrantyId;
  final int warrantyPeriodDays;
  final MaterialOption materialOption;
  final AddressPickerResult? pickupAddress;
  final List<Map<String, dynamic>> pickupMaterialList;
  final List<Map<String, dynamic>> materialByTechList;
  final TextEditingController pickupContactNameController;
  final TextEditingController pickupContactPhoneController;
  final void Function(
    String? industryTypeId,
    String? industrySubOptionId,
    String? warrantyId,
    int warrantyPeriodDays,
    MaterialOption materialOption,
    AddressPickerResult? pickupAddress,
    List<Map<String, dynamic>> pickupList,
    List<Map<String, dynamic>> materialByTechList,
  )
  onChanged;
  final void Function(BuildContext context) onAddPickupItem;
  final void Function(BuildContext context) onAddMaterialByTechItem;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return const Center(child: Text('Firebase is not configured.'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeroCard(
            title: 'Step 2 of 3',
            subtitle: 'Industry, warranty and material',
            icon: Icons.inventory_2_rounded,
          ),
          const SizedBox(height: 14),
          Text(
            'Industry and material',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn().slideX(
            begin: 0.05,
            end: 0,
            curve: Curves.easeOut,
          ),
          const SizedBox(height: 8),
          Text(
                'Select industry type, warranty, and material handling.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
              .animate()
              .fadeIn(delay: 50.ms)
              .slideX(begin: 0.03, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService.industryTypes()
                .orderBy('name')
                .snapshots(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              return DropdownButtonFormField<String>(
                    initialValue: industryTypeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Industry / property type',
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Select industry'),
                      ),
                      ...docs.map(
                        (d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(d.data()['name'] as String? ?? d.id),
                        ),
                      ),
                    ],
                    onChanged: (v) => onChanged(
                      v,
                      null,
                      warrantyId,
                      warrantyPeriodDays,
                      materialOption,
                      pickupAddress,
                      pickupMaterialList,
                      materialByTechList,
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 100.ms)
                  .slideY(begin: 0.03, end: 0, curve: Curves.easeOut);
            },
          ),
          if (industryTypeId != null) ...[
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.industrySubOptions()
                  .where('industryTypeId', isEqualTo: industryTypeId)
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                docs.sort(
                  (a, b) => ((a.data()['name'] as String?) ?? '').compareTo(
                    (b.data()['name'] as String?) ?? '',
                  ),
                );
                return DropdownButtonFormField<String>(
                      initialValue: industrySubOptionId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Industry sub-type (optional)',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Select sub-type (optional)'),
                        ),
                        ...docs.map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d.data()['name'] as String? ?? d.id),
                          ),
                        ),
                      ],
                      onChanged: (v) => onChanged(
                        industryTypeId,
                        v,
                        warrantyId,
                        warrantyPeriodDays,
                        materialOption,
                        pickupAddress,
                        pickupMaterialList,
                        materialByTechList,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 50.ms)
                    .slideY(begin: 0.02, end: 0, curve: Curves.easeOut);
              },
            ),
          ],
          const SizedBox(height: 16),
          _WarrantySelector(
            sectorId: sectorId,
            sectorSubOptionId: sectorSubOptionId,
            industryTypeId: industryTypeId,
            industrySubOptionId: industrySubOptionId,
            warrantyId: warrantyId,
            warrantyPeriodDays: warrantyPeriodDays,
            onChanged: (id, days) => onChanged(
              industryTypeId,
              industrySubOptionId,
              id,
              days,
              materialOption,
              pickupAddress,
              pickupMaterialList,
              materialByTechList,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Material handling',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 8),
          _MaterialOptionCard(
            option: MaterialOption.noPickup,
            label: 'No pickup',
            subtitle: 'Technician brings materials or uses existing',
            selected: materialOption == MaterialOption.noPickup,
            onTap: () => onChanged(
              industryTypeId,
              industrySubOptionId,
              warrantyId,
              warrantyPeriodDays,
              MaterialOption.noPickup,
              pickupAddress,
              pickupMaterialList,
              materialByTechList,
            ),
          ).animate().fadeIn(delay: 180.ms).slideX(begin: 0.02, end: 0),
          const SizedBox(height: 8),
          _MaterialOptionCard(
            option: MaterialOption.pickup,
            label: 'Pickup material',
            subtitle: 'Technician picks up material from a location',
            selected: materialOption == MaterialOption.pickup,
            onTap: () => onChanged(
              industryTypeId,
              industrySubOptionId,
              warrantyId,
              warrantyPeriodDays,
              MaterialOption.pickup,
              pickupAddress,
              pickupMaterialList,
              materialByTechList,
            ),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.02, end: 0),
          const SizedBox(height: 8),
          _MaterialOptionCard(
            option: MaterialOption.materialByTechnician,
            label: 'Material by technician',
            subtitle: 'Technician arranges materials',
            selected: materialOption == MaterialOption.materialByTechnician,
            onTap: () => onChanged(
              industryTypeId,
              industrySubOptionId,
              warrantyId,
              warrantyPeriodDays,
              MaterialOption.materialByTechnician,
              pickupAddress,
              pickupMaterialList,
              materialByTechList,
            ),
          ).animate().fadeIn(delay: 220.ms).slideX(begin: 0.02, end: 0),
          if (materialOption == MaterialOption.pickup)
            _PickupMaterialSection(
              pickupAddress: pickupAddress,
              pickupMaterialList: pickupMaterialList,
              pickupContactNameController: pickupContactNameController,
              pickupContactPhoneController: pickupContactPhoneController,
              onAddItem: onAddPickupItem,
              onChanged: (pa, list) {
                onChanged(
                  industryTypeId,
                  industrySubOptionId,
                  warrantyId,
                  warrantyPeriodDays,
                  materialOption,
                  pa,
                  list,
                  materialByTechList,
                );
              },
            ),
          if (materialOption == MaterialOption.materialByTechnician)
            _MaterialByTechSection(
              materialByTechList: materialByTechList,
              onAddItem: onAddMaterialByTechItem,
              onChanged: (list) => onChanged(
                industryTypeId,
                industrySubOptionId,
                warrantyId,
                warrantyPeriodDays,
                materialOption,
                pickupAddress,
                pickupMaterialList,
                list,
              ),
            ),
          const SizedBox(height: 32),
          Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandWarm,
                      side: const BorderSide(color: AppColors.brandWarmSoft, width: 1.2),
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SfGradientButton(
                      onPressed: industryTypeId == null
                          ? null
                          : () {
                              if (materialOption == MaterialOption.pickup) {
                                if (pickupAddress == null ||
                                    pickupContactPhoneController.text
                                        .trim()
                                        .isEmpty ||
                                    pickupMaterialList.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Pickup material: Enter pickup address, contact phone, and add at least one material item.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }
                              if (materialOption ==
                                      MaterialOption.materialByTechnician &&
                                  materialByTechList.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Material by technician: Add at least one material item with rate.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              onNext();
                            },
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ),
                ],
              )
              .animate()
              .fadeIn(delay: 250.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

class _MaterialOptionCard extends StatelessWidget {
  const _MaterialOptionCard({
    required this.option,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final MaterialOption option;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? AppColors.brandWarm.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.brandWarm : const Color(0xFFE5E7EB),
          width: selected ? 1.8 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                option == MaterialOption.noPickup
                    ? Icons.inventory_2_outlined
                    : option == MaterialOption.pickup
                    ? Icons.local_shipping_outlined
                    : Icons.build_outlined,
                color: selected ? AppColors.brandWarm : AppColors.textSecondary,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppColors.brandWarm, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarrantySelector extends StatelessWidget {
  const _WarrantySelector({
    required this.sectorId,
    required this.sectorSubOptionId,
    required this.industryTypeId,
    required this.industrySubOptionId,
    required this.warrantyId,
    required this.warrantyPeriodDays,
    required this.onChanged,
  });

  final String sectorId;
  final String? sectorSubOptionId;
  final String? industryTypeId;
  final String? industrySubOptionId;
  final String? warrantyId;
  final int warrantyPeriodDays;
  final void Function(String? id, int days) onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.defaultWarranty().snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final d = doc.data();
          final docSectorId = d['sectorId'] as String?;
          final docSectorSubOptionId = d['sectorSubOptionId'] as String?;
          final docIndustryTypeId = d['industryTypeId'] as String?;
          final docIndustrySubOptionId = d['industrySubOptionId'] as String?;
          if (docSectorId == null) return true;
          if (docSectorId != sectorId) return false;
          if (docSectorSubOptionId != null &&
              docSectorSubOptionId != sectorSubOptionId) {
            return false;
          }
          if (docIndustryTypeId != null && docIndustryTypeId != industryTypeId) {
            return false;
          }
          if (docIndustrySubOptionId != null &&
              docIndustrySubOptionId != industrySubOptionId) {
            return false;
          }
          return true;
        }).toList();
        if (filtered.isEmpty) return const SizedBox.shrink();
        return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Warranty period',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filtered.map((doc) {
                    final id = doc.id;
                    final days = (doc.data()['days'] as num?)?.toInt() ?? 0;
                    final selected = warrantyId == id;
                    return ChoiceChip(
                      label: Text('$days days'),
                      selected: selected,
                      onSelected: (v) => onChanged(v ? id : null, v ? days : 0),
                      selectedColor: AppColors.brandWarm.withValues(alpha: 0.2),
                    );
                  }).toList(),
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 120.ms)
            .slideY(begin: 0.02, end: 0, curve: Curves.easeOut);
      },
    );
  }
}

class _PickupMaterialSection extends StatelessWidget {
  const _PickupMaterialSection({
    required this.pickupAddress,
    required this.pickupMaterialList,
    required this.pickupContactNameController,
    required this.pickupContactPhoneController,
    required this.onAddItem,
    required this.onChanged,
  });

  final AddressPickerResult? pickupAddress;
  final List<Map<String, dynamic>> pickupMaterialList;
  final TextEditingController pickupContactNameController;
  final TextEditingController pickupContactPhoneController;
  final void Function(BuildContext context) onAddItem;
  final void Function(
    AddressPickerResult? pickupAddress,
    List<Map<String, dynamic>> list,
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.brandWarmBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pickup material details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final result = await showAddressPickerSheet(
                  context,
                  title: 'Select pickup address',
                  initial: pickupAddress,
                );
                if (result != null) onChanged(result, pickupMaterialList);
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(
                pickupAddress != null
                    ? 'Pickup: ${pickupAddress!.address.length > 35 ? '${pickupAddress!.address.substring(0, 35)}...' : pickupAddress!.address}'
                    : 'Select pickup address',
              ),
            ),
            if (pickupAddress != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AddressLocationMap(
                    latitude: pickupAddress!.latitude,
                    longitude: pickupAddress!.longitude,
                    height: 100,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: pickupContactNameController,
              decoration: const InputDecoration(
                labelText: 'Pickup contact name (optional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pickupContactPhoneController,
              decoration: const InputDecoration(
                labelText: 'Pickup contact phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Text(
              'Material list',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => onAddItem(context),
              icon: const Icon(Icons.add_circle_outline, size: 22),
              label: const Text('Add material items'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.brandWarm.withValues(alpha: 0.15),
                foregroundColor: AppColors.brandWarm,
              ),
            ),
            if (pickupMaterialList.isNotEmpty)
              ...pickupMaterialList.asMap().entries.map(
                (e) => ListTile(
                  dense: true,
                  title: Text(e.value['itemName'] as String? ?? ''),
                  subtitle: Text('Qty: ${e.value['qty'] ?? 1}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final list = List<Map<String, dynamic>>.from(
                        pickupMaterialList,
                      )..removeAt(e.key);
                      onChanged(pickupAddress, list);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MaterialByTechSection extends StatelessWidget {
  const _MaterialByTechSection({
    required this.materialByTechList,
    required this.onAddItem,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> materialByTechList;
  final void Function(BuildContext context) onAddItem;
  final void Function(List<Map<String, dynamic>> list) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.brandWarmBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Material by technician',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Add material items (name, qty, rate) you need. Technician will arrange them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Material list',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => onAddItem(context),
              icon: const Icon(Icons.add_circle_outline, size: 22),
              label: const Text('Add material items'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.brandWarm.withValues(alpha: 0.15),
                foregroundColor: AppColors.brandWarm,
              ),
            ),
            if (materialByTechList.isNotEmpty)
              ...materialByTechList.asMap().entries.map((e) {
                final item = e.value;
                final amt =
                    ((item['qty'] as num?)?.toInt() ?? 1) *
                    ((item['rate'] as num?)?.toDouble() ?? 0);
                return ListTile(
                  dense: true,
                  title: Text(item['itemName'] as String? ?? ''),
                  subtitle: Text(
                    'Qty: ${item['qty'] ?? 1} · Rate: ₹${(item['rate'] as num?)?.toStringAsFixed(0) ?? '0'} · ₹${amt.toStringAsFixed(0)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      final list = List<Map<String, dynamic>>.from(
                        materialByTechList,
                      )..removeAt(e.key);
                      onChanged(list);
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _PostJobStep3 extends StatelessWidget {
  const _PostJobStep3({
    required this.biddingEnabled,
    required this.onBiddingEnabledChanged,
    required this.jobAddress,
    required this.expectedTimeController,
    required this.siteContactNameController,
    required this.siteContactPhoneController,
    required this.rateController,
    required this.descriptionController,
    required this.emergency,
    required this.loading,
    required this.jobTypeId,
    required this.sectorId,
    required this.sectorSubOptionId,
    required this.industryTypeId,
    required this.industrySubOptionId,
    required this.onJobAddressChanged,
    required this.onEmergencyChanged,
    required this.onBack,
    required this.onSubmit,
  });

  final bool biddingEnabled;
  final void Function(bool v) onBiddingEnabledChanged;
  final AddressPickerResult? jobAddress;
  final TextEditingController expectedTimeController;
  final TextEditingController siteContactNameController;
  final TextEditingController siteContactPhoneController;
  final TextEditingController rateController;
  final TextEditingController descriptionController;
  final bool emergency;
  final bool loading;
  final String? jobTypeId;
  final String? sectorId;
  final String? sectorSubOptionId;
  final String? industryTypeId;
  final String? industrySubOptionId;
  final void Function(AddressPickerResult? v) onJobAddressChanged;
  final void Function(bool v) onEmergencyChanged;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepHeroCard(
            title: 'Step 3 of 3',
            subtitle: 'Price, location and final review',
            icon: Icons.task_alt_rounded,
          ),
          const SizedBox(height: 14),
          // Job location - prominent at top, bigger
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: InkWell(
              onTap: loading
                  ? null
                  : () async {
                      final result = await showAddressPickerSheet(
                        context,
                        title: 'Select job location',
                        initial: jobAddress,
                      );
                      if (result != null) onJobAddressChanged(result);
                    },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.brandWarm.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            size: 28,
                            color: AppColors.brandWarm,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Job location',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                jobAddress != null
                                    ? (jobAddress!.address.length > 50
                                          ? '${jobAddress!.address.substring(0, 50)}...'
                                          : jobAddress!.address)
                                    : 'Tap to search or select on map',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: jobAddress != null
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    if (jobAddress != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AddressLocationMap(
                            latitude: jobAddress!.latitude,
                            longitude: jobAddress!.longitude,
                            height: 160,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ).animate().fadeIn().slideY(
            begin: -0.03,
            end: 0,
            curve: Curves.easeOut,
          ),
          const SizedBox(height: 24),
          Text(
            'Job details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(delay: 50.ms),
          const SizedBox(height: 12),
          TextFormField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Job description',
              prefixIcon: Icon(Icons.description),
              hintText: 'Describe the job work...',
            ),
            maxLines: 3,
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: 16),
          TextFormField(
            controller: expectedTimeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Expected time (minutes)',
              prefixIcon: Icon(Icons.schedule),
              hintText: 'e.g. 60',
            ),
          ).animate().fadeIn(delay: 160.ms),
          const SizedBox(height: 16),
          TextFormField(
            controller: siteContactNameController,
            decoration: const InputDecoration(
              labelText: 'Site contact name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ).animate().fadeIn(delay: 180.ms),
          const SizedBox(height: 8),
          TextFormField(
            controller: siteContactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Site contact number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),
          TextFormField(
            controller: rateController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Job price (₹)',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            validator: (v) => Validators.minAmount(v, 1),
          ).animate().fadeIn(delay: 220.ms),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate type',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilterChip(
                          label: const Text('Fixed rate'),
                          selected: !biddingEnabled,
                          onSelected: (v) => onBiddingEnabledChanged(!v),
                          selectedColor: AppColors.brandWarm.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilterChip(
                          label: const Text('Bidding'),
                          selected: biddingEnabled,
                          onSelected: (v) => onBiddingEnabledChanged(v),
                          selectedColor: AppColors.brandWarm.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    biddingEnabled
                        ? 'Technician can bid on this job. You can accept, counter, or reject.'
                        : 'Technician can only accept or reject at your fixed rate.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 230.ms),
          if (FirestoreService.isAvailable &&
              jobTypeId != null &&
              sectorId != null &&
              industryTypeId != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.rateMatrix().snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                final list = docs
                    .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
                    .where((doc) {
                      final d = doc.data();
                      if (d['jobTypeId'] != jobTypeId ||
                          d['sectorId'] != sectorId ||
                          d['industryTypeId'] != industryTypeId) {
                        return false;
                      }
                      if (d['sectorSubOptionId'] != null &&
                          d['sectorSubOptionId'] != sectorSubOptionId) {
                        return false;
                      }
                      if (d['industrySubOptionId'] != null &&
                          d['industrySubOptionId'] != industrySubOptionId) {
                        return false;
                      }
                      return true;
                    })
                    .toList();
                if (list.isEmpty) return const SizedBox.shrink();
                var match = list.first;
                final exactIndustrySub = list.where(
                  (doc) =>
                      doc.data()['industrySubOptionId'] == industrySubOptionId,
                );
                if (exactIndustrySub.isNotEmpty) {
                  final exactSub = exactIndustrySub.where(
                    (doc) =>
                        doc.data()['sectorSubOptionId'] == sectorSubOptionId,
                  );
                  match = exactSub.isNotEmpty
                      ? exactSub.first
                      : exactIndustrySub.first;
                } else {
                  final exactSectorSub = list.where(
                    (doc) =>
                        doc.data()['sectorSubOptionId'] == sectorSubOptionId,
                  );
                  if (exactSectorSub.isNotEmpty) match = exactSectorSub.first;
                }
                final fixedRate =
                    (match.data()['fixedRate'] as num?)?.toDouble() ?? 0.0;
                if (fixedRate <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Suggested rate: ₹${fixedRate.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () => rateController.text = fixedRate
                                .toStringAsFixed(0),
                            child: const Text('Use suggested'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          if (FirestoreService.isAvailable)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.platformChargeConfig()
                  .limit(1)
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const SizedBox.shrink();
                final d = docs.first.data();
                final type = d['type'] as String? ?? 'percent';
                final value = (d['value'] as num?)?.toDouble() ?? 0.0;
                final rate = double.tryParse(rateController.text.trim()) ?? 0.0;
                final platformFee = type == 'percent'
                    ? rate * value / 100
                    : value;
                final techAmount = rate - platformFee;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform fee: ${type == 'percent' ? '$value%' : '₹${value.toStringAsFixed(0)}'} = ₹${platformFee.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Technician amount (approx.): ₹${techAmount.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.brandWarmBorder),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandWarm.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SwitchListTile(
                  title: const Text('Emergency job (+20% charge)'),
                  subtitle: Text(
                    'Emergency jobs are sent to 5 technicians at once.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: emergency,
                  onChanged: emergency ? null : (v) => onEmergencyChanged(v),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 240.ms),
          const SizedBox(height: 24),
          Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: loading ? null : onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandWarm,
                      side: const BorderSide(color: AppColors.brandWarmSoft, width: 1.2),
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    label: const Text('Back'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SfGradientButton(
                      onPressed: loading ? null : onSubmit,
                      label: 'Post job',
                      isLoading: loading,
                    ),
                  ),
                ],
              )
              .animate()
              .fadeIn(delay: 280.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }
}

/// Full-width saffron gradient primary CTA (glass flow).
class _SfGradientButton extends StatelessWidget {
  const _SfGradientButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final busy = isLoading;
    final interactive = onPressed != null && !busy;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: interactive
              ? const [AppColors.brandWarm, AppColors.brandWarmLight]
              : [
                  AppColors.brandWarm.withValues(alpha: 0.5),
                  AppColors.brandWarmLight.withValues(alpha: 0.45),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandWarm.withValues(alpha: interactive ? 0.26 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: busy
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : icon != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  )
                : Text(label),
      ),
    );
  }
}

class _StepChips extends StatelessWidget {
  const _StepChips({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Type', 'Details', 'Review'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index == currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandWarm, AppColors.brandWarmLight],
                    )
                  : null,
              color: active ? null : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.brandWarm.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              labels[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _StepHeroCard extends StatelessWidget {
  const _StepHeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.brandWarmBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandWarm.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brandWarm.withValues(alpha: 0.15),
                      AppColors.brandWarmLight.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.brandWarm, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.brandWarmBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandWarm.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// (old _GlassIconBadge removed – no longer used in new flat header)
