import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dealer_payment_receipt_model.dart';
import '../../shared/models/platform_invoice_model.dart';
import '../../shared/models/technician_payment_receipt_model.dart';
import '../../shared/models/warranty_release_receipt_model.dart';
import '../../shared/services/firestore_service.dart';
import '../shared/billing_pdf_helper.dart';

/// Admin: view all financial documents with filters.
class AdminFinancialDocumentsScreen extends StatefulWidget {
  const AdminFinancialDocumentsScreen({super.key});

  @override
  State<AdminFinancialDocumentsScreen> createState() => _AdminFinancialDocumentsScreenState();
}

class _AdminFinancialDocumentsScreenState extends State<AdminFinancialDocumentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Documents'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go(RouteNames.adminFinance)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dealer Receipts'),
            Tab(text: 'Platform Invoices'),
            Tab(text: 'Tech Receipts'),
            Tab(text: 'Warranty Release'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DealerReceiptsList(),
          _PlatformInvoicesList(),
          _TechReceiptsList(),
          _WarrantyReleaseList(),
        ],
      ),
    );
  }
}

class _DealerReceiptsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.dealerPaymentReceipts().orderBy('paymentDate', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No dealer payment receipts'));
        final dateFormat = DateFormat('dd MMM yyyy');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final r = DealerPaymentReceiptModel.fromFirestore(docs[index]);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${r.dealerName} · Job ${r.displayJobId}'),
                subtitle: Text('₹${r.paymentAmount.toStringAsFixed(2)} · ${r.paymentDate != null ? dateFormat.format(r.paymentDate!) : "—"}'),
                trailing: IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () async { final bytes = await BillingPdfHelper.dealerPaymentReceiptPdf(r); await Printing.sharePdf(bytes: bytes, filename: 'dealer_receipt_${r.displayReceiptId}.pdf'); }),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlatformInvoicesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.platformInvoices().orderBy('invoiceDate', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No platform invoices'));
        final dateFormat = DateFormat('dd MMM yyyy');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final inv = PlatformInvoiceModel.fromFirestore(docs[index]);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${inv.dealerName} · Job ${inv.displayJobId}'),
                subtitle: Text('₹${inv.totalPlatformCharge.toStringAsFixed(2)} · ${inv.invoiceDate != null ? dateFormat.format(inv.invoiceDate!) : "—"}'),
                trailing: IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () async { final bytes = await BillingPdfHelper.platformInvoicePdf(inv); await Printing.sharePdf(bytes: bytes, filename: 'platform_invoice_${inv.displayInvoiceId}.pdf'); }),
              ),
            );
          },
        );
      },
    );
  }
}

class _TechReceiptsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.technicianPaymentReceipts().orderBy('transferDate', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No technician payment receipts'));
        final dateFormat = DateFormat('dd MMM yyyy');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final r = TechnicianPaymentReceiptModel.fromFirestore(docs[index]);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${r.technicianName} · Job ${r.displayJobId}'),
                subtitle: Text('Paid ₹${r.technicianPaidAmount.toStringAsFixed(2)} · ${r.transferDate != null ? dateFormat.format(r.transferDate!) : "—"}'),
                trailing: IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () async { final bytes = await BillingPdfHelper.technicianPaymentReceiptPdf(r); await Printing.sharePdf(bytes: bytes, filename: 'technician_receipt_${r.displayReceiptId}.pdf'); }),
              ),
            );
          },
        );
      },
    );
  }
}

class _WarrantyReleaseList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.warrantyReleaseReceipts().orderBy('releaseDate', descending: true).limit(100).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No warranty release receipts'));
        final dateFormat = DateFormat('dd MMM yyyy');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final r = WarrantyReleaseReceiptModel.fromFirestore(docs[index]);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${r.technicianName ?? "—"} · Job ${r.displayJobId}'),
                subtitle: Text('Released ₹${r.holdAmount.toStringAsFixed(2)} · ${r.releaseDate != null ? dateFormat.format(r.releaseDate!) : "—"}'),
                trailing: IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () async { final bytes = await BillingPdfHelper.warrantyReleaseReceiptPdf(r); await Printing.sharePdf(bytes: bytes, filename: 'warranty_release_${r.displayReleaseId}.pdf'); }),
              ),
            );
          },
        );
      },
    );
  }
}
