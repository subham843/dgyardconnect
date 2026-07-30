import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/constants/billing_constants.dart';
import '../../shared/models/technician_payment_receipt_model.dart';
import '../../shared/models/warranty_release_receipt_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import '../shared/billing_pdf_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';

enum _ReceiptStatusFilter { all, paid, onHold }
enum _ReceiptDateFilter { all, today, thisMonth }

/// Soft saffron-tinted elevation around glass cards.
class _GlassShadowWrap extends StatelessWidget {
  const _GlassShadowWrap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandWarmSoft.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Technician Payment Receipts and Warranty Release Receipts.
class TechnicianPaymentReceiptsScreen extends StatefulWidget {
  const TechnicianPaymentReceiptsScreen({super.key});

  @override
  State<TechnicianPaymentReceiptsScreen> createState() => _TechnicianPaymentReceiptsScreenState();
}

class _TechnicianPaymentReceiptsScreenState extends State<TechnicianPaymentReceiptsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _ReceiptStatusFilter _statusFilter = _ReceiptStatusFilter.all;
  _ReceiptDateFilter _dateFilter = _ReceiptDateFilter.all;

  bool get _filtersActive =>
      _statusFilter != _ReceiptStatusFilter.all || _dateFilter != _ReceiptDateFilter.all;
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
      return TechnicianLightScope(
        child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const TechnicianGlassAppBar(title: 'Payment Receipts'),
        body: const TechnicianGlassBackground(
          child: Center(child: Text('Sign in required')),
        ),
        ),
      );
    }

    return TechnicianLightScope(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Payment Receipts',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: Icon(
              Icons.filter_alt_outlined,
              color: _filtersActive ? AppColors.brandWarmDark : TechnicianUiTokens.labelSecondary,
            ),
            onPressed: _openFilters,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brandWarmSoft,
          indicatorWeight: 3,
          labelColor: TechnicianUiTokens.labelPrimary,
          labelStyle: TechnicianUiTokens.textSubhead().copyWith(fontWeight: FontWeight.w700),
          unselectedLabelColor: TechnicianUiTokens.labelSecondary,
          unselectedLabelStyle: TechnicianUiTokens.textSubhead().copyWith(fontWeight: FontWeight.w500),
          dividerColor: TechnicianUiTokens.separator,
          tabs: const [Tab(text: 'Receipts'), Tab(text: 'Warranty Release')],
        ),
      ),
      body: TechnicianGlassBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _TechnicianReceiptsList(
              uid: uid,
              statusFilter: _statusFilter,
              dateFilter: _dateFilter,
            ),
            _WarrantyReleaseList(uid: uid, dateFilter: _dateFilter),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _openFilters() async {
    _ReceiptStatusFilter tempStatus = _statusFilter;
    _ReceiptDateFilter tempDate = _dateFilter;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter by status', style: TechnicianUiTokens.textHeadline()),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _ReceiptStatusFilter.values.map((f) {
                      return ChoiceChip(
                        selected: tempStatus == f,
                        label: Text(_statusLabel(f)),
                        onSelected: (_) => setModal(() => tempStatus = f),
                        selectedColor: AppColors.brandWarmLight.withValues(alpha: 0.35),
                        checkmarkColor: AppColors.brandWarmDark,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Filter by date', style: TechnicianUiTokens.textHeadline()),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _ReceiptDateFilter.values.map((f) {
                      return ChoiceChip(
                        selected: tempDate == f,
                        label: Text(_dateLabel(f)),
                        onSelected: (_) => setModal(() => tempDate = f),
                        selectedColor: AppColors.brandWarmLight.withValues(alpha: 0.35),
                        checkmarkColor: AppColors.brandWarmDark,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _statusFilter = tempStatus;
                          _dateFilter = tempDate;
                        });
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandWarmSoft,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _statusLabel(_ReceiptStatusFilter f) {
    switch (f) {
      case _ReceiptStatusFilter.paid:
        return 'Paid';
      case _ReceiptStatusFilter.onHold:
        return 'On hold';
      case _ReceiptStatusFilter.all:
        return 'All';
    }
  }

  String _dateLabel(_ReceiptDateFilter f) {
    switch (f) {
      case _ReceiptDateFilter.today:
        return 'Today';
      case _ReceiptDateFilter.thisMonth:
        return 'This month';
      case _ReceiptDateFilter.all:
        return 'All';
    }
  }
}

class _TechnicianReceiptsList extends StatelessWidget {
  const _TechnicianReceiptsList({
    required this.uid,
    required this.statusFilter,
    required this.dateFilter,
  });
  final String uid;
  final _ReceiptStatusFilter statusFilter;
  final _ReceiptDateFilter dateFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.technicianPaymentReceipts()
          .where('technicianId', isEqualTo: uid)
          .orderBy('transferDate', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.brandWarmLight, strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load receipts right now. Please check your connection and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        var docs = snapshot.data?.docs ?? [];
        docs = docs.where((d) {
          final r = TechnicianPaymentReceiptModel.fromFirestore(d);
          final dt = r.transferDate;
          final now = DateTime.now();
          final isToday = dt != null &&
              dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day;
          final isThisMonth = dt != null && dt.year == now.year && dt.month == now.month;
          if (dateFilter == _ReceiptDateFilter.today && !isToday) return false;
          if (dateFilter == _ReceiptDateFilter.thisMonth && !isThisMonth) return false;
          if (statusFilter == _ReceiptStatusFilter.paid && r.technicianPaidAmount <= 0) return false;
          if (statusFilter == _ReceiptStatusFilter.onHold && r.holdAmount <= 0) return false;
          return true;
        }).toList();
        if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No payment receipts yet.', textAlign: TextAlign.center)));
        final totalEarned = docs.fold<double>(
          0,
          (acc, d) {
            final r = TechnicianPaymentReceiptModel.fromFirestore(d);
            return acc + r.technicianPaidAmount + r.holdAmount;
          },
        );
        final onHold = docs.fold<double>(
          0,
          (acc, d) => acc + TechnicianPaymentReceiptModel.fromFirestore(d).holdAmount,
        );

        DateTime? lastDate;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryCard(totalEarned: totalEarned, onHold: onHold),
            const SizedBox(height: 14),
            ...docs.map((d) {
              final r = TechnicianPaymentReceiptModel.fromFirestore(d);
              final thisDate = r.transferDate;
              final showHeader = !_sameDay(lastDate, thisDate);
              lastDate = thisDate;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                      child: Text(
                        _groupLabel(thisDate),
                        style: TechnicianUiTokens.textSubhead(
                          color: TechnicianUiTokens.labelSecondary,
                        ),
                      ),
                    ),
                  ],
                  _ReceiptCard(
                    title: 'Job ${r.displayJobId}',
                    receiptId: r.displayReceiptId,
                    dateText: r.transferDate != null
                        ? DateFormat('dd MMM yyyy').format(r.transferDate!)
                        : '—',
                    paid: r.technicianPaidAmount,
                    hold: r.holdAmount,
                    onOpenDetail: () => _showDetail(context, r),
                  ),
                ],
              );
            }),
          ],
        );
      },
    );
  }

  void _showDetail(BuildContext context, TechnicianPaymentReceiptModel r) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(BillingConstants.platformName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(BillingConstants.technicianReceiptTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _row('Receipt ID', r.displayReceiptId),
              _row('Job ID', r.displayJobId),
              _row('Technician ID', r.displayTechnicianId),
              _row('Total Job Amount', '₹${r.totalJobAmount.toStringAsFixed(2)}'),
              _row('Paid (80%)', '₹${r.technicianPaidAmount.toStringAsFixed(2)}'),
              _row('Hold (20%)', '₹${r.holdAmount.toStringAsFixed(2)}'),
              _row('Date', r.transferDate != null ? dateFormat.format(r.transferDate!) : '—'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await Printing.layoutPdf(onLayout: (_) async => await BillingPdfHelper.technicianPaymentReceiptPdf(r));
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
                        final bytes = await BillingPdfHelper.technicianPaymentReceiptPdf(r);
                        await Printing.sharePdf(bytes: bytes, filename: 'technician_receipt_${r.displayReceiptId}.pdf');
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

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: TechnicianUiTokens.labelSecondary))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Widget _summaryCard({required double totalEarned, required double onHold}) {
    return _GlassShadowWrap(
      child: TechnicianGlassCard(
        radius: 16,
        blurSigma: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total earned: ₹${totalEarned.toStringAsFixed(0)}', style: TechnicianUiTokens.textHeadline()),
            const SizedBox(height: 6),
            Text(
              'On hold: ₹${onHold.toStringAsFixed(0)}',
              style: TechnicianUiTokens.textSubhead(color: TechnicianUiTokens.labelSecondary),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a?.year == b?.year && a?.month == b?.month && a?.day == b?.day;

  String _groupLabel(DateTime? d) {
    if (d == null) return 'Unknown';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    if (that == today) return 'Today';
    if (that == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM yyyy').format(d);
  }
}

class _WarrantyReleaseList extends StatelessWidget {
  const _WarrantyReleaseList({required this.uid, required this.dateFilter});
  final String uid;
  final _ReceiptDateFilter dateFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.warrantyReleaseReceipts()
          .where('technicianId', isEqualTo: uid)
          .orderBy('releaseDate', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.brandWarmLight, strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load warranty releases right now. Please check your connection and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        var docs = snapshot.data?.docs ?? [];
        docs = docs.where((d) {
          final r = WarrantyReleaseReceiptModel.fromFirestore(d);
          final dt = r.releaseDate;
          final now = DateTime.now();
          final isToday = dt != null &&
              dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day;
          final isThisMonth = dt != null && dt.year == now.year && dt.month == now.month;
          if (dateFilter == _ReceiptDateFilter.today && !isToday) return false;
          if (dateFilter == _ReceiptDateFilter.thisMonth && !isThisMonth) return false;
          return true;
        }).toList();
        if (docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No warranty release receipts yet.', textAlign: TextAlign.center)));
        final totalReleased = docs.fold<double>(
          0,
          (acc, d) => acc + WarrantyReleaseReceiptModel.fromFirestore(d).holdAmount,
        );
        DateTime? lastDate;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _GlassShadowWrap(
              child: TechnicianGlassCard(
                radius: 16,
                blurSigma: 20,
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Total released: ₹${totalReleased.toStringAsFixed(0)}',
                  style: TechnicianUiTokens.textHeadline(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...docs.map((d) {
              final r = WarrantyReleaseReceiptModel.fromFirestore(d);
              final showHeader = !_sameDay(lastDate, r.releaseDate);
              lastDate = r.releaseDate;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                      child: Text(
                        _groupLabel(r.releaseDate),
                        style: TechnicianUiTokens.textSubhead(color: TechnicianUiTokens.labelSecondary),
                      ),
                    ),
                  _ReleaseCard(
                    title: 'Job ${r.displayJobId}',
                    dateText: r.releaseDate != null
                        ? DateFormat('dd MMM yyyy').format(r.releaseDate!)
                        : '—',
                    amount: r.holdAmount,
                    onTap: () => _showDetail(context, r),
                  ),
                ],
              );
            }),
          ],
        );
      },
    );
  }

  void _showDetail(BuildContext context, WarrantyReleaseReceiptModel r) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(BillingConstants.warrantyReleaseTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _row('Release ID', r.displayReleaseId),
            _row('Job ID', r.displayJobId),
            _row('Technician ID', r.displayTechnicianId),
            _row('Hold Released', '₹${r.holdAmount.toStringAsFixed(2)}'),
            _row('Date', r.releaseDate != null ? dateFormat.format(r.releaseDate!) : '—'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Printing.layoutPdf(onLayout: (_) async => await BillingPdfHelper.warrantyReleaseReceiptPdf(r));
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
                      final bytes = await BillingPdfHelper.warrantyReleaseReceiptPdf(r);
                      await Printing.sharePdf(bytes: bytes, filename: 'warranty_release_${r.displayReleaseId}.pdf');
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
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: TechnicianUiTokens.labelSecondary))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
    ]),
  );

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a?.year == b?.year && a?.month == b?.month && a?.day == b?.day;

  String _groupLabel(DateTime? d) {
    if (d == null) return 'Unknown';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    if (that == today) return 'Today';
    if (that == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM yyyy').format(d);
  }
}

class _ReceiptCard extends StatefulWidget {
  const _ReceiptCard({
    required this.title,
    required this.receiptId,
    required this.dateText,
    required this.paid,
    required this.hold,
    required this.onOpenDetail,
  });

  final String title;
  final String receiptId;
  final String dateText;
  final double paid;
  final double hold;
  final VoidCallback onOpenDetail;

  @override
  State<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<_ReceiptCard> {
  bool _pressed = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final amountStyle = TechnicianUiTokens.textHeadline().copyWith(fontWeight: FontWeight.w800);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        scale: _pressed ? 0.985 : 1,
        child: _GlassShadowWrap(
          child: TechnicianGlassCard(
            radius: 16,
            blurSigma: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: TechnicianUiTokens.textHeadline()),
                          const SizedBox(height: 4),
                          Text(widget.dateText, style: TechnicianUiTokens.textCaption2()),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.paid > 0)
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '₹${widget.paid.toStringAsFixed(0)} ', style: amountStyle.copyWith(color: TechnicianUiTokens.labelPrimary)),
                                const TextSpan(
                                  text: '(Paid)',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        if (widget.hold > 0) ...[
                          if (widget.paid > 0) const SizedBox(height: 6),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '₹${widget.hold.toStringAsFixed(0)} ', style: amountStyle.copyWith(color: TechnicianUiTokens.labelPrimary)),
                                const TextSpan(
                                  text: '(On hold)',
                                  style: TextStyle(color: AppColors.brandWarmDark, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          visualDensity: VisualDensity.compact,
                          tooltip: _expanded ? 'Collapse preview' : 'Expand preview',
                          icon: Icon(
                            _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 24,
                            color: AppColors.brandWarmDark.withValues(alpha: 0.9),
                          ),
                          onPressed: () => setState(() => _expanded = !_expanded),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onOpenDetail,
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Text(
                            'View Details →',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandWarmSoft,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(height: 1, color: TechnicianUiTokens.separator.withValues(alpha: 0.6)),
                              const SizedBox(height: 10),
                              Text('Receipt ID', style: TechnicianUiTokens.textCaption2()),
                              Text(widget.receiptId, style: TechnicianUiTokens.textSubhead()),
                              const SizedBox(height: 6),
                              Text(
                                'Use View Details for print, PDF, and full breakdown.',
                                style: TechnicianUiTokens.textCaption2(),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatefulWidget {
  const _ReleaseCard({
    required this.title,
    required this.dateText,
    required this.amount,
    required this.onTap,
  });

  final String title;
  final String dateText;
  final double amount;
  final VoidCallback onTap;

  @override
  State<_ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<_ReleaseCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final amountStyle = TechnicianUiTokens.textHeadline().copyWith(fontWeight: FontWeight.w800);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        scale: _pressed ? 0.985 : 1,
        child: _GlassShadowWrap(
          child: TechnicianGlassCard(
            radius: 16,
            blurSigma: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: TechnicianUiTokens.textHeadline()),
                          const SizedBox(height: 4),
                          Text(widget.dateText, style: TechnicianUiTokens.textCaption2()),
                        ],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '₹${widget.amount.toStringAsFixed(0)} ', style: amountStyle.copyWith(color: TechnicianUiTokens.labelPrimary)),
                          const TextSpan(
                            text: '(Released)',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTapCancel: () => setState(() => _pressed = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Text(
                            'View Details →',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandWarmSoft,
                              fontSize: 14,
                            ),
                          ),
                        ],
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
