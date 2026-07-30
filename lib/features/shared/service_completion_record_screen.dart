import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' if (dart.library.html) '../../core/io_stub.dart' as io;
import '../../core/constants/legal_constants.dart';
import '../../core/constants/service_completion_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/qr_png_helper.dart';
import '../../shared/models/service_completion_record_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../core/theme/technician_ui_tokens.dart';

/// Shared screen to view Service Completion Record. Dealer can also download PDF and print.
class ServiceCompletionRecordScreen extends StatelessWidget {
  const ServiceCompletionRecordScreen({
    super.key,
    required this.jobId,
    this.allowDownloadAndPrint = false,
    this.backRoute,
  });

  final String jobId;
  final bool allowDownloadAndPrint;
  final String? backRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.description_outlined, size: 19, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Service Completion Record',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 17),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () {
            if (backRoute != null) {
              context.go(backRoute!);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF2FF), Color(0xFFF2EEFF)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.serviceCompletionRecords()
              .where('jobId', isEqualTo: jobId)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No service completion record found for this job.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final record = ServiceCompletionRecordModel.fromFirestore(docs.first);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _glassCard(
                    child: Text(
                      LegalConstants.serviceCompletionWarrantyDisclaimer,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _RecordViewContent(
                    record: record,
                    allowDownloadAndPrint: allowDownloadAndPrint,
                    onDownload: () => ServiceCompletionRecordScreen.downloadPdf(context, record),
                    onShare: () async {
                      final bytes = await ServiceCompletionRecordScreen._generatePdf(record);
                      await Printing.sharePdf(
                        bytes: bytes,
                        filename: 'service_record_${record.displayJobId}.pdf',
                      );
                    },
                    onCopyId: () async {
                      await Clipboard.setData(ClipboardData(text: record.displayRecordId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Record ID copied')),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Future<Uint8List> _generatePdf(ServiceCompletionRecordModel record) async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      ),
    );
    final dateFormat = DateFormat('dd MMM yyyy');
    final dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  ServiceCompletionConstants.platformHeader,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  ServiceCompletionConstants.recordTitle,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Record ID: ${record.displayRecordId}', style: pw.TextStyle(fontSize: 10)),
          pw.Text('Job ID: ${record.displayJobId}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 16),
          pw.Text('Dealer: ${record.dealerName} (${record.displayDealerId})', style: pw.TextStyle(fontSize: 10)),
          pw.Text('Technician: ${record.technicianName} (${record.displayTechnicianId})', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 16),
          pw.Text('Service: ${record.serviceSector ?? "—"} / ${record.serviceSubSector ?? "—"}', style: pw.TextStyle(fontSize: 10)),
          pw.Text('Type: ${record.serviceType ?? "—"}', style: pw.TextStyle(fontSize: 10)),
          pw.Text('Location: ${record.serviceLocation ?? "—"}', style: pw.TextStyle(fontSize: 10)),
          pw.Text('Completion: ${record.completionDate != null ? dateTimeFormat.format(record.completionDate!) : "—"}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 16),
          pw.Text('Customer OTP Verified: ${record.customerOtpVerified ? "Yes" : "No"}', style: pw.TextStyle(fontSize: 10)),
          pw.Text('Dealer Approved: ${record.dealerApprovalStatus ?? "—"}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 16),
          pw.Text(
            'Warranty: ${record.warrantyStartDate != null ? dateFormat.format(record.warrantyStartDate!) : "—"} to ${record.effectiveWarrantyEndDate != null ? dateFormat.format(record.effectiveWarrantyEndDate!) : "—"} (${record.effectiveWarrantyDurationDays} days)',
            style: pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Technician Payment Released (80%): ₹${record.technicianPaymentReleased.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10)),
          pw.Text('Warranty Hold (20%): ₹${record.holdPaymentAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Column(
                children: [
                  pw.Image(
                    pw.MemoryImage(qrCodeToPngBytes(ServiceCompletionConstants.verificationUrlForRecord(record.id))),
                    width: 80,
                    height: 80,
                    fit: pw.BoxFit.contain,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Scan to verify', style: pw.TextStyle(fontSize: 8)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            ServiceCompletionConstants.platformDisclaimer,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  /// Public for use from admin panel.
  static Future<void> printRecord(BuildContext context, ServiceCompletionRecordModel record) async {
    try {
      final pdfBytes = await _generatePdf(record);
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  /// Public for use from admin panel.
  static Future<void> downloadPdf(BuildContext context, ServiceCompletionRecordModel record) async {
    try {
      final pdfBytes = await _generatePdf(record);
      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Use Print dialog to save as PDF')),
          );
        }
      } else {
        final safeName = record.displayJobId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
        final path = 'service_record_$safeName.pdf';
        await Printing.sharePdf(bytes: pdfBytes, filename: path);
        final dir = await getApplicationDocumentsDirectory();
        final localPath = '${dir.path}/$path';
        final file = io.File(localPath);
        await file.writeAsBytes(pdfBytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF shared and saved: $localPath')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }
}

class _RecordViewContent extends StatelessWidget {
  const _RecordViewContent({
    required this.record,
    required this.allowDownloadAndPrint,
    required this.onDownload,
    required this.onShare,
    required this.onCopyId,
  });
  final ServiceCompletionRecordModel record;
  final bool allowDownloadAndPrint;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final VoidCallback onCopyId;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ServiceCompletionConstants.platformHeader,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Verified Service Completion Record',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '✔ Verified',
                  style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row('🆔 Record ID', record.displayRecordId),
          _row('📄 Job ID', record.displayJobId),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Text('Dealer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          _row('🏢 Name', record.dealerName),
          _row('🏢 ID', record.displayDealerId),
          const SizedBox(height: 10),
          const Text('Technician', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          _row('👨‍🔧 Name', record.technicianName),
          _row('👨‍🔧 ID', record.displayTechnicianId),
          const SizedBox(height: 10),
          const Text('Service Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          _row('Sector', record.serviceSector ?? '—'),
          _row('Type', record.serviceType ?? '—'),
          _row('📍 Location', record.serviceLocation ?? '—'),
          _row('📅 Completion date', record.completionDate != null ? dateTimeFormat.format(record.completionDate!) : '—'),
          const SizedBox(height: 10),
          const Text('Verification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.28)),
            ),
            child: Text(
              record.customerOtpVerified ? 'OTP Verified' : 'OTP Pending',
              style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700),
            ),
          ),
          _row('Dealer approved', record.dealerApprovalStatus ?? '—'),
          const SizedBox(height: 14),
          if (allowDownloadAndPrint) ...[
            _actionBtn(
              icon: Icons.download_rounded,
              label: 'Download PDF',
              filled: true,
              onTap: onDownload,
            ),
            const SizedBox(height: 8),
          ],
          _actionBtn(
            icon: Icons.share_rounded,
            label: 'Share Record',
            filled: false,
            onTap: onShare,
          ),
          const SizedBox(height: 8),
          _actionBtn(
            icon: Icons.copy_rounded,
            label: 'Copy ID',
            filled: false,
            onTap: onCopyId,
          ),
          const SizedBox(height: 14),
          Text(
            ServiceCompletionConstants.platformDisclaimer,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          _row('Warranty start', record.warrantyStartDate != null ? dateFormat.format(record.warrantyStartDate!) : '—'),
          _row('Warranty end', record.effectiveWarrantyEndDate != null ? dateFormat.format(record.effectiveWarrantyEndDate!) : '—'),
          _row('Warranty status', record.warrantyStatusLabel),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: filled ? Colors.white : TechnicianUiTokens.accent,
          backgroundColor: filled ? TechnicianUiTokens.accent : Colors.white.withValues(alpha: 0.62),
          side: filled ? null : BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

Widget _glassCard({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}
