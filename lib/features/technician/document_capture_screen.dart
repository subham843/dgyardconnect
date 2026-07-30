import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import 'edit_profile_design.dart';

/// Document capture with frame guide overlay.
/// Uses image_picker (reliable) - shows guide then opens camera.
class DocumentCaptureScreen extends StatelessWidget {
  const DocumentCaptureScreen({
    super.key,
    required this.documentType,
    required this.sideLabel,
    required this.onCaptured,
  });

  final String documentType; // 'aadhaar' | 'pan'
  final String sideLabel; // 'Front' | 'Back' | 'Single page'
  final void Function(File file) onCaptured;

  Future<void> _openCamera(BuildContext context) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (!context.mounted) return;
    if (xfile == null) {
      Navigator.of(context).pop();
      return;
    }
    final file = File(xfile.path);
    if (file.existsSync()) {
      onCaptured(file);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: '${documentType == 'aadhaar' ? 'Aadhaar' : 'PAN'} - $sideLabel',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: TechnicianGlassBackground(
        child: SafeArea(
          child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                '${documentType == 'aadhaar' ? 'Aadhaar' : 'PAN'} - $sideLabel',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: EditProfileDesign.textHeadline,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 3),
                    borderRadius: BorderRadius.circular(16),
                    // Light, frosted placeholder card (transparent glass style).
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card_rounded,
                              size: 80,
                              color: AppColors.primary.withValues(alpha: 0.28),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Place card in frame',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                color: EditProfileDesign.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Photo',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            documentType == 'aadhaar' ? 'Number' : 'Details',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openCamera(context),
                  icon: const Icon(Icons.camera_alt_rounded, size: 24),
                  label: Text(
                    'Capture',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
