import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/route_names.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/firestore_service.dart';

class AdminKycScreen extends StatelessWidget {
  const AdminKycScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('KYC')),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(RouteNames.adminHome),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.users()
            .where('kycStatus', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No pending KYC',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final user = UserModel.fromFirestore(doc);
              final ref = doc.reference;
              final data = doc.data();
              final kycData = (data['kycData'] as Map<String, dynamic>?) ?? {};
              final isDealer = user.role == AppRole.dealer;
              final aadhaarOk = kycData['aadhaarVerified'] == true;
              final panOk = kycData['panVerified'] == true;
              final livenessOk = kycData['livenessVerified'] == true;
              final dealerIdOk = (kycData['dealerIdProofFrontUrl'] as String?)?.isNotEmpty == true;
              final dealerDeclarationOk = kycData['dealerDeclarationAccepted'] == true;
              final certs = (kycData['skillCertificates'] as List?)?.length ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => AdminKycScreen._showKycDetail(context, doc),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                              child: Text(user.displayName.substring(0, 1).toUpperCase()),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${user.email ?? ""} • ${user.role == AppRole.dealer ? "Dealer" : "Technician"}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: AppColors.success),
                                  tooltip: 'Approve',
                                  onPressed: () => AdminKycScreen._approveKyc(context, ref),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: AppColors.error),
                                  tooltip: 'Reject',
                                  onPressed: () => AdminKycScreen._rejectKyc(context, ref),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (isDealer) ...[
                              _KycBadge(label: 'ID Proof', ok: dealerIdOk),
                              const SizedBox(width: 8),
                              _KycBadge(label: 'Declaration', ok: dealerDeclarationOk),
                            ] else ...[
                              _KycBadge(label: 'Aadhaar', ok: aadhaarOk),
                              const SizedBox(width: 8),
                              _KycBadge(label: 'PAN', ok: panOk),
                              const SizedBox(width: 8),
                              _KycBadge(label: 'Liveness', ok: livenessOk),
                            ],
                            if (certs > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$certs cert(s)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: index * 50))
                  .slideX(begin: 0.05, end: 0, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }

  static Future<void> _approveKyc(BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.update({'kycStatus': 'verified'});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KYC approved'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  static Future<void> _rejectKyc(BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Reject KYC'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a reason for rejection (required):',
                style: GoogleFonts.plusJakartaSans(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. Document unclear, wrong document type...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final r = controller.text.trim();
                if (r.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason')),
                  );
                  return;
                }
                Navigator.pop(ctx, r);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref.update({
        'kycStatus': 'rejected',
        'kycRejectedAt': FieldValue.serverTimestamp(),
        'kycData.kycRejectionReason': reason,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KYC rejected'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  static void _showKycDetail(BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final kycData = data['kycData'] as Map<String, dynamic>? ?? {};
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final user = UserModel.fromFirestore(doc);
    final isDealer = user.role == AppRole.dealer;
    final displayName = profile['name'] as String? ??
        kycData['dealerFullName'] as String? ??
        kycData['aadhaarName'] as String? ??
        user.email ??
        'User';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                displayName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (isDealer) ...[
                _DetailRow('ID Type', kycData['dealerIdType'] as String? ?? '—'),
                _DetailRow('ID Number', kycData['dealerIdNumber'] as String? ?? '—'),
                _DetailRow('Full Name', kycData['dealerFullName'] as String? ?? '—'),
                _DetailRow('Business Name', kycData['dealerBusinessName'] as String? ?? '—'),
                _DetailRow('Business Category', kycData['dealerBusinessCategory'] as String? ?? '—'),
                _DetailRow('Shop Address', kycData['dealerShopAddress'] as String? ?? '—'),
                _DetailRow('City / Location', kycData['dealerCity'] as String? ?? '—'),
                _DetailRow('Landmark', kycData['dealerLandmark'] as String? ?? '—'),
                _DetailRow('GSTIN', kycData['dealerGstin'] as String? ?? '—'),
                _DetailRow('Alternate Phone', kycData['dealerAlternatePhone'] as String? ?? '—'),
                _DetailRow('Declaration', kycData['dealerDeclarationAccepted'] == true ? 'Accepted' : 'Not accepted'),
                if (kycData['dealerIdProofFrontUrl'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'ID Proof',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _KycImageTile(kycData['dealerIdProofFrontUrl'] as String, 'Front'),
                ],
                if (kycData['dealerSelfieWithIdUrl'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Selfie with ID',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _KycImageTile(kycData['dealerSelfieWithIdUrl'] as String, ''),
                ],
                if (kycData['dealerShopPhotoUrl'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Shop Photo',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _KycImageTile(kycData['dealerShopPhotoUrl'] as String, ''),
                ],
              ] else ...[
                _DetailRow('Aadhaar', kycData['aadhaarVerified'] == true ? 'Verified' : '—'),
                _DetailRow('Name', kycData['aadhaarName'] as String? ?? '—'),
                _DetailRow('Relative', kycData['aadhaarRelativeName'] as String? ?? '—'),
                if (kycData['aadhaarDob'] != null) _DetailRow('Date of Birth', kycData['aadhaarDob'].toString()),
                _DetailRow('Aadhaar Address', kycData['aadhaarAddress'] as String? ?? '—'),
                _DetailRow('House/Flat', kycData['aadhaarAddressHouseFlat'] as String? ?? '—'),
                _DetailRow('Street', '${kycData['aadhaarAddressStreet1'] ?? ''} ${kycData['aadhaarAddressStreet2'] ?? ''}'.trim()),
                _DetailRow('Pincode', kycData['aadhaarAddressPincode'] as String? ?? '—'),
                _DetailRow('Town', kycData['aadhaarAddressTown'] as String? ?? '—'),
                _DetailRow('State', kycData['aadhaarAddressState'] as String? ?? '—'),
                _DetailRow('Present Address', kycData['presentAddress'] as String? ?? '—'),
                if (((kycData['relativeContacts'] as List?)?.length ?? 0) >= 2) ...[
                  const SizedBox(height: 4),
                  Text('Relative Contacts', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                  ...List.generate(2, (i) {
                    final list = kycData['relativeContacts'] as List?;
                    final c = (list != null && i < list.length) ? list[i] as Map<String, dynamic>? : null;
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${c?['name'] ?? '—'}: ${c?['number'] ?? '—'}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      ),
                    );
                  }),
                ],
                if ((kycData['aadhaarFrontUrl'] != null || kycData['aadhaarSingleUrl'] != null)) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Aadhaar Card',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (kycData['aadhaarSingleUrl'] != null)
                        _KycImageTile(kycData['aadhaarSingleUrl'] as String, 'Single page'),
                      if (kycData['aadhaarFrontUrl'] != null)
                        _KycImageTile(kycData['aadhaarFrontUrl'] as String, 'Front'),
                      if (kycData['aadhaarBackUrl'] != null)
                        _KycImageTile(kycData['aadhaarBackUrl'] as String, 'Back'),
                    ],
                  ),
                ],
                _DetailRow('PAN', kycData['panVerified'] == true ? 'Verified' : '—'),
                _DetailRow('PAN Number', kycData['panNumber'] as String? ?? '—'),
                if (kycData['panFrontUrl'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'PAN Card',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  _KycImageTile(kycData['panFrontUrl'] as String, ''),
                ],
                _DetailRow('Liveness', kycData['livenessVerified'] == true ? 'Verified' : '—'),
                if (kycData['livenessSelfieUrl'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selfie',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        _KycImageTile(kycData['livenessSelfieUrl'] as String, ''),
                      ],
                    ),
                  ),
              ],
              if ((kycData['skillCertificates'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Skill Certificates',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    (kycData['skillCertificates'] as List).length,
                    (i) => _KycImageTile(
                      (kycData['skillCertificates'] as List)[i] as String,
                      'Certificate ${i + 1}',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await AdminKycScreen._approveKyc(context, doc.reference);
                      },
                      icon: const Icon(Icons.check_circle, size: 20),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await AdminKycScreen._rejectKyc(context, doc.reference);
                      },
                      icon: const Icon(Icons.cancel, size: 20),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycBadge extends StatelessWidget {
  const _KycBadge({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? AppColors.success.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check : Icons.close, size: 12, color: ok ? AppColors.success : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ok ? AppColors.success : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _KycImageTile extends StatelessWidget {
  const _KycImageTile(this.url, this.label);
  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullImage(context, url, label),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
            errorWidget: (_, _, _) => Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url, String label) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              ),
            Flexible(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, _, _) => const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
