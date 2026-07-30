import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Verifies document type from image using ML Kit OCR.
/// Rejects wrong documents immediately (e.g. PAN photo when Aadhaar expected).
class DocumentVerifier {
  static final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Keywords that indicate Aadhaar card (English + common Hindi).
  static const _aadhaarKeywords = [
    'government of india',
    'uidai',
    'aadhaar',
    'unique identification',
    'आधार',
    'भारत सरकार',
  ];

  /// Keywords that indicate PAN card.
  static const _panKeywords = [
    'income tax',
    'permanent account number',
    'pan',
    'भारत सरकार',
    'government of india',
  ];

  /// Keywords on Aadhaar FRONT (photo, name, DOB, gender).
  static const _aadhaarFrontKeywords = [
    'male', 'female', 'gender', 'date of birth', 'dob', 'photograph',
    'your photo', 'your photograph', 'year of birth', 'yob',
  ];

  /// Keywords on Aadhaar BACK (address section, update instructions).
  static const _aadhaarBackKeywords = [
    'update your address', 'enrolment', 'enrolment centre', 'centre',
    'machine readable', 'scan', 'qr code', 'update address',
  ];

  /// Verify that the image is an Aadhaar document.
  /// Returns error message if wrong document.
  static Future<String?> verifyAadhaar(File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        return 'Image file not found. Please try again.';
      }
      final text = await _extractText(imageFile);
      if (text.isEmpty) {
        return 'Could not read document. Ensure good lighting and clear image.';
      }
      final lower = text.toLowerCase();
      for (final kw in _aadhaarKeywords) {
        if (lower.contains(kw.toLowerCase())) {
          return null; // Valid Aadhaar
        }
      }
      if (_panKeywords.any((kw) => lower.contains(kw.toLowerCase()))) {
        return 'Wrong document. This looks like PAN card. Please capture Aadhaar card only.';
      }
      return 'Invalid document. Please capture a clear photo of your Aadhaar card.';
    } catch (e) {
      return 'Verification failed: $e';
    }
  }

  /// Verify Aadhaar FRONT side only. Rejects back side.
  static Future<String?> verifyAadhaarFront(File imageFile) async {
    final err = await verifyAadhaar(imageFile);
    if (err != null) return err;
    final text = await _extractText(imageFile);
    final lower = text.toLowerCase();
    if (_aadhaarBackKeywords.any((kw) => lower.contains(kw))) {
      return 'Wrong side. This looks like Aadhaar back. Please capture the FRONT side (with photo and name).';
    }
    if (!_aadhaarFrontKeywords.any((kw) => lower.contains(kw))) {
      return 'Could not detect front side. Please capture the FRONT of Aadhaar (with photo, name, DOB).';
    }
    return null;
  }

  /// Verify Aadhaar BACK side only. Rejects front side.
  static Future<String?> verifyAadhaarBack(File imageFile) async {
    final err = await verifyAadhaar(imageFile);
    if (err != null) return err;
    final text = await _extractText(imageFile);
    final lower = text.toLowerCase();
    final hasFront = _aadhaarFrontKeywords.any((kw) => lower.contains(kw));
    final hasBack = _aadhaarBackKeywords.any((kw) => lower.contains(kw));
    if (hasFront && !hasBack) {
      return 'Wrong side. This looks like Aadhaar front. Please capture the BACK side (with address and QR).';
    }
    return null;
  }

  /// Verify that the image is a PAN document.
  /// Returns error message if wrong document.
  static Future<String?> verifyPan(File imageFile) async {
    try {
      if (!imageFile.existsSync()) {
        return 'Image file not found. Please try again.';
      }
      final text = await _extractText(imageFile);
      if (text.isEmpty) {
        return 'Could not read document. Ensure good lighting and clear image.';
      }
      final lower = text.toLowerCase();
      for (final kw in _panKeywords) {
        if (lower.contains(kw.toLowerCase())) {
          return null; // Valid PAN
        }
      }
      if (_aadhaarKeywords.any((kw) => lower.contains(kw.toLowerCase()))) {
        return 'Wrong document. This looks like Aadhaar card. Please capture PAN card only.';
      }
      return 'Invalid document. Please capture a clear photo of your PAN card.';
    } catch (e) {
      return 'Verification failed: $e';
    }
  }

  static Future<String> _extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _recognizer.processImage(inputImage);
    return recognized.text;
  }

  static void dispose() {
    _recognizer.close();
  }
}
