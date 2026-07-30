import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';
import '../../shared/services/document_verifier.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/kyc_service.dart';
import '../../shared/services/pincode_service.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/widgets/aadhaar_slots_input.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import 'document_capture_screen.dart';
import 'edit_profile_design.dart';

class TechnicianKycScreen extends StatefulWidget {
  const TechnicianKycScreen({super.key});

  @override
  State<TechnicianKycScreen> createState() => _TechnicianKycScreenState();
}

class _TechnicianKycScreenState extends State<TechnicianKycScreen> {
  bool _loading = true;
  bool _submitting = false;
  double _submitProgress = 0;
  String _submitStage = '';
  String _status = 'pending';
  Map<String, dynamic> _kycData = {};
  bool _submittedForReview = false;
  DateTime? _kycRejectedAt;
  int _currentStep = 0;

  // Aadhaar
  final _aadhaarController = TextEditingController();
  String? _aadhaarRefId;
  bool _aadhaarTestMode = false;
  final _otpController = TextEditingController();
  bool _aadhaarVerified = false;
  bool _otpVerifying = false;
  final _aadhaarNameController = TextEditingController();
  final _aadhaarRelativeController = TextEditingController();
  String? _aadhaarDob;

  // Aadhaar address (as per Aadhaar)
  final _addrHouseFlat = TextEditingController();
  final _addrStreet1 = TextEditingController();
  final _addrStreet2 = TextEditingController();
  final _addrPincode = TextEditingController();
  final _addrTown = TextEditingController();
  final _addrState = TextEditingController();
  final _addrCountry = TextEditingController();

  // Present address
  final _presentHouseFlat = TextEditingController();
  final _presentStreet1 = TextEditingController();
  final _presentStreet2 = TextEditingController();
  final _presentPincode = TextEditingController();
  final _presentTown = TextEditingController();
  final _presentState = TextEditingController();
  final _presentCountry = TextEditingController();
  bool _sameAsAadhaarAddress = false;

  // Relative contacts (2 mandatory)
  final _contact1Name = TextEditingController();
  final _contact1Number = TextEditingController();
  final _contact2Name = TextEditingController();
  final _contact2Number = TextEditingController();

  // PAN (optional)
  final _panController = TextEditingController();
  final _panNameController = TextEditingController();
  final _panDobController = TextEditingController();
  bool _panVerified = false;

  // Liveness
  bool _livenessVerified = false;
  final bool _livenessLoading = false;

  // Aadhaar document images (kept in memory until Submit)
  String? _aadhaarFrontUrl;
  String? _aadhaarBackUrl;
  String? _aadhaarSingleUrl;
  File? _aadhaarFrontFile;
  File? _aadhaarBackFile;
  File? _aadhaarSingleFile;
  bool _aadhaarIsSinglePage = false;
  bool _aadhaarDocUploading = false;

  // PAN document image
  String? _panFrontUrl;
  File? _panFrontFile;
  bool _panDocUploading = false;
  bool _panExpanded = false;

  // Liveness selfie (kept in memory until Submit)
  File? _livenessSelfieFile;

  // Skill certificates
  List<String> _certificateUrls = [];
  List<File> _certificateFiles = [];
  bool _certUploading = false;

  // Technician Agreement (12 terms)
  final List<bool> _termsAccepted = List.filled(12, false);

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _otpController.dispose();
    _aadhaarNameController.dispose();
    _aadhaarRelativeController.dispose();
    _addrHouseFlat.dispose();
    _addrStreet1.dispose();
    _addrStreet2.dispose();
    _addrPincode.dispose();
    _addrTown.dispose();
    _addrState.dispose();
    _addrCountry.dispose();
    _presentHouseFlat.dispose();
    _presentStreet1.dispose();
    _presentStreet2.dispose();
    _presentPincode.dispose();
    _presentTown.dispose();
    _presentState.dispose();
    _presentCountry.dispose();
    _contact1Name.dispose();
    _contact1Number.dispose();
    _contact2Name.dispose();
    _contact2Number.dispose();
    _panController.dispose();
    _panNameController.dispose();
    _panDobController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      setState(() => _loading = false);
      return;
    }
    final doc = await FirestoreService.users()
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    final data = doc.data();
    setState(() {
      _status = data?['kycStatus'] as String? ?? 'pending';
      _kycData = data?['kycData'] as Map<String, dynamic>? ?? {};
      _submittedForReview = _kycData['submittedForReview'] == true;
      final rejectedAt = data?['kycRejectedAt'];
      _kycRejectedAt = rejectedAt is Timestamp
          ? rejectedAt.toDate()
          : (rejectedAt as DateTime?);
      _aadhaarVerified = _kycData['aadhaarVerified'] == true;
      _aadhaarNameController.text = _kycData['aadhaarName'] as String? ?? '';
      _aadhaarRelativeController.text =
          _kycData['aadhaarRelativeName'] as String? ?? '';
      _addrHouseFlat.text =
          _kycData['aadhaarAddressHouseFlat'] as String? ?? '';
      _addrStreet1.text =
          _kycData['aadhaarAddressStreet1'] as String? ??
          _kycData['aadhaarAddress'] as String? ??
          '';
      _addrStreet2.text = _kycData['aadhaarAddressStreet2'] as String? ?? '';
      _addrPincode.text = _kycData['aadhaarAddressPincode'] as String? ?? '';
      _addrTown.text = _kycData['aadhaarAddressTown'] as String? ?? '';
      _addrState.text = _kycData['aadhaarAddressState'] as String? ?? '';
      _addrCountry.text =
          _kycData['aadhaarAddressCountry'] as String? ?? 'India';
      _presentHouseFlat.text =
          _kycData['presentAddressHouseFlat'] as String? ?? '';
      _presentStreet1.text = _kycData['presentAddressStreet1'] as String? ?? '';
      _presentStreet2.text = _kycData['presentAddressStreet2'] as String? ?? '';
      _presentPincode.text = _kycData['presentAddressPincode'] as String? ?? '';
      _presentTown.text = _kycData['presentAddressTown'] as String? ?? '';
      _presentState.text = _kycData['presentAddressState'] as String? ?? '';
      _presentCountry.text =
          _kycData['presentAddressCountry'] as String? ?? 'India';
      _sameAsAadhaarAddress = false;
      final contacts = _kycData['relativeContacts'] as List<dynamic>? ?? [];
      if (contacts.isNotEmpty) {
        final c1 = contacts[0] as Map<String, dynamic>?;
        _contact1Name.text = c1?['name'] as String? ?? '';
        _contact1Number.text = c1?['number'] as String? ?? '';
      }
      if (contacts.length >= 2) {
        final c2 = contacts[1] as Map<String, dynamic>?;
        _contact2Name.text = c2?['name'] as String? ?? '';
        _contact2Number.text = c2?['number'] as String? ?? '';
      }
      _panVerified = _kycData['panVerified'] == true;
      _livenessVerified =
          _kycData['livenessVerified'] == true ||
          (_kycData['livenessSelfieUrl'] != null &&
              _kycData['livenessSelfieUrl'].toString().isNotEmpty);
      _aadhaarFrontUrl = _kycData['aadhaarFrontUrl'] as String?;
      _aadhaarBackUrl = _kycData['aadhaarBackUrl'] as String?;
      _aadhaarSingleUrl = _kycData['aadhaarSingleUrl'] as String?;
      _aadhaarFrontFile = null;
      _aadhaarBackFile = null;
      _aadhaarSingleFile = null;
      _aadhaarIsSinglePage = _aadhaarSingleUrl != null;
      _panFrontUrl = _kycData['panFrontUrl'] as String?;
      _panFrontFile = null;
      _livenessSelfieFile = null;
      _certificateFiles = [];
      _panExpanded =
          _panVerified ||
          _panFrontUrl != null ||
          _panController.text.trim().isNotEmpty;
      _certificateUrls = List<String>.from(_kycData['skillCertificates'] ?? []);
      final draftStep = (_kycData['draftStep'] as num?)?.toInt();
      _currentStep = draftStep == null ? 0 : (draftStep - 1).clamp(0, 5);
      _loading = false;
    });
  }

  Future<void> _aadhaarSendOtp() async {
    final aadhaar = _aadhaarController.text.replaceAll(RegExp(r'\D'), '');
    if (aadhaar.length != 12) {
      _showSnack('Enter valid 12-digit Aadhaar number');
      return;
    }
    _showSnack('Sending OTP...');
    final result = await KycService.aadhaarGenerateOtp(aadhaar);
    if (!mounted) return;
    if (result.success) {
      final respData = result.data?['data'] as Map<String, dynamic>?;
      final refId = respData?['reference_id']?.toString();
      final testMode = respData?['test_mode'] == true;
      setState(() {
        _aadhaarRefId = refId;
        _aadhaarTestMode = testMode;
      });
      _showSnack(
        testMode
            ? 'Test mode: Use OTP 123456 to verify'
            : 'OTP sent to Aadhaar-linked mobile',
      );
    } else {
      final err = result.error ?? 'Failed to send OTP';
      _showSnack(
        err.toLowerCase().contains('test api key')
            ? 'OTP service is in test mode. Please try again or contact support.'
            : err,
      );
    }
  }

  Future<void> _aadhaarVerifyOtp() async {
    if (_otpVerifying) return;
    if (_aadhaarRefId == null) {
      _showSnack('Send OTP first');
      return;
    }
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showSnack('Enter 6-digit OTP');
      return;
    }
    setState(() => _otpVerifying = true);
    _showSnack('Verifying...');
    final result = await KycService.aadhaarVerifyOtp(
      referenceId: _aadhaarRefId!,
      otp: otp,
    );
    if (!mounted) return;
    if (result.success) {
      final apiData = result.data?['data'] as Map<String, dynamic>?;
      final fullAddr = apiData?['full_address'] as String? ?? '';
      setState(() {
        _aadhaarNameController.text = apiData?['name'] as String? ?? '';
        _aadhaarRelativeController.text = apiData?['care_of'] as String? ?? '';
        _aadhaarDob = apiData?['date_of_birth'] as String?;
        if (fullAddr.isNotEmpty) _addrStreet1.text = fullAddr;
        _aadhaarVerified = true;
        _aadhaarRefId = null;
        _aadhaarTestMode = false;
        _otpController.clear();
      });
      if (fullAddr.isNotEmpty) {
        final pincodeMatch = RegExp(r'\b(\d{6})\b').firstMatch(fullAddr);
        if (pincodeMatch != null) {
          _addrPincode.text = pincodeMatch.group(1)!;
          final pinResult = await PincodeService.lookup(pincodeMatch.group(1)!);
          if (pinResult != null && mounted) {
            setState(() {
              _addrTown.text = pinResult.town;
              _addrState.text = pinResult.state;
              _addrCountry.text = pinResult.country;
            });
          }
        }
      }
      _showSnack('Aadhaar verified');
    } else {
      _showSnack(result.error ?? 'Verification failed');
    }
    if (mounted) setState(() => _otpVerifying = false);
  }

  Future<void> _panVerify() async {
    final pan = _panController.text.toUpperCase().replaceAll(RegExp(r'\s'), '');
    final name = _panNameController.text.trim();
    final dob = _panDobController.text.trim();
    if (pan.length != 10) {
      _showSnack('Enter valid 10-character PAN');
      return;
    }
    if (name.isEmpty || dob.isEmpty) {
      _showSnack('Enter full name and date of birth');
      return;
    }
    _showSnack('Verifying PAN...');
    final result = await KycService.panVerify(
      panNumber: pan,
      fullName: name,
      dateOfBirth: dob,
    );
    if (!mounted) return;
    if (result.success) {
      setState(() => _panVerified = true);
      _showSnack('PAN verified');
    } else {
      _showSnack(result.error ?? 'PAN verification failed');
    }
  }

  Future<void> _captureLiveness() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (xfile == null || !mounted) return;
    setState(() {
      _livenessSelfieFile = File(xfile.path);
      _livenessVerified = true;
      if (_currentStep == 0) _currentStep = 1;
    });
    _showSnack('Selfie captured. Moving to next step...');
  }

  Future<void> _captureAadhaarDoc(String type) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('Please sign in');
      return;
    }
    final sideLabel = type == 'single'
        ? 'Single page'
        : (type == 'front' ? 'Front' : 'Back');
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => DocumentCaptureScreen(
          documentType: 'aadhaar',
          sideLabel: sideLabel,
          onCaptured: (file) => _processAadhaarDoc(file, type, uid),
        ),
      ),
    );
  }

  Future<void> _processAadhaarDoc(File file, String type, String uid) async {
    setState(() => _aadhaarDocUploading = true);
    try {
      final err = type == 'front'
          ? await DocumentVerifier.verifyAadhaarFront(file)
          : type == 'back'
          ? await DocumentVerifier.verifyAadhaarBack(file)
          : await DocumentVerifier.verifyAadhaar(file);
      if (err != null) {
        if (err.contains('MissingPluginException')) {
          if (mounted) _showSnack('Will be verified by admin');
        } else {
          if (mounted) _showSnack(err);
          return;
        }
      }
      if (!mounted) return;
      if (type == 'front') {
        setState(() {
          _aadhaarFrontFile = file;
          _aadhaarFrontUrl = null;
        });
      } else if (type == 'back') {
        setState(() {
          _aadhaarBackFile = file;
          _aadhaarBackUrl = null;
        });
      } else {
        setState(() {
          _aadhaarSingleFile = file;
          _aadhaarSingleUrl = null;
          _aadhaarIsSinglePage = true;
          _aadhaarFrontFile = null;
          _aadhaarBackFile = null;
          _aadhaarFrontUrl = null;
          _aadhaarBackUrl = null;
        });
      }
      if (mounted) {
        _showSnack('Aadhaar ${type == 'single' ? 'card' : type} captured');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _aadhaarDocUploading = false);
    }
  }

  Future<void> _capturePanDoc(String type) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('Please sign in');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => DocumentCaptureScreen(
          documentType: 'pan',
          sideLabel: 'PAN card',
          onCaptured: (file) => _processPanDoc(file, uid),
        ),
      ),
    );
  }

  Future<void> _processPanDoc(File file, String uid) async {
    setState(() => _panDocUploading = true);
    try {
      final err = await DocumentVerifier.verifyPan(file);
      if (err != null) {
        if (err.contains('MissingPluginException')) {
          if (mounted) _showSnack('Will be verified by admin');
        } else {
          if (mounted) _showSnack(err);
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _panFrontFile = file;
        _panFrontUrl = null;
      });
      if (mounted) _showSnack('PAN card captured');
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _panDocUploading = false);
    }
  }

  Future<void> _addCertificate() async {
    setState(() => _certUploading = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
      );
      if (xfile == null || !mounted) return;
      setState(() {
        _certificateFiles = [..._certificateFiles, File(xfile.path)];
      });
      if (mounted) _showSnack('Certificate added');
    } finally {
      if (mounted) setState(() => _certUploading = false);
    }
  }

  bool get _aadhaarDocComplete => _aadhaarIsSinglePage
      ? (_aadhaarSingleUrl != null || _aadhaarSingleFile != null)
      : ((_aadhaarFrontUrl != null || _aadhaarFrontFile != null) &&
            (_aadhaarBackUrl != null || _aadhaarBackFile != null));

  bool get _aadhaarDetailsComplete =>
      _aadhaarNameController.text.trim().isNotEmpty &&
      _aadhaarRelativeController.text.trim().isNotEmpty &&
      _isAddressComplete(
        _addrHouseFlat,
        _addrStreet1,
        _addrPincode,
        _addrTown,
        _addrState,
        _addrCountry,
      ) &&
      _isAddressComplete(
        _presentHouseFlat,
        _presentStreet1,
        _presentPincode,
        _presentTown,
        _presentState,
        _presentCountry,
      );

  bool get _contactsComplete =>
      _isContactValid(_contact1Name, _contact1Number) &&
      _isContactValid(_contact2Name, _contact2Number);

  bool get _panAndCertificatesComplete =>
      !_panVerified || _panFrontUrl != null || _panFrontFile != null;

  bool get _agreementComplete => _termsAccepted.every((v) => v);

  bool _isStepComplete(int step) {
    switch (step) {
      case 0:
        return _livenessVerified;
      case 1:
        return _aadhaarVerified && _aadhaarDocComplete;
      case 2:
        return _aadhaarDetailsComplete;
      case 3:
        return _contactsComplete;
      case 4:
        return _panAndCertificatesComplete;
      case 5:
        return _agreementComplete;
      default:
        return false;
    }
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return 'Selfie';
      case 1:
        return 'Aadhaar + OTP';
      case 2:
        return 'Address';
      case 3:
        return 'Contacts';
      case 4:
        return 'PAN & Certificates';
      case 5:
        return 'Agreement';
      default:
        return '';
    }
  }

  String? _stepErrorMessage(int step) {
    switch (step) {
      case 0:
        return _livenessVerified ? null : 'Please capture a selfie to continue.';
      case 1:
        if (!_aadhaarVerified) return 'Please complete Aadhaar OTP verification.';
        if (!_aadhaarDocComplete) return 'Please add Aadhaar document photo(s).';
        return null;
      case 2:
        return _aadhaarDetailsComplete ? null : 'Please complete required address details.';
      case 3:
        return _contactsComplete ? null : 'Please add 2 valid relative contacts.';
      case 4:
        return _panAndCertificatesComplete
            ? null
            : 'PAN is verified but PAN card photo is missing.';
      case 5:
        return _agreementComplete ? null : 'Please accept all agreement terms.';
      default:
        return 'Complete this step to continue.';
    }
  }

  Future<void> _saveAndResumeLater() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirestoreService.users().doc(uid).set({
        'kycData': {
          ..._kycData,
          'draftStep': _currentStep + 1,
          'draftSavedAt': FieldValue.serverTimestamp(),
          'aadhaarName': _aadhaarNameController.text.trim(),
          'aadhaarRelativeName': _aadhaarRelativeController.text.trim(),
          'aadhaarAddressHouseFlat': _addrHouseFlat.text.trim(),
          'aadhaarAddressStreet1': _addrStreet1.text.trim(),
          'aadhaarAddressStreet2': _addrStreet2.text.trim(),
          'aadhaarAddressPincode': _addrPincode.text.trim(),
          'aadhaarAddressTown': _addrTown.text.trim(),
          'aadhaarAddressState': _addrState.text.trim(),
          'aadhaarAddressCountry': _addrCountry.text.trim(),
          'presentAddressHouseFlat': _presentHouseFlat.text.trim(),
          'presentAddressStreet1': _presentStreet1.text.trim(),
          'presentAddressStreet2': _presentStreet2.text.trim(),
          'presentAddressPincode': _presentPincode.text.trim(),
          'presentAddressTown': _presentTown.text.trim(),
          'presentAddressState': _presentState.text.trim(),
          'presentAddressCountry': _presentCountry.text.trim(),
          'relativeContacts': [
            {
              'name': _contact1Name.text.trim(),
              'number': _contact1Number.text.replaceAll(RegExp(r'\D'), ''),
            },
            {
              'name': _contact2Name.text.trim(),
              'number': _contact2Number.text.replaceAll(RegExp(r'\D'), ''),
            },
          ],
          'panVerified': _panVerified,
          'livenessVerified': _livenessVerified,
          'aadhaarVerified': _aadhaarVerified,
        },
      }, SetOptions(merge: true));
      if (mounted) _showSnack('Progress saved. You can resume later.');
    } catch (_) {
      if (mounted) _showSnack('Unable to save draft right now.');
    }
  }

  bool _isAddressComplete(
    TextEditingController house,
    TextEditingController street1,
    TextEditingController pincode,
    TextEditingController town,
    TextEditingController state,
    TextEditingController country,
  ) =>
      house.text.trim().isNotEmpty &&
      street1.text.trim().isNotEmpty &&
      pincode.text.replaceAll(RegExp(r'\D'), '').length == 6 &&
      town.text.trim().isNotEmpty &&
      state.text.trim().isNotEmpty &&
      country.text.trim().isNotEmpty;

  bool _isContactValid(
    TextEditingController name,
    TextEditingController number,
  ) =>
      name.text.trim().isNotEmpty &&
      number.text.replaceAll(RegExp(r'\D'), '').length == 10;

  String _buildFullAddress(
    TextEditingController house,
    TextEditingController street1,
    TextEditingController street2,
    TextEditingController pincode,
    TextEditingController town,
    TextEditingController state,
    TextEditingController country,
  ) {
    final parts = <String>[
      house.text.trim(),
      street1.text.trim(),
      if (street2.text.trim().isNotEmpty) street2.text.trim(),
      '${pincode.text.trim()} ${town.text.trim()}',
      state.text.trim(),
      country.text.trim(),
    ];
    return parts.where((p) => p.isNotEmpty).join(', ');
  }

  Future<void> _lookupPincode(
    TextEditingController pincode,
    TextEditingController town,
    TextEditingController state,
    TextEditingController country,
  ) async {
    final digits = pincode.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) return;
    final result = await PincodeService.lookup(digits);
    if (result != null && mounted) {
      setState(() {
        town.text = result.town;
        state.text = result.state;
        country.text = result.country;
      });
    }
  }

  void _copyAadhaarToPresentAddress() {
    setState(() {
      _presentHouseFlat.text = _addrHouseFlat.text;
      _presentStreet1.text = _addrStreet1.text;
      _presentStreet2.text = _addrStreet2.text;
      _presentPincode.text = _addrPincode.text;
      _presentTown.text = _addrTown.text;
      _presentState.text = _addrState.text;
      _presentCountry.text = _addrCountry.text;
      _sameAsAadhaarAddress = true;
    });
  }

  Future<void> _pickContact(int index) async {
    if (!mounted) return;
    _showSnack(
      'Phone book import is disabled. Please enter contact details manually.',
    );
  }

  Future<void> _submitForAdmin() async {
    if (_submitting) return;
    if (!_aadhaarVerified || !_livenessVerified) {
      _showSnack('Complete Aadhaar and Selfie verification first');
      return;
    }
    if (!_aadhaarDocComplete) {
      _showSnack(
        'Please capture Aadhaar card photos (front + back or single page)',
      );
      return;
    }
    if (_aadhaarNameController.text.trim().isEmpty) {
      _showSnack('Please add your full name');
      return;
    }
    if (_aadhaarRelativeController.text.trim().isEmpty) {
      _showSnack(
        'Please add relative name (e.g. Father\'s name, Husband\'s name, Mother\'s name as per Aadhaar)',
      );
      return;
    }
    if (!_isAddressComplete(
      _addrHouseFlat,
      _addrStreet1,
      _addrPincode,
      _addrTown,
      _addrState,
      _addrCountry,
    )) {
      _showSnack(
        'Please complete Aadhaar address (house, street, pincode, town, state, country)',
      );
      return;
    }
    if (!_isAddressComplete(
      _presentHouseFlat,
      _presentStreet1,
      _presentPincode,
      _presentTown,
      _presentState,
      _presentCountry,
    )) {
      _showSnack('Please complete Present address');
      return;
    }
    if (!_isContactValid(_contact1Name, _contact1Number) ||
        !_isContactValid(_contact2Name, _contact2Number)) {
      _showSnack(
        'Please add 2 relative contacts with name and 10-digit number',
      );
      return;
    }
    if (_panVerified && _panFrontUrl == null && _panFrontFile == null) {
      _showSnack('Please capture PAN card front photo');
      return;
    }
    if (!_termsAccepted.every((v) => v)) {
      _showSnack('Please accept all terms and conditions');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (!StorageService.isAvailable) {
      _showSnack('Storage unavailable. Please try again.');
      return;
    }
    _showSnack('Submitting...');
    try {
      if (mounted) {
        setState(() {
          _submitting = true;
          _submitProgress = 0.06;
          _submitStage = 'Preparing documents...';
        });
      }
      final aadhaarAddr = _buildFullAddress(
        _addrHouseFlat,
        _addrStreet1,
        _addrStreet2,
        _addrPincode,
        _addrTown,
        _addrState,
        _addrCountry,
      );
      final presentAddr = _buildFullAddress(
        _presentHouseFlat,
        _presentStreet1,
        _presentStreet2,
        _presentPincode,
        _presentTown,
        _presentState,
        _presentCountry,
      );
      final kycData = <String, dynamic>{
        'aadhaarVerified': true,
        'aadhaarName': _aadhaarNameController.text.trim(),
        'aadhaarRelativeName': _aadhaarRelativeController.text.trim(),
        'aadhaarAddress': aadhaarAddr,
        'aadhaarAddressHouseFlat': _addrHouseFlat.text.trim(),
        'aadhaarAddressStreet1': _addrStreet1.text.trim(),
        'aadhaarAddressStreet2': _addrStreet2.text.trim(),
        'aadhaarAddressPincode': _addrPincode.text.trim(),
        'aadhaarAddressTown': _addrTown.text.trim(),
        'aadhaarAddressState': _addrState.text.trim(),
        'aadhaarAddressCountry': _addrCountry.text.trim(),
        'presentAddress': presentAddr,
        'presentAddressHouseFlat': _presentHouseFlat.text.trim(),
        'presentAddressStreet1': _presentStreet1.text.trim(),
        'presentAddressStreet2': _presentStreet2.text.trim(),
        'presentAddressPincode': _presentPincode.text.trim(),
        'presentAddressTown': _presentTown.text.trim(),
        'presentAddressState': _presentState.text.trim(),
        'presentAddressCountry': _presentCountry.text.trim(),
        'relativeContacts': [
          {
            'name': _contact1Name.text.trim(),
            'number': _contact1Number.text.replaceAll(RegExp(r'\D'), ''),
          },
          {
            'name': _contact2Name.text.trim(),
            'number': _contact2Number.text.replaceAll(RegExp(r'\D'), ''),
          },
        ],
        'livenessVerified': true,
        'submittedForReview': true,
        'submittedAt': FieldValue.serverTimestamp(),
      };
      if (_aadhaarDob != null) kycData['aadhaarDob'] = _aadhaarDob;
      if (_aadhaarIsSinglePage) {
        if (_aadhaarSingleFile != null) {
          _setSubmitProgress(0.20, 'Uploading Aadhaar document...');
          final url = await StorageService.uploadKycDocument(
            userId: uid,
            file: _aadhaarSingleFile!,
            type: 'aadhaar_single',
          );
          if (url == null) throw Exception('Aadhaar upload failed');
          kycData['aadhaarSingleUrl'] = url;
          kycData.remove('aadhaarFrontUrl');
          kycData.remove('aadhaarBackUrl');
        } else if (_aadhaarSingleUrl != null) {
          kycData['aadhaarSingleUrl'] = _aadhaarSingleUrl;
        }
      } else {
        if (_aadhaarFrontFile != null) {
          _setSubmitProgress(0.20, 'Uploading Aadhaar front...');
          final url = await StorageService.uploadKycDocument(
            userId: uid,
            file: _aadhaarFrontFile!,
            type: 'aadhaar_front',
          );
          if (url == null) throw Exception('Aadhaar front upload failed');
          kycData['aadhaarFrontUrl'] = url;
        } else if (_aadhaarFrontUrl != null) {
          kycData['aadhaarFrontUrl'] = _aadhaarFrontUrl;
        }
        if (_aadhaarBackFile != null) {
          _setSubmitProgress(0.33, 'Uploading Aadhaar back...');
          final url = await StorageService.uploadKycDocument(
            userId: uid,
            file: _aadhaarBackFile!,
            type: 'aadhaar_back',
          );
          if (url == null) throw Exception('Aadhaar back upload failed');
          kycData['aadhaarBackUrl'] = url;
        } else if (_aadhaarBackUrl != null) {
          kycData['aadhaarBackUrl'] = _aadhaarBackUrl;
        }
      }
      if (_livenessSelfieFile != null) {
        _setSubmitProgress(0.46, 'Uploading selfie...');
        final url = await StorageService.uploadKycDocument(
          userId: uid,
          file: _livenessSelfieFile!,
          type: 'selfie',
        );
        if (url == null) throw Exception('Selfie upload failed');
        kycData['livenessSelfieUrl'] = url;
      }
      if (_panFrontFile != null) {
        _setSubmitProgress(0.56, 'Uploading PAN...');
        final url = await StorageService.uploadKycDocument(
          userId: uid,
          file: _panFrontFile!,
          type: 'pan_front',
        );
        if (url == null) throw Exception('PAN upload failed');
        kycData['panFrontUrl'] = url;
      } else if (_panFrontUrl != null && _panVerified) {
        kycData['panFrontUrl'] = _panFrontUrl;
      }
      if (_panVerified) {
        kycData['panVerified'] = true;
        kycData['panNumber'] = _panController.text.toUpperCase().replaceAll(
          RegExp(r'\s'),
          '',
        );
      }
      final certUrls = <String>[..._certificateUrls];
      final certCount = _certificateFiles.length;
      var certIndex = 0;
      for (final f in _certificateFiles) {
        certIndex += 1;
        final p = 0.64 + ((certIndex / (certCount == 0 ? 1 : certCount)) * 0.20);
        _setSubmitProgress(p.clamp(0.64, 0.84), 'Uploading certificates ($certIndex/$certCount)...');
        final url = await StorageService.uploadKycDocument(
          userId: uid,
          file: f,
          type: 'cert',
        );
        if (url != null) certUrls.add(url);
      }
      if (certUrls.isNotEmpty) {
        kycData['skillCertificates'] = certUrls;
      }
      _setSubmitProgress(0.92, 'Finalizing submission...');
      await FirestoreService.users().doc(uid).set({
        'kycData': kycData,
        'kycStatus': 'pending',
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitProgress = 0;
          _submitStage = '';
          _status = 'pending';
          _submittedForReview = true;
          _loading = false;
        });
        _showSnack('Submitted for verification');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitProgress = 0;
          _submitStage = '';
        });
      }
      if (mounted) _showSnack('${AppConstants.errorGeneric} $e');
    }
  }

  void _setSubmitProgress(double value, String stage) {
    if (!mounted) return;
    setState(() {
      _submitProgress = value;
      _submitStage = stage;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return TechnicianLightScope(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: TechnicianGlassAppBar(
          title: 'KYC Verification',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.go(RouteNames.technicianHome),
          ),
        ),
        body: TechnicianGlassBackground(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.brandWarmLight,
                    strokeWidth: 2,
                  ),
                )
              : _status == 'verified'
              ? _buildVerifiedView()
              : _status == 'pending' && _submittedForReview
              ? _buildWaitingForApprovalView()
              : _status == 'rejected'
              ? _buildRejectedView()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStatusBanner(),
                            const SizedBox(height: 14),
                            _buildWizardProgress(),
                            const SizedBox(height: 14),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: _buildCurrentStepCard(),
                            ),
                            const SizedBox(height: 12),
                            TechnicianGlassCard(
                              radius: TechnicianUiTokens.rLg,
                              blurSigma: 25,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_rounded, size: 16, color: AppColors.brandWarmDark),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Your data is secure and encrypted',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: TechnicianUiTokens.labelSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    if (_currentStep != 1)
                      SafeArea(
                      top: false,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          bottomPadding + 12,
                        ),
                        color: Colors.white.withValues(alpha: 0.92),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                TextButton(
                                  onPressed: _submitting ? null : _saveAndResumeLater,
                                  child: const Text('Save & Resume Later'),
                                ),
                                const Spacer(),
                                if (_currentStep > 0)
                                  TextButton(
                                    onPressed: _submitting ? null : () =>
                                        setState(() => _currentStep -= 1),
                                    child: const Text('Back'),
                                  ),
                              ],
                            ),
                            if (_submitting) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 7,
                                  value: _submitProgress <= 0 ? null : _submitProgress,
                                  color: AppColors.brandWarmDark,
                                  backgroundColor: AppColors.brandWarmLight.withValues(alpha: 0.20),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _submitStage.isNotEmpty ? _submitStage : 'Submitting...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: TechnicianUiTokens.labelSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (_currentStep != 0) ...[
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submitting ? null : () async {
                                    final err = _stepErrorMessage(_currentStep);
                                    if (err != null) {
                                      _showSnack(err);
                                      setState(() {});
                                      return;
                                    }
                                    if (_currentStep == 5) {
                                      await _submitForAdmin();
                                      return;
                                    }
                                    _showSnack('${_stepTitle(_currentStep)} completed');
                                    setState(() => _currentStep += 1);
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: AppColors.brandWarmLight,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        EditProfileDesign.radiusMd,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _currentStep == 5
                                        ? 'Submit for Verification'
                                        : 'Continue',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildVerifiedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_rounded, size: 72, color: AppColors.success)
                .animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut)
                .fadeIn(),
            const SizedBox(height: 24),
            Text(
              'KYC Approved',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: EditProfileDesign.textHeadline,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your verification is complete.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: EditProfileDesign.textBody,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForApprovalView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_rounded, size: 80, color: AppColors.warning)
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 400.ms)
                .then()
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.05, 1.05),
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                )
                .then()
                .scale(
                  begin: const Offset(1.05, 1.05),
                  end: const Offset(1, 1),
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 24),
            Text(
              'Waiting for Admin Approval',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: EditProfileDesign.textHeadline,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Approval may take up to 24 hours.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: EditProfileDesign.textBody,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will be notified once your KYC is reviewed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: EditProfileDesign.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedView() {
    final canReapply =
        _kycRejectedAt != null &&
        DateTime.now().difference(_kycRejectedAt!).inDays >= 7;
    final reason = _kycData['kycRejectionReason'] as String?;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_rounded, size: 72, color: AppColors.error)
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 24),
            Text(
              'KYC Rejected',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: EditProfileDesign.textHeadline,
              ),
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: EditProfileDesign.textHeadline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: EditProfileDesign.textBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              canReapply
                  ? 'You can reapply for KYC verification now.'
                  : 'You can reapply after 1 week from the rejection date.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: EditProfileDesign.textBody,
              ),
            ),
            if (canReapply) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  await FirestoreService.users().doc(uid).update({
                    'kycStatus': 'pending',
                    'kycData.submittedForReview': false,
                    'kycData.kycRejectionReason': FieldValue.delete(),
                    'kycRejectedAt': FieldValue.delete(),
                  });
                  _loadStatus();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  backgroundColor: AppColors.brandWarmLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Reapply for KYC',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (_status) {
      case 'verified':
        statusColor = AppColors.success;
        statusText = 'KYC Approved';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusText = 'KYC Rejected';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = AppColors.brandWarmDark;
        statusText = 'Pending verification';
        statusIcon = Icons.schedule_rounded;
    }
    return Row(
      children: [
        Icon(statusIcon, size: 18, color: statusColor),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _buildWizardProgress() {
    final completedCount = List.generate(6, (i) => i)
        .where((i) => _isStepComplete(i))
        .length;
    return TechnicianGlassCard(
      key: const ValueKey('kyc_progress'),
      radius: TechnicianUiTokens.rXl,
      blurSigma: 28,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${_currentStep + 1} of 6',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: TechnicianUiTokens.labelPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _stepTitle(_currentStep),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: TechnicianUiTokens.labelSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(6, (i) {
              final done = _isStepComplete(i);
              final active = i == _currentStep;
              final color = done
                  ? AppColors.success
                  : active
                  ? AppColors.brandWarmLight
                  : TechnicianUiTokens.separator;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(right: i == 5 ? 0 : 6),
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            '$completedCount/6 completed',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: TechnicianUiTokens.labelSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepCard() {
    Widget stepChild;
    switch (_currentStep) {
      case 0:
        stepChild = _buildLivenessStep();
        break;
      case 1:
        stepChild = _buildAadhaarStep();
        break;
      case 2:
        stepChild = _buildAddressStep();
        break;
      case 3:
        stepChild = _buildContactsStep();
        break;
      case 4:
        stepChild = _buildPanCertificatesStep();
        break;
      default:
        stepChild = _buildTermsStep();
    }
    return TechnicianGlassCard(
      key: ValueKey('kyc_step_$_currentStep'),
      radius: TechnicianUiTokens.rXl,
      blurSigma: 24,
      padding: const EdgeInsets.all(16),
      child: stepChild,
    );
  }

  Widget _buildAadhaarDocStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Capture with camera only. Wrong document will be rejected immediately.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: EditProfileDesign.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        if (!_aadhaarIsSinglePage) ...[
          Row(
            children: [
              Expanded(
                child: _DocCaptureTile(
                  label: 'Front',
                  url: _aadhaarFrontUrl,
                  file: _aadhaarFrontFile,
                  loading: _aadhaarDocUploading,
                  onTap: () => _captureAadhaarDoc('front'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DocCaptureTile(
                  label: 'Back',
                  url: _aadhaarBackUrl,
                  file: _aadhaarBackFile,
                  loading: _aadhaarDocUploading,
                  onTap: () => _captureAadhaarDoc('back'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _aadhaarDocUploading
                ? null
                : () => _captureAadhaarDoc('single'),
            child: Text(
              'I have single-page Aadhaar',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
          ),
        ] else ...[
          _DocCaptureTile(
            label: 'Single page Aadhaar',
            url: _aadhaarSingleUrl,
            file: _aadhaarSingleFile,
            loading: _aadhaarDocUploading,
            onTap: () => _captureAadhaarDoc('single'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _aadhaarDocUploading
                ? null
                : () => setState(() {
                    _aadhaarIsSinglePage = false;
                    _aadhaarSingleUrl = null;
                    _aadhaarSingleFile = null;
                  }),
            child: Text(
              'Switch to front + back',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAadhaarStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AadhaarSlotsInput(
          controller: _aadhaarController,
          validator: (v) {
            final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (digits.length != 12) return 'Enter valid 12-digit Aadhaar';
            return null;
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Aadhaar card photos',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: EditProfileDesign.textHeadline,
          ),
        ),
        const SizedBox(height: 12),
        _buildAadhaarDocStep(),
        const SizedBox(height: 20),
        Text(
          'Verify via OTP',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: EditProfileDesign.textHeadline,
          ),
        ),
        const SizedBox(height: 12),
        if (_aadhaarRefId == null)
          OutlinedButton.icon(
            onPressed: _aadhaarSendOtp,
            icon: const Icon(Icons.sms_rounded, size: 18),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: AppColors.brandWarmDark,
              side: BorderSide(
                color: AppColors.brandWarmLight.withValues(alpha: 0.75),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
              ),
            ),
            label: Text(
              'Send OTP',
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _otpController,
          enabled: _aadhaarRefId != null,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: InputDecoration(
            labelText: 'Enter OTP',
            hintText: _aadhaarRefId != null
                ? (_aadhaarTestMode ? '123456 (test)' : '6-digit OTP from SMS')
                : 'Tap Send OTP first',
            helperText: _aadhaarTestMode ? 'Test mode: enter 123456' : null,
            counterText: '',
            filled: true,
            fillColor: EditProfileDesign.surfaceBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) async {
            if (v.trim().length == 6 &&
                _aadhaarRefId != null &&
                !_aadhaarVerified &&
                !_otpVerifying) {
              await _aadhaarVerifyOtp();
            }
          },
        ),
        if (_aadhaarVerified) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  'OTP verified successfully',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandWarmSoft.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (_aadhaarRefId == null) {
                  _showSnack('Send OTP first');
                  return;
                }
                if (!_aadhaarVerified) {
                  await _aadhaarVerifyOtp();
                }
                if (_aadhaarVerified && _aadhaarDocComplete) {
                  if (!mounted) return;
                  _showSnack('Aadhaar step completed');
                  setState(() => _currentStep = 2);
                  return;
                }
                if (!_aadhaarDocComplete) {
                  _showSnack('Please add Aadhaar card photo(s) to continue.');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
                  ),
                ),
                child: Center(
                  child: Text(
                    _otpVerifying ? 'Verifying...' : 'Verify & Continue',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _currentStep = 0),
            child: Text(
              'Back',
              style: GoogleFonts.plusJakartaSans(
                color: TechnicianUiTokens.labelSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAadhaarDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_aadhaarVerified)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Auto-filled from Aadhaar. You can edit if needed.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: EditProfileDesign.textMuted,
              ),
            ),
          ),
        TextField(
          controller: _aadhaarNameController,
          decoration: _inputDecoration(
            'Full Name *',
            'As on Aadhaar card',
            icon: Icons.badge_rounded,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _aadhaarRelativeController,
          decoration: InputDecoration(
            labelText: 'Relative Name *',
            helperText:
                'ex: Father\'s name, Husband\'s name, Mother\'s name (as per Aadhaar)',
            hintText: 'S/O, D/O, W/O etc.',
            filled: true,
            fillColor: EditProfileDesign.surfaceBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Full Address (as per Aadhaar) *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: EditProfileDesign.textHeadline,
          ),
        ),
        const SizedBox(height: 12),
        _buildAddressFields(
          house: _addrHouseFlat,
          street1: _addrStreet1,
          street2: _addrStreet2,
          pincode: _addrPincode,
          town: _addrTown,
          state: _addrState,
          country: _addrCountry,
          onPincodeLookup: () =>
              _lookupPincode(_addrPincode, _addrTown, _addrState, _addrCountry),
        ),
        const SizedBox(height: 20),
        Text(
          'Present Address *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: EditProfileDesign.textHeadline,
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _sameAsAadhaarAddress,
          onChanged: (v) {
            if (v == true) {
              _copyAadhaarToPresentAddress();
            } else {
              setState(() => _sameAsAadhaarAddress = false);
            }
          },
          title: Text(
            'Same as Aadhaar address',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.brandWarmLight,
        ),
        if (!_sameAsAadhaarAddress) ...[
          const SizedBox(height: 8),
          _buildAddressFields(
            house: _presentHouseFlat,
            street1: _presentStreet1,
            street2: _presentStreet2,
            pincode: _presentPincode,
            town: _presentTown,
            state: _presentState,
            country: _presentCountry,
            onPincodeLookup: () => _lookupPincode(
              _presentPincode,
              _presentTown,
              _presentState,
              _presentCountry,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddressStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Address details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: EditProfileDesign.textHeadline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Fill Aadhaar address and current address.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: EditProfileDesign.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        _buildAadhaarDetailsStep(),
      ],
    );
  }

  Widget _buildContactsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Emergency contacts',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: EditProfileDesign.textHeadline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add 2 contacts with name and 10-digit number.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: EditProfileDesign.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        _buildContactRow(1, _contact1Name, _contact1Number),
        const SizedBox(height: 12),
        _buildContactRow(2, _contact2Name, _contact2Number),
      ],
    );
  }

  Widget _buildPanCertificatesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPanStep(),
        const SizedBox(height: 16),
        _buildCertificatesStep(),
      ],
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint, {
    IconData? icon,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 18),
        filled: true,
        fillColor: EditProfileDesign.surfaceBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
          borderSide: BorderSide.none,
        ),
      );

  Widget _buildAddressFields({
    required TextEditingController house,
    required TextEditingController street1,
    required TextEditingController street2,
    required TextEditingController pincode,
    required TextEditingController town,
    required TextEditingController state,
    required TextEditingController country,
    required Future<void> Function() onPincodeLookup,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: house,
          decoration: _inputDecoration(
            'House no, Flat no & name *',
            'e.g. 101, ABC Apartments',
            icon: Icons.home_work_rounded,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: street1,
          decoration: _inputDecoration(
            'Street line 1 *',
            '',
            icon: Icons.location_on_rounded,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: street2,
          decoration: _inputDecoration('Street line 2', 'Optional'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pincode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: _inputDecoration(
            'Pincode *',
            '6 digits - Town, State auto-fill',
            icon: Icons.pin_drop_rounded,
          ),
          onChanged: (_) async {
            setState(() {});
            if (pincode.text.replaceAll(RegExp(r'\D'), '').length == 6) {
              await onPincodeLookup();
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: town,
          decoration: _inputDecoration(
            'Town / City *',
            'Auto-filled from pincode',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: state,
          decoration: _inputDecoration('State *', 'Auto-filled from pincode'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: country,
          decoration: _inputDecoration('Country *', 'Auto-filled from pincode'),
        ),
      ],
    );
  }

  Widget _buildContactRow(
    int index,
    TextEditingController nameCtrl,
    TextEditingController numberCtrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EditProfileDesign.surfaceBg,
        borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Contact $index *',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: EditProfileDesign.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  decoration: _inputDecoration('Name', ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _pickContact(index),
                icon: const Icon(Icons.contacts_rounded, size: 20),
                tooltip: 'Add from phone book',
                style: IconButton.styleFrom(backgroundColor: AppColors.brandWarmLight),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: numberCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: '10-digit number *',
              hintText: 'e.g. 9876543210',
              errorText:
                  numberCtrl.text.isNotEmpty &&
                      numberCtrl.text.replaceAll(RegExp(r'\D'), '').length != 10
                  ? 'Must be 10 digits'
                  : null,
              filled: true,
              fillColor: EditProfileDesign.surfaceBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildPanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _panExpanded = !_panExpanded),
          borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.brandWarmLight.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
              border: Border.all(
                color: AppColors.brandWarmLight.withValues(alpha: 0.26),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _panExpanded
                      ? Icons.expand_less_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 24,
                  color: AppColors.brandWarmDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add PAN details (optional)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: EditProfileDesign.textHeadline,
                    ),
                  ),
                ),
                if (_panVerified || _panFrontUrl != null)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.success,
                  ),
              ],
            ),
          ),
        ),
        if (_panExpanded) ...[
          const SizedBox(height: 16),
          Text(
            'PAN card photo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: EditProfileDesign.textHeadline,
            ),
          ),
          const SizedBox(height: 10),
          _DocCaptureTile(
            label: 'PAN card',
            url: _panFrontUrl,
            file: _panFrontFile,
            loading: _panDocUploading,
            onTap: () => _capturePanDoc(''),
          ),
          const SizedBox(height: 20),
          Text(
            'PAN details',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: EditProfileDesign.textHeadline,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _panController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: 'PAN Number',
              hintText: 'ABCDE1234F',
              counterText: '',
              filled: true,
              fillColor: EditProfileDesign.surfaceBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _panNameController,
            decoration: InputDecoration(
              labelText: 'Full Name (as on PAN)',
              filled: true,
              fillColor: EditProfileDesign.surfaceBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _panDobController,
            decoration: InputDecoration(
              labelText: 'Date of Birth (DD/MM/YYYY)',
              hintText: '01/01/1990',
              filled: true,
              fillColor: EditProfileDesign.surfaceBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _panVerify,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.brandWarmLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
              ),
            ),
            child: Text(
              'Verify PAN',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLivenessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Take a clear selfie for verification',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: EditProfileDesign.textHeadline,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Keep your face centered and clearly visible',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: EditProfileDesign.textMuted,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.brandWarmLight.withValues(alpha: 0.85),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.brandWarmDark,
                    size: 34,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.7, end: 1, duration: 1200.ms),
                const SizedBox(height: 10),
                Text(
                  'Ensure good lighting',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TechnicianUiTokens.labelPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Face clearly visible',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: TechnicianUiTokens.labelSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandWarmSoft.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _livenessLoading ? null : _captureLiveness,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _livenessLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded, size: 20, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      _livenessLoading ? 'Opening Camera...' : 'Take Selfie & Continue',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Camera opens instantly. After capture, we move to Step 2 automatically.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: TechnicianUiTokens.labelSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCertificatesStep() {
    return _CertificatesStepContent(
      certificateUrls: _certificateUrls,
      certificateFiles: _certificateFiles,
      certUploading: _certUploading,
      onAddCertificate: _addCertificate,
    );
  }

  static const List<String> _agreementTerms = [
    'I confirm that all personal information and documents provided by me are true, accurate, and valid.',
    'I agree to follow all service rules, standards, and policies of D.G.Yard Connect.',
    'I understand that all service payments must be processed only through the platform and that the platform service commission may be deducted.',
    'I agree that payment will be released only after the dealer verifies and approves the job completion.',
    'I agree to upload required before and after work images as proof of service completion.',
    'I agree to upload material pickup and return images when the material pickup option is selected.',
    'I accept responsibility for the safe pickup, transportation, and return of materials when assigned.',
    'I agree to provide genuine service and maintain professional behavior with dealers and customers.',
    'I accept that warranty responsibility for the work performed will be as per the platform policy.',
    'I understand that attempting to bypass the platform for direct payment with dealers may lead to account suspension.',
    'I understand that violation of platform rules may lead to account suspension or permanent ban.',
    'I understand that the platform may review job images, activity logs, and location data for verification and dispute resolution.',
  ];

  Widget _buildTermsStep() {
    final allAccepted = _termsAccepted.every((v) => v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Technician Agreement',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: EditProfileDesign.textHeadline,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Read and accept all terms to proceed',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: EditProfileDesign.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _showAgreementPopup(context),
          icon: Icon(
            allAccepted
                ? Icons.check_circle_rounded
                : Icons.description_rounded,
            size: 20,
            color: AppColors.brandWarmDark,
          ),
          label: Text(
            allAccepted ? 'Terms accepted ✓' : 'Read & Accept All Terms',
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(
              color: allAccepted
                  ? AppColors.success
                  : AppColors.brandWarmLight.withValues(alpha: 0.6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EditProfileDesign.radiusMd),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAgreementPopup(BuildContext context) async {
    bool accepted = _termsAccepted.every((v) => v);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: EditProfileDesign.surfaceBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        'Technician Agreement',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _agreementTerms
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                t,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: EditProfileDesign.textBody,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: accepted,
                        onChanged: (v) =>
                            setModalState(() => accepted = v ?? false),
                        title: Text(
                          'I have read and accept all terms',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.brandWarmLight,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: accepted
                              ? () {
                                  setState(() {
                                    for (
                                      var i = 0;
                                      i < _termsAccepted.length;
                                      i++
                                    ) {
                                      _termsAccepted[i] = true;
                                    }
                                  });
                                  Navigator.pop(ctx);
                                  _showSnack('All terms accepted');
                                }
                              : () => _showSnack(
                                  'Please check "I have read and accept all terms"',
                                ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.brandWarmLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                EditProfileDesign.radiusMd,
                              ),
                            ),
                          ),
                          child: Text(
                            'Accept & Continue',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DocCaptureTile extends StatelessWidget {
  const _DocCaptureTile({
    required this.label,
    this.url,
    this.file,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final String? url;
  final File? file;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null || file != null;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: EditProfileDesign.surfaceBg,
          borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
          border: Border.all(
            color: EditProfileDesign.textMuted.withValues(alpha: 0.3),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    if (file != null)
                      Image.file(file!, fit: BoxFit.cover)
                    else
                      CachedNetworkImage(
                        imageUrl: url!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, _, _) => _buildPlaceholder(),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        // Light glass ribbon (avoid dark overlay).
                        color: Colors.white.withValues(alpha: 0.78),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.textPrimary.withValues(
                                  alpha: 0.92,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const CircularProgressIndicator(color: AppColors.brandWarmLight)
        else
          Icon(
            Icons.camera_alt_rounded,
            size: 28,
            color: EditProfileDesign.textMuted,
          ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: EditProfileDesign.textMuted,
          ),
        ),
      ],
    );
  }
}

class _CertificatesStepContent extends StatelessWidget {
  const _CertificatesStepContent({
    required this.certificateUrls,
    required this.certificateFiles,
    required this.certUploading,
    required this.onAddCertificate,
  });
  final List<String> certificateUrls;
  final List<File> certificateFiles;
  final bool certUploading;
  final VoidCallback onAddCertificate;

  @override
  Widget build(BuildContext context) {
    final totalCount = certificateUrls.length + certificateFiles.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: EditProfileDesign.textMuted.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                Icons.school_rounded,
                size: 20,
                color: EditProfileDesign.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add skill or training certificates (optional). Capture with camera.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: EditProfileDesign.textBody,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (totalCount > 0) ...[
          const SizedBox(height: 14),
          ...List.generate(totalCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    EditProfileDesign.radiusSm,
                  ),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 22,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Certificate ${i + 1}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: certUploading ? null : onAddCertificate,
          icon: certUploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_rounded, size: 20),
          label: Text(
            certUploading ? 'Uploading...' : 'Add Certificate',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: AppColors.brandWarmLight.withValues(alpha: 0.5)),
            foregroundColor: AppColors.brandWarmDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
            ),
          ),
        ),
      ],
    );
  }
}
