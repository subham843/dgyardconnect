import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static FirebaseStorage get _storage => FirebaseStorage.instance;

  static Reference ref(String path) => _storage.ref(path);

  static bool get isAvailable => Firebase.apps.isNotEmpty;

  static const _cacheControl = 'public, max-age=31536000, immutable';

  static SettableMetadata _meta(String contentType) => SettableMetadata(
        contentType: contentType,
        cacheControl: _cacheControl,
      );

  static final SettableMetadata _imageMetadata = _meta('image/jpeg');

  /// Upload file to Storage with metadata.
  static Future<String?> _uploadFile(Reference storageRef, File file) async {
    await storageRef.putFile(file, _imageMetadata);
    return await storageRef.getDownloadURL();
  }

  /// Upload bytes to Storage (works on web and mobile).
  static Future<String?> _uploadBytes(
    Reference storageRef,
    Uint8List bytes, {
    String contentType = 'image/png',
  }) async {
    await storageRef.putData(bytes, _meta(contentType));
    return await storageRef.getDownloadURL();
  }

  /// Upload a brand kit asset. Returns download URL or null.
  static Future<String?> uploadBrandAsset({
    required String assetKey,
    required Uint8List bytes,
    String contentType = 'image/png',
  }) async {
    if (!isAvailable) return null;
    try {
      final ext = _extensionForContentType(contentType);
      final name = '${assetKey}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'brand_kit/$name';
      final storageRef = ref(path);
      return await _uploadBytes(storageRef, bytes, contentType: contentType);
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('Storage uploadBrandAsset error: $e');
        return true;
      }());
      return null;
    }
  }

  static String _extensionForContentType(String contentType) {
    final ct = contentType.toLowerCase();
    if (ct.contains('gif')) return 'gif';
    if (ct.contains('svg')) return 'svg';
    if (ct.contains('webp')) return 'webp';
    if (ct.contains('jpeg') || ct.contains('jpg')) return 'jpg';
    return 'png';
  }


  /// Upload a proof photo for a job. Returns the download URL or null on failure.
  static Future<String?> uploadProofPhoto({
    required String jobId,
    required String type,
    required File file,
  }) async {
    if (!isAvailable) return null;
    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'proofs/$jobId/$type/$name';
      final storageRef = ref(path);
      return await _uploadFile(storageRef, file);
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('Storage uploadProofPhoto error: $e');
        return true;
      }());
      return null;
    }
  }

  /// Upload material pickup photo with slNo/partNumber. Returns download URL or null.
  static Future<String?> uploadMaterialPickupPhoto({
    required String jobId,
    required int slNo,
    required String itemName,
    String? partNumber,
    required File file,
  }) async {
    if (!isAvailable) return null;
    try {
      final part = partNumber ?? 'item$slNo';
      final name = '${slNo}_${part}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'proofs/$jobId/pickup_material/$name';
      final storageRef = ref(path);
      return await _uploadFile(storageRef, file);
    } catch (_) {
      return null;
    }
  }

  /// Upload material return photo (before). Returns download URL or null.
  static Future<String?> uploadMaterialReturnPhoto({
    required String jobId,
    required int index,
    required File file,
  }) async {
    if (!isAvailable) return null;
    try {
      final name = 'material_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'proofs/$jobId/material_return/$name';
      final storageRef = ref(path);
      return await _uploadFile(storageRef, file);
    } catch (_) {
      return null;
    }
  }

  /// Upload material return after photo. Returns download URL or null.
  /// Image is compressed before upload.
  static Future<String?> uploadMaterialReturnAfterPhoto({
    required String jobId,
    required int index,
    required File file,
  }) async {
    if (!isAvailable) return null;
    try {
      final name = 'material_after_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'proofs/$jobId/material_return_after/$name';
      final storageRef = ref(path);
      return await _uploadFile(storageRef, file);
    } catch (_) {
      return null;
    }
  }

  /// Upload an ad asset (image or video). Returns download URL or null.
  /// Works on both web and mobile (uses bytes, not File).
  static Future<String?> uploadAdAsset({
    required String type,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (!isAvailable) return null;
    try {
      final ext = contentType.contains('video') ? 'mp4' : (contentType.contains('png') ? 'png' : 'jpg');
      final name = '${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'ads/$name';
      final storageRef = ref(path);
      return await _uploadBytes(storageRef, bytes, contentType: contentType);
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('Storage uploadAdAsset error: $e');
        return true;
      }());
      rethrow;
    }
  }

  /// Upload ad file (image or video from File). Returns download URL or null.
  static Future<String?> uploadAdFile({
    required File file,
    required String type,
    String contentType = 'image/jpeg',
  }) async {
    if (!isAvailable) return null;
    try {
      final ext = contentType.contains('video') ? 'mp4' : (contentType.contains('png') ? 'png' : 'jpg');
      final name = '${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'ads/$name';
      final storageRef = ref(path);
      await storageRef.putFile(file, _meta(contentType));
      return await storageRef.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Listing photo under `marketplace/products/{userId}/{listingId}/…` (Storage rules).
  /// Uses bytes so the same path works on web and mobile.
  static Future<String?> uploadMarketplaceListingImage({
    required String userId,
    required String listingId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (!isAvailable) return null;
    try {
      final ext = contentType.contains('png')
          ? 'png'
          : contentType.contains('webp')
              ? 'webp'
              : 'jpg';
      final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'marketplace/products/$userId/$listingId/$name';
      final storageRef = ref(path);
      return await _uploadBytes(storageRef, bytes, contentType: contentType);
    } catch (_) {
      return null;
    }
  }

  /// Deletes all objects under `marketplace/products/{userId}/{listingId}/` (e.g. after admin rejects a new listing).
  static Future<void> deleteMarketplaceListingFolder({
    required String userId,
    required String listingId,
  }) async {
    if (!isAvailable) return;
    try {
      await _deleteStorageChildren(ref('marketplace/products/$userId/$listingId'));
    } catch (_) {}
  }

  static Future<void> _deleteStorageChildren(Reference dir) async {
    final list = await dir.listAll();
    for (final item in list.items) {
      await item.delete();
    }
    for (final prefix in list.prefixes) {
      await _deleteStorageChildren(prefix);
    }
  }

  /// Upload a KYC document for a user. Returns the download URL or null on failure.
  /// [type] e.g. 'aadhaar_front', 'aadhaar_back', 'aadhaar_single', 'pan_front', 'pan_back', 'selfie', 'cert'
  static Future<String?> uploadKycDocument({
    required String userId,
    required File file,
    String type = 'cert',
  }) async {
    if (!isAvailable) return null;
    try {
      final name = '${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'users/$userId/kyc/$name';
      final storageRef = ref(path);
      return await _uploadFile(storageRef, file);
    } catch (_) {
      return null;
    }
  }

  /// Upload profile photo for a user. Returns the download URL or null on failure.
  static Future<String?> uploadProfilePhoto({
    required String userId,
    required File file,
  }) async {
    if (!isAvailable) return null;
    try {
      final name = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'users/$userId/$name';
      final storageRef = ref(path);
      return await _uploadFile(storageRef, file);
    } catch (_) {
      return null;
    }
  }

  /// Upload warranty claim photo (path uses jobId until claim is created). Returns download URL or null.
  static Future<String?> uploadWarrantyClaimPhoto({
    required String jobId,
    required int index,
    required File file,
  }) async {
    if (!isAvailable) return null;
    try {
      final name = 'photo_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'warranty_claims/$jobId/$name';
      final storageRef = ref(path);
      return await _uploadFile(storageRef, file);
    } catch (_) {
      return null;
    }
  }

  /// Upload warranty claim video (optional). Returns download URL or null.
  static Future<String?> uploadWarrantyClaimVideo({
    required String jobId,
    required File file,
  }) async {
    if (!isAvailable) return null;
    try {
      final name = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final path = 'warranty_claims/$jobId/$name';
      final storageRef = ref(path);
      await storageRef.putFile(file, _meta('video/mp4'));
      return await storageRef.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Upload a support ticket attachment image file. Returns URL or null.
  static Future<String?> uploadSupportTicketAttachmentFile({
    required String ticketId,
    required File file,
    String contentType = 'image/jpeg',
  }) async {
    if (!isAvailable) return null;
    try {
      final ext = contentType.contains('png') ? 'png' : 'jpg';
      final name = 'att_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'support_tickets/$ticketId/attachments/$name';
      final storageRef = ref(path);
      await storageRef.putFile(file, _meta(contentType));
      return await storageRef.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Upload a support ticket attachment (bytes). Useful for screenshots.
  static Future<String?> uploadSupportTicketAttachmentBytes({
    required String ticketId,
    required Uint8List bytes,
    String contentType = 'image/png',
  }) async {
    if (!isAvailable) return null;
    try {
      final ext = contentType.contains('png') ? 'png' : 'jpg';
      final name = 'att_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'support_tickets/$ticketId/attachments/$name';
      final storageRef = ref(path);
      return await _uploadBytes(storageRef, bytes, contentType: contentType);
    } catch (_) {
      return null;
    }
  }

  /// Upload job dispute photo. Path: job_disputes/{jobId}/photo_{index}.jpg
  static Future<String?> uploadJobDisputePhoto({
    required String jobId,
    required int index,
    required File file,
  }) async {
    if (!isAvailable) return null;
    try {
      final path = 'job_disputes/$jobId/photo_$index.jpg';
      final storageRef = ref(path);
      await storageRef.putFile(file, _imageMetadata);
      return await storageRef.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Upload job dispute video (optional). Path: job_disputes/{jobId}/video.mp4
  static Future<String?> uploadJobDisputeVideo({
    required String jobId,
    required File file,
  }) async {
    if (!isAvailable) return null;
    try {
      final path = 'job_disputes/$jobId/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final storageRef = ref(path);
      await storageRef.putFile(file, _meta('video/mp4'));
      return await storageRef.getDownloadURL();
    } catch (_) {
      return null;
    }
  }
}
