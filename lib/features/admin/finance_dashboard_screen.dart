import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';

/// Admin Finance Dashboard: revenue, commission, fees, expenses, net profit, charts.
class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  String _chartRange = '30'; // 30, 90, 365 days

  static const _bgLight = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Finance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go(RouteNames.adminHome)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MetricsSection(),
            const SizedBox(height: 24),
            _NetProfitCard(),
            const SizedBox(height: 24),
            _ChartsSection(chartRange: _chartRange, onRangeChanged: (v) => setState(() => _chartRange = v)),
            const SizedBox(height: 24),
            _ActionButtons(),
          ],
        ),
      ),
    );
  }
}

class _MetricsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.dealerPaymentReceipts().snapshots(),
          builder: (context, snap) {
            double payments = 0, razorpayFees = 0;
            if (snap.hasData) {
              for (final d in snap.data!.docs) {
                final data = d.data();
                payments += (data['paymentAmount'] as num?)?.toDouble() ?? 0;
                razorpayFees += (data['razorpayFee'] as num?)?.toDouble() ?? 0;
              }
            }
            return Column(
              children: [
                _MetricCard(title: 'Total Dealer Payments', value: '₹${payments.toStringAsFixed(2)}', icon: Icons.payments, color: AppColors.primary),
                const SizedBox(height: 12),
                _MetricCard(title: 'Razorpay Fees', value: '₹${razorpayFees.toStringAsFixed(2)}', icon: Icons.credit_card, color: Colors.purple),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.platformInvoices().snapshots(),
          builder: (context, snap) {
            double total = 0;
            if (snap.hasData) {
              for (final d in snap.data!.docs) {
                total += (d.data()['totalPlatformCharge'] as num?)?.toDouble() ?? 0;
              }
            }
            return _MetricCard(title: 'Platform Commission (Invoiced)', value: '₹${total.toStringAsFixed(2)}', icon: Icons.receipt, color: AppColors.success);
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.technicianPaymentReceipts().snapshots(),
          builder: (context, snap) {
            double paid = 0, hold = 0;
            if (snap.hasData) {
              for (final d in snap.data!.docs) {
                paid += (d.data()['technicianPaidAmount'] as num?)?.toDouble() ?? 0;
                hold += (d.data()['holdAmount'] as num?)?.toDouble() ?? 0;
              }
            }
            return Column(
              children: [
                _MetricCard(title: 'Technician Payouts (80%)', value: '₹${paid.toStringAsFixed(2)}', icon: Icons.engineering, color: Colors.blue),
                const SizedBox(height: 12),
                _MetricCard(title: 'Warranty Hold (20%)', value: '₹${hold.toStringAsFixed(2)}', icon: Icons.lock, color: Colors.orange),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.platformExpenses().snapshots(),
          builder: (context, snap) {
            double total = 0;
            if (snap.hasData) {
              for (final d in snap.data!.docs) {
                total += (d.data()['expenseAmount'] as num?)?.toDouble() ?? 0;
              }
            }
            return _MetricCard(title: 'Platform Expenses', value: '₹${total.toStringAsFixed(2)}', icon: Icons.money_off, color: Colors.red);
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.wallets().snapshots(),
          builder: (context, snap) {
            double escrow = 0;
            double warrantyHold = 0;
            if (snap.hasData) {
              for (final d in snap.data!.docs) {
                final data = d.data();
                final locks = (data['locks'] as List<dynamic>?) ?? [];
                for (final l in locks) {
                  final amt = (l is Map && l['amount'] != null) ? (l['amount'] as num).toDouble() : 0.0;
                  escrow += amt;
                }
                warrantyHold += (data['heldBalance'] as num?)?.toDouble() ?? 0;
              }
            }
            return Column(
              children: [
                _MetricCard(title: 'Escrow Balance', value: '₹${escrow.toStringAsFixed(2)}', icon: Icons.account_balance_wallet, color: Colors.indigo),
                const SizedBox(height: 12),
                _MetricCard(title: 'Warranty Holds (Tech)', value: '₹${warrantyHold.toStringAsFixed(2)}', icon: Icons.lock_clock, color: Colors.deepOrange),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.jobs().where('status', isEqualTo: 'pending_dealer_confirm').snapshots(),
          builder: (context, snap) {
            double pending = 0;
            if (snap.hasData) {
              for (final d in snap.data!.docs) {
                final data = d.data();
                pending += (data['technicianPayoutAmount'] as num?)?.toDouble() ?? (data['agreedAmount'] as num?)?.toDouble() ?? 0;
              }
            }
            return _MetricCard(title: 'Pending Payouts (Approval)', value: '₹${pending.toStringAsFixed(2)}', icon: Icons.pending_actions, color: Colors.teal);
          },
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.jobDisputes().where('status', isEqualTo: 'open').snapshots(),
          builder: (context, snap) {
            final count = snap.hasData ? snap.data!.docs.length : 0;
            return _MetricCard(title: 'Open Disputes', value: '$count', icon: Icons.gavel, color: Colors.amber.shade700);
          },
        ),
      ],
    );
  }
}

class _NetProfitCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.platformInvoices().snapshots(),
      builder: (context, invSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.dealerPaymentReceipts().snapshots(),
          builder: (context, recSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirestoreService.platformExpenses().snapshots(),
              builder: (context, expSnap) {
                double commission = 0, fees = 0, expenses = 0;
                if (invSnap.hasData) for (final d in invSnap.data!.docs) { commission += (d.data()['totalPlatformCharge'] as num?)?.toDouble() ?? 0; }
                if (recSnap.hasData) for (final d in recSnap.data!.docs) { fees += (d.data()['razorpayFee'] as num?)?.toDouble() ?? 0; }
                if (expSnap.hasData) for (final d in expSnap.data!.docs) { expenses += (d.data()['expenseAmount'] as num?)?.toDouble() ?? 0; }
                final netProfit = commission - fees - expenses;
                return Card(
                  color: netProfit >= 0 ? AppColors.success.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, size: 44, color: netProfit >= 0 ? AppColors.success : Colors.red),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Net Profit', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
                              Text('₹${netProfit.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                              Text('Commission − Razorpay fees − Expenses', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ChartsSection extends StatelessWidget {
  const _ChartsSection({required this.chartRange, required this.onRangeChanged});
  final String chartRange;
  final ValueChanged<String> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final limit = int.tryParse(chartRange) ?? 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Revenue & Profit Trend', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '30', label: Text('30d')),
                ButtonSegment(value: '90', label: Text('90d')),
                ButtonSegment(value: '365', label: Text('1y')),
              ],
              selected: {chartRange},
              onSelectionChanged: (s) => onRangeChanged(s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService.platformFinancialReports()
              .orderBy('date', descending: true)
              .limit(limit)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text('No report data yet. Daily reports are generated at 03:00 UTC.', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ),
              );
            }
            final docs = snapshot.data!.docs;
            final list = docs.map((d) {
              final data = d.data();
              return _DayReport(
                date: data['date'] as String? ?? '',
                totalPaymentsReceived: (data['totalPaymentsReceived'] as num?)?.toDouble() ?? 0,
                platformCommission: (data['platformCommission'] as num?)?.toDouble() ?? 0,
                netProfit: (data['netProfit'] as num?)?.toDouble() ?? 0,
              );
            }).toList();
            list.sort((a, b) => a.date.compareTo(b.date));
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: () { final m = list.map((e) => e.platformCommission).fold<double>(0, (a, b) => a > b ? a : b); return m < 1 ? 1.0 : m * 1.15; }(),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i >= 0 && i < list.length && (i % (list.length ~/ 6).clamp(1, 31)) == 0) {
                                final d = list[i].date;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(d.length >= 10 ? d.substring(5, 10) : d, style: const TextStyle(fontSize: 10)),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            reservedSize: 28,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, _) => Text('₹${(v / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10))),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false),
                      borderData: FlBorderData(show: false),
                      barGroups: list.asMap().entries.map((e) {
                        final i = e.key;
                        final r = e.value;
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(toY: r.platformCommission, color: AppColors.primary, width: list.length > 20 ? 4 : 8, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                          ],
                          showingTooltipIndicators: [0],
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 200),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DayReport {
  _DayReport({required this.date, required this.totalPaymentsReceived, required this.platformCommission, required this.netProfit});
  final String date;
  final double totalPaymentsReceived;
  final double platformCommission;
  final double netProfit;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(onPressed: () => context.push(RouteNames.adminExpenses), icon: const Icon(Icons.list), label: const Text('Expenses')),
        OutlinedButton.icon(onPressed: () => context.push(RouteNames.adminFinancialDocuments), icon: const Icon(Icons.description), label: const Text('Financial Documents')),
        OutlinedButton.icon(onPressed: () => context.push(RouteNames.adminDisputes), icon: const Icon(Icons.gavel), label: const Text('Disputes')),
        OutlinedButton.icon(onPressed: () => context.push(RouteNames.adminBillingGst), icon: const Icon(Icons.settings), label: const Text('GST Config')),
      ],
    );
  }
}
