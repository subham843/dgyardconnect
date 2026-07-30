import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/pincode_service.dart';
import '../../shared/services/storage_service.dart';

class DealerKycScreen extends StatefulWidget {
  const DealerKycScreen({super.key});

  @override
  State<DealerKycScreen> createState() => _DealerKycScreenState();
}

class _DealerKycScreenState extends State<DealerKycScreen> {
  static const _kBgLight = Color(0xFFF7F8FC);
  static const _kTextPrimary = Color(0xFF1A1A1A);
  static const _kTextSecondary = Color(0xFF6B7280);
  static const _kBorder = Color(0xFFDDE3EE);

  bool _loading = true;
  bool _submitting = false;
  String _status = 'pending';
  Map<String, dynamic> _kycData = {};
  bool _submittedForReview = false;
  DateTime? _kycRejectedAt;
  final _formKey = GlobalKey<FormState>();
  bool _idProofError = false;
  bool _declarationError = false;
  bool _termsError = false;
  bool _pincodeLookupLoading = false;

  final _fullNameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _shopUnitController = TextEditingController();
  final _street1Controller = TextEditingController();
  final _street2Controller = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _gstinController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _landmarkController = TextEditingController();

  String _idType = 'Aadhaar Card';
  String _businessCategory = 'Electrical';
  bool _declarationAccepted = false;
  bool _termsAccepted = false;

  File? _idProofFrontFile;
  String? _idProofFrontUrl;
  File? _selfieWithIdFile;
  String? _selfieWithIdUrl;
  File? _shopPhotoFile;
  String? _shopPhotoUrl;

  static const _idTypes = ['Aadhaar Card', 'PAN Card', 'Driving License'];
  /// Broad sector list for dealer KYC (searchable via dropdown filter in UI if needed later).
  static const _businessCategories = [
    'Agriculture & Irrigation',
    'Automotive & Garage',
    'Building Materials & Hardware',
    'CCTV & Security Systems',
    'Cleaning & Housekeeping',
    'Computer & IT Services',
    'Construction & Civil',
    'Electrical',
    'Electronics & Home Appliances',
    'Events & Rentals',
    'Fabrication & Welding',
    'Fire Safety & Firefighting',
    'Flooring & Tiling',
    'Glass & Aluminium',
    'HVAC & Refrigeration',
    'Industrial Machinery & Equipment',
    'Internet & Networking',
    'Landscaping & Gardening',
    'Lighting & Fixtures',
    'Locksmith & Keys',
    'Metal Works & Fabrication',
    'Office Equipment & Supplies',
    'Painting & Coating',
    'Pest Control',
    'Photography & Audio-Visual',
    'Plumbing',
    'Printing & Signage',
    'Pumps & Motors',
    'Renewable Energy (Solar / Wind)',
    'Road & Transport Services',
    'Safety Equipment & PPE',
    'Software & Web Services',
    'Steel & Structural',
    'Surveying & Calibration',
    'Telecom & Cabling',
    'Tools & Power Tools',
    'Water Treatment & RO Systems',
    'Waterproofing',
    'Wood & Carpentry',
    'Multi-service',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _idNumberController.dispose();
    _businessNameController.dispose();
    _shopUnitController.dispose();
    _street1Controller.dispose();
    _street2Controller.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _gstinController.dispose();
    _alternatePhoneController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      setState(() => _loading = false);
      return;
    }
    final doc = await FirestoreService.users().doc(uid).get(const GetOptions(source: Source.server));
    final data = doc.data() ?? <String, dynamic>{};
    final kycData = data['kycData'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final rejectedAtRaw = data['kycRejectedAt'];

    setState(() {
      _status = data['kycStatus'] as String? ?? 'pending';
      _kycData = kycData;
      _submittedForReview = kycData['submittedForReview'] == true;
      _kycRejectedAt = rejectedAtRaw is Timestamp
          ? rejectedAtRaw.toDate()
          : rejectedAtRaw is DateTime
              ? rejectedAtRaw
              : null;

      _fullNameController.text = kycData['dealerFullName'] as String? ?? '';
      _idType = kycData['dealerIdType'] as String? ?? _idType;
      _idNumberController.text = kycData['dealerIdNumber'] as String? ?? '';
      _businessNameController.text = kycData['dealerBusinessName'] as String? ?? '';
      _shopUnitController.text = kycData['dealerShopUnit'] as String? ?? '';
      _street1Controller.text = kycData['dealerStreet1'] as String? ?? '';
      _street2Controller.text = kycData['dealerStreet2'] as String? ?? '';
      _pincodeController.text = kycData['dealerPincode'] as String? ?? '';
      _cityController.text = kycData['dealerCity'] as String? ?? '';
      _stateController.text = kycData['dealerState'] as String? ?? '';
      _countryController.text = kycData['dealerCountry'] as String? ?? '';
      if (_street1Controller.text.isEmpty) {
        _street1Controller.text = kycData['dealerShopAddress'] as String? ?? '';
      }
      _gstinController.text = kycData['dealerGstin'] as String? ?? '';
      _alternatePhoneController.text = kycData['dealerAlternatePhone'] as String? ?? '';
      _landmarkController.text = kycData['dealerLandmark'] as String? ?? '';
      _businessCategory = kycData['dealerBusinessCategory'] as String? ?? _businessCategory;
      _declarationAccepted = kycData['dealerDeclarationAccepted'] == true;
      _termsAccepted = kycData['dealerTermsAccepted'] == true;

      _idProofFrontUrl = kycData['dealerIdProofFrontUrl'] as String?;
      _selfieWithIdUrl = kycData['dealerSelfieWithIdUrl'] as String?;
      _shopPhotoUrl = kycData['dealerShopPhotoUrl'] as String?;
      _idProofFrontFile = null;
      _selfieWithIdFile = null;
      _shopPhotoFile = null;
      _loading = false;
    });
  }

  Future<void> _pickImage(void Function(File) onSelected, {ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 65,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null || !mounted) return;
    onSelected(File(file.path));
  }

  Future<void> _pickSelfieWithInstructions() async {
    if (_submitting) return;
    final shouldOpenCamera = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.brandWarm),
            SizedBox(width: 8),
            Text('Selfie Instructions'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please follow before taking selfie:'),
            SizedBox(height: 10),
            Text('1. Hold your ID card next to your face.'),
            SizedBox(height: 4),
            Text('2. Keep your face and ID clearly visible in frame.'),
            SizedBox(height: 4),
            Text('3. Use good lighting and avoid blur/glare.'),
            SizedBox(height: 4),
            Text('4. Ensure ID text and photo are readable.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Front Camera'),
          ),
        ],
      ),
    );

    if (shouldOpenCamera != true || !mounted) return;
    await _pickImage(
      (f) => setState(() => _selfieWithIdFile = f),
      source: ImageSource.camera,
    );
  }

  Future<void> _pickIdProofWithSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take photo from camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickImage(
      (f) => setState(() {
        _idProofFrontFile = f;
        _idProofError = false;
      }),
      source: source,
    );
  }

  String _composeLegacyShopAddress() {
    return [
      _shopUnitController.text.trim(),
      _street1Controller.text.trim(),
      _street2Controller.text.trim(),
      _landmarkController.text.trim(),
    ].where((e) => e.isNotEmpty).join(', ');
  }

  Future<void> _onPincodeChanged(String value) async {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return;
    setState(() => _pincodeLookupLoading = true);
    final result = await PincodeService.lookup(digits);
    if (!mounted) return;
    setState(() {
      _pincodeLookupLoading = false;
      if (result != null) {
        _cityController.text = result.town;
        _stateController.text = result.state;
        _countryController.text = result.country;
      }
    });
  }

  Future<void> _submitForReview() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final hasIdProof =
        _idProofFrontFile != null ||
        (_idProofFrontUrl != null && _idProofFrontUrl!.isNotEmpty);
    setState(() {
      _idProofError = !hasIdProof;
      _declarationError = !_declarationAccepted;
      _termsError = !_termsAccepted;
    });
    if (!valid || !hasIdProof || !_declarationAccepted || !_termsAccepted) {
      return _snack('Please fix the highlighted fields and try again.');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !StorageService.isAvailable || !FirestoreService.isAvailable) {
      return _snack('Unable to submit KYC at the moment. Please try again.');
    }

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'dealerFullName': _fullNameController.text.trim(),
        'dealerIdType': _idType,
        'dealerIdNumber': _idNumberController.text.trim(),
        'dealerBusinessName': _businessNameController.text.trim(),
        'dealerBusinessCategory': _businessCategory,
        'dealerShopUnit': _shopUnitController.text.trim(),
        'dealerStreet1': _street1Controller.text.trim(),
        'dealerStreet2': _street2Controller.text.trim(),
        'dealerPincode': _pincodeController.text.trim(),
        'dealerShopAddress': _composeLegacyShopAddress(),
        'dealerCity': _cityController.text.trim(),
        'dealerState': _stateController.text.trim(),
        'dealerCountry': _countryController.text.trim(),
        'dealerLandmark': _landmarkController.text.trim(),
        'dealerGstin': _gstinController.text.trim(),
        'dealerAlternatePhone': _alternatePhoneController.text.trim(),
        'dealerDeclarationAccepted': true,
        'dealerTermsAccepted': true,
        'submittedForReview': true,
        'submittedAt': FieldValue.serverTimestamp(),
      };

      if (_idProofFrontFile != null) {
        final url = await StorageService.uploadKycDocument(userId: uid, file: _idProofFrontFile!, type: 'dealer_id_front');
        if (url == null) throw Exception('Failed to upload ID proof');
        payload['dealerIdProofFrontUrl'] = url;
      } else {
        payload['dealerIdProofFrontUrl'] = _idProofFrontUrl;
      }

      if (_selfieWithIdFile != null) {
        final url = await StorageService.uploadKycDocument(userId: uid, file: _selfieWithIdFile!, type: 'dealer_selfie_with_id');
        if (url != null) payload['dealerSelfieWithIdUrl'] = url;
      } else if (_selfieWithIdUrl != null) {
        payload['dealerSelfieWithIdUrl'] = _selfieWithIdUrl;
      }

      if (_shopPhotoFile != null) {
        final url = await StorageService.uploadKycDocument(userId: uid, file: _shopPhotoFile!, type: 'dealer_shop_photo');
        if (url != null) payload['dealerShopPhotoUrl'] = url;
      } else if (_shopPhotoUrl != null) {
        payload['dealerShopPhotoUrl'] = _shopPhotoUrl;
      }

      await FirestoreService.users().doc(uid).set({'kycStatus': 'pending', 'kycData': payload}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _status = 'pending';
        _submittedForReview = true;
      });
      _snack('KYC submitted for verification.');
    } catch (e) {
      _snack('Submission failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Widget _input(
    TextEditingController c,
    String l, {
    int maxLines = 1,
    bool requiredField = false,
    TextInputType? keyboardType,
    bool readOnly = false,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) => TextFormField(
        controller: c,
        maxLines: maxLines,
        readOnly: readOnly,
        maxLength: maxLength,
        onChanged: onChanged,
        keyboardType: keyboardType,
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: l,
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(
            color: _kTextSecondary,
            fontWeight: FontWeight.w500,
          ),
          helperStyle: const TextStyle(
            color: _kTextSecondary,
            fontSize: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.brandWarmSoft, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.4),
          ),
        ),
      );

  Widget _dropdown(String label, String value, List<String> values, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : values.first,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.8),
        labelStyle: const TextStyle(
          color: _kTextSecondary,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.brandWarmSoft, width: 1.6),
        ),
      ),
      items: values.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _imageTile({
    required String title,
    required File? file,
    required String? url,
    required VoidCallback onTap,
    bool requiredField = false,
    String? hint,
    bool hasError = false,
  }) {
    final hasImage = file != null || (url != null && url.isNotEmpty);
    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      scale: _submitting ? 1 : 0.999,
      child: InkWell(
        onTap: _submitting ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFE53935)
                  : (hasImage ? const Color(0xFF16A34A) : _kBorder),
              width: hasError || hasImage ? 1.4 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandWarmSoft.withValues(alpha: 0.09),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 82,
                height: 82,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _kBgLight.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: hasImage
                    ? (file != null
                          ? Image.file(file, fit: BoxFit.cover)
                          : Image.network(url!, fit: BoxFit.cover))
                    : const Icon(
                        Icons.cloud_upload_outlined,
                        color: _kTextSecondary,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      requiredField ? '$title *' : title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint ?? 'JPG, PNG up to 5MB',
                      style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasImage ? 'Uploaded successfully' : 'Tap to upload',
                      style: TextStyle(
                        color: hasImage
                            ? const Color(0xFF16A34A)
                            : (hasError
                                  ? const Color(0xFFE53935)
                                  : _kTextSecondary),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hasImage ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: hasImage
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withValues(alpha: 0.64),
                border: Border.all(color: _kBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Step 1/2 • Identity and Business Verification',
                      style: TextStyle(
                        color: _kTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Row(
              children: [
                Icon(Icons.badge_rounded, color: AppColors.brandWarm, size: 20),
                SizedBox(width: 8),
                Text(
                  'Identity Details',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _input(
              _fullNameController,
              'Full Name (as per ID) *',
              requiredField: true,
            ),
            const SizedBox(height: 16),
            _dropdown(
              'ID Type *',
              _idType,
              _idTypes,
              (v) => setState(() => _idType = v),
            ),
            const SizedBox(height: 16),
            _input(_idNumberController, 'ID Number *', requiredField: true),
            const SizedBox(height: 16),
            _imageTile(
              title: 'ID Proof Upload (Front photo)',
              file: _idProofFrontFile,
              url: _idProofFrontUrl,
              requiredField: true,
              hint: 'Use camera or gallery (required)',
              hasError: _idProofError,
              onTap: _pickIdProofWithSource,
            ),
            if (_idProofError) ...[
              const SizedBox(height: 6),
              const Text(
                'Please upload your ID proof.',
                style: TextStyle(color: Color(0xFFE53935), fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            _imageTile(
              title: 'Selfie with ID (Recommended)',
              file: _selfieWithIdFile,
              url: _selfieWithIdUrl,
              hint: 'Use camera for better trust verification',
              onTap: _pickSelfieWithInstructions,
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.storefront_rounded, color: AppColors.brandWarm, size: 20),
                SizedBox(width: 8),
                Text(
                  'Business Details',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _input(_businessNameController, 'Business Name (Optional)'),
            const SizedBox(height: 16),
            _dropdown(
              'Business Category (Optional)',
              _businessCategory,
              _businessCategories,
              (v) => setState(() => _businessCategory = v),
            ),
            const SizedBox(height: 16),
            _input(_shopUnitController, 'Shop No / House No / Flat No *', requiredField: true),
            const SizedBox(height: 16),
            _input(_street1Controller, 'Street 1 *', requiredField: true),
            const SizedBox(height: 16),
            _input(_street2Controller, 'Street 2 (Optional)'),
            const SizedBox(height: 16),
            _input(_landmarkController, 'Landmark (Optional)'),
            const SizedBox(height: 16),
            _input(
              _pincodeController,
              'Pincode *',
              requiredField: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: _onPincodeChanged,
            ),
            if (_pincodeLookupLoading)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Auto-filling city/state/country...',
                      style: TextStyle(fontSize: 12, color: _kTextSecondary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _input(_cityController, 'City *', requiredField: true),
            const SizedBox(height: 16),
            _input(_stateController, 'State *', requiredField: true),
            const SizedBox(height: 16),
            _input(_countryController, 'Country *', requiredField: true),
            const SizedBox(height: 16),
            _input(_gstinController, 'GSTIN (Optional)'),
            const SizedBox(height: 16),
            _input(
              _alternatePhoneController,
              'Alternate Contact Number (Optional)',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _imageTile(
              title: 'Shop Photo (Optional)',
              file: _shopPhotoFile,
              url: _shopPhotoUrl,
              hint: 'Storefront photo builds customer trust',
              onTap: () => _pickImage((f) => setState(() => _shopPhotoFile = f)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Declaration',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary,
              ),
            ),
            CheckboxListTile(
              value: _declarationAccepted,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() {
                      _declarationAccepted = v ?? false;
                      _declarationError = false;
                    }),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.brandWarm,
              title: const Text(
                'I confirm that the details and documents submitted are true and belong to me.',
              ),
            ),
            if (_declarationError)
              const Text(
                'Please accept this declaration.',
                style: TextStyle(color: Color(0xFFE53935), fontSize: 12),
              ),
            CheckboxListTile(
              value: _termsAccepted,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() {
                      _termsAccepted = v ?? false;
                      _termsError = false;
                    }),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.brandWarm,
              title: const Text(
                'I agree to admin KYC review and approval before account actions.',
              ),
            ),
            if (_termsError)
              const Text(
                'Please accept the terms.',
                style: TextStyle(color: Color(0xFFE53935), fontSize: 12),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.64),
                border: Border.all(color: _kBorder),
              ),
              child: const Text(
                'Your data is secure and encrypted.',
                style: TextStyle(
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SaffronGradientPillButton(
              label: 'Submit KYC',
              isLoading: _submitting,
              onPressed: _submitting ? null : _submitForReview,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kycTrustFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          const Text(
            'Your data is secure and encrypted.',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusView(IconData icon, Color accentColor, String title, String subtitle) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: _KycGlassStatusCard(
        accentColor: accentColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.18),
                    AppColors.brandWarmLight.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, size: 44, color: accentColor),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _kTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            _kycTrustFooter(),
          ],
        ),
      ),
    );
  }

  Widget _rejectedView() {
    final reason = _kycData['kycRejectionReason'] as String?;
    final canReapply =
        _kycRejectedAt == null || DateTime.now().difference(_kycRejectedAt!).inDays >= 7;
    final message = reason == null || reason.isEmpty
        ? 'Your KYC submission was rejected. Please review your documents and submit again.'
        : reason;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: _KycGlassStatusCard(
        accentColor: const Color(0xFFE53935),
        borderColor: const Color(0x4DE53935),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0x29E53935),
                    AppColors.brandWarmLight.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(color: const Color(0x66E53935)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x33E53935),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.cancel_rounded, size: 44, color: Color(0xFFE53935)),
            ),
            const SizedBox(height: 22),
            const Text(
              'KYC Rejected',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _kTextPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x33E53935)),
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _kTextSecondary,
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (canReapply)
              _SaffronGradientPillButton(
                label: 'Reapply KYC',
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  await FirestoreService.users().doc(uid).update({
                    'kycStatus': 'pending',
                    'kycData.submittedForReview': false,
                    'kycData.kycRejectionReason': FieldValue.delete(),
                    'kycRejectedAt': FieldValue.delete(),
                  });
                  await _loadStatus();
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'You can reapply 7 days after rejection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _kTextSecondary.withValues(alpha: 0.95),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            _kycTrustFooter(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: AppColors.brandWarm.withValues(alpha: 0.25),
        foregroundColor: _kTextPrimary,
        title: const Text(
          'KYC Verification',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.dealerHome),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandWarm, AppColors.brandWarmLight],
            ),
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.brandWarm,
                strokeWidth: 2.5,
              ),
            )
          : _status == 'verified'
              ? _statusView(Icons.verified_rounded, const Color(0xFF16A34A), 'KYC Approved', 'Your dealer KYC has been approved by admin.')
              : _status == 'rejected'
                  ? _rejectedView()
                  : (_submittedForReview
                      ? _statusView(
                          Icons.schedule_rounded,
                          AppColors.brandWarmSoft,
                          'Waiting for Admin Approval',
                          'Your KYC request is under review. This may take up to 24 hours.',
                        )
                      : _formView()),
    );
  }
}

/// Glass card wrapper for verified / pending / rejected KYC states.
class _KycGlassStatusCard extends StatelessWidget {
  const _KycGlassStatusCard({
    required this.accentColor,
    required this.child,
    this.borderColor,
  });

  final Color accentColor;
  final Color? borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderColor ?? _DealerKycScreenState._kBorder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.58),
            border: Border.all(color: effectiveBorder, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SaffronGradientPillButton extends StatefulWidget {
  const _SaffronGradientPillButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<_SaffronGradientPillButton> createState() =>
      _SaffronGradientPillButtonState();
}

class _SaffronGradientPillButtonState extends State<_SaffronGradientPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    return Listener(
      onPointerDown: (_) {
        if (!disabled) setState(() => _pressed = true);
      },
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed && !disabled ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brandWarm,
                AppColors.brandWarmLight,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x4DEA580C),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FilledButton(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
