import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/dealer_ui_tokens.dart';
import '../../shared/models/job_model.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/dealer_ui_kit.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key, this.initialSearchQuery});

  /// Optional query from home search (`/dealer/jobs?q=`).
  final String? initialSearchQuery;

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _JobFilter _filter = _JobFilter.all;

  @override
  void initState() {
    super.initState();
    final preset = widget.initialSearchQuery?.trim();
    if (preset != null && preset.isNotEmpty) {
      _searchController.text = preset;
      _searchQuery = preset;
    }
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return Scaffold(
        appBar: DealerMinimalAppBar(
          title: 'My jobs',
          onBack: () => context.go(RouteNames.dealerHome),
        ),
        body: const Center(child: Text(AppConstants.signInRequired)),
      );
    }

    return Scaffold(
      backgroundColor: DealerUiTokens.pageBg,
      appBar: DealerMinimalAppBar(
        title: 'My jobs',
        backgroundColor: Colors.white,
        foregroundColor: DealerUiTokens.textPrimary,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(RouteNames.dealerHome);
          }
        },
        actions: [
          IconButton(
            tooltip: 'Under warranty jobs',
            icon: const Icon(Icons.verified_user_outlined, color: DealerUiTokens.textPrimary),
            onPressed: () => context.push(RouteNames.dealerUnderWarrantyJobs),
          ),
          IconButton(
            tooltip: 'Post job',
            icon: const Icon(Icons.add_rounded, color: DealerUiTokens.textPrimary),
            onPressed: () => context.push(RouteNames.dealerPostJob),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.jobs()
            .where('dealerId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${AppConstants.errorGeneric} ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allJobs = snapshot.data!.docs.map(JobModel.fromFirestore).toList(growable: false);
          final filtered = allJobs.where((job) => _passesFilters(job)).toList(growable: false);

          if (allJobs.isEmpty) {
            return _buildEmptyState(uid);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: _JobsOverviewHeader(
                    total: allJobs.length,
                    active: allJobs.where((j) => _isActiveStatus(j.status)).length,
                    completed: allJobs.where((j) => j.status == JobStatus.completed).length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _QuickActionsRow(
                    onUnderWarrantyTap: () => context.push(RouteNames.dealerUnderWarrantyJobs),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _SearchBar(
                    controller: _searchController,
                    onClear: () => _searchController.clear(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: _FilterRow(
                    value: _filter,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoFilteredJobs(),
                )
              else
                SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final job = filtered[index];
                    return Padding(
                      padding: EdgeInsets.fromLTRB(16, index == 0 ? 2 : 0, 16, index == filtered.length - 1 ? 24 : 0),
                      child: _JobCard(job: job),
                    )
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: index * 35))
                        .slideY(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.users().doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        final approved = userSnapshot.data?.data()?['approved'] as bool? ?? false;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.work_outline_rounded, size: 40, color: AppColors.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  'No jobs yet',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Post your first requirement and start receiving technician responses.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                DealerMorphingButton(
                  label: 'Post a job',
                  icon: Icons.add_rounded,
                  onPressed: approved ? () => context.push(RouteNames.dealerPostJob) : null,
                  width: 210,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _passesFilters(JobModel job) {
    final statusPass = switch (_filter) {
      _JobFilter.all => true,
      _JobFilter.active => _isActiveStatus(job.status),
      _JobFilter.completed => job.status == JobStatus.completed,
      _JobFilter.cancelled => job.status == JobStatus.cancelled,
    };
    if (!statusPass) return false;
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return (job.title ?? '').toLowerCase().contains(q) ||
        job.displayId.toLowerCase().contains(q) ||
        job.status.name.toLowerCase().contains(q);
  }
}

class _JobsOverviewHeader extends StatelessWidget {
  const _JobsOverviewHeader({
    required this.total,
    required this.active,
    required this.completed,
  });

  final int total;
  final int active;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DealerUiTokens.rLg),
        border: Border.all(color: DealerUiTokens.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jobs overview',
            style: GoogleFonts.inter(
              color: DealerUiTokens.textPrimary,
              fontSize: DealerUiTokens.titleSection,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetricTile(label: 'Total', value: total.toString()),
              const SizedBox(width: 8),
              _MetricTile(label: 'Active', value: active.toString()),
              const SizedBox(width: 8),
              _MetricTile(label: 'Completed', value: completed.toString()),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.onUnderWarrantyTap});

  final VoidCallback onUnderWarrantyTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onUnderWarrantyTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_user_rounded, size: 18, color: AppColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Under warranty jobs',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                color: const Color(0xFF111827),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF6B7280),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Search by title, ID or status',
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.value,
    required this.onChanged,
  });

  final _JobFilter value;
  final ValueChanged<_JobFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipItem(
            label: 'All',
            selected: value == _JobFilter.all,
            onTap: () => onChanged(_JobFilter.all),
          ),
          _FilterChipItem(
            label: 'Active',
            selected: value == _JobFilter.active,
            onTap: () => onChanged(_JobFilter.active),
          ),
          _FilterChipItem(
            label: 'Completed',
            selected: value == _JobFilter.completed,
            onTap: () => onChanged(_JobFilter.completed),
          ),
          _FilterChipItem(
            label: 'Cancelled',
            selected: value == _JobFilter.cancelled,
            onTap: () => onChanged(_JobFilter.cancelled),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? Colors.white : const Color(0xFF334155),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final JobModel job;

  @override
  Widget build(BuildContext context) {
    final amount = (job.agreedAmount ?? job.dealerRate ?? 0).toDouble();
    final created = job.createdAt;
    final statusTone = _statusTone(job.status);
    final dateLabel = created == null ? '—' : DateFormat('dd MMM yyyy').format(created);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(RouteNames.dealerJobDetail.replaceFirst(':id', job.id)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusTone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.work_outline_rounded, color: statusTone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title ?? 'Job ${job.displayId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ID: ${job.displayId}',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(label: _statusLabel(job.status), color: statusTone),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoCell(
                      label: 'Amount',
                      value: '₹${amount.toStringAsFixed(2)}',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoCell(
                      label: 'Created',
                      value: dateLabel,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFilteredJobs extends StatelessWidget {
  const _NoFilteredJobs();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              'No jobs match this filter',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Try changing search or status filter.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _JobFilter { all, active, completed, cancelled }

bool _isActiveStatus(JobStatus status) =>
    status == JobStatus.posted ||
    status == JobStatus.bidding ||
    status == JobStatus.agreed ||
    status == JobStatus.paymentPending ||
    status == JobStatus.paid ||
    status == JobStatus.inProgress ||
    status == JobStatus.pendingDealerConfirm;

String _statusLabel(JobStatus status) {
  switch (status) {
    case JobStatus.paymentPending:
      return 'Payment pending';
    case JobStatus.inProgress:
      return 'In progress';
    case JobStatus.pendingDealerConfirm:
      return 'Awaiting confirmation';
    default:
      return status.name.replaceAll('_', ' ');
  }
}

Color _statusTone(JobStatus status) {
  switch (status) {
    case JobStatus.completed:
      return AppColors.success;
    case JobStatus.cancelled:
    case JobStatus.expired:
      return AppColors.error;
    case JobStatus.paymentPending:
    case JobStatus.pendingDealerConfirm:
      return AppColors.warning;
    default:
      return AppColors.primary;
  }
}
