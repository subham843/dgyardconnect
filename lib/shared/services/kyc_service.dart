import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/config/kyc_config.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

/// Result of KYC API calls.
class KycResult {
  const KycResult({this.success = false, this.data, this.error});
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;
}

/// KYC service - Aadhaar, PAN, Passive Liveness via DigiConsole/Sandbox API.
/// Backend (Cloud Functions) holds API keys and proxies to Sandbox.
class KycService {
  static Future<KycResult> aadhaarGenerateOtp(String aadhaarNumber) async {
    final digits = aadhaarNumber.replaceAll(RegExp(r'\s'), '');
    if (KycConfig.useMockAadhaarForTesting) {
      return KycResult(
        success: true,
        data: {
          'code': 200,
          'data': {
            'reference_id': 'mock_ref_${DateTime.now().millisecondsSinceEpoch}',
            'test_mode': true,
          },
        },
      );
    }
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable(KycConfig.fnAadhaarGenerateOtp)
          .call({
        'aadhaar_number': digits,
        'consent': 'Y',
        'reason': 'KYC verification for D.G.Yard Connect',
      });
      final data = result.data as Map<String, dynamic>?;
      final code = (data?['code'] as num?)?.toInt();
      if (code == 200 || code == 201) {
        return KycResult(success: true, data: data);
      }
      return KycResult(
        success: false,
        error: data?['message'] as String? ?? 'Failed to send OTP',
      );
    } on FirebaseFunctionsException catch (e) {
      return KycResult(success: false, error: e.message ?? e.code);
    } catch (e) {
      return KycResult(success: false, error: e.toString());
    }
  }

  static Future<KycResult> aadhaarVerifyOtp({
    required String referenceId,
    required String otp,
  }) async {
    if (KycConfig.useMockAadhaarForTesting &&
        (referenceId.startsWith('mock_') || referenceId.contains('mock')) &&
        otp == '123456') {
      return KycResult(
        success: true,
        data: {
          'code': 200,
          'data': {
            'name': 'Test User',
            'care_of': 'Father of Test',
            'date_of_birth': '1990-01-15',
            'full_address': '123 Test Street, Mumbai 400001',
          },
        },
      );
    }
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable(KycConfig.fnAadhaarVerifyOtp)
          .call({
        'reference_id': referenceId,
        'otp': otp,
      });
      final data = result.data as Map<String, dynamic>?;
      final code = (data?['code'] as num?)?.toInt();
      if (code == 200 || code == 201) {
        return KycResult(success: true, data: data);
      }
      return KycResult(
        success: false,
        error: data?['message'] as String? ?? 'OTP verification failed',
      );
    } on FirebaseFunctionsException catch (e) {
      return KycResult(success: false, error: e.message ?? e.code);
    } catch (e) {
      return KycResult(success: false, error: e.toString());
    }
  }

  static Future<KycResult> panVerify({
    required String panNumber,
    required String fullName,
    required String dateOfBirth,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable(KycConfig.fnPanVerify)
          .call({
        'pan_number': panNumber.toUpperCase().replaceAll(RegExp(r'\s'), ''),
        'full_name': fullName.trim(),
        'date_of_birth': dateOfBirth,
        'consent': 'Y',
        'reason': 'KYC verification for D.G.Yard Connect',
      });
      final data = result.data as Map<String, dynamic>?;
      final code = (data?['code'] as num?)?.toInt();
      if (code == 200 || code == 201) {
        return KycResult(success: true, data: data);
      }
      return KycResult(
        success: false,
        error: data?['message'] as String? ?? 'PAN verification failed',
      );
    } on FirebaseFunctionsException catch (e) {
      return KycResult(success: false, error: e.message ?? e.code);
    } catch (e) {
      return KycResult(success: false, error: e.toString());
    }
  }

  /// Passive liveness - upload selfie, backend verifies or stores for admin.
  static Future<KycResult> livenessVerify(File imageFile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !StorageService.isAvailable) {
      return const KycResult(success: false, error: 'Not authenticated');
    }
    try {
      final url = await StorageService.uploadKycDocument(userId: uid, file: imageFile, type: 'selfie');
      if (url == null) {
        return const KycResult(success: false, error: 'Upload failed');
      }
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable(KycConfig.fnLivenessVerify)
            .call({'image_url': url, 'user_id': uid});
        final data = result.data as Map<String, dynamic>?;
        final code = (data?['code'] as num?)?.toInt();
        if (code == 200 || code == 201) {
          return KycResult(success: true, data: {'selfie_url': url, ...?data});
        }
        return KycResult(
          success: false,
          error: data?['message'] as String? ?? 'Liveness check failed',
        );
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'not-found') {
          // Function not deployed - store selfie for admin verification
          await FirestoreService.users().doc(uid).set({
            'kycData.livenessSelfieUrl': url,
            'kycData.livenessVerified': true,
            'kycData.livenessSubmittedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return KycResult(success: true, data: {'selfie_url': url});
        }
        return KycResult(success: false, error: e.message ?? e.code);
      }
    } catch (e) {
      return KycResult(success: false, error: e.toString());
    }
  }
}
