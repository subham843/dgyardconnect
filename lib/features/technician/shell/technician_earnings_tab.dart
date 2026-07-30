import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/technician_ui_tokens.dart';
import '../../../shared/widgets/technician_glass_kit.dart';

class TechnicianEarningsTab extends StatelessWidget {
  const TechnicianEarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    const totalEarnings = 42850.0;
    const todayEarnings = 2450.0;
    const jobsCompleted = 26;
    const pendingPayout = 3200.0;
    const weekEarnings = 11800.0;
    final transactions = <_TxItem>[
      const _TxItem(amount: 1250, dateLabel: 'Today, 10:30 AM', title: 'Job payout credited'),
      const _TxItem(amount: 400, dateLabel: 'Yesterday, 6:15 PM', title: 'Warranty release'),
      const _TxItem(amount: 1800, dateLabel: 'Mar 29, 4:42 PM', title: 'Installation payout'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Earnings', style: TechnicianUiTokens.textTitle1())
              .animate()
              .fadeIn(duration: TechnicianUiTokens.motionMedium)
              .slideY(begin: 0.06, curve: TechnicianUiTokens.motionCurve),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _EarningsSummaryCard(
                  totalEarnings: totalEarnings,
                  todayEarnings: todayEarnings,
                )
                    .animate(delay: 80.ms)
                    .fadeIn(duration: TechnicianUiTokens.motionMedium)
                    .slideY(begin: 0.04, curve: TechnicianUiTokens.motionCurve),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickStatCard(
                        label: 'Jobs completed',
                        value: '$jobsCompleted',
                        icon: Icons.task_alt_rounded,
                        valueColor: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickStatCard(
                        label: 'Pending payout',
                        value: '₹${pendingPayout.toStringAsFixed(0)}',
                        icon: Icons.hourglass_top_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickStatCard(
                        label: 'This week',
                        value: '₹${weekEarnings.toStringAsFixed(0)}',
                        icon: Icons.calendar_view_week_rounded,
                        valueColor: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Quick actions', style: TechnicianUiTokens.textCaption1()),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: [
                    _ActionGridTile(
                      label: 'Wallet',
                      icon: Icons.account_balance_wallet_rounded,
                      onTap: () => context.push(RouteNames.technicianWallet),
                    ),
                    _ActionGridTile(
                      label: 'Receipts',
                      icon: Icons.receipt_long_rounded,
                      onTap: () => context.push(RouteNames.technicianPaymentReceipts),
                    ),
                    _ActionGridTile(
                      label: 'Payout history',
                      icon: Icons.payments_rounded,
                      onTap: () => context.push(RouteNames.technicianPayoutHistory),
                    ),
                    _ActionGridTile(
                      label: 'Settlement',
                      icon: Icons.account_balance_rounded,
                      onTap: () => context.push(RouteNames.technicianSettlementAccount),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Recent activity', style: TechnicianUiTokens.textCaption1()),
                const SizedBox(height: 8),
                TechnicianGlassCard(
                  radius: 16,
                  blurSigma: TechnicianUiTokens.blurMedium,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: transactions
                        .map((tx) => _RecentTxTile(item: tx))
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 14),
                _WithdrawButton(onTap: () => context.push(RouteNames.technicianSettlementAccount)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsSummaryCard extends StatelessWidget {
  const _EarningsSummaryCard({
    required this.totalEarnings,
    required this.todayEarnings,
  });

  final double totalEarnings;
  final double todayEarnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandWarmSoft.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TechnicianGlassCard(
        radius: 16,
        blurSigma: TechnicianUiTokens.blurHeavy,
        padding: const EdgeInsets.all(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.brandWarmSoft.withValues(alpha: 0.88),
                AppColors.brandWarmLight.withValues(alpha: 0.92),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total earnings', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                '₹${totalEarnings.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Today: ₹${todayEarnings.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return TechnicianGlassCard(
      radius: 16,
      blurSigma: TechnicianUiTokens.blurMedium,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.brandWarmSoft),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor ?? TechnicianUiTokens.labelPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TechnicianUiTokens.textCaption2(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ActionGridTile extends StatefulWidget {
  const _ActionGridTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ActionGridTile> createState() => _ActionGridTileState();
}

class _ActionGridTileState extends State<_ActionGridTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 0.98 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(16),
          child: TechnicianGlassCard(
            radius: 16,
            blurSigma: TechnicianUiTokens.blurMedium,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandWarmSoft.withValues(alpha: 0.22),
                        AppColors.brandWarmLight.withValues(alpha: 0.22),
                      ],
                    ),
                  ),
                  child: Icon(widget.icon, color: AppColors.brandWarmSoft),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TechnicianUiTokens.textSubhead(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TxItem {
  const _TxItem({
    required this.amount,
    required this.dateLabel,
    required this.title,
  });

  final double amount;
  final String dateLabel;
  final String title;
}

class _RecentTxTile extends StatelessWidget {
  const _RecentTxTile({required this.item});

  final _TxItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0x1422C55E),
        child: Icon(Icons.south_west_rounded, color: Color(0xFF16A34A), size: 18),
      ),
      title: Text(item.title, style: TechnicianUiTokens.textSubhead()),
      subtitle: Text(item.dateLabel, style: TechnicianUiTokens.textCaption2()),
      trailing: Text(
        '+₹${item.amount.toStringAsFixed(0)}',
        style: GoogleFonts.inter(
          color: const Color(0xFF16A34A),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _WithdrawButton extends StatelessWidget {
  const _WithdrawButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [AppColors.brandWarmSoft, AppColors.brandWarmLight],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandWarmSoft.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Withdraw',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
