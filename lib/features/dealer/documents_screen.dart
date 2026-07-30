import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/constants/billing_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/dealer_payment_receipt_model.dart';
import '../../shared/models/platform_invoice_model.dart';
import '../../shared/services/firestore_service.dart';
import '../shared/billing_pdf_helper.dart';

/// Dealer Documents: Payment Receipts and Platform Invoices.
class DealerDocumentsScreen extends StatefulWidget {
  const DealerDocumentsScreen({super.key});

  @override
  State<DealerDocumentsScreen> createState() => _DealerDocumentsScreenState();
}

class _DealerDocumentsScreenState extends State<DealerDocumentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _bgLight = Color(0xFFF8FAFC);
  static const _cardBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Documents'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Sign in required')),
      );
    }

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Documents'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: const Color(0xFF64748B),
          dividerColor: _cardBorder,
          tabs: const [
            Tab(text: 'Payment Receipts'),
            Tab(text: 'Platform Invoices'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PaymentReceiptsList(uid: uid),
          _PlatformInvoicesList(uid: uid),
        ],
      ),
    );
  }
}

class _PaymentReceiptsList extends StatelessWidget {
  const _PaymentReceiptsList({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.dealerPaymentReceipts()
          .where('dealerId', isEqualTo: uid)
          .orderBy('paymentDate', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load payment receipts right now. Please check your connection and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No job payment receipts yet. Receipts appear after you pay for a specific on-site service job (processed via Razorpay).',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final dateFormat = DateFormat('dd MMM yyyy');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final r = DealerPaymentReceiptModel.fromFirestore(docs[index]);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                title: Text(
                  'Receipt ${r.displayReceiptId}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Job: ${r.displayJobId}\n₹${r.paymentAmount.toStringAsFixed(2)} · ${r.paymentDate != null ? dateFormat.format(r.paymentDate!) : "—"}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => _onAction(context, v, r),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View')),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Text('Download PDF'),
                    ),
                    const PopupMenuItem(value: 'print', child: Text('Print')),
                  ],
                ),
                onTap: () => _showReceiptDetail(context, r),
              ),
            );
          },
        );
      },
    );
  }

  void _showReceiptDetail(BuildContext context, DealerPaymentReceiptModel r) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                BillingConstants.platformName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                BillingConstants.paymentReceiptTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _row('Receipt ID', r.displayReceiptId),
              _row('Job ID', r.displayJobId),
              _row('Dealer ID', r.displayDealerId),
              _row('Dealer', r.dealerName),
              _row(
                'Service',
                '${r.serviceSector ?? "—"} / ${r.serviceType ?? "—"}',
              ),
              _row('Amount', '₹${r.paymentAmount.toStringAsFixed(2)}'),
              _row(
                'Date',
                r.paymentDate != null ? dateFormat.format(r.paymentDate!) : '—',
              ),
              _row('Method', r.paymentMethod ?? '—'),
              _row('Gateway', 'Razorpay (on-site job payment)'),
              _row('Status', r.paymentStatus ?? '—'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final bytes =
                            await BillingPdfHelper.dealerPaymentReceiptPdf(r);
                        await Printing.layoutPdf(onLayout: (_) async => bytes);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final bytes =
                            await BillingPdfHelper.dealerPaymentReceiptPdf(r);
                        await Printing.sharePdf(
                          bytes: bytes,
                          filename: 'dealer_receipt_${r.displayReceiptId}.pdf',
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('PDF'),
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

  Future<void> _onAction(
    BuildContext context,
    String action,
    DealerPaymentReceiptModel r,
  ) async {
    final bytes = await BillingPdfHelper.dealerPaymentReceiptPdf(r);
    if (action == 'print') {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else if (action == 'pdf') {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'dealer_receipt_${r.displayReceiptId}.pdf',
      );
    } else {
      _showReceiptDetail(context, r);
    }
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

class _PlatformInvoicesList extends StatelessWidget {
  const _PlatformInvoicesList({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.platformInvoices()
          .where('dealerId', isEqualTo: uid)
          .orderBy('invoiceDate', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load platform invoices right now. Please check your connection and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No platform invoices yet. Invoices are created when a job is completed.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final dateFormat = DateFormat('dd MMM yyyy');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final inv = PlatformInvoiceModel.fromFirestore(docs[index]);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                title: Text(
                  'Invoice ${inv.displayInvoiceId}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Job: ${inv.displayJobId}\nTotal: ₹${inv.totalPlatformCharge.toStringAsFixed(2)} · ${inv.invoiceDate != null ? dateFormat.format(inv.invoiceDate!) : "—"}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) => _onAction(context, v, inv),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('View')),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Text('Download PDF'),
                    ),
                    const PopupMenuItem(value: 'print', child: Text('Print')),
                  ],
                ),
                onTap: () => _showInvoiceDetail(context, inv),
              ),
            );
          },
        );
      },
    );
  }

  void _showInvoiceDetail(BuildContext context, PlatformInvoiceModel inv) {
    final dateFormat = DateFormat('dd MMM yyyy');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                BillingConstants.platformName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                BillingConstants.platformInvoiceTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _row('Invoice ID', inv.displayInvoiceId),
              _row('Job ID', inv.displayJobId),
              _row('Dealer ID', inv.displayDealerId),
              _row('Dealer', inv.dealerName),
              _row(
                'Service Amount',
                '₹${inv.serviceAmount.toStringAsFixed(2)}',
              ),
              _row(
                'Platform Commission',
                '₹${inv.platformCommission.toStringAsFixed(2)}',
              ),
              _row('GST', '₹${inv.gstAmount.toStringAsFixed(2)}'),
              _row('Total', '₹${inv.totalPlatformCharge.toStringAsFixed(2)}'),
              _row(
                'Date',
                inv.invoiceDate != null
                    ? dateFormat.format(inv.invoiceDate!)
                    : '—',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Printing.layoutPdf(
                          onLayout: (_) async =>
                              await BillingPdfHelper.platformInvoicePdf(inv),
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final bytes = await BillingPdfHelper.platformInvoicePdf(
                          inv,
                        );
                        await Printing.sharePdf(
                          bytes: bytes,
                          filename:
                              'platform_invoice_${inv.displayInvoiceId}.pdf',
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('PDF'),
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

  Future<void> _onAction(
    BuildContext context,
    String action,
    PlatformInvoiceModel inv,
  ) async {
    final bytes = await BillingPdfHelper.platformInvoicePdf(inv);
    if (action == 'print' || action == 'pdf') {
      if (action == 'print') {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'platform_invoice_${inv.displayInvoiceId}.pdf',
        );
      }
    } else {
      _showInvoiceDetail(context, inv);
    }
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}
