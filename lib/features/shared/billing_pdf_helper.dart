import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/billing_constants.dart';
import '../../shared/models/dealer_payment_receipt_model.dart';
import '../../shared/models/platform_invoice_model.dart';
import '../../shared/models/technician_payment_receipt_model.dart';
import '../../shared/models/warranty_release_receipt_model.dart';

abstract final class BillingPdfHelper {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');

  static Future<pw.Document> _buildDocument() async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    return pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      ),
    );
  }

  static Future<Uint8List> dealerPaymentReceiptPdf(DealerPaymentReceiptModel r) async {
    final pdf = await _buildDocument();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(BillingConstants.platformName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.Text(BillingConstants.paymentReceiptTitle, style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 16),
          pw.Text('Receipt ID: ${r.displayReceiptId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Job ID: ${r.displayJobId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Dealer ID: ${r.displayDealerId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Dealer: ${r.dealerName}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Service: ${r.serviceSector ?? "—"} / ${r.serviceType ?? "—"}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.Text('Payment Amount: ₹${r.paymentAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text('Payment Date: ${r.paymentDate != null ? _dateTimeFormat.format(r.paymentDate!) : "—"}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Payment Method: ${r.paymentMethod ?? "—"}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Payment Gateway: Razorpay', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Payment Status: ${r.paymentStatus ?? "—"}', style: const pw.TextStyle(fontSize: 10)),
          if (r.razorpayPaymentId != null) pw.Text('Razorpay Payment ID: ${r.razorpayPaymentId}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 20),
          pw.Text(BillingConstants.disclaimer, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> platformInvoicePdf(PlatformInvoiceModel inv) async {
    final pdf = await _buildDocument();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(BillingConstants.platformName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.Text(BillingConstants.platformInvoiceTitle, style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 16),
          pw.Text('Invoice ID: ${inv.displayInvoiceId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Invoice Date: ${inv.invoiceDate != null ? _dateFormat.format(inv.invoiceDate!) : "—"}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Dealer: ${inv.dealerName}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Job ID: ${inv.displayJobId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Dealer ID: ${inv.displayDealerId}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.Text('Service Amount: ₹${inv.serviceAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Platform Commission: ₹${inv.platformCommission.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('GST: ₹${inv.gstAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Total Platform Charge: ₹${inv.totalPlatformCharge.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          if (inv.razorpayPaymentId != null) pw.Text('Razorpay Payment ID: ${inv.razorpayPaymentId}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 20),
          pw.Text(BillingConstants.disclaimer, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> technicianPaymentReceiptPdf(TechnicianPaymentReceiptModel r) async {
    final pdf = await _buildDocument();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(BillingConstants.platformName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.Text(BillingConstants.technicianReceiptTitle, style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 16),
          pw.Text('Receipt ID: ${r.displayReceiptId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Technician: ${r.technicianName}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Technician ID: ${r.displayTechnicianId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Job ID: ${r.displayJobId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Service Amount: ₹${r.totalJobAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.Text('Paid Amount (80%): ₹${r.technicianPaidAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text('Warranty Hold (20%): ₹${r.holdAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Transfer Date: ${r.transferDate != null ? _dateTimeFormat.format(r.transferDate!) : "—"}', style: const pw.TextStyle(fontSize: 10)),
          if (r.transferId != null) pw.Text('Transfer ID: ${r.transferId}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 20),
          pw.Text(BillingConstants.disclaimer, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> warrantyReleaseReceiptPdf(WarrantyReleaseReceiptModel r) async {
    final pdf = await _buildDocument();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text(BillingConstants.platformName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.Text(BillingConstants.warrantyReleaseTitle, style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 16),
          pw.Text('Release ID: ${r.displayReleaseId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Technician: ${r.technicianName ?? "—"}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Technician ID: ${r.displayTechnicianId}', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Job ID: ${r.displayJobId}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.Text('Hold Amount Released: ₹${r.holdAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text('Release Date: ${r.releaseDate != null ? _dateTimeFormat.format(r.releaseDate!) : "—"}', style: const pw.TextStyle(fontSize: 10)),
          if (r.transferId != null) pw.Text('Transfer ID: ${r.transferId}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 20),
          pw.Text(BillingConstants.disclaimer, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
    return pdf.save();
  }
}
